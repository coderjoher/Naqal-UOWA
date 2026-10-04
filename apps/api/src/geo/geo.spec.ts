import { haversineKm, insidePolygon, isPolygon } from './geo';

describe('geo', () => {
  it('haversine: Karbala centre to Warith campus is a few km', () => {
    const d = haversineKm({ lat: 32.616, lng: 44.0249 }, { lat: 32.5847, lng: 44.0617 });
    expect(d).toBeGreaterThan(4);
    expect(d).toBeLessThan(6);
    expect(haversineKm({ lat: 1, lng: 1 }, { lat: 1, lng: 1 })).toBe(0);
  });

  it('point in polygon (square around Karbala)', () => {
    const sq: [number, number][] = [
      [32.5, 43.9],
      [32.5, 44.2],
      [32.7, 44.2],
      [32.7, 43.9],
    ];
    expect(insidePolygon({ lat: 32.6, lng: 44.0 }, sq)).toBe(true);
    expect(insidePolygon({ lat: 33.3, lng: 44.4 }, sq)).toBe(false); // Baghdad
    expect(insidePolygon({ lat: 33.3, lng: 44.4 }, [])).toBe(true);
    expect(isPolygon(sq)).toBe(true);
    expect(isPolygon([[1, 'x']])).toBe(false);
  });
});
