import { subscriptionPrice, tierDifference } from './pricing';

const A = { id: 'a', minKm: 0, subscriptionPrice: 40000, ridePrice: 1500 };
const B = { id: 'b', minKm: 5, subscriptionPrice: 60000, ridePrice: 2000 };
const C = { id: 'c', minKm: 15, subscriptionPrice: 80000, ridePrice: 3000 };

describe('pricing', () => {
  it('[T3-03] subscription price is the registered tier price', () => {
    expect(subscriptionPrice(B)).toBe(60000);
  });

  it('[T3-03] boarding farther costs the exact ride-price difference; same or nearer costs 0', () => {
    expect(tierDifference(B, C)).toBe(1000);
    expect(tierDifference(A, C)).toBe(1500);
    expect(tierDifference(B, B)).toBe(0);
    expect(tierDifference(C, A)).toBe(0);
    // A farther tier that is (oddly) cheaper never produces a negative charge.
    expect(tierDifference(A, { ...C, ridePrice: 1000 })).toBe(0);
  });
});
