import { LatLng } from '../geo/geo';
import { counts, distanceToSegmentKm, TrackInput, verifyTrack } from './verify';

const campus = { lat: 32.5847, lng: 44.0617 };
const stops = [
  { lat: 32.6160, lng: 44.0240 },
  { lat: 32.6050, lng: 44.0380 },
  { lat: 32.5950, lng: 44.0500 },
];
const T0 = new Date('2026-10-05T04:30:00Z').getTime();

/** A normal track: one stored point a minute at ~30 km/h along the legs, plus one at every stop. */
function drive(path: LatLng[], startAt = T0) {
  const out: (LatLng & { at: Date })[] = [];
  let t = startAt;
  out.push({ ...path[0], at: new Date(t) });
  for (let i = 1; i < path.length; i++) {
    const a = path[i - 1];
    const b = path[i];
    const km = Math.hypot((b.lat - a.lat) * 110.57, (b.lng - a.lng) * 93.9);
    const minutes = Math.max(1, Math.ceil((km / 30) * 60));
    for (let m = 1; m <= minutes; m++) {
      t += 60_000;
      out.push({ lat: a.lat + ((b.lat - a.lat) * m) / minutes, lng: a.lng + ((b.lng - a.lng) * m) / minutes, at: new Date(t) });
    }
  }
  return { positions: out, end: t };
}

function morningRun(mutate?: (p: (LatLng & { at: Date })[]) => void): TrackInput {
  const home = { lat: 32.6250, lng: 44.0150 };
  const { positions, end } = drive([home, ...stops, campus]);
  mutate?.(positions);
  return { morning: true, completed: true, startedAt: new Date(T0), endedAt: new Date(end), campus, stops, positions };
}

describe('run verification (SE-02) and GPS anomalies (NF-15)', () => {
  it('a normal morning run is verified with no flags', () => {
    expect(verifyTrack(morningRun())).toEqual({ verified: true, flags: [] });
  });

  it('a normal return run (campus → stops) is verified', () => {
    const { positions, end } = drive([campus, ...[...stops].reverse()]);
    expect(verifyTrack({ morning: false, completed: true, startedAt: new Date(T0), endedAt: new Date(end), campus, stops: [...stops].reverse(), positions })).toEqual({ verified: true, flags: [] });
  });

  it('[T6-03] runs that skip a stop, end elsewhere or have impossible speeds are excluded', () => {
    // Skips stop 2: every point near it is moved 1 km away.
    const skipped = verifyTrack(morningRun((ps) => ps.forEach((p) => {
      if (Math.abs(p.lat - stops[1].lat) < 0.002 && Math.abs(p.lng - stops[1].lng) < 0.002) p.lat += 0.009;
    })));
    expect(skipped.verified).toBe(false);
    expect(skipped.flags).toContain('missed_stop:2');

    // Ends 5 km from campus.
    const elsewhere = verifyTrack(morningRun((ps) => ps.splice(ps.length - 2, 2)));
    const r = morningRun();
    r.positions = r.positions.filter((p) => Math.hypot(p.lat - campus.lat, p.lng - campus.lng) > 0.01);
    expect(verifyTrack(r).flags).toContain('ended_elsewhere');
    expect(elsewhere.verified).toBe(false);

    // 300 km/h between two points two minutes apart.
    const fast = verifyTrack(morningRun((ps) => {
      const i = 4;
      ps[i] = { ...ps[i], lat: ps[i - 1].lat + 0.09, at: new Date(ps[i - 1].at.getTime() + 120_000) };
    }));
    expect(fast.verified).toBe(false);
    expect(fast.flags).toContain('too_fast');

    // Never started / ended.
    expect(verifyTrack({ ...morningRun(), completed: false }).flags).toContain('not_completed');
    expect(verifyTrack({ ...morningRun(), positions: [] })).toEqual({ verified: false, flags: ['no_gps'] });
  });

  it('[T6-09] teleport, too-fast and off-path tracks are flagged; normal fixture tracks are not', () => {
    const teleport = verifyTrack(morningRun((ps) => {
      ps[6] = { ...ps[6], lat: ps[6].lat + 0.2, lng: ps[6].lng + 0.2, at: new Date(ps[5].at.getTime() + 30_000) };
    }));
    expect(teleport.flags).toContain('teleport');
    expect(teleport.verified).toBe(false);

    const tooFast = verifyTrack(morningRun((ps) => {
      ps[3] = { ...ps[3], at: new Date(ps[2].at.getTime() + 5_000) };
    }));
    expect(tooFast.flags).toContain('too_fast');

    // A detour 4 km off the planned legs between stop 1 and stop 2: flagged, still counted.
    const off = { lat: stops[0].lat + 0.036, lng: stops[0].lng + 0.03 };
    const d = drive([{ lat: 32.6250, lng: 44.0150 }, stops[0], off, ...stops.slice(1), campus]);
    const detour = verifyTrack({ morning: true, completed: true, startedAt: new Date(T0), endedAt: new Date(d.end), campus, stops, positions: d.positions });
    expect(detour.flags).toEqual(['off_path']);
    expect(detour.verified).toBe(true);

    // Normal fixtures at several start times and both directions: never flagged.
    for (let h = 0; h < 6; h++) {
      const { positions, end } = drive([{ lat: 32.63, lng: 44.01 }, ...stops, campus], T0 + h * 3600_000);
      expect(verifyTrack({ morning: true, completed: true, startedAt: new Date(T0 + h * 3600_000), endedAt: new Date(end), campus, stops, positions }).flags).toEqual([]);
    }
  });

  it('the office verdict overrides the GPS check', () => {
    expect(counts({ gpsVerified: false, officeVerdict: true })).toBe(true);
    expect(counts({ gpsVerified: true, officeVerdict: false })).toBe(false);
    expect(counts({ gpsVerified: true, officeVerdict: null })).toBe(true);
    expect(counts({ gpsVerified: null, officeVerdict: null })).toBe(false);
  });

  it('distance to a segment', () => {
    expect(distanceToSegmentKm(campus, campus, stops[0])).toBeCloseTo(0, 5);
    expect(distanceToSegmentKm({ lat: 32.5847 + 0.009, lng: 44.0617 }, campus, { lat: 32.5847, lng: 44.2 })).toBeCloseTo(1, 1);
  });
});
