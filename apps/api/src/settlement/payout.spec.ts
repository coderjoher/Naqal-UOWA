import fc from 'fast-check';
import { computePayouts, floorDiv, toBasisPoints } from './payout';

describe('settlement payout (SE-01)', () => {
  it('[T6-01] PRD worked example: pool 6 000 000, c = 10 %, 50/400 runs, 100 000 cash → 665 000 IQD', () => {
    const r = computePayouts({
      commissionBp: toBasisPoints('10.00'),
      tiers: [{ tierId: 'A', pool: 6_000_000n }],
      drivers: [
        { driverId: 'd1', runs: { A: 50 }, cash: 100_000n },
        { driverId: 'd2', runs: { A: 350 }, cash: 0n },
      ],
    });
    const d1 = r.lines.find((l) => l.driverId === 'd1')!;
    expect(d1.payout).toBe(665_000n);
    expect(d1.cashCommission).toBe(10_000n);
    expect(d1.tiers).toEqual([{ tierId: 'A', runs: 50, share: 675_000n }]);
    expect(r.lines.find((l) => l.driverId === 'd2')!.payout).toBe(4_725_000n);
    expect(r.totalCommission).toBe(610_000n);
    expect(r.roundingResidual).toBe(0n);
  });

  it('a driver who kept more cash than earned owes the office (negative payout)', () => {
    const r = computePayouts({ commissionBp: 1000, tiers: [{ tierId: 'A', pool: 0n }], drivers: [{ driverId: 'd', runs: { A: 1 }, cash: 50_000n }] });
    expect(r.lines[0].payout).toBe(-5_000n);
  });

  it('a tier with no verified runs is reported as unallocated, not paid', () => {
    const r = computePayouts({ commissionBp: 1000, tiers: [{ tierId: 'A', pool: 900n }, { tierId: 'B', pool: 500n }], drivers: [{ driverId: 'd', runs: { A: 3 }, cash: 0n }] });
    expect(r.unallocated).toBe(500n);
    expect(r.lines[0].payout).toBe(810n);
    expect(r.totalCommission).toBe(90n);
    expect(r.roundingResidual).toBe(0n);
  });

  it('runs a driver did in several tiers add up, floored once', () => {
    const r = computePayouts({
      commissionBp: 1250,
      tiers: [{ tierId: 'A', pool: 1_000_001n }, { tierId: 'B', pool: 333_333n }],
      drivers: [
        { driverId: 'x', runs: { A: 1, B: 2 }, cash: 7n },
        { driverId: 'y', runs: { A: 2, B: 1 }, cash: 0n },
      ],
    });
    // x: 1 000 001 × 0.875 / 3 + 333 333 × 0.875 × 2/3 − 0.125 × 7 = 291 666.958… + 194 444.25 − 0.875
    expect(r.lines[0].payout).toBe(486_110n);
    expect(r.roundingResidual >= 0n && r.roundingResidual < 3n).toBe(true);
  });

  it('floorDiv rounds toward minus infinity', () => {
    expect(floorDiv(7n, 2n)).toBe(3n);
    expect(floorDiv(-7n, 2n)).toBe(-4n);
    expect(floorDiv(-6n, 2n)).toBe(-3n);
  });

  it('rejects commission outside 0–100 %', () => {
    expect(() => toBasisPoints('120')).toThrow();
    expect(toBasisPoints(12.5)).toBe(1250);
  });

  it('[T6-02] Σ payouts + Σ commission + residual (+ unallocated) = Σ pools across random months', () => {
    const tierIds = ['A', 'B', 'C', 'D'];
    const month = fc.record({
      commissionBp: fc.integer({ min: 0, max: 3000 }),
      pools: fc.array(fc.bigInt({ min: 0n, max: 200_000_000n }), { minLength: 4, maxLength: 4 }),
      drivers: fc.array(
        fc.record({
          runs: fc.array(fc.integer({ min: 0, max: 60 }), { minLength: 4, maxLength: 4 }),
          cash: fc.bigInt({ min: 0n, max: 5_000_000n }),
        }),
        { minLength: 1, maxLength: 40 },
      ),
    });
    fc.assert(
      fc.property(month, (m) => {
        const r = computePayouts({
          commissionBp: m.commissionBp,
          tiers: tierIds.map((tierId, i) => ({ tierId, pool: m.pools[i] })),
          drivers: m.drivers.map((d, i) => ({ driverId: `d${String(i).padStart(2, '0')}`, runs: Object.fromEntries(tierIds.map((t, j) => [t, d.runs[j]])), cash: d.cash })),
        });
        const pools = m.pools.reduce((a, b) => a + b, 0n);
        expect(r.totalPayout + r.totalCommission + r.roundingResidual + r.unallocated).toBe(pools);
        // Flooring loses less than one dinar per driver, plus one for the commission.
        expect(r.roundingResidual >= 0n).toBe(true);
        expect(r.roundingResidual <= BigInt(m.drivers.length + 1)).toBe(true);
        // Same inputs, same answer (T6-04 relies on it).
        expect(computePayouts({
          commissionBp: m.commissionBp,
          tiers: tierIds.map((tierId, i) => ({ tierId, pool: m.pools[i] })),
          drivers: m.drivers.map((d, i) => ({ driverId: `d${String(i).padStart(2, '0')}`, runs: Object.fromEntries(tierIds.map((t, j) => [t, d.runs[j]])), cash: d.cash })),
        })).toEqual(r);
      }),
      { numRuns: Number(process.env.SETTLEMENT_PROPERTY_RUNS ?? 500) },
    );
  });
});
