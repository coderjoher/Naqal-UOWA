import { BadRequestException, ConflictException, ForbiddenException, HttpException, HttpStatus, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { fromDbDate, instantAt } from '../dispatch/clock';
import { DispatchEngine } from '../dispatch/dispatch.engine';
import { RidesService } from '../dispatch/rides.service';
import { LiveHub } from '../live/live.hub';
import { LiveService } from '../live/live.service';
import { NotificationsService } from '../notifications/notifications.service';
import { notificationsFor } from '../notifications/rules';
import { PaymentsService } from '../payments/payments.service';
import { PrismaService, Tx } from '../prisma/prisma.service';
import { SettlementService } from '../settlement/settlement.service';
import { officeViews } from '../common/swr-cache';
import { runAsTenant } from '../tenancy/tenant-context';
import { nextRunState, RunAction, RunState, stopDeparture } from './run-rules';

export type ActionType = RunAction | 'board';

export interface RunActionInput {
  /** Idempotency key from the device (NF-09): the same action is applied once. */
  clientId: string;
  type: ActionType;
  /** Device time; buffered actions keep the time they happened. */
  at?: string;
  /** `arrive`: stop number (1-based). */
  seq?: number;
  /** `board` (and `start` on return runs): riders who got on. */
  requestIds?: string[];
}

/** The bus is still waiting for missing riders (SM-04). */
export class StillWaitingException extends HttpException {
  constructor(waitLeftS: number) {
    super({ statusCode: 409, message: `Wait ${waitLeftS} more seconds for missing riders, or mark them on board`, waitLeftS }, HttpStatus.CONFLICT);
  }
}

@Injectable()
export class RunsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly engine: DispatchEngine,
    private readonly rides: RidesService,
    private readonly live: LiveService,
    private readonly hub: LiveHub,
    private readonly notifications: NotificationsService,
    private readonly payments: PaymentsService,
    private readonly settlement: SettlementService,
  ) {}

  /** DR-04: apply driver actions in order (a batch arrives after an offline period). */
  async act(driverId: string, universityId: string, runId: string, actions: RunActionInput[]) {
    const results: { clientId: string; applied: boolean }[] = [];
    for (const a of actions) results.push({ clientId: a.clientId, applied: await this.applyOne(driverId, universityId, runId, a) });
    this.live.invalidate(runId);
    await this.notifications.deliverPending(universityId);
    return { results, run: await this.view(runId) };
  }

  private async applyOne(driverId: string, universityId: string, runId: string, a: RunActionInput): Promise<boolean> {
    const head = await this.prisma.db.run.findUnique({ where: { id: runId }, select: { driverId: true, waveId: true, date: true } });
    if (!head) throw new NotFoundException('Run not found');
    if (head.driverId !== driverId) throw new ForbiddenException('Not your run');
    const ref = { universityId, waveId: head.waveId, date: fromDbDate(head.date) };

    const out = await this.engine.locked(ref, async (tx) => {
      if (await tx.runEvent.findUnique({ where: { runId_clientId: { runId, clientId: a.clientId } } })) return null; // already applied
      const run = await tx.run.findUniqueOrThrow({
        where: { id: runId },
        include: { wave: true, university: true, stops: { orderBy: { seq: 'asc' } }, requests: { where: { status: { in: ['assigned', 'no_show'] } } } },
      });
      const now = Date.now();
      const parsed = a.at ? Date.parse(a.at) : NaN;
      const at = new Date(Number.isFinite(parsed) ? Math.min(parsed, now) : now);
      const morning = run.wave.type === 'morning';
      const wait = run.university.noShowWaitMinutes;
      const next = run.stops.find((s) => !s.servedAt);
      const stopsLeft = run.stops.filter((s) => !s.servedAt).length;
      const state = run.status as RunState;
      const riders = run.requests.filter((r) => r.status === 'assigned');
      let status: RunState | null = state;
      let seq: number | null = null;
      const drafts: ReturnType<typeof notificationsFor> = [];

      const board = async (ids: string[] | undefined, allowed: typeof riders) => {
        const set = new Set(ids ?? []);
        const unknown = [...set].filter((id) => !allowed.some((r) => r.id === id));
        if (unknown.length) throw new BadRequestException('These riders are not waiting at this stop');
        if (set.size) await tx.rideRequest.updateMany({ where: { id: { in: [...set] }, boardedAt: null }, data: { boardedAt: at } });
        return allowed.map((r) => ({ id: r.id, boarded: !!r.boardedAt || set.has(r.id) }));
      };
      const noShow = async (ids: string[]) => {
        if (ids.length) await tx.rideRequest.updateMany({ where: { id: { in: ids } }, data: { status: 'no_show' } });
      };

      switch (a.type) {
        case 'start': {
          status = nextRunState(state, 'start', { stopsLeft });
          if (!status) throw new ConflictException(`Cannot start a run that is ${state}`);
          if (!morning) {
            // Return runs: riders board on campus before the bus leaves at the wave time.
            const list = await board(a.requestIds, riders);
            const dep = stopDeparture(list, instantAt(fromDbDate(run.date), run.wave.minuteOfDay * 60), at, wait);
            if (!dep.canDepart) throw new StillWaitingException(dep.waitLeftS);
            await noShow(dep.noShows);
          }
          await tx.run.update({ where: { id: runId }, data: { status, startedAt: at } });
          break;
        }
        case 'arrive': {
          status = nextRunState(state, 'arrive', { stopsLeft });
          if (!status || !next) throw new ConflictException(`Cannot arrive at a stop while the run is ${state}`);
          if (a.seq != null && a.seq !== next.seq + 1) throw new ConflictException(`The next stop is number ${next.seq + 1}`);
          seq = next.seq + 1;
          await tx.runStop.update({ where: { id: next.id }, data: { arrivedAt: at } });
          await tx.run.update({ where: { id: runId }, data: { status } });
          if (morning) {
            const here = riders.filter((r) => !r.boardedAt && r.pointId === next.pointId).map((r) => ({ requestId: r.id, studentId: r.studentId, seq: seq! }));
            drafts.push(...notificationsFor({ type: 'arrived', runId, seq, riders: here }));
          }
          break;
        }
        case 'board': {
          if (morning) {
            if (state !== 'at_stop' || !next) throw new ConflictException('Riders board when the bus is at their stop');
            await board(a.requestIds, riders.filter((r) => r.pointId === next.pointId));
          } else {
            if (state !== 'planned') throw new ConflictException('On return runs riders board on campus before leaving');
            await board(a.requestIds, riders);
          }
          break;
        }
        case 'depart': {
          status = nextRunState(state, 'depart', { stopsLeft });
          if (!status || !next) throw new ConflictException(`Cannot leave a stop while the run is ${state}`);
          if (morning) {
            const here = riders.filter((r) => r.pointId === next.pointId).map((r) => ({ id: r.id, boarded: !!r.boardedAt }));
            const dep = stopDeparture(here, next.arrivedAt ?? at, at, wait);
            if (!dep.canDepart) throw new StillWaitingException(dep.waitLeftS);
            await noShow(dep.noShows);
          }
          seq = next.seq + 1;
          await tx.runStop.update({ where: { id: next.id }, data: { servedAt: at } });
          await tx.run.update({ where: { id: runId }, data: { status } });
          break;
        }
        case 'end': {
          status = nextRunState(state, 'end', { stopsLeft });
          if (!status) throw new ConflictException(stopsLeft ? `${stopsLeft} stop(s) are not done yet` : `Cannot end a run that is ${state}`);
          await tx.rideRequest.updateMany({ where: { runId, status: 'assigned', ...(morning ? { boardedAt: { not: null } } : {}) }, data: { status: 'done' } });
          await tx.run.update({ where: { id: runId }, data: { status, endedAt: at } });
          break;
        }
        default:
          throw new BadRequestException('Unknown action');
      }
      await tx.runEvent.create({ data: { universityId, runId, clientId: a.clientId, type: a.type, payload: { seq: a.seq ?? null, requestIds: a.requestIds ?? [] }, at } });
      await NotificationsService.add(tx, universityId, drafts);
      return { status, seq };
    });
    if (!out) return false;
    officeViews.invalidate(`${universityId}:`);
    this.hub.runStatus(universityId, runId, driverId, { status: out.status ?? '', seq: out.seq });
    // SE-02: check the GPS track as soon as the run ends (rechecked when the month is settled).
    if (out.status === 'done') await runAsTenant(universityId, () => this.settlement.verifyRun(runId));
    return true;
  }

  /** DR-07 / PA-03: cash fare at the tier price (or tier difference), immutable and idempotent. */
  async fare(driverId: string, universityId: string, runId: string, input: { requestId: string; clientId: string }) {
    const db = this.prisma.db;
    const existing = await db.payment.findFirst({ where: { OR: [{ idempotencyKey: input.clientId }, { rideRequestId: input.requestId }] } });
    if (existing) return { payment: existing, duplicate: true };
    const run = await db.run.findUnique({ where: { id: runId } });
    if (!run) throw new NotFoundException('Run not found');
    if (run.driverId !== driverId) throw new ForbiddenException('Not your run');
    const req = await db.rideRequest.findFirst({ where: { id: input.requestId, runId } });
    if (!req) throw new NotFoundException('This rider is not on your run');
    if (!req.boardedAt) throw new ConflictException('Record the fare once the rider is on board');
    if (req.fare <= 0) throw new BadRequestException('This rider has nothing to pay (subscription)');
    try {
      const payment = await db.$transaction((tx) =>
        this.payments.record(tx as Tx, {
          universityId,
          type: 'cash_fare',
          method: 'cash_driver',
          amount: req.fare,
          studentId: req.studentId,
          collectedById: driverId,
          reference: req.id,
          runId,
          rideRequestId: req.id,
          idempotencyKey: input.clientId,
        }),
      );
      return { payment, duplicate: false };
    } catch (e) {
      // A retry raced the first attempt: the unique keys kept one row; return it.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        return { payment: await db.payment.findFirstOrThrow({ where: { OR: [{ idempotencyKey: input.clientId }, { rideRequestId: input.requestId }] } }), duplicate: true };
      }
      throw e;
    }
  }

  /** The driver's view of one run (same shape as GET /drivers/me/runs) plus live state. */
  async view(runId: string) {
    const run = await this.prisma.db.run.findUnique({
      where: { id: runId },
      include: {
        wave: true,
        university: { select: { noShowWaitMinutes: true } },
        stops: { orderBy: { seq: 'asc' }, include: { point: true } },
        requests: { where: { status: { in: ['assigned', 'done', 'no_show'] } }, include: { student: true } },
        payments: { select: { rideRequestId: true } },
      },
    });
    if (!run) throw new NotFoundException('Run not found');
    const paid = new Set(run.payments.map((p) => p.rideRequestId));
    const base = this.rides.runView(run);
    return {
      ...base,
      startedAt: run.startedAt,
      endedAt: run.endedAt,
      waitMinutes: run.university.noShowWaitMinutes,
      stops: base.stops.map((s, i) => ({
        ...s,
        arrivedAt: run.stops[i].arrivedAt,
        passengers: s.passengers.map((p) => {
          const r = run.requests.find((q) => q.id === p.requestId)!;
          return { ...p, status: r.status, paid: paid.has(r.id) };
        }),
      })),
    };
  }

  /** ST-06: what a student needs to follow their bus — never other riders or their places. */
  async track(studentId: string, universityId: string, requestId: string) {
    const req = await this.prisma.db.rideRequest.findFirst({ where: { id: requestId, studentId }, include: { run: { include: { stops: { orderBy: { seq: 'asc' } }, wave: true } }, point: true } });
    if (!req) throw new NotFoundException();
    if (!req.run) return { runId: null, status: req.status, stop: null, bus: null };
    const stop = req.run.stops.find((s) => s.pointId === req.pointId);
    return {
      runId: req.run.id,
      status: req.run.status,
      rideStatus: req.status,
      boarded: !!req.boardedAt,
      stop: stop ? { seq: stop.seq + 1, lat: req.point.lat, lng: req.point.lng, name: req.point.name, nameAr: req.point.nameAr, eta: stop.eta, arrivedAt: stop.arrivedAt, servedAt: stop.servedAt } : null,
      bus: await this.live.last(universityId, req.run.id),
    };
  }

  /** TO-07: today's runs with status and last position, for the live operations map. */
  /** Live operations snapshot (sockets push changes afterwards); cached like the dispatch board. */
  ops(universityId: string, date: string) {
    return officeViews.get(`${universityId}:ops:${date}`, () => this.loadOps(universityId, date));
  }

  private async loadOps(universityId: string, date: string) {
    return runAsTenant(universityId, async () => {
      const day = new Date(`${date}T00:00:00Z`);
      const runs = await this.prisma.db.run.findMany({
        // Today's runs, plus buses on the road for yesterday's date (a wave just after midnight starts
        // the evening before). Older runs a driver never ended are not "on the road": settlement sends
        // them to the office's review instead.
        where: { OR: [{ date: day, status: { not: 'cancelled' } }, { date: { gte: new Date(day.getTime() - 86400_000), lt: day }, status: { in: ['started', 'at_stop'] } }] },
        include: { wave: true, driver: { include: { driver: true } }, stops: { orderBy: { seq: 'asc' }, include: { point: true } }, requests: { where: { status: { in: ['assigned', 'done', 'no_show'] } }, select: { status: true, boardedAt: true } } },
        orderBy: { wave: { minuteOfDay: 'asc' } },
      });
      return Promise.all(
        runs.map(async (r) => ({
          runId: r.id,
          status: r.status,
          wave: { type: r.wave.type, time: `${String(Math.floor(r.wave.minuteOfDay / 60)).padStart(2, '0')}:${String(r.wave.minuteOfDay % 60).padStart(2, '0')}` },
          driverName: r.driver.nameAr ?? r.driver.name,
          plate: r.driver.driver?.plate ?? null,
          femaleOnly: r.gender === 'female',
          capacity: r.capacity,
          booked: r.requests.length,
          boarded: r.requests.filter((q) => q.boardedAt).length,
          noShows: r.requests.filter((q) => q.status === 'no_show').length,
          stops: r.stops.map((s) => ({ seq: s.seq + 1, name: s.point.nameAr ?? s.point.name, lat: s.point.lat, lng: s.point.lng, served: !!s.servedAt, arrived: !!s.arrivedAt })),
          bus: r.status === 'started' || r.status === 'at_stop' ? await this.live.last(universityId, r.id) : null,
        })),
      );
    });
  }
}
