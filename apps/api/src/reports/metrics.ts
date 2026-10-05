/**
 * TO-10 report metrics. Pure: the service loads one month of rows and this computes the numbers,
 * so every definition is in one place and tested against hand-computed fixtures (T7-04).
 *
 * - fulfilment   = rides served (done or no-show: a seat was there) / rides requested
 *                  (requests the student did not cancel themselves)
 * - on time      = morning runs that reached campus by the wave time, return runs that left
 *                  campus within 5 minutes of it / finished runs
 * - waitlist expiry = requests cancelled because no seat freed up in time / rides requested
 * - renewal      = last month's subscribers who subscribed again this month / last month's subscribers
 * - revenue per tier = subscriptions + cash fares (incl. tier differences) collected for the tier
 */

export const RETURN_GRACE_S = 5 * 60;

export interface ReportRequest {
  tierId: string;
  status: 'open' | 'assigned' | 'waitlisted' | 'cancelled' | 'done' | 'no_show';
  cancelReason: string | null;
  fare: number;
}

export interface ReportRun {
  tierId: string;
  waveType: 'morning' | 'return';
  /** The wave instant (morning: arrive-by, return: departure), epoch ms. */
  waveAt: number;
  status: string;
  startedAt: number | null;
  endedAt: number | null;
}

export interface ReportInput {
  tiers: { id: string; name: string }[];
  requests: ReportRequest[];
  runs: ReportRun[];
  /** Active subscriptions of the month: student and tier. */
  subscriptions: { studentId: string; tierId: string; price: number }[];
  previousSubscribers: { studentId: string; tierId: string }[];
  /** Cash collected by drivers for rides of the month, with the ride's tier. */
  cashFares: { tierId: string; amount: number }[];
}

export interface Rate {
  value: number | null;
  num: number;
  den: number;
}

const rate = (num: number, den: number): Rate => ({ value: den ? Math.round((num / den) * 1000) / 10 : null, num, den });

export function computeReport(input: ReportInput, tierId?: string) {
  const inTier = <T extends { tierId: string }>(xs: T[]) => (tierId ? xs.filter((x) => x.tierId === tierId) : xs);
  const requests = inTier(input.requests);
  const runs = inTier(input.runs);
  const subs = inTier(input.subscriptions);
  const prev = inTier(input.previousSubscribers);

  const requested = requests.filter((r) => !(r.status === 'cancelled' && r.cancelReason === 'student'));
  const served = requested.filter((r) => r.status === 'done' || r.status === 'no_show');
  const expired = requested.filter((r) => r.status === 'cancelled' && r.cancelReason === 'expired');

  const finished = runs.filter((r) => r.status === 'done');
  const onTime = finished.filter((r) =>
    r.waveType === 'morning' ? r.endedAt != null && r.endedAt <= r.waveAt : r.startedAt != null && r.startedAt <= r.waveAt + RETURN_GRACE_S * 1000,
  );

  const now = new Set(subs.map((s) => s.studentId));
  const renewed = prev.filter((p) => now.has(p.studentId));

  const tiers = (tierId ? input.tiers.filter((t) => t.id === tierId) : input.tiers).map((t) => {
    const subscriptions = input.subscriptions.filter((s) => s.tierId === t.id).reduce((k, s) => k + s.price, 0);
    const cash = input.cashFares.filter((c) => c.tierId === t.id).reduce((k, c) => k + c.amount, 0);
    return { tierId: t.id, name: t.name, subscribers: input.subscriptions.filter((s) => s.tierId === t.id).length, subscriptions, cash, revenue: subscriptions + cash };
  });

  return {
    subscribers: now.size,
    requests: requested.length,
    served: served.length,
    fulfilment: rate(served.length, requested.length),
    onTime: rate(onTime.length, finished.length),
    waitlistExpiry: rate(expired.length, requested.length),
    renewal: rate(renewed.length, prev.length),
    runs: finished.length,
    tiers,
    revenue: tiers.reduce((k, t) => k + t.revenue, 0),
  };
}

export type Report = ReturnType<typeof computeReport>;

/** CSV with a BOM so Excel opens Arabic text correctly. */
export function reportCsv(month: string, r: Report): string {
  const rows: (string | number | null)[][] = [
    ['month', month],
    ['subscribers', r.subscribers],
    ['requests', r.requests],
    ['served', r.served],
    ['fulfilment_pct', r.fulfilment.value],
    ['on_time_pct', r.onTime.value],
    ['waitlist_expiry_pct', r.waitlistExpiry.value],
    ['renewal_pct', r.renewal.value],
    ['runs', r.runs],
    ['revenue_iqd', r.revenue],
    [],
    ['tier', 'subscribers', 'subscriptions_iqd', 'cash_iqd', 'revenue_iqd'],
    ...r.tiers.map((t) => [t.name, t.subscribers, t.subscriptions, t.cash, t.revenue]),
  ];
  const cell = (v: string | number | null) => {
    const s = v == null ? '' : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return '﻿' + rows.map((row) => row.map(cell).join(',')).join('\r\n') + '\r\n';
}
