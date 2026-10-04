import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { isPolygon } from '../geo/geo';
import { PrismaService } from '../prisma/prisma.service';
import { RoutingService } from '../routing/routing.service';
import { CreateUniversityDto, UpdateUniversityDto } from './universities.dto';

@Injectable()
export class UniversitiesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly routing: RoutingService,
  ) {}

  private checkCoverage(coverage: unknown) {
    if (coverage === undefined) return;
    if (!isPolygon(coverage) || (coverage.length > 0 && coverage.length < 3)) throw new BadRequestException('Coverage must be a polygon of at least 3 [lat, lng] points');
  }

  list() {
    return this.prisma.db.university.findMany({ orderBy: { createdAt: 'asc' } });
  }

  async get(id: string) {
    const u = await this.prisma.db.university.findUnique({ where: { id } });
    if (!u) throw new NotFoundException();
    return u;
  }

  /** SA-01: university + optional first transport-office account, in one transaction. */
  async create(dto: CreateUniversityDto) {
    this.checkCoverage(dto.coverage);
    const { officeAccount, ...data } = dto;
    try {
      return await this.prisma.db.$transaction(async (tx) => {
        const uni = await tx.university.create({ data: { ...data, coverage: data.coverage ?? [] } });
        if (officeAccount) {
          await tx.user.create({
            data: {
              universityId: uni.id,
              role: 'office',
              name: officeAccount.name,
              email: officeAccount.email.toLowerCase(),
              passwordHash: await bcrypt.hash(officeAccount.password, 10),
            },
          });
        }
        return uni;
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') throw new ConflictException('Slug or office email already in use');
      throw e;
    }
  }

  /** SA-02 / SA-03 and campus/coverage edits. */
  async update(id: string, dto: UpdateUniversityDto) {
    this.checkCoverage(dto.coverage);
    const before = await this.get(id);
    const uni = await this.prisma.db.university.update({ where: { id }, data: dto });
    if (before.campusLat !== uni.campusLat || before.campusLng !== uni.campusLng) await this.routing.scheduleMatrixRebuild(id);
    return uni;
  }
}
