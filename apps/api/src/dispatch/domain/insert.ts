import { cloneRun, load, retier, retime, rideSeconds, served, started, violation } from './schedule';
import { Ctx, Passenger, Run } from './types';

export interface Insertion {
  run: Run; // the updated copy
  runIndex: number;
  cost: number; // extra seconds (+ tier-mixing penalty)
}

/** Positions where a stop for `pointId` could still be added: never before a served stop. */
function openFrom(run: Run, ctx: Ctx): number | null {
  if (ctx.wave.kind === 'return') return started(run, ctx) ? null : 0; // students board on campus
  return served(run, ctx);
}

/**
 * Try every legal position in one run. Joining an existing, not-yet-served stop at the same point
 * costs nothing extra. Returns the cheapest feasible copy, or null.
 */
export function bestInsertionInRun(run: Run, p: Passenger, ctx: Ctx): { run: Run; cost: number } | null {
  if (run.gender !== p.gender || load(run) >= run.capacity) return null;
  const from = openFrom(run, ctx);
  if (from == null) return null;
  const frozen = served(run, ctx);
  // The bus has already passed this point: going back is never offered.
  if (run.stops.slice(0, frozen).some((s) => s.pointId === p.pointId)) return null;
  const before = rideSeconds(run.stops, ctx);
  const mixPenalty = run.stops.length > 0 && run.tierRank !== p.tierRank ? ctx.cfg.mixTierThresholdS : 0;
  let best: { run: Run; cost: number } | null = null;

  const existing = run.stops.findIndex((s, i) => i >= from && s.pointId === p.pointId);
  if (existing >= 0) {
    const copy = cloneRun(run);
    copy.stops[existing].passengers.push(p);
    retier(copy);
    if (!violation(copy, ctx)) return { run: copy, cost: mixPenalty };
  }

  for (let pos = from; pos <= run.stops.length; pos++) {
    const copy = cloneRun(run);
    copy.stops.splice(pos, 0, { pointId: p.pointId, time: 0, passengers: [p] });
    retime(copy, ctx, frozen);
    retier(copy);
    if (violation(copy, ctx)) continue;
    if (ctx.wave.kind === 'morning' && frozen === 0 && copy.stops[0].time < ctx.now) continue; // cannot start in the past
    const cost = rideSeconds(copy.stops, ctx) - before + mixPenalty;
    if (!best || cost < best.cost) best = { run: copy, cost };
  }
  return best;
}

/** DS-03: cheapest insertion across all runs with a free seat that have not passed the point. */
export function cheapestInsertion(runs: Run[], p: Passenger, ctx: Ctx): Insertion | null {
  let best: Insertion | null = null;
  runs.forEach((run, runIndex) => {
    const r = bestInsertionInRun(run, p, ctx);
    if (r && (!best || r.cost < best.cost)) best = { run: r.run, runIndex, cost: r.cost };
  });
  return best;
}

/**
 * Remove a passenger who has not been picked up yet; an emptied stop is dropped and later stops
 * re-timed. Returns null when the passenger is not on this run or their stop was already served.
 */
export function removePassenger(run: Run, requestId: string, ctx: Ctx): Run | null {
  const idx = run.stops.findIndex((s) => s.passengers.some((x) => x.id === requestId));
  const frozen = served(run, ctx);
  if (idx < 0 || idx < frozen) return null;
  if (ctx.wave.kind === 'return' && started(run, ctx)) return null; // already on board
  const copy = cloneRun(run);
  const stop = copy.stops[idx];
  stop.passengers = stop.passengers.filter((x) => x.id !== requestId);
  if (stop.passengers.length === 0) {
    copy.stops.splice(idx, 1);
    retime(copy, ctx, frozen);
  }
  retier(copy);
  return copy;
}

/** Ordering for seats: subscribers first (SM-03), then first come first served. */
export function priority(a: Passenger, b: Passenger): number {
  if (a.subscriber !== b.subscriber) return a.subscriber ? -1 : 1;
  return a.createdAt - b.createdAt;
}
