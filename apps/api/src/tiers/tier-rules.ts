export interface TierInput {
  id?: string;
  name: string;
  minKm: number;
  maxKm: number | null;
  subscriptionPrice: number;
  ridePrice: number;
}

export interface TierRange {
  id: string;
  minKm: number;
  maxKm: number | null;
}

const EPS = 1e-9;

/**
 * Tiers must cover [0, ∞) exactly once: sorted by minKm, first starts at 0, each next starts
 * where the previous ends, only the last is open-ended (PA-01). Returns problems; empty = valid.
 */
export function validateTiers(tiers: TierInput[]): string[] {
  const errors: string[] = [];
  if (tiers.length === 0) return ['At least one tier is required'];
  const sorted = [...tiers].sort((a, b) => a.minKm - b.minKm);
  const names = new Set<string>();
  sorted.forEach((t, i) => {
    const label = `"${t.name}"`;
    if (names.has(t.name.trim())) errors.push(`Duplicate tier name ${label}`);
    names.add(t.name.trim());
    if (t.minKm < 0) errors.push(`${label}: minimum distance cannot be negative`);
    if (t.maxKm !== null && t.maxKm <= t.minKm + EPS) errors.push(`${label}: maximum must be greater than minimum`);
    if (!Number.isInteger(t.subscriptionPrice) || t.subscriptionPrice <= 0) errors.push(`${label}: subscription price must be a positive whole number`);
    if (!Number.isInteger(t.ridePrice) || t.ridePrice <= 0) errors.push(`${label}: ride price must be a positive whole number`);
    if (i === 0 && Math.abs(t.minKm) > EPS) errors.push(`The first tier must start at 0 km`);
    const isLast = i === sorted.length - 1;
    if (!isLast && t.maxKm === null) errors.push(`${label}: only the last tier can be open-ended`);
    if (isLast && t.maxKm !== null) errors.push(`The last tier must have no maximum so every distance is covered`);
    if (i > 0) {
      const prev = sorted[i - 1];
      if (prev.maxKm !== null && Math.abs(prev.maxKm - t.minKm) > EPS) {
        errors.push(prev.maxKm < t.minKm ? `Gap between "${prev.name}" and ${label}` : `"${prev.name}" overlaps ${label}`);
      }
    }
  });
  return errors;
}

/** The single tier containing `km` (min inclusive, max exclusive). */
export function resolveTier<T extends TierRange>(tiers: T[], km: number): T {
  const hit = tiers.find((t) => km >= t.minKm - EPS && (t.maxKm === null || km < t.maxKm - EPS));
  if (!hit) throw new Error(`No tier covers ${km} km`);
  return hit;
}
