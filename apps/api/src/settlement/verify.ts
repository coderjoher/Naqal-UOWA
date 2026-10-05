import { haversineKm, LatLng } from '../geo/geo';

/**
 * SE-02 / NF-15: does the stored GPS track prove the run happened?
 *
 * A run counts only when it was started and ended, every stop was visited (a stored point within
 * 150 m), it ended on campus (morning) or at the last stop (return), and no speed was impossible.
 * Off-path points are flagged for the office but do not fail the run on their own (detours happen).
 */

export const STOP_RADIUS_M = 150;
/** Campus is a large site: the run may end anywhere within this distance of its pin. */
export const CAMPUS_RADIUS_M = 400;
/** Faster than any minibus on Karbala roads. */
export const MAX_KMH = 140;
/** A jump this far within a minute is a GPS teleport (spoofing or a bad fix). */
export const TELEPORT_KM = 3;
export const TELEPORT_WINDOW_S = 90;
/** Farther than this from the planned path (straight legs between stops) is flagged. */
export const OFF_PATH_KM = 2.5;

export type Flag =
  | 'not_completed'
  | 'no_gps'
  | `missed_stop:${number}`
  | 'ended_elsewhere'
  | 'too_fast'
  | 'teleport'
  | 'off_path';

/** Flags that make a run unverified. */
const FAILS = (f: Flag) => f !== 'off_path';

export interface TrackInput {
  morning: boolean;
  completed: boolean;
  startedAt: Date | null;
  endedAt: Date | null;
  campus: LatLng;
  /** Stops in order. */
  stops: LatLng[];
  /** Stored positions (any order). */
  positions: (LatLng & { at: Date })[];
}

export interface Verdict {
  verified: boolean;
  flags: Flag[];
}

/** Distance in km from p to the segment a–b (flat-earth approximation, fine at city scale). */
export function distanceToSegmentKm(p: LatLng, a: LatLng, b: LatLng): number {
  const kx = 111.32 * Math.cos((p.lat * Math.PI) / 180);
  const ky = 110.57;
  const ax = (a.lng - p.lng) * kx, ay = (a.lat - p.lat) * ky;
  const bx = (b.lng - p.lng) * kx, by = (b.lat - p.lat) * ky;
  const dx = bx - ax, dy = by - ay;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / len2));
  return Math.hypot(ax + t * dx, ay + t * dy);
}

export function verifyTrack(input: TrackInput): Verdict {
  const flags: Flag[] = [];
  if (!input.completed || !input.startedAt || !input.endedAt) flags.push('not_completed');

  const from = input.startedAt?.getTime() ?? -Infinity;
  const to = input.endedAt?.getTime() ?? Infinity;
  // Allow one minute either side: the device may have recorded just before tapping.
  const track = input.positions
    .filter((p) => p.at.getTime() >= from - 60_000 && p.at.getTime() <= to + 60_000)
    .sort((a, b) => a.at.getTime() - b.at.getTime());

  if (track.length < 2) {
    flags.push('no_gps');
    return { verified: false, flags };
  }

  input.stops.forEach((s, i) => {
    if (!track.some((p) => haversineKm(p, s) * 1000 <= STOP_RADIUS_M)) flags.push(`missed_stop:${i + 1}`);
  });

  // Where the run ends: campus in the morning, the last drop-off on return runs.
  const end = input.morning || input.stops.length === 0 ? input.campus : input.stops[input.stops.length - 1];
  const radius = input.morning || input.stops.length === 0 ? CAMPUS_RADIUS_M : STOP_RADIUS_M;
  const tail = track.slice(-3);
  if (!tail.some((p) => haversineKm(p, end) * 1000 <= radius)) flags.push('ended_elsewhere');

  for (let i = 1; i < track.length; i++) {
    const a = track[i - 1];
    const b = track[i];
    const km = haversineKm(a, b);
    const s = (b.at.getTime() - a.at.getTime()) / 1000;
    if (km >= TELEPORT_KM && s <= TELEPORT_WINDOW_S) {
      if (!flags.includes('teleport')) flags.push('teleport');
    } else if (s > 0 && (km / s) * 3600 > MAX_KMH && km > 0.2) {
      if (!flags.includes('too_fast')) flags.push('too_fast');
    }
  }

  // Morning runs start wherever the driver lives: the path is checked from the first stop on.
  const path = input.morning ? [...input.stops, input.campus] : [input.campus, ...input.stops];
  const first = track.findIndex((p) => haversineKm(p, path[0]) * 1000 <= CAMPUS_RADIUS_M);
  if (path.length >= 2 && first >= 0 && track.slice(first).some((p) => Math.min(...path.slice(1).map((b, i) => distanceToSegmentKm(p, path[i], b))) > OFF_PATH_KM)) flags.push('off_path');

  return { verified: !flags.some(FAILS), flags };
}

/** Whether a run counts for settlement: the office's review wins over the GPS check. */
export const counts = (run: { gpsVerified: boolean | null; officeVerdict: boolean | null }) => run.officeVerdict ?? run.gpsVerified ?? false;
