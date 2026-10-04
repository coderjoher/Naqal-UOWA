import fc from 'fast-check';
import { cancelRequest, insertRequest, planWave, recheckWaitlist } from './dispatch';
import { arrival, load, passengers } from './schedule';
import { ctxFor, Coords } from './test-city';
import { CAMPUS, Ctx, Passenger, Run } from './types';

/** CI runs a fixed seed; the nightly job raises NUM_RUNS to 100 000 (P4 exit gate). */
const NUM_RUNS = Number(process.env.DISPATCH_PROPERTY_RUNS ?? 10_000);
const SEED = Number(process.env.DISPATCH_PROPERTY_SEED ?? 20261004);

const scenario = fc
  .record({
    points: fc.array(fc.tuple(fc.double({ min: -0.12, max: 0.12, noNaN: true }), fc.double({ min: -0.12, max: 0.12, noNaN: true })), { minLength: 1, maxLength: 8 }),
    kind: fc.constantFrom('morning' as const, 'return' as const),
    seats: fc.array(fc.integer({ min: 4, max: 30 }), { minLength: 0, maxLength: 6 }),
    requests: fc.array(
      fc.record({ point: fc.nat(), female: fc.boolean(), tier: fc.integer({ min: 0, max: 2 }), subscriber: fc.boolean(), boarded: fc.boolean() }),
      { maxLength: 60 },
    ),
    mix: fc.constantFrom(0, 600, 36000),
    ops: fc.array(fc.record({ kind: fc.constantFrom('insert', 'cancel', 'recheck', 'tick'), pick: fc.nat(), point: fc.nat(), female: fc.boolean(), sub: fc.boolean() }), { maxLength: 15 }),
  })
  .map((s) => {
    const coords: Coords = { [CAMPUS]: [32.5847, 44.0617] };
    s.points.forEach(([dlat, dlng], i) => (coords[`p${i}`] = [32.5847 + dlat, 44.0617 + dlng]));
    return { ...s, coords };
  });

function check(runs: Run[], ctx: Ctx, all: Passenger[]) {
  const seen = new Set<string>();
  for (const run of runs) {
    expect(load(run)).toBeLessThanOrEqual(run.capacity); // capacity
    for (const p of passengers(run)) {
      expect(p.gender).toBe(run.gender); // SM-02: never mixed
      expect(seen.has(p.id)).toBe(false); // nobody on two buses
      seen.add(p.id);
    }
    if (run.stops.length && ctx.wave.kind === 'morning') {
      expect(arrival(run, ctx)).toBeLessThanOrEqual(ctx.wave.time); // never misses the wave
      expect(arrival(run, ctx) - run.stops[0].time).toBeLessThanOrEqual(ctx.cfg.maxRideS);
    }
    for (const s of run.stops) expect(s.passengers.length).toBeGreaterThan(0);
    const farthest = Math.max(...passengers(run).map((p) => p.tierRank));
    if (run.stops.length) expect(run.tierRank).toBe(farthest); // DS-06
  }
  for (const id of seen) expect(all.some((p) => p.id === id)).toBe(true);
}

describe('[T4-01] dispatch hard constraints (property)', () => {
  it(`no run mixes genders, overflows or misses the wave (${NUM_RUNS} scenarios)`, () => {
    fc.assert(
      fc.property(scenario, (s) => {
        const ctx = ctxFor(s.coords, s.kind, 8, 6 * 3600, { mixTierThresholdS: s.mix });
        const pointIds = s.points.map((_, i) => `p${i}`);
        let n = 0;
        const mk = (point: number, female: boolean, tier: number, subscriber: boolean, boarded = false): Passenger => ({
          id: `q${n++}`,
          pointId: pointIds[point % pointIds.length],
          gender: female ? 'female' : 'male',
          tierId: `t${tier}`,
          tierRank: tier,
          subscriber,
          boarded,
          createdAt: n,
        });
        const all = s.requests.map((r) => mk(r.point, r.female, r.tier, r.subscriber, r.boarded));
        const plan = planWave(all, s.seats.map((seats, i) => ({ id: `d${i}`, seats })), ctx);
        check(plan.runs, ctx, all);
        // Every request is either on exactly one bus or on the waitlist.
        expect(plan.runs.reduce((k, r) => k + load(r), 0) + plan.waitlisted.length).toBe(all.length);

        let runs = plan.runs;
        let waitlist = plan.waitlisted.map((p) => ({ passenger: p, expiresAt: ctx.now + 1800 }));
        let now = ctx.now;
        for (const op of s.ops) {
          const c = { ...ctx, now };
          if (op.kind === 'insert') {
            const p = mk(op.point, op.female, op.point % 3, op.sub);
            all.push(p);
            const r = insertRequest(runs, p, c);
            runs = r.runs;
            if (!r.placed) waitlist.push({ passenger: p, expiresAt: now + 1800 });
            if (r.bumped) waitlist.push({ passenger: r.bumped, expiresAt: now + 1800 });
          } else if (op.kind === 'cancel') {
            const on = runs.flatMap(passengers);
            if (on.length) runs = cancelRequest(runs, on[op.pick % on.length].id, c).runs;
          } else if (op.kind === 'recheck') {
            const r = recheckWaitlist(runs, waitlist, c, 1800);
            runs = r.runs;
            waitlist = r.waitlist;
          } else {
            now += 300 + (op.pick % 1800);
          }
          check(runs, { ...ctx, now }, all);
        }
      }),
      { numRuns: NUM_RUNS, seed: SEED },
    );
  });
});
