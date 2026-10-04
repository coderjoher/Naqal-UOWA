export interface PricedTier {
  id: string;
  minKm: number;
  subscriptionPrice: number;
  ridePrice: number;
}

/** PA-02: the subscription price is the tier of the student's registered gathering point. */
export const subscriptionPrice = (registered: PricedTier) => registered.subscriptionPrice;

/**
 * PA-02: a subscriber boarding at a farther tier pays the difference between the two tiers'
 * per-ride prices for that ride; boarding at the same or a nearer tier costs nothing.
 */
export function tierDifference(registered: PricedTier, boarding: PricedTier): number {
  if (boarding.minKm <= registered.minKm) return 0;
  return Math.max(0, boarding.ridePrice - registered.ridePrice);
}
