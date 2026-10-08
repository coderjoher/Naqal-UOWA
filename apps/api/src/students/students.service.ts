import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { randomInt } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeIraqiPhone } from '../drivers/phone';
import { RosterRowDto, UpdateStudentProfileDto } from './students.dto';

export const ACTIVATION_TTL_DAYS = 7;

@Injectable()
export class StudentsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Office view: roster entries with their activation state. */
  async list() {
    const [roster, users] = await Promise.all([
      this.prisma.db.rosterEntry.findMany({ orderBy: { studentId: 'asc' } }),
      this.prisma.db.user.findMany({ where: { role: 'student' }, select: { studentId: true, id: true, phone: true, status: true } }),
    ]);
    const byId = new Map(users.map((u) => [u.studentId, u]));
    return roster.map((r) => ({
      id: r.id,
      studentId: r.studentId,
      name: r.name,
      nameAr: r.nameAr,
      gender: r.gender,
      activated: !!r.activatedAt,
      activationPending: !!r.activationExpiresAt && r.activationExpiresAt > new Date(),
      userId: byId.get(r.studentId)?.id ?? null,
      phone: byId.get(r.studentId)?.phone ?? null,
    }));
  }

  /** Upserts roster rows (e.g. from the registrar's CSV). Existing accounts follow the roster's name/gender. */
  async importRoster(universityId: string, rows: RosterRowDto[]) {
    const ids = rows.map((r) => r.studentId.trim());
    if (new Set(ids).size !== ids.length) throw new BadRequestException('The file contains the same student number twice');
    let created = 0;
    let updated = 0;
    await this.prisma.db.$transaction(async (tx) => {
      for (const r of rows) {
        const data = { name: r.name.trim(), nameAr: r.nameAr?.trim() || null, gender: r.gender };
        const existing = await tx.rosterEntry.findUnique({ where: { universityId_studentId: { universityId, studentId: r.studentId.trim() } } });
        if (existing) {
          await tx.rosterEntry.update({ where: { id: existing.id }, data });
          updated++;
        } else {
          await tx.rosterEntry.create({ data: { ...data, universityId, studentId: r.studentId.trim() } });
          created++;
        }
        await tx.user.updateMany({ where: { studentId: r.studentId.trim(), role: 'student' }, data });
      }
    });
    return { created, updated };
  }

  /** One-time 6-digit code the office hands to the student (shown once, stored hashed). */
  async issueActivationCode(studentId: string) {
    const entry = await this.prisma.db.rosterEntry.findFirst({ where: { studentId } });
    if (!entry) throw new NotFoundException('Student not in roster');
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    const expiresAt = new Date(Date.now() + ACTIVATION_TTL_DAYS * 86400_000);
    await this.prisma.db.rosterEntry.update({ where: { id: entry.id }, data: { activationCodeHash: await bcrypt.hash(code, 10), activationExpiresAt: expiresAt, activationAttempts: 0 } });
    return { studentId, code, expiresAt };
  }

  async profile(userId: string) {
    const u = await this.prisma.db.user.findUnique({
      where: { id: userId },
      select: { id: true, studentId: true, name: true, nameAr: true, gender: true, phone: true, defaultPoint: { select: { id: true, name: true, nameAr: true, tierId: true, active: true } }, university: { select: { taxiEnabled: true } } },
    });
    if (!u) throw new NotFoundException();
    const { university, ...rest } = u;
    // P10: the app shows the campus taxi entry only where the office has switched it on.
    return { ...rest, taxiEnabled: !!university?.taxiEnabled };
  }

  async updateProfile(userId: string, dto: UpdateStudentProfileDto) {
    if (dto.defaultPointId) {
      const point = await this.prisma.db.gatheringPoint.findUnique({ where: { id: dto.defaultPointId } });
      if (!point || !point.active) throw new BadRequestException('Choose an active gathering point');
    }
    await this.prisma.db.user.update({
      where: { id: userId },
      data: { phone: dto.phone === undefined ? undefined : normalizeIraqiPhone(dto.phone), defaultPointId: dto.defaultPointId },
    });
    return this.profile(userId);
  }
}
