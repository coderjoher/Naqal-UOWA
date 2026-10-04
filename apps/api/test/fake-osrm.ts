/**
 * Deterministic stand-in for OSRM used by tests and local demos (the real Iraq extract is ~1 GB).
 * Road distance = straight-line × 1.2, speed 30 km/h. Implements /route and /table (driving).
 *   npx ts-node test/fake-osrm.ts 5000
 */
import { createServer, Server } from 'node:http';

const R = 6371008.8;
const rad = (d: number) => (d * Math.PI) / 180;
function metres(a: [number, number], b: [number, number]) {
  const [lng1, lat1] = a;
  const [lng2, lat2] = b;
  const h = Math.sin(rad(lat2 - lat1) / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lng2 - lng1) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h)) * 1.2;
}
const seconds = (m: number) => m / (30_000 / 3600);

export const fakeOsrmStats = { route: 0, table: 0 };

export function startFakeOsrm(port: number, host = '127.0.0.1'): Promise<Server> {
  const server = createServer((req, res) => {
    res.setHeader('content-type', 'application/json');
    const url = new URL(req.url ?? '/', 'http://x');
    const m = /^\/(route|table)\/v1\/driving\/(.+)$/.exec(url.pathname);
    if (!m) return void res.end(JSON.stringify({ code: 'InvalidUrl' }));
    const coords = m[2].split(';').map((c) => c.split(',').map(Number) as [number, number]);
    if (m[1] === 'route') {
      fakeOsrmStats.route++;
      const d = metres(coords[0], coords[coords.length - 1]);
      return void res.end(JSON.stringify({ code: 'Ok', routes: [{ distance: d, duration: seconds(d) }] }));
    }
    fakeOsrmStats.table++;
    const distances = coords.map((a) => coords.map((b) => metres(a, b)));
    const durations = distances.map((row) => row.map(seconds));
    res.end(JSON.stringify({ code: 'Ok', durations, distances }));
  });
  return new Promise((resolve) => server.listen(port, host, () => resolve(server)));
}

if (require.main === module) {
  const port = Number(process.argv[2] ?? 5000);
  startFakeOsrm(port, '0.0.0.0').then(() => console.log(`fake OSRM on :${port}`));
}
