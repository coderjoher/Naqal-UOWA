import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { planWave } from './dispatch';
import { load, passengers, violation } from './schedule';
import { ctxFor } from './test-city';
import { Gender, Passenger, WaveKind } from './types';

interface Fixture {
  name: string;
  kind: WaveKind;
  waveHour: number;
  points: Record<string, [number, number]>;
  tiers: Record<string, number>;
  requests: [string, Gender, number][];
  drivers: number[];
}

const DIR = join(__dirname, 'fixtures');
const UPDATE = process.env.UPDATE_GOLDENS === '1';

describe('[T4-02] planWave on fixture cities', () => {
  for (const file of readdirSync(DIR).filter((f) => f.endsWith('.json') && !f.endsWith('.golden.json'))) {
    it(`${file}: groups by gender and tier with the fewest runs`, () => {
      const fx = JSON.parse(readFileSync(join(DIR, file), 'utf8')) as Fixture;
      const ctx = ctxFor(fx.points, fx.kind, fx.waveHour, (fx.waveHour - 1) * 3600);
      let n = 0;
      const requests: Passenger[] = fx.requests.flatMap(([pointId, gender, count]) =>
        Array.from({ length: count }, () => ({ id: `q${++n}`, pointId, gender, tierId: `T${fx.tiers[pointId]}`, tierRank: fx.tiers[pointId], subscriber: true, createdAt: n })),
      );
      const { runs, waitlisted } = planWave(requests, fx.drivers.map((seats, i) => ({ id: `d${i + 1}`, seats })), ctx);

      expect(waitlisted).toEqual([]);
      for (const r of runs) expect(violation(r, ctx)).toBeNull();

      // Fewest runs: never more than packing each gender/tier group separately into the biggest
      // free buses, never fewer than the seats physically allow per gender.
      const groups = new Map<string, number>();
      const genders = new Map<string, number>();
      for (const p of requests) {
        groups.set(`${p.gender}/${p.tierId}`, (groups.get(`${p.gender}/${p.tierId}`) ?? 0) + 1);
        genders.set(p.gender, (genders.get(p.gender) ?? 0) + 1);
      }
      const buses = (counts: number[]) => {
        const pool = [...fx.drivers].sort((a, b) => b - a);
        let used = 0;
        for (const c of counts) for (let seats = 0; seats < c; used++) seats += pool[used];
        return used;
      };
      const upper = buses([...groups.values()]);
      const lower = Math.max(...[...genders.values()].map((c) => buses([c])));
      expect(runs.length).toBeLessThanOrEqual(upper);
      expect(runs.length).toBeGreaterThanOrEqual(lower);

      const summary = {
        runs: runs.length,
        plan: runs
          .map((r) => ({
            gender: r.gender,
            tier: r.tierId,
            seats: `${load(r)}/${r.capacity}`,
            stops: r.stops.map((s) => `${s.pointId}×${s.passengers.length}@${clock(s.time)}`),
            tiers: [...new Set(passengers(r).map((p) => p.tierId))].sort(),
          }))
          .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b))),
      };
      const golden = join(DIR, file.replace('.json', '.golden.json'));
      if (UPDATE || !existsSync(golden)) writeFileSync(golden, JSON.stringify(summary, null, 2) + '\n');
      expect(summary).toEqual(JSON.parse(readFileSync(golden, 'utf8')));
    });
  }
});

function clock(s: number) {
  return `${String(Math.floor(s / 3600)).padStart(2, '0')}:${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}`;
}
