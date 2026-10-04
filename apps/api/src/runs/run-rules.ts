/**
 * DR-04 run state machine. Pure: the service loads state, asks here what is allowed, then writes.
 *   planned → started → at_stop → started → … → done
 */
export type RunState = 'planned' | 'started' | 'at_stop' | 'done' | 'cancelled';
export type RunAction = 'start' | 'arrive' | 'depart' | 'end';

export interface RunFacts {
  /** Stops not yet served (departed). */
  stopsLeft: number;
}

export function nextRunState(state: RunState, action: RunAction, facts: RunFacts): RunState | null {
  switch (action) {
    case 'start':
      return state === 'planned' ? 'started' : null;
    case 'arrive':
      return state === 'started' && facts.stopsLeft > 0 ? 'at_stop' : null;
    case 'depart':
      return state === 'at_stop' ? 'started' : null;
    case 'end':
      return state === 'started' && facts.stopsLeft === 0 ? 'done' : null;
  }
}

export interface Rider {
  id: string;
  boarded: boolean;
}

/**
 * SM-04: at a stop the bus waits the university's fixed time for riders who have not boarded.
 * After that it may leave and the missing riders become `no_show` — no penalty is applied.
 */
export function stopDeparture(riders: Rider[], arrivedAt: Date, now: Date, waitMinutes: number) {
  const missing = riders.filter((r) => !r.boarded).map((r) => r.id);
  if (missing.length === 0) return { canDepart: true, waitLeftS: 0, noShows: [] as string[] };
  const leftS = Math.ceil((arrivedAt.getTime() + waitMinutes * 60_000 - now.getTime()) / 1000);
  if (leftS > 0) return { canDepart: false, waitLeftS: leftS, noShows: [] as string[] };
  return { canDepart: true, waitLeftS: 0, noShows: missing };
}
