import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { DriversService } from '../drivers/drivers.service';
import { officeViews } from '../common/swr-cache';
import { PrismaService } from '../prisma/prisma.service';
import { currentTenant, runAsTenant } from '../tenancy/tenant-context';
import { covers } from '../subscriptions/period-policy';
import { tierDifference } from '../subscriptions/pricing';
import { baghdadDate, dbDate, fromDbDate, isDate, runsOn, secondsInto } from './clock';
import { DispatchEngine } from './dispatch.engine';

/** How far ahead drivers may set availability (DR-02). */
export const AVAILABILITY_DAYS = 7;

const minute = (m: number) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;

@Injectable()
export class RidesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly engine: DispatchEngine,
    private readonly drivers: DriversService,
  ) {}

  // ── students ────────────────────────────────────────────────────────────────

  /** Wave slots a student can still request: the rest of today and tomorrow. */
  async options(studentId: string) {
    const now = this.engine.now();
    const student = await this.prisma.db.user.findUniqueOrThrow({ where: { id: studentId } });
    const waves = await this.prisma.db.wave.findMany({ where: { active: true }, orderBy: [{ minuteOfDay: 'asc' }] });
    const slots = [0, 1].flatMap((plus) => {
      const date = baghdadDate(now, plus);
      const at = secondsInto(date, now);
      return waves
        .filter((w) => runsOn(w.weekdays, date) && at < w.minuteOfDay * 60)
        .map((w) => ({ waveId: w.id, date, type: w.type, minuteOfDay: w.minuteOfDay, time: minute(w.minuteOfDay), today: plus === 0 }));
    });
    return { slots, defaultPointId: student.defaultPointId, gender: student.gender };
  }

  /** ST-04: create the request. Planning or insertion happens in a worker (NF-03). */
  async request(studentId: string, universityId: string, input: { waveId: string; date?: string; pointId?: string }) {
    const db = this.prisma.db;
    const now = this.engine.now();
    const student = await db.user.findUniqueOrThrow({ where: { id: studentId } });
    if (student.status !== 'active') throw new ForbiddenException('Your account is suspended');
    if (!student.gender) throw new UnprocessableEntityException('Your gender is missing from your university record. Please contact the transport office.');
    const date = input.date ?? baghdadDate(now);
    if (!isDate(date) || (date !== baghdadDate(now) && date !== baghdadDate(now, 1))) throw new BadRequestException('Rides can be requested for today or tomorrow');
    const wave = await db.wave.findUnique({ where: { id: input.waveId } });
    if (!wave || !wave.active || !runsOn(wave.weekdays, date)) throw new BadRequestException('This wave does not run on that day');
    if (secondsInto(date, now) >= wave.minuteOfDay * 60) throw new ConflictException('This wave has already left');
    const pointId = input.pointId ?? student.defaultPointId;
    if (!pointId) throw new BadRequestException('Choose a gathering point');
    const point = await db.gatheringPoint.findUnique({ where: { id: pointId }, include: { tier: true } });
    if (!point || !point.active) throw new BadRequestException('This gathering point is not available');

    // PA-02/PA-03: subscribers ride free in their tier (difference when farther); others pay the ride price.
    const subs = await db.subscription.findMany({ where: { studentId, status: 'active', periodEnd: { gte: dbDate(date) } }, take: 3 });
    const sub = subs.find((s) => covers({ start: s.periodStart, end: s.periodEnd }, new Date(`${date}T09:00:00Z`)));
    let fare = point.tier.ridePrice;
    if (sub) {
      const registered = await db.distanceTier.findUnique({ where: { id: sub.tierId } });
      fare = registered ? tierDifference(registered, point.tier) : 0;
    }

    let created;
    try {
      created = await db.rideRequest.create({
        data: { universityId, studentId, waveId: wave.id, date: dbDate(date), pointId, tierId: point.tierId, gender: student.gender, subscriber: !!sub, fare },
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') throw new ConflictException('You already have a request for this wave');
      throw e;
    }
    officeViews.invalidate(`${universityId}:`);
    if (await this.engine.isPlanned(wave.id, date)) await this.engine.enqueueRecheck({ universityId, waveId: wave.id, date });
    return this.view(created.id);
  }

  async cancel(studentId: string, universityId: string, id: string) {
    const req = await this.prisma.db.rideRequest.findFirst({ where: { id, studentId } });
    if (!req) throw new NotFoundException();
    await this.engine.cancel({ universityId, waveId: req.waveId, date: fromDbDate(req.date) }, id, 'student');
    return this.view(id);
  }

  /** ST-05/ST-07: today's and tomorrow's requests with assignment or waitlist details. */
  async mine(studentId: string) {
    const today = baghdadDate(this.engine.now());
    const rows = await this.prisma.db.rideRequest.findMany({
      where: { studentId, date: { gte: dbDate(today) } },
      orderBy: [{ date: 'asc' }, { createdAt: 'desc' }],
      select: { id: true },
      take: 10,
    });
    return Promise.all(rows.map((r) => this.view(r.id, studentId)));
  }

  private async view(id: string, viewerId?: string) {
    const db = this.prisma.db;
    const r = await db.rideRequest.findUniqueOrThrow({
      where: { id },
      include: {
        wave: true,
        point: true,
        run: { include: { driver: { include: { driver: true } }, stops: { orderBy: { seq: 'asc' } } } },
      },
    });
    let assignment = null;
    if (r.run && (r.status === 'assigned' || r.status === 'done')) {
      const stop = r.run.stops.find((s) => s.pointId === r.pointId);
      const link = await this.drivers.documentLink(r.run.driverId, 'vehicle_photo', viewerId ?? r.studentId, r.universityId, { reuse: true }).catch(() => null);
      assignment = {
        runId: r.run.id,
        driverName: r.run.driver.nameAr ?? r.run.driver.name,
        driverPhone: r.run.driver.loginPhone ?? r.run.driver.phone,
        plate: r.run.driver.driver?.plate ?? null,
        vehicleType: r.run.driver.driver?.vehicleType ?? null,
        vehiclePhotoUrl: link?.url ?? null,
        pickupAt: stop?.eta ?? null,
        stopNumber: stop ? stop.seq + 1 : null,
        stops: r.run.stops.length,
        runStatus: r.run.status,
      };
    }
    return {
      id: r.id,
      status: r.status,
      date: fromDbDate(r.date),
      wave: { id: r.wave.id, type: r.wave.type, minuteOfDay: r.wave.minuteOfDay, time: minute(r.wave.minuteOfDay) },
      point: { id: r.point.id, name: r.point.name, nameAr: r.point.nameAr },
      subscriber: r.subscriber,
      fare: r.fare,
      waitlistedUntil: r.waitlistedUntil,
      cancelReason: r.cancelReason,
      assignment,
      createdAt: r.createdAt,
    };
  }

  // ── drivers ─────────────────────────────────────────────────────────────────

  /** DR-02: the next days with the waves that run on each, and whether the driver offered them. */
  async availability(driverId: string) {
    const db = this.prisma.db;
    const now = this.engine.now();
    const dates = Array.from({ length: AVAILABILITY_DAYS }, (_, i) => baghdadDate(now, i));
    const [waves, mine, runs, plans] = await Promise.all([
      db.wave.findMany({ where: { active: true }, orderBy: [{ minuteOfDay: 'asc' }] }),
      db.driverAvailability.findMany({ where: { driverId, date: { gte: dbDate(dates[0]) } } }),
      db.run.findMany({ where: { driverId, date: { gte: dbDate(dates[0]) } }, select: { waveId: true, date: true } }),
      db.wavePlan.findMany({ where: { date: { gte: dbDate(dates[0]) } } }),
    ]);
    const has = (set: { waveId: string; date: Date }[], waveId: string, date: string) => set.some((x) => x.waveId === waveId && fromDbDate(x.date) === date);
    return dates.map((date) => ({
      date,
      waves: waves
        .filter((w) => runsOn(w.weekdays, date))
        .map((w) => ({
          waveId: w.id,
          type: w.type,
          time: minute(w.minuteOfDay),
          available: has(mine, w.id, date),
          // Locked once planned or past: the plan already counted on (or without) this driver.
          locked: has(plans, w.id, date) || has(runs, w.id, date) || secondsInto(date, now) >= w.minuteOfDay * 60,
        })),
    }));
  }

  async setAvailability(driverId: string, universityId: string, date: string, waveIds: string[]) {
    await this.drivers.assertApproved(driverId);
    const days = await this.availability(driverId);
    const day = days.find((d) => d.date === date);
    if (!day) throw new BadRequestException(`Availability can be set for the next ${AVAILABILITY_DAYS} days`);
    const want = new Set(waveIds);
    for (const id of want) if (!day.waves.some((w) => w.waveId === id)) throw new BadRequestException('Unknown wave for that day');
    for (const w of day.waves) {
      if (w.locked && w.available !== want.has(w.waveId)) throw new ConflictException(`The ${w.time} wave is already planned`);
    }
    const db = this.prisma.db;
    await db.$transaction(async (tx) => {
      await tx.driverAvailability.deleteMany({ where: { driverId, date: dbDate(date), waveId: { notIn: [...want] } } });
      for (const waveId of want) {
        await tx.driverAvailability.upsert({ where: { driverId_date_waveId: { driverId, date: dbDate(date), waveId } }, create: { universityId, driverId, date: dbDate(date), waveId }, update: {} });
      }
    });
    return (await this.availability(driverId)).find((d) => d.date === date);
  }

  /** DR-03: the driver's runs for a date with ordered stops and passengers per stop. */
  async driverRuns(driverId: string, date = baghdadDate(this.engine.now())) {
    if (!isDate(date)) throw new BadRequestException('Bad date');
    await this.drivers.assertApproved(driverId);
    const uni = await this.prisma.db.user.findUniqueOrThrow({ where: { id: driverId }, select: { university: { select: { noShowWaitMinutes: true } } } });
    const runs = await this.prisma.db.run.findMany({
      where: { driverId, date: dbDate(date), status: { not: 'cancelled' } },
      include: {
        wave: true,
        stops: { orderBy: { seq: 'asc' }, include: { point: true } },
        requests: { where: { status: { in: ['assigned', 'done'] } }, include: { student: true } },
      },
      orderBy: { wave: { minuteOfDay: 'asc' } },
    });
    return runs.map((run) => ({ ...this.runView(run), waitMinutes: uni.university?.noShowWaitMinutes ?? 3 }));
  }

  runView(run: {
    id: string;
    driverId: string;
    date: Date;
    gender: string;
    capacity: number;
    status: string;
    tierId: string;
    wave: { id: string; type: string; minuteOfDay: number };
    stops: { seq: number; eta: Date; servedAt: Date | null; point: { id: string; name: string; nameAr: string | null; lat: number; lng: number } }[];
    requests: { id: string; pointId: string; fare: number; subscriber: boolean; boardedAt: Date | null; student: { name: string; nameAr: string | null; studentId: string | null; phone: string | null } }[];
  }) {
    const morning = run.wave.type === 'morning';
    return {
      id: run.id,
      driverId: run.driverId,
      date: fromDbDate(run.date),
      status: run.status,
      gender: run.gender,
      femaleOnly: run.gender === 'female',
      tierId: run.tierId,
      capacity: run.capacity,
      booked: run.requests.length,
      wave: { id: run.wave.id, type: run.wave.type, time: minute(run.wave.minuteOfDay) },
      // Morning: leave for the first stop. Return: leave campus at the wave time.
      departAt: morning ? (run.stops[0]?.eta ?? null) : new Date(Date.parse(`${fromDbDate(run.date)}T00:00:00Z`) - 3 * 3600_000 + run.wave.minuteOfDay * 60_000),
      stops: run.stops.map((s) => {
        const riders = run.requests.filter((q) => q.pointId === s.point.id);
        return {
          seq: s.seq + 1,
          eta: s.eta,
          served: !!s.servedAt,
          point: { id: s.point.id, name: s.point.name, nameAr: s.point.nameAr, lat: s.point.lat, lng: s.point.lng },
          count: riders.length,
          cashToCollect: riders.reduce((n, q) => n + q.fare, 0),
          passengers: riders.map((q) => ({ requestId: q.id, name: q.student.nameAr ?? q.student.name, studentId: q.student.studentId, phone: q.student.phone, fare: q.fare, subscriber: q.subscriber, boarded: !!q.boardedAt })),
        };
      }),
    };
  }

  // ── transport office ───────────────────────────────────────────────────────

  /** Waves of a day with requests, runs and waitlist (operations view; live map in P5). */
  /** Office dispatch board (polled every 5 s): served from a short stale-while-revalidate cache. */
  async board(date: string) {
    if (!isDate(date)) throw new BadRequestException('Bad date');
    const uid = currentTenant()!.universityId!;
    return officeViews.get(`${uid}:board:${date}`, () => runAsTenant(uid, () => this.loadBoard(date)));
  }

  private async loadBoard(date: string) {
    const db = this.prisma.db;
    const [waves, plans, requests, runs, tiers] = await Promise.all([
      db.wave.findMany({ where: { active: true }, orderBy: [{ minuteOfDay: 'asc' }] }),
      db.wavePlan.findMany({ where: { date: dbDate(date) } }),
      db.rideRequest.findMany({ where: { date: dbDate(date) }, include: { student: true, point: true }, orderBy: { createdAt: 'asc' } }),
      db.run.findMany({
        where: { date: dbDate(date) },
        include: { wave: true, driver: { include: { driver: true } }, stops: { orderBy: { seq: 'asc' }, include: { point: true } }, requests: { where: { status: { in: ['assigned', 'done'] } }, include: { student: true } } },
      }),
      db.distanceTier.findMany(),
    ]);
    const tierName = new Map(tiers.map((t) => [t.id, t.name]));
    return waves
      .filter((w) => runsOn(w.weekdays, date))
      .map((w) => {
        const reqs = requests.filter((r) => r.waveId === w.id);
        const count = (s: string) => reqs.filter((r) => r.status === s).length;
        return {
          waveId: w.id,
          type: w.type,
          time: minute(w.minuteOfDay),
          planned: plans.some((p) => p.waveId === w.id),
          counts: { open: count('open'), assigned: count('assigned'), waitlisted: count('waitlisted'), cancelled: count('cancelled') },
          runs: runs
            .filter((r) => r.waveId === w.id)
            .map((r) => ({ ...this.runView(r), driverName: r.driver.nameAr ?? r.driver.name, plate: r.driver.driver?.plate ?? null, tierName: tierName.get(r.tierId) ?? null })),
          waitlist: reqs
            .filter((r) => r.status === 'waitlisted' || r.status === 'open')
            .map((r) => ({ id: r.id, status: r.status, name: r.student.nameAr ?? r.student.name, studentId: r.student.studentId, gender: r.gender, point: r.point.nameAr ?? r.point.name, subscriber: r.subscriber, until: r.waitlistedUntil })),
        };
      });
  }

  /** The wave and date a request belongs to (for locking). */
  async refOf(requestId: string) {
    const r = await this.prisma.db.rideRequest.findUnique({ where: { id: requestId } });
    if (!r) throw new NotFoundException('Request not found');
    return { universityId: r.universityId, waveId: r.waveId, date: fromDbDate(r.date) };
  }

  async freeDrivers(waveId: string, date: string) {
    if (!isDate(date) || !/^[0-9a-f-]{36}$/i.test(waveId ?? '')) throw new BadRequestException('Bad wave or date');
    const db = this.prisma.db;
    const busy = await db.run.findMany({ where: { waveId, date: dbDate(date) }, select: { driverId: true } });
    const offered = await db.driverAvailability.findMany({ where: { waveId, date: dbDate(date) }, select: { driverId: true } });
    const drivers = await db.user.findMany({
      where: { role: 'driver', status: 'active', id: { notIn: busy.map((b) => b.driverId) }, driver: { status: 'approved', seats: { gt: 0 } } },
      include: { driver: true },
      orderBy: { name: 'asc' },
    });
    const offeredIds = new Set(offered.map((o) => o.driverId));
    return drivers
      .map((d) => ({ id: d.id, name: d.nameAr ?? d.name, plate: d.driver?.plate ?? null, seats: d.driver?.seats ?? 0, offered: offeredIds.has(d.id) }))
      .sort((a, b) => Number(b.offered) - Number(a.offered));
  }
}
