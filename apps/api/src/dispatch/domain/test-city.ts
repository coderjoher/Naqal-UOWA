/* Test helpers for the dispatch domain (imported only by *.spec.ts). */
import { CAMPUS, Ctx, DEFAULT_CONFIG, DispatchConfig, Gender, Passenger, TravelFn, WaveKind } from './types';

export type Coords = Record<string, [number, number]>;

/** Same model as the fake OSRM: straight line × 1.2 at 30 km/h. */
export function travelFrom(coords: Coords): TravelFn {
  return (a, b) => {
    if (a === b) return 0;
    const [la1, lo1] = coords[a];
    const [la2, lo2] = coords[b];
    const r = Math.PI / 180;
    const h = Math.sin(((la2 - la1) * r) / 2) ** 2 + Math.cos(la1 * r) * Math.cos(la2 * r) * Math.sin(((lo2 - lo1) * r) / 2) ** 2;
    const km = 2 * 6371 * Math.asin(Math.sqrt(h)) * 1.2;
    return Math.round((km / 30) * 3600);
  };
}

export function ctxFor(coords: Coords, kind: WaveKind = 'morning', waveHour = 8, now = 0, cfg: Partial<DispatchConfig> = {}): Ctx {
  return { wave: { kind, time: waveHour * 3600 }, travel: travelFrom(coords), cfg: { ...DEFAULT_CONFIG, ...cfg }, now };
}

let n = 0;
export function rider(pointId: string, o: Partial<Passenger> = {}): Passenger {
  n++;
  return { id: `r${n}`, gender: 'male' as Gender, pointId, tierId: 'A', tierRank: 0, subscriber: true, createdAt: n, ...o };
}

export function riders(count: number, pointId: string, o: Partial<Passenger> = {}): Passenger[] {
  return Array.from({ length: count }, () => rider(pointId, o));
}

/** Warith campus and real-ish Karbala neighbourhoods. */
export const KARBALA: Coords = {
  [CAMPUS]: [32.5847, 44.0617],
  bab_baghdad: [32.6, 44.05],
  abbas_sq: [32.616, 44.0249],
  hay_hussein: [32.62, 44.0],
  hay_askari: [32.63, 44.03],
  al_hurr: [32.66, 43.93],
  ain_tamr_rd: [32.6, 43.9],
  hindiya_rd: [32.55, 44.1],
};
