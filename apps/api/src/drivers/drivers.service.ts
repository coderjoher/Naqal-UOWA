import { BadRequestException, ConflictException, ForbiddenException, Inject, Injectable, NotFoundException, UnauthorizedException, UnprocessableEntityException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { DriverRequirementsService } from '../driver-requirements/requirements.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { runAsSystem, runAsTenant } from '../tenancy/tenant-context';
import { DriverStatus, editable, missingRequirements, nextStatus, ReviewAction } from './driver-rules';
import { UpdateApplicationDto } from './drivers.dto';
import { OtpService, SMS_SENDER, SmsSender } from './otp.service';
import { normalizeIraqiPhone } from './phone';

export const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);
export const MAX_DOC_BYTES = 8 * 1024 * 1024;

@Injectable()
export class DriversService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly otp: OtpService,
    private readonly storage: StorageService,
    private readonly requirements: DriverRequirementsService,
    @Inject(SMS_SENDER) private readonly sms: SmsSender,
  ) {}

  private phone(input: string) {
    try {
      return normalizeIraqiPhone(input);
    } catch {
      throw new BadRequestException('Enter an Iraqi mobile number');
    }
  }

  requestOtp(phone: string) {
    return this.otp.issue(this.phone(phone), this.sms);
  }

  /** DR-01 sign-in: phone + code. First time creates the driver (draft application) in the chosen university. */
  async verifyOtp(phoneInput: string, code: string, universitySlug?: string) {
    const phone = this.phone(phoneInput);
    if (!(await this.otp.consume(phone, code))) throw new UnauthorizedException('The code is wrong or has expired');
    const user = await runAsSystem(async () => {
      const existing = await this.prisma.db.user.findUnique({ where: { loginPhone: phone } });
      if (existing) {
        if (existing.role !== 'driver') throw new ForbiddenException('This number belongs to another account type');
        return existing;
      }
      if (!universitySlug) throw new BadRequestException('Choose your university');
      const uni = await this.prisma.db.university.findUnique({ where: { slug: universitySlug } });
      if (!uni) throw new NotFoundException('Unknown university');
      return this.prisma.db.$transaction(async (tx) => {
        const u = await tx.user.create({ data: { universityId: uni.id, role: 'driver', name: '', phone, loginPhone: phone } });
        await tx.driverProfile.create({ data: { userId: u.id, universityId: uni.id } });
        return u;
      });
    });
    if (user.status !== 'active') throw new UnauthorizedException('Account suspended');
    const accessToken = await this.jwt.signAsync({ sub: user.id, role: 'driver', uid: user.universityId });
    return { accessToken, user: { id: user.id, name: user.name, role: 'driver', universityId: user.universityId } };
  }

  /** The driver's own application with what is still missing. */
  async mine(userId: string, universityId: string) {
    // Drivers created outside the OTP flow (seed, office import) get their draft application on first visit.
    const p = await this.prisma.db.driverProfile.upsert({
      where: { userId },
      create: { userId, universityId },
      update: {},
      include: { user: true, documents: true },
    });
    const req = await this.requirements.get(universityId);
    return {
      status: p.status as DriverStatus,
      reviewNote: p.reviewNote,
      application: { name: p.user.name || null, phone: p.user.phone, vehicleType: p.vehicleType, plate: p.plate, seats: p.seats, modelYear: p.modelYear },
      documents: p.documents.map((d) => ({ key: d.key, mime: d.mime, sizeBytes: d.sizeBytes, uploadedAt: d.uploadedAt })),
      missing: missingRequirements(this.application(p), req, { taxi: await this.requirements.taxiEnabled(universityId) }),
      form: await this.requirements.registrationForm(universityId),
    };
  }

  private application(p: { user: { name: string; phone: string | null }; vehicleType: string | null; plate: string | null; seats: number | null; modelYear: number | null; documents: { key: string }[] }) {
    return { name: p.user.name || null, phone: p.user.phone, vehicleType: p.vehicleType, plate: p.plate, seats: p.seats, modelYear: p.modelYear, documentKeys: p.documents.map((d) => d.key) };
  }

  private async editableProfile(userId: string) {
    const p = await this.prisma.db.driverProfile.findUnique({ where: { userId } });
    if (!p) throw new NotFoundException();
    if (!editable(p.status as DriverStatus)) throw new ConflictException('The application is under review or already approved');
    return p;
  }

  async update(userId: string, universityId: string, dto: UpdateApplicationDto) {
    await this.editableProfile(userId);
    const db = this.prisma.db;
    await db.$transaction([
      db.user.update({ where: { id: userId }, data: { name: dto.name?.trim() } }),
      db.driverProfile.update({ where: { userId }, data: { vehicleType: dto.vehicleType, plate: dto.plate?.trim(), seats: dto.seats, modelYear: dto.modelYear } }),
    ]);
    return this.mine(userId, universityId);
  }

  async upload(userId: string, universityId: string, key: string, file: { buffer: Buffer; mimetype: string; size: number } | undefined) {
    await this.editableProfile(userId);
    if (!file) throw new BadRequestException('Attach a file');
    if (!ALLOWED_MIME.has(file.mimetype)) throw new UnprocessableEntityException('Upload a photo (JPEG, PNG, WebP) or a PDF');
    if (file.size > MAX_DOC_BYTES) throw new UnprocessableEntityException('The file is larger than 8 MB');
    const req = await this.requirements.get(universityId);
    if (!req.documents.some((d) => d.key === key)) throw new BadRequestException('This document is not requested by the transport office');
    const storageKey = await this.storage.put(`drivers/${universityId}/${userId}`, file.buffer);
    await this.prisma.db.driverDocument.upsert({
      where: { driverId_key: { driverId: userId, key } },
      create: { universityId, driverId: userId, key, storageKey, mime: file.mimetype, sizeBytes: file.size },
      update: { storageKey, mime: file.mimetype, sizeBytes: file.size, uploadedAt: new Date() },
    });
    return this.mine(userId, universityId);
  }

  /** DR-01 / T2-06: refuses until every requirement from TO-01 is met. */
  async submit(userId: string, universityId: string) {
    await this.editableProfile(userId);
    const current = await this.mine(userId, universityId);
    if (current.missing.length) throw new UnprocessableEntityException({ message: 'The application is incomplete', missing: current.missing });
    await this.prisma.db.driverProfile.update({ where: { userId }, data: { status: 'pending', submittedAt: new Date(), reviewNote: null } });
    return this.mine(userId, universityId);
  }

  // ---------------- Office (TO-02) ----------------

  async list(status?: DriverStatus) {
    const rows = await this.prisma.db.driverProfile.findMany({
      where: status ? { status } : { status: { not: 'draft' } },
      include: { user: { select: { name: true, phone: true } }, documents: { select: { key: true } } },
      orderBy: [{ submittedAt: 'desc' }],
    });
    return rows.map((r) => ({
      id: r.userId,
      name: r.user.name,
      phone: r.user.phone,
      status: r.status,
      vehicleType: r.vehicleType,
      plate: r.plate,
      seats: r.seats,
      modelYear: r.modelYear,
      documents: r.documents.map((d) => d.key),
      submittedAt: r.submittedAt,
      reviewedAt: r.reviewedAt,
      reviewNote: r.reviewNote,
    }));
  }

  async detail(driverId: string, universityId: string) {
    const p = await this.prisma.db.driverProfile.findUnique({ where: { userId: driverId }, include: { user: true, documents: true } });
    if (!p) throw new NotFoundException();
    const req = await this.requirements.get(universityId);
    return {
      id: p.userId,
      name: p.user.name,
      phone: p.user.phone,
      status: p.status,
      reviewNote: p.reviewNote,
      submittedAt: p.submittedAt,
      reviewedAt: p.reviewedAt,
      vehicleType: p.vehicleType,
      plate: p.plate,
      seats: p.seats,
      modelYear: p.modelYear,
      documents: req.documents.map((d) => {
        const doc = p.documents.find((x) => x.key === d.key);
        return { key: d.key, label: d.label, labelAr: d.labelAr, required: d.required, uploaded: !!doc, mime: doc?.mime ?? null, uploadedAt: doc?.uploadedAt ?? null };
      }),
      missing: missingRequirements(this.application(p), req, { taxi: await this.requirements.taxiEnabled(p.universityId) }),
    };
  }

  async review(driverId: string, reviewerId: string, action: ReviewAction, note?: string) {
    const p = await this.prisma.db.driverProfile.findUnique({ where: { userId: driverId } });
    if (!p) throw new NotFoundException();
    const to = nextStatus(p.status as DriverStatus, action);
    if (!to) throw new ConflictException(`Cannot ${action} a driver who is ${p.status}`);
    if ((action === 'reject' || action === 'suspend') && !note?.trim()) throw new BadRequestException('Give the driver a reason');
    await this.prisma.db.driverProfile.update({ where: { userId: driverId }, data: { status: to, reviewedAt: new Date(), reviewedById: reviewerId, reviewNote: note?.trim() || null } });
    return { id: driverId, status: to };
  }

  /** NF-13: a short-lived link for one document; every issuance is logged with who and when. */
  async documentLink(driverId: string, key: string, viewerId: string, universityId: string, opts: { reuse?: boolean } = {}) {
    const doc = await this.prisma.db.driverDocument.findFirst({ where: { driverId, key } });
    if (!doc) throw new NotFoundException();
    // A student's app asks for the bus photo on every refresh: reuse the link already issued (and
    // logged) to them while it has a few minutes left, instead of logging a new access each time.
    if (opts.reuse) {
      const issued = await this.prisma.db.documentAccess.findFirst({ where: { documentId: doc.id, userId: viewerId, expiresAt: { gt: new Date(Date.now() + 120_000) } }, orderBy: { expiresAt: 'desc' } });
      if (issued) {
        const { token, expiresAt } = this.storage.signUntil(doc.storageKey, doc.mime, Math.floor(issued.expiresAt.getTime() / 1000));
        return { url: `/files/${token}`, expiresAt };
      }
    }
    const { token, expiresAt } = this.storage.sign(doc.storageKey, doc.mime);
    await this.prisma.db.documentAccess.create({ data: { universityId, documentId: doc.id, userId: viewerId, expiresAt } });
    return { url: `/files/${token}`, expiresAt };
  }

  /** Guard used by run endpoints: only approved drivers may operate (T2-08). */
  async assertApproved(userId: string) {
    const p = await this.prisma.db.driverProfile.findUnique({ where: { userId } });
    if (!p || p.status !== 'approved') throw new ForbiddenException(p?.status === 'suspended' ? 'Your account is suspended by the transport office' : 'Your application is not approved yet');
  }
}

export { runAsTenant };
