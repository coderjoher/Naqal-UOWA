import { bestInsertionInRun, cheapestInsertion, priority, removePassenger } from './insert';
import { cloneRun, load, passengers, retier, retime, runCost, served, started, violation } from './schedule';
import { CAMPUS, Ctx, DispatchEvent, Driver, Passenger, Run, WaitlistEntry } from './types';

export interface AssignResult {
  runs: Run[];
  placed: boolean;
  /** A pay-per-ride passenger moved to the waitlist to make room for a subscriber (SM-03). */
  bumped?: Passenger;
  runId?: string;
}

/**
 * Place one request into existing runs (DS-03). A subscriber who finds no seat may take the seat
 * of the lowest-priority pay-per-ride passenger who has not boarded yet.
 */
export function insertRequest(runsIn: Run[], p: Passenger, ctx: Ctx): AssignResult {
  const runs = runsIn.map(cloneRun);
  const ins = cheapestInsertion(runs, p, ctx);
  if (ins) {
    runs[ins.runIndex] = ins.run;
    return { runs, placed: true, runId: ins.run.id };
  }
  if (!p.subscriber) return { runs, placed: false };

  // Candidates: unboarded pay-per-ride passengers on same-gender runs, lowest priority first.
  const candidates = runs
    .flatMap((run, runIndex) => {
      if (run.gender !== p.gender) return [];
      const frozen = served(run, ctx);
      return run.stops.flatMap((s, i) => (i >= frozen ? s.passengers.filter((x) => !x.subscriber && !x.boarded).map((x) => ({ x, runIndex })) : []));
    })
    .sort((a, b) => priority(b.x, a.x));
  for (const { x, runIndex } of candidates) {
    const without = removePassenger(runs[runIndex], x.id, ctx);
    if (!without) continue;
    const r = bestInsertionInRun(without, p, ctx);
    if (!r) continue;
    runs[runIndex] = r.run;
    return { runs, placed: true, bumped: x, runId: r.run.id };
  }
  return { runs, placed: false };
}

/** Remove a cancelled request from whichever run holds it. */
export function cancelRequest(runsIn: Run[], requestId: string, ctx: Ctx): { runs: Run[]; freed: boolean } {
  const runs = runsIn.map(cloneRun);
  for (let i = 0; i < runs.length; i++) {
    const next = removePassenger(runs[i], requestId, ctx);
    if (next) {
      runs[i] = next;
      return { runs, freed: true };
    }
  }
  return { runs, freed: false };
}

/**
 * DS-04: expire overdue entries, then try to seat the rest — subscribers first, then in order of
 * request. A subscriber may bump an unboarded pay-per-ride passenger, who rejoins the waitlist.
 */
export function recheckWaitlist(runsIn: Run[], waitlist: WaitlistEntry[], ctx: Ctx, waitlistS: number) {
  let runs = runsIn.map(cloneRun);
  const events: DispatchEvent[] = [];
  const remaining: WaitlistEntry[] = [];
  const queue = [...waitlist].sort((a, b) => priority(a.passenger, b.passenger));
  while (queue.length) {
    const entry = queue.shift()!;
    if (entry.expiresAt <= ctx.now) {
      events.push({ type: 'expired', requestId: entry.passenger.id });
      continue;
    }
    const r = insertRequest(runs, entry.passenger, ctx);
    runs = r.runs;
    if (!r.placed) {
      remaining.push(entry);
      continue;
    }
    events.push({ type: 'assigned', requestId: entry.passenger.id, runId: r.runId! });
    if (r.bumped) {
      events.push({ type: 'bumped', requestId: r.bumped.id, runId: r.runId! });
      // A bumped pay-per-ride passenger can never displace anyone, so re-queue them at the end.
      queue.push({ passenger: r.bumped, expiresAt: ctx.now + waitlistS });
    }
  }
  return { runs, waitlist: remaining, events };
}

export interface PlanResult {
  runs: Run[];
  waitlisted: Passenger[];
}

/**
 * DS-02: build runs for one wave. Requests are grouped by gender (never mixed) and tier; each new
 * run starts from the farthest open point of the group that holds the most urgent request and
 * grows by cheapest insertion. Drivers are used largest vehicle first. Afterwards small runs are
 * dissolved into other runs when that saves more than the tier-mixing threshold (DS-06), freed
 * buses take leftover requests, and the rest go to the waitlist.
 */
export function planWave(requests: Passenger[], drivers: Driver[], ctx: Ctx): PlanResult {
  const pool = [...drivers].sort((a, b) => b.seats - a.seats || a.id.localeCompare(b.id));
  const open = [...requests].sort(priority);
  const runs: Run[] = [];
  const leftovers: Passenger[] = [];
  let seq = 0;

  const buildRuns = () => {
    while (pool.length && open.length) {
      const lead = open[0];
      const group = open.filter((p) => p.gender === lead.gender && p.tierId === lead.tierId);
      const run = startRun(group, pool[0], ctx, `run-${++seq}`);
      if (!run) {
        open.shift(); // the lead request alone cannot be served in time; it will be waitlisted
        leftovers.push(lead);
        continue;
      }
      pool.shift();
      grow(run, group, ctx);
      for (const x of passengers(run)) open.splice(open.indexOf(x), 1);
      runs.push(run);
    }
  };
  buildRuns();

  // DS-06: dissolve small runs into others when the saving beats the mixing threshold.
  let changed = true;
  while (changed) {
    changed = false;
    const order = runs.map((r, i) => i).sort((a, b) => load(runs[a]) - load(runs[b]));
    for (const i of order) {
      const victim = runs[i];
      const others = runs.filter((_, j) => j !== i);
      const merged = mergeInto(others, passengers(victim), ctx);
      if (!merged) continue;
      const saving = runCost(victim, ctx) + others.reduce((n, r) => n + runCost(r, ctx), 0) - merged.reduce((n, r) => n + runCost(r, ctx), 0);
      if (saving > ctx.cfg.mixTierThresholdS) {
        runs.splice(0, runs.length, ...merged);
        pool.push({ id: victim.driverId, seats: victim.capacity });
        pool.sort((a, b) => b.seats - a.seats || a.id.localeCompare(b.id));
        changed = true;
        break;
      }
    }
  }

  open.push(...leftovers.splice(0));
  open.sort(priority);
  buildRuns();

  // Last resort: any same-gender run with a free seat, even across tiers.
  const waitlisted: Passenger[] = [];
  const rest = [...open, ...leftovers].sort(priority);
  while (rest.length) {
    const p = rest.shift()!;
    const r = insertRequest(runs, p, ctx);
    if (!r.placed) {
      waitlisted.push(p);
      continue;
    }
    runs.splice(0, runs.length, ...r.runs);
    if (r.bumped) rest.push(r.bumped); // SM-03: a subscriber outranks a pay-per-ride rider
  }
  return { runs, waitlisted };
}

function startRun(group: Passenger[], driver: Driver, ctx: Ctx, id: string): Run | null {
  // Seed with the farthest point that has an open request in this group.
  const byPoint = [...new Set(group.map((p) => p.pointId))].sort((a, b) => ctx.travel(b, CAMPUS) - ctx.travel(a, CAMPUS));
  for (const pointId of byPoint) {
    const riders = group.filter((p) => p.pointId === pointId).slice(0, driver.seats);
    const run: Run = { id, driverId: driver.id, gender: riders[0].gender, capacity: driver.seats, tierId: riders[0].tierId, tierRank: riders[0].tierRank, stops: [{ pointId, time: 0, passengers: riders }] };
    retime(run, ctx, 0);
    if (!violation(run, ctx) && (ctx.wave.kind === 'return' || run.stops[0].time >= ctx.now)) return run;
  }
  return null;
}

/** Add more of the group by cheapest insertion until full or nothing fits. */
function grow(run: Run, group: Passenger[], ctx: Ctx) {
  for (;;) {
    const onboard = new Set(passengers(run).map((p) => p.id));
    let best: { run: Run; cost: number } | null = null;
    for (const p of group) {
      if (onboard.has(p.id)) continue;
      const r = bestInsertionInRun(run, p, ctx);
      if (r && (!best || r.cost < best.cost)) best = r;
    }
    if (!best) return;
    run.stops = best.run.stops;
    retier(run);
  }
}

function mergeInto(others: Run[], riders: Passenger[], ctx: Ctx): Run[] | null {
  let runs = others.map(cloneRun);
  for (const p of [...riders].sort(priority)) {
    const ins = cheapestInsertion(runs, p, ctx);
    if (!ins) return null;
    runs = runs.map((r, i) => (i === ins.runIndex ? ins.run : r));
  }
  return runs;
}

export { load, passengers, started };

export type MoveError = 'not-found' | 'boarded' | 'same-run' | 'passed' | 'gender' | 'capacity' | 'time';

/**
 * TO-08: the office moves one passenger to another run. The hard constraints are checked again
 * on the target (same gender, a free seat, arrival by the wave time and ride length); the source
 * run is re-timed without them. Nothing is bumped.
 */
export function moveRequest(runsIn: Run[], requestId: string, targetRunId: string, ctx: Ctx): { runs: Run[]; fromRunId: string } | { error: MoveError } {
  const runs = runsIn.map(cloneRun);
  const fromIndex = runs.findIndex((r) => passengers(r).some((p) => p.id === requestId));
  const toIndex = runs.findIndex((r) => r.id === targetRunId);
  if (fromIndex < 0 || toIndex < 0) return { error: 'not-found' };
  if (fromIndex === toIndex) return { error: 'same-run' };
  const p = passengers(runs[fromIndex]).find((x) => x.id === requestId)!;
  if (p.boarded) return { error: 'boarded' };
  const target = runs[toIndex];
  if (target.gender !== p.gender) return { error: 'gender' };
  if (load(target) >= target.capacity) return { error: 'capacity' };
  const without = removePassenger(runs[fromIndex], requestId, ctx);
  if (!without) return { error: 'passed' };
  const placed = bestInsertionInRun(target, p, ctx);
  if (!placed) return { error: 'time' };
  runs[fromIndex] = without;
  runs[toIndex] = placed.run;
  return { runs, fromRunId: runsIn[fromIndex].id };
}

/**
 * TO-08: an extra bus for a wave that has people waiting. It starts empty and takes waitlisted
 * passengers like any freed seat would (subscribers first, then by request time).
 */
export function addExtraRun(runsIn: Run[], extra: { id: string; driverId: string; gender: Run['gender']; capacity: number }, waitlist: WaitlistEntry[], ctx: Ctx, waitlistS: number) {
  const empty: Run = { id: extra.id, driverId: extra.driverId, gender: extra.gender, capacity: extra.capacity, tierId: '', tierRank: 0, stops: [] };
  // Only the new bus takes people; existing runs keep their passengers and seats as they are.
  const r = recheckWaitlist([empty], waitlist.filter((w) => w.passenger.gender === extra.gender), ctx, waitlistS);
  const run = r.runs[0];
  return { runs: [...runsIn.map(cloneRun), run], placed: load(run), events: r.events.filter((e) => e.type === 'assigned') };
}
