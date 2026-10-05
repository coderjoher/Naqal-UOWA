import { BadRequestException, Injectable } from '@nestjs/common';
import { baghdadDate, dbDate, isDate, midnight } from '../dispatch/clock';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { runAsTenant } from '../tenancy/tenant-context';

export interface AnnouncementInput {
  title: string;
  body: string;
  target: 'all' | 'wave' | 'point';
  waveId?: string;
  date?: string;
  pointId?: string;
  /** How long the in-app banner stays (all / point targets). Default 3 days. */
  days?: number;
}

const LIVE = ['open', 'assigned', 'waitlisted'] as const;

/**
 * TO-11: the office writes to all students, the students of one wave on one date, or the students
 * of one gathering point. Each recipient gets a push and an in-app banner until it expires.
 */
@Injectable()
export class AnnouncementsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Who receives it: active students only, each once. */
  async recipients(input: AnnouncementInput): Promise<string[]> {
    const db = this.prisma.db;
    const today = dbDate(baghdadDate(new Date()));
    let ids: string[];
    switch (input.target) {
      case 'all':
        ids = (await db.user.findMany({ where: { role: 'student', status: 'active' }, select: { id: true } })).map((u) => u.id);
        break;
      case 'wave': {
        if (!input.waveId || !input.date || !isDate(input.date)) throw new BadRequestException('Choose the wave and its date');
        const reqs = await db.rideRequest.findMany({ where: { waveId: input.waveId, date: dbDate(input.date), status: { in: [...LIVE] } }, select: { studentId: true } });
        ids = reqs.map((r) => r.studentId);
        break;
      }
      case 'point': {
        if (!input.pointId) throw new BadRequestException('Choose the gathering point');
        const home = await db.user.findMany({ where: { role: 'student', status: 'active', defaultPointId: input.pointId }, select: { id: true } });
        const riding = await db.rideRequest.findMany({ where: { pointId: input.pointId, date: { gte: today }, status: { in: [...LIVE] } }, select: { studentId: true } });
        ids = [...home.map((u) => u.id), ...riding.map((r) => r.studentId)];
        break;
      }
      default:
        throw new BadRequestException('Unknown target');
    }
    const active = await db.user.findMany({ where: { id: { in: [...new Set(ids)] }, status: 'active' }, select: { id: true } });
    return active.map((u) => u.id).sort();
  }

  async create(universityId: string, actorId: string, input: AnnouncementInput) {
    const ids = await this.recipients(input);
    // A wave message is about that wave: it disappears at the end of its day.
    const expiresAt =
      input.target === 'wave' ? new Date(midnight(input.date!) + 24 * 3600_000) : new Date(Date.now() + Math.min(Math.max(input.days ?? 3, 1), 30) * 86400_000);
    const a = await this.prisma.db.announcement.create({
      data: {
        universityId,
        title: input.title.trim(),
        body: input.body.trim(),
        target: input.target,
        waveId: input.target === 'wave' ? input.waveId : null,
        date: input.target === 'wave' ? dbDate(input.date!) : null,
        pointId: input.target === 'point' ? input.pointId : null,
        recipients: ids.length,
        createdById: actorId,
        expiresAt,
      },
    });
    await this.notifications.addNow(
      universityId,
      ids.map((userId) => ({ userId, kind: 'announcement' as const, dedupeKey: `ann:${a.id}:${userId}`, data: { announcementId: a.id, title: a.title, body: a.body, expiresAt: expiresAt.toISOString() } })),
    );
    return a;
  }

  async list() {
    const rows = await this.prisma.db.announcement.findMany({ orderBy: { createdAt: 'desc' }, take: 100 });
    const [waves, points] = await Promise.all([
      this.prisma.db.wave.findMany({ where: { id: { in: rows.map((r) => r.waveId).filter((x): x is string => !!x) } } }),
      this.prisma.db.gatheringPoint.findMany({ where: { id: { in: rows.map((r) => r.pointId).filter((x): x is string => !!x) } } }),
    ]);
    return rows.map((r) => {
      const w = waves.find((x) => x.id === r.waveId);
      const p = points.find((x) => x.id === r.pointId);
      return {
        ...r,
        date: r.date?.toISOString().slice(0, 10) ?? null,
        wave: w ? { type: w.type, time: `${String(Math.floor(w.minuteOfDay / 60)).padStart(2, '0')}:${String(w.minuteOfDay % 60).padStart(2, '0')}` } : null,
        point: p ? { name: p.name, nameAr: p.nameAr } : null,
      };
    });
  }

  /** In-app banner: the student's announcements that have not expired and were not dismissed. */
  async active(userId: string, universityId: string) {
    const rows = await runAsTenant(universityId, () =>
      this.prisma.db.notification.findMany({ where: { userId, kind: 'announcement', readAt: null }, orderBy: { createdAt: 'desc' }, take: 20 }),
    );
    const now = Date.now();
    return rows
      .map((n) => ({ id: n.id, ...(n.data as { announcementId: string; title: string; body: string; expiresAt: string }), createdAt: n.createdAt }))
      .filter((n) => Date.parse(n.expiresAt) > now);
  }
}
