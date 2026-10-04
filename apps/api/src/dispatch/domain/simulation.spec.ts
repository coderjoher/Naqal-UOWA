import { planWave } from './dispatch';
import { load, violation } from './schedule';
import { ctxFor, Coords } from './test-city';
import { CAMPUS, Passenger } from './types';

/**
 * P4 exit gate: one real morning — 500 requests over two waves (8:00 and 10:00), 30 buses —
 * assigns at least 95 % with zero constraint violations.
 */
describe('morning simulation (P4 exit gate)', () => {
  it('assigns ≥ 95 % of 500 requests with 30 buses and no violations', () => {
    let seed = 42;
    const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2 ** 31) / 2 ** 31);

    // 30 gathering points spread over Karbala (≈ 2–14 km from campus), tiers by distance.
    const coords: Coords = { [CAMPUS]: [32.5847, 44.0617] };
    const tier: Record<string, number> = {};
    for (let i = 0; i < 30; i++) {
      const angle = rnd() * 2 * Math.PI;
      const km = 2 + rnd() * 12;
      const id = `pt${i}`;
      coords[id] = [32.5847 + (km / 111) * Math.cos(angle), 44.0617 + (km / 94) * Math.sin(angle)];
      tier[id] = km < 5 ? 0 : km < 10 ? 1 : 2;
    }
    const pointIds = Object.keys(coords).filter((k) => k !== CAMPUS);
    const buses = Array.from({ length: 30 }, (_, i) => ({ id: `bus${i}`, seats: [14, 14, 18, 26][i % 4] }));

    let n = 0;
    const make = (count: number): Passenger[] =>
      Array.from({ length: count }, () => {
        const pointId = pointIds[Math.floor(rnd() * pointIds.length)];
        return { id: `q${++n}`, pointId, gender: rnd() < 0.55 ? 'female' : 'male', tierId: `T${tier[pointId]}`, tierRank: tier[pointId], subscriber: rnd() < 0.7, createdAt: n };
      });

    let assigned = 0;
    let total = 0;
    for (const [hour, count] of [
      [8, 350],
      [10, 150],
    ]) {
      const ctx = ctxFor(coords, 'morning', hour, (hour - 1) * 3600);
      const requests = make(count);
      const { runs, waitlisted } = planWave(requests, buses, ctx);
      for (const r of runs) expect(violation(r, ctx)).toBeNull();
      const seated = runs.reduce((k, r) => k + load(r), 0);
      expect(seated + waitlisted.length).toBe(count);
      assigned += seated;
      total += count;
    }
    expect(assigned / total).toBeGreaterThanOrEqual(0.95);
  });
});
