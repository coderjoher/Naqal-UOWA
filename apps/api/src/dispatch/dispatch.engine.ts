import { InjectQueue } from '@nestjs/bullmq';
import { ConflictException, Injectable, Logger } from '@nestjs/common';
import { RideRequest, Run as DbRun, RunStop as DbStop } from '@prisma/client';
import { Queue } from 'bullmq';
import { haversineKm } from '../geo/geo';
import { LiveHub } from '../live/live.hub';
import { NotificationsService } from '../notifications/notifications.service';
import { notificationsFor } from '../notifications/rules';
import { PrismaService, Tx } from '../prisma/prisma.service';
import { CAMPUS_KEY } from '../routing/travel-matrix.processor';
import { runAsTenant } from '../tenancy/tenant-context';
import { dbDate, instantAt, secondsInto } from './clock';
import { cancelRequest, insertRequest, planWave, recheckWaitlist } from './domain/dispatch';
import { CAMPUS, Ctx, DEFAULT_CONFIG, DispatchEvent, Passenger, Run, TravelFn, WaitlistEntry } from './domain/types';

export const DISPATCH_QUEUE = 'dispatch';
export const WAVE_PLAN = 'wave.plan';
export const WAITLIST_RECHECK = 'waitlist.recheck';
export const WAITLIST_EXPIRE = 'waitlist.expire';
export const WAVE_TICK = 'wave.tick';
/** Waves are planned this many minutes before the wave time (DS-02). */
export const PLAN_LEAD_MIN = 60;

export interface WaveRef {
  universityId: string;
  waveId: string;
  date: string;
}

type LoadedRun = DbRun & { stops: DbStop[]; requests: RideRequest[] };

/**
 * Glue between the pure dispatch domain and the database. Every change to one wave on one date
 * runs in a transaction holding an advisory lock for that wave and date, so planning, insertions,
 * cancellations and expiries never interleave.
 */
@Injectable()
export class DispatchEngine {
  private readonly log = new Logger(DispatchEngine.name);

  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(DISPATCH_QUEUE) private readonly queue: Queue,
    private readonly hub: LiveHub,
    private readonly notifications: NotificationsService,
  ) {}

  /** Overridable in tests. */
  now() {
    return new Date();
  }

  // ── public operations ───────────────────────────────────────────────────────

  /** DS-02: plan the wave once; later calls fall through to a re-check. */
  async plan(ref: WaveRef) {
    const out = await this.locked(ref, async (tx) => {
      const done = await tx.wavePlan.findUnique({ where: { waveId_date: { waveId: ref.waveId, date: dbDate(ref.date) } } });
      if (done) return this.recheckIn(tx, ref);
      const s = await this.load(tx, ref);
      const used = new Set(s.dbRuns.map((r) => r.driverId));
      const available = await tx.driverAvailability.findMany({
        where: { waveId: ref.waveId, date: dbDate(ref.date), driver: { status: 'active', driver: { status: 'approved', seats: { gt: 0 } } } },
        include: { driver: { include: { driver: true } } },
      });
      const drivers = available.filter((a) => !used.has(a.driverId)).map((a) => ({ id: a.driverId, seats: a.driver.driver!.seats! }));
      const open = s.requests.filter((r) => r.status === 'open').map((r) => s.passenger(r));
      const plan = planWave(open, drivers, s.ctx);
      const after = [...s.domainRuns, ...plan.runs];
      const events: DispatchEvent[] = plan.runs.flatMap((r) => r.stops.flatMap((st) => st.passengers.map((p) => ({ type: 'assigned' as const, requestId: p.id, runId: r.id }))));
      const waitlist = plan.waitlisted.map((p) => ({ passenger: p, expiresAt: s.waitlistUntil }));
      events.push(...waitlist.map((w) => ({ type: 'waitlisted' as const, requestId: w.passenger.id })));
      const result = await this.save(tx, s, after, waitlist, events);
      await tx.wavePlan.create({ data: { universityId: ref.universityId, waveId: ref.waveId, date: dbDate(ref.date) } });
      this.log.log(`Planned wave ${ref.waveId} ${ref.date}: ${plan.runs.length} runs, ${plan.waitlisted.length} waitlisted`);
      return result;
    });
    await this.afterCommit(ref, out);
    return out.summary;
  }

  /** DS-03/DS-04: seat open requests and the waitlist; expire overdue entries. No-op before planning. */
  async recheck(ref: WaveRef) {
    const out = await this.locked(ref, async (tx) => {
      const done = await tx.wavePlan.findUnique({ where: { waveId_date: { waveId: ref.waveId, date: dbDate(ref.date) } } });
      if (!done) return { summary: { planned: false, runs: 0, assigned: 0, waitlisted: 0 }, expiries: [], changed: [] };
      return this.recheckIn(tx, ref);
    });
    await this.afterCommit(ref, out);
    return out.summary;
  }

  /** ST-08: cancel before pickup. Frees the seat and triggers a re-check. */
  async cancel(ref: WaveRef, requestId: string, reason: 'student' | 'office') {
    const out = await this.locked(ref, async (tx) => {
      let changed: { runId: string; driverId: string }[] = [];
      const req = await tx.rideRequest.findUniqueOrThrow({ where: { id: requestId } });
      if (req.status === 'cancelled' || req.status === 'done' || req.status === 'no_show') throw new ConflictException('This request is already closed');
      if (req.boardedAt) throw new ConflictException('You have already been picked up');
      if (req.status === 'assigned') {
        const s = await this.load(tx, ref);
        const r = cancelRequest(s.domainRuns, requestId, s.ctx);
        if (!r.freed) throw new ConflictException('The bus has already passed your stop');
        changed = (await this.save(tx, s, r.runs, [], [])).changed;
      }
      await tx.rideRequest.update({ where: { id: requestId }, data: { status: 'cancelled', cancelReason: reason, runId: null, waitlistedUntil: null } });
      return { expiries: [], changed };
    });
    await this.afterCommit(ref, out);
    await this.enqueueRecheck(ref);
  }

  async enqueueRecheck(ref: WaveRef, delayMs = 0) {
    await this.queue.add(WAITLIST_RECHECK, ref, { delay: delayMs, removeOnComplete: true, removeOnFail: 100, attempts: 3, backoff: { type: 'exponential', delay: 1000 } });
  }

  async enqueuePlan(ref: WaveRef) {
    await this.queue.add(WAVE_PLAN, ref, { jobId: `plan-${ref.waveId}-${ref.date}`, removeOnComplete: true, removeOnFail: 100, attempts: 3, backoff: { type: 'exponential', delay: 2000 } });
  }

  async isPlanned(waveId: string, date: string) {
    return !!(await this.prisma.db.wavePlan.findUnique({ where: { waveId_date: { waveId, date: dbDate(date) } } }));
  }

  // ── internals ───────────────────────────────────────────────────────────────

  /** Also used by run actions, so they never interleave with dispatch on the same wave. */
  async locked<T>(ref: WaveRef, fn: (tx: Tx) => Promise<T>): Promise<T> {
    return runAsTenant(ref.universityId, () =>
      this.prisma.db.$transaction(
        async (tx) => {
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${`dispatch:${ref.waveId}:${ref.date}`}))`;
          return fn(tx as Tx);
        },
        { timeout: 60_000, maxWait: 30_000 },
      ),
    );
  }

  private async recheckIn(tx: Tx, ref: WaveRef) {
    const s = await this.load(tx, ref);
    const entries: WaitlistEntry[] = s.requests
      .filter((r) => r.status === 'open' || r.status === 'waitlisted')
      .map((r) => ({ passenger: s.passenger(r), expiresAt: r.waitlistedUntil ? secondsInto(ref.date, r.waitlistedUntil) : s.waitlistUntil }));
    const r = recheckWaitlist(s.domainRuns, entries, s.ctx, s.waitlistUntil - s.ctx.now);
    // Open requests that found no seat join the waitlist now.
    const newlyWaiting = r.waitlist.filter((w) => s.requests.find((q) => q.id === w.passenger.id)?.status === 'open');
    r.events.push(...newlyWaiting.map((w) => ({ type: 'waitlisted' as const, requestId: w.passenger.id })));
    return this.save(tx, s, r.runs, r.waitlist, r.events);
  }

  private async load(tx: Tx, ref: WaveRef) {
    const date = dbDate(ref.date);
    const [uni, wave, tiers, dbRuns, requests] = await Promise.all([
      tx.university.findUniqueOrThrow({ where: { id: ref.universityId } }),
      tx.wave.findUniqueOrThrow({ where: { id: ref.waveId } }),
      tx.distanceTier.findMany({ orderBy: { minKm: 'asc' } }),
      tx.run.findMany({ where: { waveId: ref.waveId, date, status: { in: ['planned', 'started', 'at_stop'] } }, include: { stops: { orderBy: { seq: 'asc' } }, requests: { where: { status: { in: ['assigned', 'no_show'] } } } } }),
      tx.rideRequest.findMany({ where: { waveId: ref.waveId, date, status: { in: ['open', 'assigned', 'waitlisted'] } }, orderBy: { createdAt: 'asc' } }),
    ]);
    const rank = new Map(tiers.map((t, i) => [t.id, i]));
    const nowAt = this.now();
    const ctx: Ctx = {
      wave: { kind: wave.type, time: wave.minuteOfDay * 60 },
      travel: await this.travel(tx, { lat: uni.campusLat, lng: uni.campusLng }),
      cfg: DEFAULT_CONFIG,
      now: secondsInto(ref.date, nowAt),
    };
    const passenger = (r: RideRequest): Passenger => ({
      id: r.id,
      gender: r.gender,
      pointId: r.pointId,
      tierId: r.tierId,
      tierRank: rank.get(r.tierId) ?? 0,
      subscriber: r.subscriber,
      createdAt: r.createdAt.getTime(),
      boarded: !!r.boardedAt || r.status === 'no_show',
    });
    const domainRuns: Run[] = (dbRuns as LoadedRun[]).map((run) => {
      const stops = run.stops
        .map((st) => ({ pointId: st.pointId, time: secondsInto(ref.date, st.eta), passengers: run.requests.filter((q) => q.pointId === st.pointId).map(passenger), servedAt: st.servedAt }))
        .filter((st) => st.passengers.length > 0);
      const servedStops = stops.filter((st) => st.servedAt).length;
      return {
        id: run.id,
        driverId: run.driverId,
        gender: run.gender,
        capacity: run.capacity,
        tierId: run.tierId,
        tierRank: rank.get(run.tierId) ?? 0,
        stops: stops.map(({ pointId, time, passengers }) => ({ pointId, time, passengers })),
        servedStops: servedStops || undefined,
      };
    });
    // DS-04: the waitlist lasts the university's configured minutes, never past the wave time.
    const waitlistUntil = Math.min(ctx.now + uni.waitlistMinutes * 60, ctx.wave.time);
    return { ref, ctx, dbRuns: dbRuns as LoadedRun[], domainRuns, requests, passenger, waitlistUntil };
  }

  /** Travel times from the OSRM matrix (DS-01), falling back to straight line × 1.3 at 30 km/h. */
  private async travel(tx: Tx, campus: { lat: number; lng: number }): Promise<TravelFn> {
    const [rows, points] = await Promise.all([tx.travelTime.findMany({ select: { fromKey: true, toKey: true, durationS: true } }), tx.gatheringPoint.findMany({ select: { id: true, lat: true, lng: true } })]);
    const m = new Map(rows.map((r) => [`${r.fromKey}|${r.toKey}`, r.durationS]));
    const where = new Map(points.map((p) => [p.id, { lat: p.lat, lng: p.lng }]));
    const key = (k: string) => (k === CAMPUS ? CAMPUS_KEY : k);
    return (a, b) => {
      if (a === b) return 0;
      const hit = m.get(`${key(a)}|${key(b)}`);
      if (hit != null) return hit;
      const pa = a === CAMPUS ? campus : where.get(a);
      const pb = b === CAMPUS ? campus : where.get(b);
      if (!pa || !pb) return 3600;
      return Math.round(((haversineKm(pa, pb) * 1.3) / 30) * 3600);
    };
  }

  private async save(tx: Tx, s: Awaited<ReturnType<DispatchEngine['load']>>, after: Run[], waitlist: WaitlistEntry[], events: DispatchEvent[]) {
    const { ref } = s;
    const date = dbDate(ref.date);
    const existing = new Map(s.dbRuns.map((r) => [r.id, r]));
    const before = new Map(s.requests.map((r) => [r.id, r]));
    const idMap = new Map<string, string>();
    const keep = new Set<string>();
    const changed: { runId: string; driverId: string }[] = [];

    for (const run of after) {
      if (run.stops.length === 0) continue;
      let id = run.id;
      const old = existing.get(run.id);
      if (old) {
        await tx.run.update({ where: { id }, data: { tierId: run.tierId, capacity: run.capacity } });
        await tx.runStop.deleteMany({ where: { runId: id } });
      } else {
        id = (await tx.run.create({ data: { universityId: ref.universityId, driverId: run.driverId, waveId: ref.waveId, date, gender: run.gender, tierId: run.tierId, capacity: run.capacity } })).id;
      }
      idMap.set(run.id, id);
      keep.add(id);
      const history = new Map((old?.stops ?? []).map((st) => [st.pointId, { servedAt: st.servedAt, arrivedAt: st.arrivedAt }]));
      await tx.runStop.createMany({
        data: run.stops.map((st, seq) => ({ universityId: ref.universityId, runId: id, seq, pointId: st.pointId, eta: instantAt(ref.date, st.time), servedAt: history.get(st.pointId)?.servedAt ?? null, arrivedAt: history.get(st.pointId)?.arrivedAt ?? null })),
      });
      const ids = run.stops.flatMap((st) => st.passengers.map((p) => p.id));
      // No-shows keep their status: they stay counted on the bus they missed.
      await tx.rideRequest.updateMany({ where: { id: { in: ids }, status: { not: 'no_show' } }, data: { runId: id, status: 'assigned', waitlistedUntil: null } });
      const sig = (stops: { pointId: string; passengers: { id: string }[] }[]) => stops.map((st) => `${st.pointId}:${st.passengers.map((p) => p.id).sort().join(',')}`).join('|');
      const oldSig = old ? sig(s.domainRuns.find((d) => d.id === old.id)?.stops ?? []) : '';
      if (!old || oldSig !== sig(run.stops)) changed.push({ runId: id, driverId: run.driverId });
    }
    // Runs left with nobody on board are removed, which frees the driver.
    for (const old of s.dbRuns) {
      if (keep.has(old.id)) continue;
      changed.push({ runId: old.id, driverId: old.driverId });
      await tx.rideRequest.updateMany({ where: { runId: old.id, status: 'assigned' }, data: { runId: null } });
      await tx.run.delete({ where: { id: old.id } });
    }

    const expiries: { requestId: string; at: Date }[] = [];
    for (const w of waitlist) {
      const at = instantAt(ref.date, w.expiresAt);
      await tx.rideRequest.update({ where: { id: w.passenger.id }, data: { status: 'waitlisted', runId: null, waitlistedUntil: at } });
      if (before.get(w.passenger.id)?.waitlistedUntil?.getTime() !== at.getTime()) expiries.push({ requestId: w.passenger.id, at });
    }
    const expired = events.filter((e) => e.type === 'expired').map((e) => e.requestId);
    if (expired.length) await tx.rideRequest.updateMany({ where: { id: { in: expired } }, data: { status: 'cancelled', cancelReason: 'expired', runId: null, waitlistedUntil: null } });

    // Outbox (ST-07/ST-09): one message per change, deduplicated by key.
    const drafts = events.flatMap((e) => {
      const req = before.get(e.requestId);
      if (!req) return [];
      const base = { requestId: e.requestId, studentId: req.studentId };
      switch (e.type) {
        case 'assigned':
          return notificationsFor({ type: 'assigned', ...base, runId: idMap.get(e.runId) ?? e.runId });
        case 'waitlisted':
          return notificationsFor({ type: 'waitlisted', ...base });
        case 'bumped':
          return notificationsFor({ type: 'bumped', ...base });
        case 'expired':
          return notificationsFor({ type: 'expired', ...base });
      }
    });
    await NotificationsService.add(tx, ref.universityId, drafts, { waveId: ref.waveId, date: ref.date });

    const runs = after.filter((r) => r.stops.length > 0);
    return {
      summary: { planned: true, runs: runs.length, assigned: runs.reduce((n, r) => n + r.stops.reduce((k, st) => k + st.passengers.length, 0), 0), waitlisted: waitlist.length },
      expiries,
      changed,
    };
  }

  /** After the transaction: expiry jobs, live run updates to drivers (DR-09), notification delivery. */
  private async afterCommit(ref: WaveRef, out: { expiries: { requestId: string; at: Date }[]; changed: { runId: string; driverId: string }[] }) {
    await this.scheduleExpiries(ref, out.expiries);
    for (const c of out.changed) this.hub.runChanged(ref.universityId, c.runId, c.driverId);
    await this.notifications.deliverPending(ref.universityId);
  }

  private async scheduleExpiries(ref: WaveRef, expiries: { requestId: string; at: Date }[]) {
    const now = this.now().getTime();
    for (const e of expiries) {
      await this.queue.add(WAITLIST_EXPIRE, { ...ref, requestId: e.requestId }, { delay: Math.max(0, e.at.getTime() - now), removeOnComplete: true, removeOnFail: 100, attempts: 3 });
    }
  }
}
