import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditService } from '../audit/audit.service';
import { midnight } from '../dispatch/clock';
import { PrismaService, Tx } from '../prisma/prisma.service';
import { calendarMonth, monthOf, nextMonth } from '../subscriptions/period-policy';
import { runAsSystem, runAsTenant } from '../tenancy/tenant-context';
import { computePayouts, toBasisPoints } from './payout';
import { ExportData, settlementPdf, settlementXlsx } from './settlement-export';
import { counts, verifyTrack } from './verify';

const num = (b: bigint) => Number(b);

/** Civil month → the instants and run dates it covers (Asia/Baghdad). */
export function monthRange(month: string) {
  let p;
  try {
    p = calendarMonth(month);
  } catch {
    throw new BadRequestException('Month must look like 2026-10');
  }
  const next = calendarMonth(nextMonth(month));
  return {
    firstDay: p.start,
    lastDay: p.end,
    from: new Date(midnight(p.start.toISOString().slice(0, 10))),
    to: new Date(midnight(next.start.toISOString().slice(0, 10))),
  };
}

/**
 * TO-09 / SE-01 / SE-02 / DR-08 / SA-04: monthly driver settlement. Everything is computed from
 * immutable inputs (subscriptions, cash-fare payments, stored GPS), so a draft can be recomputed
 * any number of times with the same result until the office approves it.
 */
@Injectable()
export class SettlementService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  /** SE-02: check one run's stored track and keep the result on the run. */
  async verifyRun(runId: string, tx: Tx = this.prisma.db) {
    const run = await tx.run.findUnique({
      where: { id: runId },
      include: { wave: true, university: true, stops: { orderBy: { seq: 'asc' }, include: { point: true } }, positions: { select: { lat: true, lng: true, at: true } } },
    });
    if (!run) throw new NotFoundException('Run not found');
    const v = verifyTrack({
      morning: run.wave.type === 'morning',
      completed: run.status === 'done',
      startedAt: run.startedAt,
      endedAt: run.endedAt,
      campus: { lat: run.university.campusLat, lng: run.university.campusLng },
      stops: run.stops.map((s) => ({ lat: s.point.lat, lng: s.point.lng })),
      positions: run.positions,
    });
    if (run.gpsVerified !== v.verified || JSON.stringify(run.gpsFlags) !== JSON.stringify(v.flags)) {
      await tx.run.update({ where: { id: runId }, data: { gpsVerified: v.verified, gpsFlags: v.flags } });
    }
    return v;
  }

  /** The inputs and the formula's answer for a month (nothing is written). */
  private async calculate(universityId: string, month: string, opts: { verify: boolean }) {
    const db = this.prisma.db;
    const r = monthRange(month);
    const uni = await db.university.findUniqueOrThrow({ where: { id: universityId } });
    const runs = await db.run.findMany({
      where: { universityId, date: { gte: r.firstDay, lte: r.lastDay }, status: { not: 'cancelled' } },
      select: { id: true, driverId: true, tierId: true, gpsVerified: true, officeVerdict: true, status: true },
      orderBy: { id: 'asc' },
    });
    if (opts.verify) {
      for (const run of runs) {
        if (run.officeVerdict !== null) continue;
        run.gpsVerified = (await this.verifyRun(run.id)).verified;
      }
    }
    const counted = runs.filter(counts);

    const subs = await db.subscription.groupBy({ by: ['tierId'], where: { universityId, month, status: 'active' }, _sum: { price: true } });
    const tiers = await db.distanceTier.findMany({ where: { universityId }, orderBy: { minKm: 'asc' } });
    const pools = tiers.map((t) => ({ tierId: t.id, pool: BigInt(subs.find((s) => s.tierId === t.id)?._sum.price ?? 0) }));

    // Cash fares collected on this month's runs, net of any reversal.
    const runIds = runs.map((x) => x.id);
    const fares = await db.payment.findMany({
      where: { universityId, method: 'cash_driver', OR: [{ runId: { in: runIds } }, { reverses: { runId: { in: runIds } } }] },
      select: { amount: true, runId: true, reverses: { select: { runId: true } } },
    });
    const driverOf = new Map(runs.map((x) => [x.id, x.driverId]));
    const cash = new Map<string, bigint>();
    for (const f of fares) {
      const d = driverOf.get(f.runId ?? f.reverses?.runId ?? '');
      if (d) cash.set(d, (cash.get(d) ?? 0n) + BigInt(f.amount));
    }
    // P10: campus taxi fares the driver kept in cash, by the month the trip ended, net of reversals.
    const taxiFares = await db.payment.findMany({
      where: {
        universityId,
        method: 'cash_driver',
        OR: [{ taxiRide: { endedAt: { gte: r.from, lt: r.to } } }, { reverses: { taxiRide: { endedAt: { gte: r.from, lt: r.to } } } }],
      },
      select: { amount: true, taxiRide: { select: { driverId: true } }, reverses: { select: { taxiRide: { select: { driverId: true } } } } },
    });
    for (const f of taxiFares) {
      const d = f.taxiRide?.driverId ?? f.reverses?.taxiRide?.driverId;
      if (d) cash.set(d, (cash.get(d) ?? 0n) + BigInt(f.amount));
    }

    const drivers = new Map<string, Record<string, number>>();
    for (const run of counted) {
      const m = drivers.get(run.driverId) ?? {};
      m[run.tierId] = (m[run.tierId] ?? 0) + 1;
      drivers.set(run.driverId, m);
    }
    for (const d of cash.keys()) if (!drivers.has(d)) drivers.set(d, {});

    const commissionBp = toBasisPoints(uni.commissionPct.toString());
    const result = computePayouts({ commissionBp, tiers: pools, drivers: [...drivers].map(([driverId, runs]) => ({ driverId, runs, cash: cash.get(driverId) ?? 0n })) });
    return { uni, tiers, commissionBp, result, excludedRuns: runs.length - counted.length, runs };
  }

  /** Compute (or recompute) the month's draft. Refused once approved (T6-04). */
  async compute(universityId: string, month: string) {
    const existing = await this.prisma.db.settlement.findUnique({ where: { universityId_month: { universityId, month } } });
    if (existing?.status === 'approved') throw new ConflictException('This month is already approved and cannot be recomputed');
    const { tiers, commissionBp, result, excludedRuns } = await this.calculate(universityId, month, { verify: true });
    const tierNames = new Map(tiers.map((t) => [t.id, t.name]));
    const head = {
      commissionBp,
      tiers: result.tiers.map((t) => ({ tierId: t.tierId, name: tierNames.get(t.tierId) ?? '', pool: num(t.pool), runs: t.runs, commission: num(t.commission) })),
      totalPool: result.totalPool,
      totalPayout: result.totalPayout,
      totalCommission: result.totalCommission,
      totalCash: result.totalCash,
      unallocated: result.unallocated,
      roundingResidual: result.roundingResidual,
      excludedRuns,
      computedAt: new Date(),
    };
    await this.prisma.db.$transaction(async (tx) => {
      const s = await tx.settlement.upsert({
        where: { universityId_month: { universityId, month } },
        create: { universityId, month, ...head },
        update: head,
      });
      if (s.status === 'approved') throw new ConflictException('This month is already approved and cannot be recomputed');
      await tx.settlementLine.deleteMany({ where: { settlementId: s.id } });
      await tx.settlementLine.createMany({
        data: result.lines.map((l) => ({
          universityId,
          settlementId: s.id,
          driverId: l.driverId,
          runs: l.runs,
          tiers: l.tiers.map((t) => ({ tierId: t.tierId, runs: t.runs, share: num(t.share) })),
          cash: l.cash,
          cashCommission: l.cashCommission,
          payout: l.payout,
        })),
      });
    });
    return this.get(universityId, month);
  }

  async get(universityId: string, month: string) {
    const s = await this.prisma.db.settlement.findUnique({
      where: { universityId_month: { universityId, month } },
      include: { lines: { include: { driver: { select: { id: true, name: true, nameAr: true, loginPhone: true, driver: { select: { plate: true } } } } } } },
    });
    if (!s) return null;
    return {
      id: s.id,
      month: s.month,
      status: s.status,
      commissionPct: s.commissionBp / 100,
      tiers: s.tiers as { tierId: string; name: string; pool: number; runs: number; commission: number }[],
      totals: {
        pool: num(s.totalPool),
        payout: num(s.totalPayout),
        commission: num(s.totalCommission),
        cash: num(s.totalCash),
        unallocated: num(s.unallocated),
        residual: num(s.roundingResidual),
      },
      excludedRuns: s.excludedRuns,
      computedAt: s.computedAt,
      approvedAt: s.approvedAt,
      approvedById: s.approvedById,
      lines: s.lines
        .map((l) => ({
          driverId: l.driverId,
          name: l.driver.name,
          nameAr: l.driver.nameAr,
          phone: l.driver.loginPhone,
          plate: l.driver.driver?.plate ?? null,
          runs: l.runs,
          tiers: l.tiers,
          cash: num(l.cash),
          cashCommission: num(l.cashCommission),
          payout: num(l.payout),
        }))
        .sort((a, b) => b.payout - a.payout || a.driverId.localeCompare(b.driverId)),
    };
  }

  async list(universityId: string) {
    const rows = await this.prisma.db.settlement.findMany({ where: { universityId }, orderBy: { month: 'desc' } });
    return rows.map((s) => ({ month: s.month, status: s.status, totalPayout: num(s.totalPayout), totalCommission: num(s.totalCommission), approvedAt: s.approvedAt }));
  }

  /** TO-09: after approval nothing about the month can change (database trigger as a backstop). */
  async approve(universityId: string, month: string, actorId: string) {
    const s = await this.prisma.db.settlement.findUnique({ where: { universityId_month: { universityId, month } } });
    if (!s) throw new NotFoundException('Compute the settlement first');
    if (s.status === 'approved') throw new ConflictException('Already approved');
    await this.prisma.db.$transaction(async (tx) => {
      await tx.settlement.update({ where: { id: s.id }, data: { status: 'approved', approvedAt: new Date(), approvedById: actorId } });
      await this.audit.record(
        {
          universityId,
          actorId,
          action: 'settlement.approve',
          entity: 'Settlement',
          entityId: s.id,
          before: { month, status: 'draft' },
          after: { month, status: 'approved', totalPayout: num(s.totalPayout), totalCommission: num(s.totalCommission), totalPool: num(s.totalPool) },
        },
        tx,
      );
    });
    return this.get(universityId, month);
  }

  /** Runs the office should look at: failed the GPS check or carry anomaly flags (NF-15). */
  async review(universityId: string, month: string) {
    const r = monthRange(month);
    const runs = await this.prisma.db.run.findMany({
      where: { universityId, date: { gte: r.firstDay, lte: r.lastDay }, status: { not: 'cancelled' }, OR: [{ gpsVerified: false }, { NOT: { gpsFlags: { equals: [] } } }, { officeVerdict: { not: null } }] },
      include: { wave: true, driver: { select: { name: true, nameAr: true } }, _count: { select: { positions: true, stops: true } } },
      orderBy: [{ date: 'asc' }, { id: 'asc' }],
    });
    return runs.map((x) => ({
      id: x.id,
      date: x.date.toISOString().slice(0, 10),
      waveType: x.wave.type,
      waveMinute: x.wave.minuteOfDay,
      driver: x.driver.nameAr ?? x.driver.name,
      status: x.status,
      gpsVerified: x.gpsVerified,
      flags: x.gpsFlags as string[],
      officeVerdict: x.officeVerdict,
      officeNote: x.officeNote,
      counted: counts(x),
      positions: x._count.positions,
      stops: x._count.stops,
    }));
  }

  /** The office decides about a flagged run (counts / does not count / back to the GPS check). */
  async verdict(universityId: string, runId: string, verdict: boolean | null, note: string | undefined, actorId: string) {
    const run = await this.prisma.db.run.findUnique({ where: { id: runId } });
    if (!run) throw new NotFoundException('Run not found');
    const month = run.date.toISOString().slice(0, 7);
    const s = await this.prisma.db.settlement.findUnique({ where: { universityId_month: { universityId, month } } });
    if (s?.status === 'approved') throw new ConflictException('This month is already approved');
    if (verdict !== null && !note?.trim()) throw new BadRequestException('Add a short note explaining the decision');
    await this.prisma.db.$transaction(async (tx) => {
      await tx.run.update({ where: { id: runId }, data: { officeVerdict: verdict, officeNote: verdict === null ? null : note!.trim() } });
      await this.audit.record(
        { universityId, actorId, action: 'run.verdict', entity: 'Run', entityId: runId, before: { officeVerdict: run.officeVerdict, officeNote: run.officeNote }, after: { officeVerdict: verdict, officeNote: verdict === null ? null : note!.trim() } },
        tx,
      );
    });
    return { id: runId, officeVerdict: verdict };
  }

  async exportFile(universityId: string, month: string, kind: 'pdf' | 'xlsx') {
    const s = await this.get(universityId, month);
    if (!s) throw new NotFoundException('Compute the settlement first');
    const uni = await this.prisma.db.university.findUniqueOrThrow({ where: { id: universityId } });
    const data: ExportData = {
      universityName: uni.nameAr ?? uni.name,
      month,
      status: s.status,
      approvedAt: s.approvedAt,
      commissionPct: s.commissionPct,
      tiers: s.tiers.map((t) => ({ name: t.name, pool: t.pool, runs: t.runs, commission: t.commission })),
      lines: s.lines.map((l) => ({ driver: l.nameAr ?? l.name, plate: l.plate ?? '', runs: l.runs, cash: l.cash, cashCommission: l.cashCommission, payout: l.payout })),
      totals: s.totals,
    };
    return kind === 'pdf' ? settlementPdf(data) : settlementXlsx(data);
  }

  /** DR-08: this month so far (estimate, same formula as the draft) and past approved settlements. */
  async driverEarnings(driverId: string, universityId: string, month = monthOf(new Date())) {
    const db = this.prisma.db;
    const draft = await db.settlement.findUnique({ where: { universityId_month: { universityId, month } }, include: { lines: { where: { driverId } } } });
    let line: { runs: number; cash: number; cashCommission: number; payout: number } | null = null;
    let source: 'approved' | 'draft' | 'estimate';
    if (draft) {
      const l = draft.lines[0];
      line = l ? { runs: l.runs, cash: num(l.cash), cashCommission: num(l.cashCommission), payout: num(l.payout) } : null;
      source = draft.status === 'approved' ? 'approved' : 'draft';
    } else {
      const { result } = await this.calculate(universityId, month, { verify: false });
      const l = result.lines.find((x) => x.driverId === driverId);
      line = l ? { runs: l.runs, cash: num(l.cash), cashCommission: num(l.cashCommission), payout: num(l.payout) } : null;
      source = 'estimate';
    }
    const r = monthRange(month);
    const runs = await db.run.findMany({
      where: { driverId, date: { gte: r.firstDay, lte: r.lastDay }, status: { not: 'cancelled' } },
      include: { wave: true },
      orderBy: [{ date: 'desc' }, { wave: { minuteOfDay: 'desc' } }],
    });
    const past = await db.settlementLine.findMany({
      where: { driverId, settlement: { status: 'approved', month: { not: month } } },
      include: { settlement: { select: { month: true, approvedAt: true } } },
      orderBy: { settlement: { month: 'desc' } },
      take: 24,
    });
    return {
      month,
      source,
      runs: line?.runs ?? 0,
      cash: line?.cash ?? 0,
      cashCommission: line?.cashCommission ?? 0,
      estimate: line?.payout ?? 0,
      list: runs.map((x) => ({
        id: x.id,
        date: x.date.toISOString().slice(0, 10),
        waveType: x.wave.type,
        waveMinute: x.wave.minuteOfDay,
        status: x.status,
        counted: counts(x),
        flagged: x.status === 'done' && !counts(x),
      })),
      past: past.map((p) => ({ month: p.settlement.month, approvedAt: p.settlement.approvedAt, runs: p.runs, cash: num(p.cash), payout: num(p.payout) })),
    };
  }

  /**
   * SA-04: per-university money and usage for one month, and the platform totals (which are the
   * plain sums of the per-university rows — T6-07).
   */
  async overview(month: string) {
    const r = monthRange(month);
    const unis = await runAsSystem(() => this.prisma.db.university.findMany({ orderBy: { createdAt: 'asc' } }));
    const rows: Awaited<ReturnType<SettlementService['universityMonth']>>[] = [];
    for (const u of unis) rows.push(await runAsTenant(u.id, () => this.universityMonth(u, month)));
    const total = (f: (x: (typeof rows)[number]) => number) => rows.reduce((k, x) => k + f(x), 0);
    const requests = total((x) => x.requests);
    return {
      month,
      universities: rows,
      totals: {
        revenue: total((x) => x.revenue.total),
        subscriptions: total((x) => x.revenue.subscriptions),
        cashFares: total((x) => x.revenue.cashFares),
        commission: total((x) => x.commission),
        payout: total((x) => x.payout),
        subscribers: total((x) => x.subscribers),
        runs: total((x) => x.runs),
        requests,
        fulfilment: requests ? Math.round((rows.reduce((k, x) => k + ((x.fulfilment ?? 0) * x.requests) / 100, 0) / requests) * 1000) / 10 : null,
      },
    };
  }

  private async universityMonth(u: { id: string; name: string; nameAr: string | null; commissionPct: { toString(): string } }, month: string) {
    const r = monthRange(month);
    const db = this.prisma.db;
    const pays = await db.payment.groupBy({ by: ['type'], where: { universityId: u.id, createdAt: { gte: r.from, lt: r.to } }, _sum: { amount: true } });
    const sum = (t: string) => pays.filter((p) => p.type === t).reduce((k, p) => k + (p._sum.amount ?? 0), 0);
    const s = await db.settlement.findUnique({ where: { universityId_month: { universityId: u.id, month } } });
    let commission: number;
    let payout: number;
    let settlement: 'approved' | 'draft' | 'estimate';
    if (s) {
      commission = num(s.totalCommission);
      payout = num(s.totalPayout);
      settlement = s.status;
    } else {
      const { result } = await this.calculate(u.id, month, { verify: false });
      commission = num(result.totalCommission);
      payout = num(result.totalPayout);
      settlement = 'estimate';
    }
    const subscribers = await db.subscription.count({ where: { universityId: u.id, month, status: 'active' } });
    const reqs = await db.rideRequest.groupBy({ by: ['status'], where: { universityId: u.id, date: { gte: r.firstDay, lte: r.lastDay } }, _count: true });
    const c = (st: string) => reqs.find((x) => x.status === st)?._count ?? 0;
    const requested = reqs.reduce((k, x) => k + x._count, 0) - c('cancelled');
    const served = c('done') + c('no_show') + c('assigned');
    const runs = await db.run.count({ where: { universityId: u.id, date: { gte: r.firstDay, lte: r.lastDay }, status: 'done' } });
    return {
      universityId: u.id,
      name: u.nameAr ?? u.name,
      commissionPct: Number(u.commissionPct),
      revenue: { subscriptions: sum('subscription'), cashFares: sum('cash_fare'), tierDifference: sum('tier_difference'), total: pays.reduce((k, p) => k + (p._sum.amount ?? 0), 0) },
      commission,
      payout,
      settlement,
      subscribers,
      requests: requested,
      fulfilment: requested ? Math.round((served / requested) * 1000) / 10 : null,
      runs,
    };
  }
}
export { monthRange as settlementMonthRange };
