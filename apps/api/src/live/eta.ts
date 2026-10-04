import { haversineKm } from '../geo/geo';

export interface RouteStop {
  seq: number; // 1-based
  pointId: string;
  lat: number;
  lng: number;
  served: boolean;
}

/** Road factor and urban speed used for the leg from the bus's live position to its next stop. */
const ROAD_FACTOR = 1.3;
const URBAN_KMH = 30;

/**
 * ST-06: seconds from the bus's current position to every remaining stop. The first leg is
 * estimated from the live point; later legs come from the OSRM matrix (DS-01), plus dwell time.
 */
export function etas(bus: { lat: number; lng: number }, stops: RouteStop[], travel: (from: string, to: string) => number | undefined, dwellS = 60) {
  const left = stops.filter((s) => !s.served).sort((a, b) => a.seq - b.seq);
  const out: { seq: number; seconds: number }[] = [];
  let t = 0;
  left.forEach((s, i) => {
    if (i === 0) {
      t += Math.round(((haversineKm(bus, s) * ROAD_FACTOR) / URBAN_KMH) * 3600);
    } else {
      const prev = left[i - 1];
      t += dwellS + (travel(prev.pointId, s.pointId) ?? Math.round(((haversineKm(prev, s) * ROAD_FACTOR) / URBAN_KMH) * 3600));
    }
    out.push({ seq: s.seq, seconds: t });
  });
  return out;
}
