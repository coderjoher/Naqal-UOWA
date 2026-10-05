import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { baghdadDate, dbDate } from '../dispatch/clock';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

const PAGE = 20;
const minute = (m: number) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
const take = (limit?: number) => Math.min(Math.max(limit ?? PAGE, 1), 50);

/** ST-10 / ST-11: ride and payment history, ratings, problem reports and the office inbox. */
@Injectable()
export class FeedbackService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /** ST-10: past and closed rides, newest first, page by page. */
  async rideHistory(studentId: string, cursor?: string, limit?: number) {
    const n = take(limit);
    const today = dbDate(baghdadDate(new Date()));
    const rows = await this.prisma.db.rideRequest.findMany({
      where: { studentId, OR: [{ date: { lt: today } }, { status: { in: ['done', 'no_show', 'cancelled'] } }] },
      include: { wave: true, point: true, run: { include: { driver: { include: { driver: true } } } } },
      orderBy: [{ date: 'desc' }, { createdAt: 'desc' }, { id: 'desc' }],
      take: n + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    const page = rows.slice(0, n);
    const ratings = await this.prisma.db.rideRating.findMany({ where: { requestId: { in: page.map((r) => r.id) } } });
    const stars = new Map(ratings.map((r) => [r.requestId, r.stars]));
    return {
      items: page.map((r) => ({
        id: r.id,
        date: r.date.toISOString().slice(0, 10),
        waveType: r.wave.type,
        waveTime: minute(r.wave.minuteOfDay),
        point: { name: r.point.name, nameAr: r.point.nameAr },
        status: r.status,
        cancelReason: r.cancelReason,
        fare: r.fare,
        driverName: r.run ? (r.run.driver.nameAr ?? r.run.driver.name) : null,
        plate: r.run?.driver.driver?.plate ?? null,
        rating: stars.get(r.id) ?? null,
        canRate: r.status === 'done' && !!r.runId && !stars.has(r.id),
      })),
      next: rows.length > n ? page[page.length - 1].id : null,
    };
  }

  /** ST-10: every payment the student made (and any reversal), newest first. */
  async paymentHistory(studentId: string, cursor?: string, limit?: number) {
    const n = take(limit);
    const rows = await this.prisma.db.payment.findMany({
      where: { studentId },
      include: { subscription: { select: { month: true } }, reverses: { include: { subscription: { select: { month: true } } } } },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: n + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    const page = rows.slice(0, n);
    return {
      items: page.map((p) => ({
        id: p.id,
        type: p.type,
        method: p.method,
        amount: p.amount,
        receiptNo: p.receiptNo,
        month: p.subscription?.month ?? p.reverses?.subscription?.month ?? null,
        reversal: p.amount < 0,
        createdAt: p.createdAt,
      })),
      next: rows.length > n ? page[page.length - 1].id : null,
    };
  }

  /** ST-11: 1–5 stars once per finished ride. */
  async rate(studentId: string, universityId: string, requestId: string, stars: number, comment?: string) {
    const req = await this.prisma.db.rideRequest.findUnique({ where: { id: requestId }, include: { run: true } });
    if (!req) throw new NotFoundException('Ride not found');
    if (req.studentId !== studentId) throw new ForbiddenException('Not your ride');
    if (req.status !== 'done' || !req.run) throw new ConflictException('Only a finished ride can be rated');
    try {
      return await this.prisma.db.rideRating.create({
        data: { universityId, requestId, studentId, driverId: req.run.driverId, runId: req.run.id, stars, comment: comment?.trim() || null },
        select: { id: true, requestId: true, stars: true, comment: true, createdAt: true },
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') throw new ConflictException('You have already rated this ride');
      throw e;
    }
  }

  /** ST-11: report a problem; it lands in the office inbox. */
  async report(studentId: string, universityId: string, input: { category: string; text: string; requestId?: string }) {
    if (input.requestId) {
      const req = await this.prisma.db.rideRequest.findUnique({ where: { id: input.requestId } });
      if (!req || req.studentId !== studentId) throw new BadRequestException('Unknown ride');
    }
    return this.prisma.db.problemReport.create({
      data: { universityId, studentId, requestId: input.requestId ?? null, category: input.category, text: input.text.trim() },
      select: { id: true, category: true, text: true, status: true, createdAt: true },
    });
  }

  myProblems(studentId: string) {
    return this.prisma.db.problemReport.findMany({
      where: { studentId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: { id: true, category: true, text: true, status: true, reply: true, resolvedAt: true, createdAt: true },
    });
  }

  /** Office inbox: problem reports (open first) with the student and ride. */
  async inbox(status?: 'open' | 'resolved') {
    const rows = await this.prisma.db.problemReport.findMany({
      where: status ? { status } : {},
      include: { student: { select: { name: true, nameAr: true, studentId: true, phone: true } } },
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
      take: 200,
    });
    const reqs = await this.prisma.db.rideRequest.findMany({
      where: { id: { in: rows.map((r) => r.requestId).filter((x): x is string => !!x) } },
      include: { wave: true, run: { include: { driver: true } } },
    });
    const byId = new Map(reqs.map((r) => [r.id, r]));
    return rows.map((r) => {
      const q = r.requestId ? byId.get(r.requestId) : undefined;
      return {
        id: r.id,
        category: r.category,
        text: r.text,
        status: r.status,
        reply: r.reply,
        createdAt: r.createdAt,
        resolvedAt: r.resolvedAt,
        student: r.student,
        ride: q ? { date: q.date.toISOString().slice(0, 10), waveType: q.wave.type, waveTime: minute(q.wave.minuteOfDay), driverName: q.run ? (q.run.driver.nameAr ?? q.run.driver.name) : null } : null,
      };
    });
  }

  /** The office answers and closes a report; the student is notified. */
  async resolve(id: string, universityId: string, actorId: string, reply: string) {
    const r = await this.prisma.db.problemReport.findUnique({ where: { id } });
    if (!r) throw new NotFoundException('Report not found');
    if (r.status === 'resolved') throw new ConflictException('Already answered');
    const updated = await this.prisma.db.problemReport.update({
      where: { id },
      data: { status: 'resolved', reply: reply.trim(), resolvedById: actorId, resolvedAt: new Date() },
    });
    await this.notifications.addNow(universityId, [{ userId: r.studentId, kind: 'problem.answered', dedupeKey: `problem:${id}`, data: { problemId: id, reply: reply.trim() } }]);
    return updated;
  }

  /** Ratings overview for the office: recent ratings and the average per driver. */
  async ratings() {
    const db = this.prisma.db;
    const recent = await db.rideRating.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: { driver: { select: { name: true, nameAr: true } }, student: { select: { name: true, nameAr: true } } },
    });
    const avg = await db.rideRating.groupBy({ by: ['driverId'], _avg: { stars: true }, _count: true });
    const drivers = await db.user.findMany({ where: { id: { in: avg.map((a) => a.driverId) } }, select: { id: true, name: true, nameAr: true } });
    const names = new Map(drivers.map((d) => [d.id, d.nameAr ?? d.name]));
    return {
      drivers: avg
        .map((a) => ({ driverId: a.driverId, name: names.get(a.driverId) ?? '', average: Math.round((a._avg.stars ?? 0) * 10) / 10, count: a._count }))
        .sort((a, b) => a.average - b.average),
      recent: recent.map((r) => ({ id: r.id, stars: r.stars, comment: r.comment, createdAt: r.createdAt, driver: r.driver.nameAr ?? r.driver.name, student: r.student.nameAr ?? r.student.name })),
    };
  }
}
