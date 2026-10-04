import { etas } from './eta';

describe('live ETA', () => {
  const stops = [
    { seq: 1, pointId: 'a', lat: 32.62, lng: 44.0, served: true },
    { seq: 2, pointId: 'b', lat: 32.616, lng: 44.0249, served: false },
    { seq: 3, pointId: 'c', lat: 32.6, lng: 44.05, served: false },
  ];

  it('skips served stops, estimates the first leg from the bus and adds matrix legs + dwell', () => {
    const bus = { lat: 32.616, lng: 44.0249 }; // at stop b
    const out = etas(bus, stops, (f, t) => (f === 'b' && t === 'c' ? 420 : undefined), 60);
    expect(out).toEqual([
      { seq: 2, seconds: 0 },
      { seq: 3, seconds: 480 },
    ]);
  });

  it('falls back to straight line × 1.3 at 30 km/h when the matrix has no pair', () => {
    const out = etas({ lat: 32.62, lng: 44.0 }, stops, () => undefined, 0);
    expect(out[0].seconds).toBeGreaterThan(300);
    expect(out[1].seconds).toBeGreaterThan(out[0].seconds);
  });
});
