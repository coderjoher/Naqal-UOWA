import { CAMPUS, Ctx, Passenger, Run, Stop } from './types';

/** Driving + standing time from the first stop to campus (morning) or campus to the last stop (return). */
export function rideSeconds(stops: Pick<Stop, 'pointId'>[], ctx: Ctx): number {
  if (stops.length === 0) return 0;
  const { travel, cfg } = ctx;
  let total = 0;
  if (ctx.wave.kind === 'morning') {
    for (let i = 0; i < stops.length - 1; i++) total += cfg.dwellS + travel(stops[i].pointId, stops[i + 1].pointId);
    total += cfg.dwellS + travel(stops[stops.length - 1].pointId, CAMPUS);
  } else {
    total += travel(CAMPUS, stops[0].pointId);
    for (let i = 1; i < stops.length; i++) total += cfg.dwellS + travel(stops[i - 1].pointId, stops[i].pointId);
  }
  return total;
}

/** Number of stops the bus has already served. Served stops are frozen. */
export function served(run: Run, ctx: Ctx): number {
  if (run.servedStops != null) return run.servedStops;
  let n = 0;
  while (n < run.stops.length && run.stops[n].time <= ctx.now) n++;
  return n;
}

export function started(run: Run, ctx: Ctx): boolean {
  if (run.servedStops != null && run.servedStops > 0) return true;
  if (ctx.wave.kind === 'return') return ctx.now >= ctx.wave.time;
  return run.stops.length > 0 && run.stops[0].time <= ctx.now;
}

/**
 * Recompute stop times. A morning run that has not started is anchored to arrive `bufferS`
 * before the wave; once started, served stops keep their times and the rest follow on.
 * A return run always leaves campus at the wave time.
 */
export function retime(run: Run, ctx: Ctx, frozen = served(run, ctx)): void {
  const { travel, cfg, wave } = ctx;
  const s = run.stops;
  if (s.length === 0) return;
  if (wave.kind === 'morning') {
    if (frozen === 0) {
      let t = wave.time - cfg.bufferS - rideSeconds(s, ctx);
      s[0].time = t;
      for (let i = 1; i < s.length; i++) {
        t += cfg.dwellS + travel(s[i - 1].pointId, s[i].pointId);
        s[i].time = t;
      }
    } else {
      for (let i = frozen; i < s.length; i++) s[i].time = s[i - 1].time + cfg.dwellS + travel(s[i - 1].pointId, s[i].pointId);
    }
  } else {
    const from = Math.max(frozen, 0);
    for (let i = from; i < s.length; i++) {
      s[i].time = i === 0 ? wave.time + travel(CAMPUS, s[0].pointId) : s[i - 1].time + cfg.dwellS + travel(s[i - 1].pointId, s[i].pointId);
    }
  }
}

/** Morning: when the bus reaches campus. Return: when it reaches the last stop. */
export function arrival(run: Run, ctx: Ctx): number {
  const s = run.stops;
  if (s.length === 0) return ctx.wave.time;
  const last = s[s.length - 1];
  return ctx.wave.kind === 'morning' ? last.time + ctx.cfg.dwellS + ctx.travel(last.pointId, CAMPUS) : last.time;
}

export function load(run: Run): number {
  return run.stops.reduce((n, s) => n + s.passengers.length, 0);
}

export function passengers(run: Run): Passenger[] {
  return run.stops.flatMap((s) => s.passengers);
}

/** DS-06: the run's tier is the tier of its farthest stop. */
export function retier(run: Run): void {
  let best: Passenger | undefined;
  for (const p of passengers(run)) if (!best || p.tierRank > best.tierRank) best = p;
  if (best) {
    run.tierId = best.tierId;
    run.tierRank = best.tierRank;
  }
}

/** Hard constraints (DS-05, SM-02). Returns the first violation or null. */
export function violation(run: Run, ctx: Ctx): string | null {
  if (load(run) > run.capacity) return 'capacity';
  if (passengers(run).some((p) => p.gender !== run.gender)) return 'gender';
  if (run.stops.some((s) => s.passengers.length === 0)) return 'empty-stop';
  if (run.stops.length === 0) return null;
  if (ctx.wave.kind === 'morning') {
    if (arrival(run, ctx) > ctx.wave.time) return 'late';
    const ride = arrival(run, ctx) - run.stops[0].time;
    if (ride > ctx.cfg.maxRideS) return 'too-long';
  } else {
    if (arrival(run, ctx) - ctx.wave.time > ctx.cfg.maxRideS) return 'too-long';
  }
  return null;
}

/** Cost used to compare solutions: one bus + its driving time. */
export function runCost(run: Run, ctx: Ctx): number {
  return run.stops.length === 0 ? 0 : ctx.cfg.runCostS + rideSeconds(run.stops, ctx);
}

export function cloneRun(run: Run): Run {
  return { ...run, stops: run.stops.map((s) => ({ ...s, passengers: [...s.passengers] })) };
}
