import { resolveTier, TierInput, validateTiers } from './tier-rules';

const t = (name: string, minKm: number, maxKm: number | null): TierInput => ({ name, minKm, maxKm, subscriptionPrice: 50000, ridePrice: 2000 });
const valid = [t('A', 0, 5), t('B', 5, 15), t('C', 15, null)];

describe('tier rules', () => {
  it('[T1-04] accepts contiguous tiers that cover [0, ∞) in any input order', () => {
    expect(validateTiers(valid)).toEqual([]);
    expect(validateTiers([valid[2], valid[0], valid[1]])).toEqual([]);
    expect(validateTiers([t('Only', 0, null)])).toEqual([]);
  });

  it('[T1-04] rejects gaps, overlaps, a closed last tier, an open middle tier and a non-zero start', () => {
    expect(validateTiers([t('A', 0, 5), t('B', 6, null)])).toContainEqual(expect.stringContaining('Gap'));
    expect(validateTiers([t('A', 0, 7), t('B', 5, null)])).toContainEqual(expect.stringContaining('overlaps'));
    expect(validateTiers([t('A', 0, 5), t('B', 5, 15)])).toContainEqual(expect.stringContaining('no maximum'));
    expect(validateTiers([t('A', 0, null), t('B', 5, null)])).toContainEqual(expect.stringContaining('only the last'));
    expect(validateTiers([t('A', 1, null)])).toContainEqual(expect.stringContaining('start at 0'));
    expect(validateTiers([])).toEqual(['At least one tier is required']);
  });

  it('rejects bad prices, inverted ranges and duplicate names', () => {
    expect(validateTiers([{ ...t('A', 0, null), subscriptionPrice: 0 }])).toHaveLength(1);
    expect(validateTiers([{ ...t('A', 0, null), ridePrice: 12.5 }])).toHaveLength(1);
    expect(validateTiers([t('A', 0, 5), t('A', 5, null)])).toContainEqual(expect.stringContaining('Duplicate'));
    expect(validateTiers([t('A', 0, 0), t('B', 0, null)])).toContainEqual(expect.stringContaining('greater than'));
  });

  it('[T1-04] every distance resolves to exactly one tier (boundary goes to the farther tier)', () => {
    const tiers = valid.map((v, i) => ({ ...v, id: String(i) }));
    expect(resolveTier(tiers, 0).name).toBe('A');
    expect(resolveTier(tiers, 4.99).name).toBe('A');
    expect(resolveTier(tiers, 5).name).toBe('B');
    expect(resolveTier(tiers, 15).name).toBe('C');
    expect(resolveTier(tiers, 400).name).toBe('C');
    for (let km = 0; km < 40; km += 0.25) {
      expect(tiers.filter((x) => km >= x.minKm && (x.maxKm === null || km < x.maxKm))).toHaveLength(1);
    }
    expect(() => resolveTier([{ id: 'x', minKm: 1, maxKm: 2 }], 0)).toThrow();
  });
});
