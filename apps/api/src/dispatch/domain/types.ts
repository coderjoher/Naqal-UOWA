/**
 * Dispatch domain types. This folder is pure TypeScript: no Nest, no Prisma, no I/O,
 * so every rule can be tested in isolation (P4).
 *
 * Times are seconds after midnight (Asia/Baghdad) on the wave's date.
 */
export type Gender = 'male' | 'female';
export type WaveKind = 'morning' | 'return';

/** Travel time in seconds between two keys (a gathering point id or {@link CAMPUS}). */
export type TravelFn = (from: string, to: string) => number;
export const CAMPUS = 'campus';

export interface DispatchConfig {
  /** Seconds a bus stands at each stop. */
  dwellS: number;
  /** Morning runs are planned to arrive this much before the wave time. */
  bufferS: number;
  /** Longest time a passenger may spend on a run, first stop to campus (or campus to last stop). */
  maxRideS: number;
  /** Fixed cost of using one more bus, in seconds of driving. */
  runCostS: number;
  /** DS-06: a mixed-tier solution is used only when it saves more than this (seconds). */
  mixTierThresholdS: number;
}

export const DEFAULT_CONFIG: DispatchConfig = {
  dwellS: 60,
  bufferS: 10 * 60,
  maxRideS: 45 * 60,
  runCostS: 20 * 60,
  mixTierThresholdS: 10 * 60,
};

export interface Passenger {
  id: string; // ride request id
  gender: Gender;
  pointId: string;
  tierId: string;
  /** Higher = farther tier. */
  tierRank: number;
  subscriber: boolean;
  /** Request time, epoch ms. Earlier wins among equals. */
  createdAt: number;
  /** Boarded passengers can never be moved or bumped. */
  boarded?: boolean;
}

export interface Stop {
  pointId: string;
  /** Planned pickup time (morning) or drop-off time (return). */
  time: number;
  passengers: Passenger[];
}

export interface Run {
  id: string;
  driverId: string;
  gender: Gender;
  capacity: number;
  /** DS-06: tier of the farthest stop. */
  tierId: string;
  tierRank: number;
  stops: Stop[];
  /** Stops already served (set from live progress in P5); otherwise derived from `now`. */
  servedStops?: number;
}

export interface Driver {
  id: string;
  seats: number;
}

export interface Wave {
  kind: WaveKind;
  /** Morning: arrive-by time. Return: departure from campus. Seconds after midnight. */
  time: number;
}

export interface Ctx {
  wave: Wave;
  travel: TravelFn;
  cfg: DispatchConfig;
  /** Current time, seconds after midnight on the wave date. */
  now: number;
}

export interface WaitlistEntry {
  passenger: Passenger;
  /** Seconds after midnight when the waitlist period ends (SA-03). */
  expiresAt: number;
}

export type DispatchEvent =
  | { type: 'assigned'; requestId: string; runId: string }
  | { type: 'waitlisted'; requestId: string }
  | { type: 'bumped'; requestId: string; runId: string }
  | { type: 'expired'; requestId: string };
