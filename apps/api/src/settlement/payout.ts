/**
 * SE-01 settlement formula, in exact integer arithmetic (whole IQD, BigInt):
 *
 *   payout_d = Σ_tier Pool_tier × (1 − c) × runs_d,tier / runs_tier  −  c × cash_d
 *
 * Every payout is floored once per driver. What flooring leaves over is reported as the rounding
 * residual, so the books always balance:
 *
 *   Σ pools = Σ payouts + commission + unallocated + residual
 *
 * where commission = c × (pools of tiers that ran) + c × Σ cash (floored once), and unallocated is
 * the pool of any tier with no verified run in the month.
 */

export interface TierPool {
  tierId: string;
  /** Subscription money collected for this tier and month. */
  pool: bigint;
}

export interface DriverMonth {
  driverId: string;
  /** Verified runs per tier. */
  runs: Record<string, number>;
  /** Cash fares the driver collected and kept. */
  cash: bigint;
}

export interface PayoutLine {
  driverId: string;
  runs: number;
  tiers: { tierId: string; runs: number; share: bigint }[];
  cash: bigint;
  cashCommission: bigint;
  payout: bigint;
}

export interface PayoutResult {
  lines: PayoutLine[];
  tiers: { tierId: string; pool: bigint; runs: number; commission: bigint }[];
  totalPool: bigint;
  totalPayout: bigint;
  totalCommission: bigint;
  totalCash: bigint;
  unallocated: bigint;
  roundingResidual: bigint;
}

const BP = 10_000n;

/** Floor division that rounds toward −∞ (BigInt `/` truncates toward 0). */
export function floorDiv(a: bigint, b: bigint): bigint {
  const q = a / b;
  return (a % b !== 0n && (a < 0n) !== (b < 0n)) ? q - 1n : q;
}

/** An exact fraction n/d with d > 0. */
type Frac = { n: bigint; d: bigint };
const add = (a: Frac, b: Frac): Frac => (a.d === b.d ? { n: a.n + b.n, d: a.d } : { n: a.n * b.d + b.n * a.d, d: a.d * b.d });

/** Commission percent (Decimal like "10.00" or number) → basis points. */
export function toBasisPoints(pct: string | number): number {
  const bp = Math.round(Number(pct) * 100);
  if (!Number.isFinite(bp) || bp < 0 || bp > 10_000) throw new Error(`Commission must be 0–100 %, got ${pct}`);
  return bp;
}

export function computePayouts(input: { commissionBp: number; tiers: TierPool[]; drivers: DriverMonth[] }): PayoutResult {
  const c = BigInt(input.commissionBp);
  const runsPerTier = new Map<string, number>();
  for (const d of input.drivers) for (const [t, n] of Object.entries(d.runs)) if (n > 0) runsPerTier.set(t, (runsPerTier.get(t) ?? 0) + n);

  const pools = new Map(input.tiers.map((t) => [t.tierId, t.pool]));
  const lines: PayoutLine[] = [...input.drivers]
    .sort((a, b) => a.driverId.localeCompare(b.driverId))
    .map((d) => {
      let total: Frac = { n: 0n, d: 1n };
      const tiers: PayoutLine['tiers'] = [];
      for (const [tierId, runs] of Object.entries(d.runs).sort(([a], [b]) => a.localeCompare(b))) {
        const tierRuns = runsPerTier.get(tierId) ?? 0;
        const pool = pools.get(tierId) ?? 0n;
        if (runs <= 0 || tierRuns === 0) continue;
        const share: Frac = { n: pool * (BP - c) * BigInt(runs), d: BP * BigInt(tierRuns) };
        tiers.push({ tierId, runs, share: floorDiv(share.n, share.d) });
        total = add(total, share);
      }
      const cashCommission: Frac = { n: c * d.cash, d: BP };
      total = add(total, { n: -cashCommission.n, d: cashCommission.d });
      return {
        driverId: d.driverId,
        runs: tiers.reduce((k, t) => k + t.runs, 0),
        tiers,
        cash: d.cash,
        cashCommission: floorDiv(cashCommission.n, cashCommission.d),
        payout: floorDiv(total.n, total.d),
      };
    });

  const tiers = input.tiers.map((t) => {
    const runs = runsPerTier.get(t.tierId) ?? 0;
    return { tierId: t.tierId, pool: t.pool, runs, commission: runs ? floorDiv(t.pool * c, BP) : 0n };
  });
  const totalPool = tiers.reduce((k, t) => k + t.pool, 0n);
  const unallocated = tiers.filter((t) => t.runs === 0).reduce((k, t) => k + t.pool, 0n);
  const allocated = totalPool - unallocated;
  const totalCash = input.drivers.reduce((k, d) => k + d.cash, 0n);
  const totalCommission = floorDiv((allocated + totalCash) * c, BP);
  const totalPayout = lines.reduce((k, l) => k + l.payout, 0n);
  const roundingResidual = totalPool - totalPayout - totalCommission - unallocated;
  return { lines, tiers, totalPool, totalPayout, totalCommission, totalCash, unallocated, roundingResidual };
}
