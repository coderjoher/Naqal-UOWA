import { coarse, driversToOffer, etaMinutes, fareFor, nextTaxiState, ONLINE_STALE_MS } from './taxi-rules';

const tariff = { baseFare: 2000, perKm: 500, minFare: 3000 };

describe('taxi rules (P10)', () => {
  it('[T10-01] fare: base + per km, minimum, rounded up to 250 IQD', () => {
    expect(fareFor(0, tariff)).toBe(3000); // minimum
    expect(fareFor(1, tariff)).toBe(3000); // 2500 → minimum 3000
    expect(fareFor(4, tariff)).toBe(4000);
    expect(fareFor(4.1, tariff)).toBe(4250); // 2000 + 2050 = 4050 → 4250
    expect(fareFor(10.37, tariff)).toBe(7250); // 2000 + 5185 = 7185 → 7250
    expect(fareFor(-3, tariff)).toBe(3000);
    for (let km = 0; km < 40; km += 0.37) expect(fareFor(km, tariff) % 250).toBe(0);
  });

  it('[T10-02] offers show only the area, never the exact point', () => {
    const exact = { lat: 32.61637, lng: 44.02491 };
    const c = coarse(exact);
    expect(c).toEqual({ lat: 32.615, lng: 44.025 });
    expect(Math.abs(c.lat - exact.lat)).toBeLessThan(0.003);
    expect(coarse({ lat: 32.6176, lng: 44.0224 })).toEqual({ lat: 32.62, lng: 44.02 });
  });

  it('[T10-02] offers go to fresh, free, nearby taxis, nearest first', () => {
    const now = 1_000_000;
    const point = { lat: 32.6, lng: 44.0 };
    const online = [
      { driverId: 'far', lat: 32.7, lng: 44.0, at: now }, // ~11 km
      { driverId: 'near', lat: 32.601, lng: 44.0, at: now },
      { driverId: 'mid', lat: 32.63, lng: 44.0, at: now },
      { driverId: 'stale', lat: 32.6, lng: 44.0, at: now - ONLINE_STALE_MS - 1 },
      { driverId: 'busy', lat: 32.6, lng: 44.0, at: now },
    ];
    expect(driversToOffer(online, point, now, new Set(['busy'])).map((d) => d.driverId)).toEqual(['near', 'mid']);
    expect(driversToOffer(online, point, now, new Set(), 8, 1).map((d) => d.driverId)).toEqual(['busy']);
  });

  it('[T10-04] ride state machine', () => {
    expect(nextTaxiState('requested', 'accept')).toBe('accepted');
    expect(nextTaxiState('accepted', 'accept')).toBeNull(); // second driver loses
    expect(nextTaxiState('accepted', 'arrive')).toBe('arrived');
    expect(nextTaxiState('arrived', 'start')).toBe('on_trip');
    expect(nextTaxiState('accepted', 'start')).toBe('on_trip');
    expect(nextTaxiState('requested', 'start')).toBeNull();
    expect(nextTaxiState('on_trip', 'end')).toBe('done');
    expect(nextTaxiState('arrived', 'end')).toBeNull();
    expect(nextTaxiState('on_trip', 'cancel_student')).toBeNull(); // not mid-trip
    expect(nextTaxiState('arrived', 'cancel_student')).toBe('cancelled');
    expect(nextTaxiState('accepted', 'cancel_driver')).toBe('requested'); // back on offer
    expect(nextTaxiState('on_trip', 'cancel_driver')).toBeNull();
    expect(nextTaxiState('requested', 'expire')).toBe('expired');
    expect(nextTaxiState('accepted', 'expire')).toBeNull();
  });

  it('ETA is at least a minute and grows with distance', () => {
    expect(etaMinutes({ lat: 32.6, lng: 44 }, { lat: 32.6, lng: 44 })).toBe(1);
    expect(etaMinutes({ lat: 32.6, lng: 44 }, { lat: 32.65, lng: 44 })).toBeGreaterThan(10);
  });
});
