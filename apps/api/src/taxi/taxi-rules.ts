import type { TaxiRideStatus } from '@prisma/client';
import { haversineKm, LatLng } from '../geo/geo';

/** P10 campus taxis: the pure rules (fare, privacy of offers, driver choice, ride state). */

export interface TaxiTariff {
  baseFare: number;
  perKm: number;
  minFare: number;
}

/** Fares are rounded up to the nearest 250 IQD, the smallest note in use. */
export const FARE_STEP = 250;

/** TX-03: base + per-km × road distance, never below the minimum, rounded up to 250 IQD. */
export function fareFor(distanceKm: number, t: TaxiTariff): number {
  const raw = Math.max(t.minFare, t.baseFare + Math.ceil(Math.max(0, distanceKm) * t.perKm));
  return Math.ceil(raw / FARE_STEP) * FARE_STEP;
}

/**
 * TX-02 / NF-12: before a driver accepts, an offer shows only the area (about 500 m), never the
 * student's exact location. The exact point goes to the one driver who accepts.
 */
export function coarse(p: LatLng): LatLng {
  const r = (v: number) => Math.round(v / 0.005) * 0.005;
  return { lat: Number(r(p.lat).toFixed(3)), lng: Number(r(p.lng).toFixed(3)) };
}

export interface OnlineTaxi extends LatLng {
  driverId: string;
  /** Last heartbeat, epoch ms. */
  at: number;
}

/** Drivers stop counting as online when they have not reported for this long. */
export const ONLINE_STALE_MS = 60_000;
/** Offers go to taxis within this distance of the student, nearest first. */
export const OFFER_RADIUS_KM = 8;
export const OFFER_MAX_DRIVERS = 15;

/** TX-02: online, fresh, within the radius, not busy; nearest first. */
export function driversToOffer(online: OnlineTaxi[], point: LatLng, now: number, busy: Set<string>, radiusKm = OFFER_RADIUS_KM, max = OFFER_MAX_DRIVERS) {
  return online
    .filter((d) => now - d.at <= ONLINE_STALE_MS && !busy.has(d.driverId))
    .map((d) => ({ ...d, km: haversineKm(d, point) }))
    .filter((d) => d.km <= radiusKm)
    .sort((a, b) => a.km - b.km)
    .slice(0, max);
}

export type TaxiAction = 'accept' | 'arrive' | 'start' | 'end' | 'cancel_student' | 'cancel_driver' | 'expire';

/** Allowed status changes. `cancel_driver` puts the ride back on offer for other drivers. */
export function nextTaxiState(s: TaxiRideStatus, a: TaxiAction): TaxiRideStatus | null {
  switch (a) {
    case 'accept':
      return s === 'requested' ? 'accepted' : null;
    case 'arrive':
      return s === 'accepted' ? 'arrived' : null;
    case 'start':
      return s === 'accepted' || s === 'arrived' ? 'on_trip' : null;
    case 'end':
      return s === 'on_trip' ? 'done' : null;
    case 'cancel_student':
      return s === 'requested' || s === 'accepted' || s === 'arrived' ? 'cancelled' : null;
    case 'cancel_driver':
      return s === 'accepted' || s === 'arrived' ? 'requested' : null;
    case 'expire':
      return s === 'requested' ? 'expired' : null;
  }
}

export const ACTIVE_TAXI: TaxiRideStatus[] = ['requested', 'accepted', 'arrived', 'on_trip'];

/** Minutes for a taxi to cover a distance in town (straight line × road factor at 25 km/h). */
export function etaMinutes(from: LatLng, to: LatLng): number {
  return Math.max(1, Math.round(((haversineKm(from, to) * 1.3) / 25) * 60));
}
