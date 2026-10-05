import { Injectable } from '@nestjs/common';
import { instantAt } from '../dispatch/clock';
import { PrismaService } from '../prisma/prisma.service';
import { settlementMonthRange } from '../settlement/settlement.service';
import { computeReport } from './metrics';

const prevMonth = (month: string) => {
  const [y, m] = month.split('-').map(Number);
  return m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`;
};

/** TO-10: loads one month for the current university and computes the report. */
@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async report(month: string, tierId?: string) {
    const db = this.prisma.db;
    const r = settlementMonthRange(month);
    const [tiers, requests, runs, subs, prev] = await Promise.all([
      db.distanceTier.findMany({ orderBy: { minKm: 'asc' }, select: { id: true, name: true } }),
      db.rideRequest.findMany({ where: { date: { gte: r.firstDay, lte: r.lastDay } }, select: { id: true, tierId: true, status: true, cancelReason: true, fare: true } }),
      db.run.findMany({ where: { date: { gte: r.firstDay, lte: r.lastDay }, status: { not: 'cancelled' } }, include: { wave: true } }),
      db.subscription.findMany({ where: { month, status: 'active' }, select: { studentId: true, tierId: true, price: true } }),
      db.subscription.findMany({ where: { month: prevMonth(month), status: 'active' }, select: { studentId: true, tierId: true } }),
    ]);
    const tierOf = new Map(requests.map((q) => [q.id, q.tierId]));
    const fares = await db.payment.findMany({ where: { method: 'cash_driver', rideRequestId: { in: requests.map((q) => q.id) } }, select: { amount: true, rideRequestId: true } });
    const report = computeReport(
      {
        tiers,
        requests,
        runs: runs.map((x) => {
          const date = x.date.toISOString().slice(0, 10);
          return { tierId: x.tierId, waveType: x.wave.type, waveAt: instantAt(date, x.wave.minuteOfDay * 60).getTime(), status: x.status, startedAt: x.startedAt?.getTime() ?? null, endedAt: x.endedAt?.getTime() ?? null };
        }),
        subscriptions: subs,
        previousSubscribers: prev,
        cashFares: fares.map((f) => ({ tierId: tierOf.get(f.rideRequestId!) ?? '', amount: f.amount })),
      },
      tierId,
    );
    return { month, tierId: tierId ?? null, ...report };
  }
}
