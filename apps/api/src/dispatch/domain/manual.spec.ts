import { addExtraRun, moveRequest, planWave } from './dispatch';
import { load, passengers, violation } from './schedule';
import { ctxFor, KARBALA, rider, riders } from './test-city';

const coords = KARBALA;

describe('manual overrides (TO-08)', () => {
  const ctx = ctxFor(coords, 'morning', 8, 6 * 3600);

  function twoRuns() {
    const req = [...riders(3, 'bab_baghdad'), ...riders(2, 'abbas_sq'), rider('hay_hussein', { gender: 'female', id: 'f1' })];
    return planWave(req, [{ id: 'd1', seats: 4 }, { id: 'd2', seats: 4 }, { id: 'd3', seats: 4 }], ctx).runs;
  }

  it('moves a passenger and keeps both runs valid', () => {
    const runs = twoRuns().filter((r) => r.gender === 'male');
    expect(runs.length).toBeGreaterThanOrEqual(1);
    const src = runs[0];
    const target = { ...runs[0], id: 'spare', driverId: 'd9', stops: [], capacity: 4 };
    const all = [...runs, target];
    const p = passengers(src)[0];
    const out = moveRequest(all, p.id, 'spare', ctx);
    if ('error' in out) throw new Error(out.error);
    expect(out.fromRunId).toBe(src.id);
    const moved = out.runs.find((r) => r.id === 'spare')!;
    expect(passengers(moved).map((x) => x.id)).toEqual([p.id]);
    expect(load(out.runs.find((r) => r.id === src.id)!)).toBe(load(src) - 1);
    for (const r of out.runs) expect(violation(r, ctx)).toBeNull();
  });

  it('refuses a move that breaks gender, capacity or the wave time', () => {
    const runs = twoRuns();
    const female = runs.find((r) => r.gender === 'female')!;
    const male = runs.find((r) => r.gender === 'male')!;
    expect(moveRequest(runs, passengers(female)[0].id, male.id, ctx)).toEqual({ error: 'gender' });

    const full = { ...male, id: 'full', capacity: load(male), stops: male.stops.map((s) => ({ ...s, passengers: s.passengers.map((p) => ({ ...p, id: `c-${p.id}` })) })) };
    const other = { ...male, id: 'other', servedStops: 0, stops: [{ pointId: 'al_hurr', time: 0, passengers: [rider('al_hurr', { id: 'z' })] }] };
    expect(moveRequest([full, other], 'z', 'full', ctx)).toEqual({ error: 'capacity' });

    // At 07:55 nothing can reach campus by 08:00 from a new far stop.
    const late = ctxFor(coords, 'morning', 8, 7 * 3600 + 55 * 60);
    const spare = { ...male, id: 'spare', driverId: 'd9', stops: [], capacity: 4 };
    const res = moveRequest([other, spare], 'z', 'spare', late);
    expect(res).toEqual({ error: 'time' });

    expect(moveRequest(runs, 'nobody', male.id, ctx)).toEqual({ error: 'not-found' });
    expect(moveRequest(runs, passengers(male)[0].id, male.id, ctx)).toEqual({ error: 'same-run' });
    const boarded = { ...male, stops: male.stops.map((s) => ({ ...s, passengers: s.passengers.map((p) => ({ ...p, boarded: true })) })) };
    expect(moveRequest([boarded, spare], passengers(boarded)[0].id, 'spare', ctx)).toEqual({ error: 'boarded' });
  });

  it('an extra bus takes waitlisted passengers of its gender, subscribers first', () => {
    const waiting = [
      { passenger: rider('abbas_sq', { id: 'w1', subscriber: false, createdAt: 1 }), expiresAt: 7 * 3600 },
      { passenger: rider('hay_askari', { id: 'w2', subscriber: true, createdAt: 2 }), expiresAt: 7 * 3600 },
      { passenger: rider('abbas_sq', { id: 'w3', gender: 'female', createdAt: 3 }), expiresAt: 7 * 3600 },
      { passenger: rider('bab_baghdad', { id: 'w4', createdAt: 4 }), expiresAt: 7 * 3600 },
    ];
    const out = addExtraRun([], { id: 'x', driverId: 'd5', gender: 'male', capacity: 2 }, waiting, ctx, 1800);
    expect(out.placed).toBe(2);
    expect(passengers(out.runs[0]).map((p) => p.id).sort()).toEqual(['w2', 'w4']);
    expect(out.events.map((e) => e.requestId).sort()).toEqual(['w2', 'w4']);
    expect(violation(out.runs[0], ctx)).toBeNull();
  });
});
