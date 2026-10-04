/*
 * Demo: drives today's dispatched runs like real drivers would — start, GPS every few seconds
 * along the route, arrive, board everyone, leave, … , end — through the public API, so the
 * dashboard's Live operations page and the student app's tracking show moving buses.
 *
 *   docker compose exec api npx ts-node scripts/simulate.ts          (inside the stack)
 *   pnpm simulate                                                     (local API on :3000)
 *
 * Env: API_URL (default http://localhost:3000), JWT_SECRET, DATABASE_URL, SIM_STEP_MS (default 2000).
 */
import { PrismaClient } from '@prisma/client';
import { SignJWT } from 'jose';
import { randomUUID } from 'node:crypto';

const API = (process.env.API_URL ?? `http://localhost:${process.env.PORT ?? 3000}`).replace(/\/$/, '');
const STEP_MS = Number(process.env.SIM_STEP_MS ?? 2000);
const prisma = new PrismaClient();
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const today = () => new Date(Date.now() + 3 * 3600_000).toISOString().slice(0, 10);

async function token(user: { id: string; role: string; universityId: string | null }) {
  return new SignJWT({ role: user.role, uid: user.universityId })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(user.id)
    .setIssuedAt()
    .setExpirationTime('2h')
    .sign(new TextEncoder().encode(process.env.JWT_SECRET!));
}

async function call(tok: string, path: string, body: object) {
  const res = await fetch(`${API}${path}`, { method: 'POST', headers: { authorization: `Bearer ${tok}`, 'content-type': 'application/json' }, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`${path}: ${res.status} ${await res.text()}`);
  return res.json();
}

async function drive(runId: string) {
  const run = await prisma.run.findUniqueOrThrow({
    where: { id: runId },
    include: { driver: true, wave: true, university: true, stops: { orderBy: { seq: 'asc' }, include: { point: true } }, requests: { where: { status: 'assigned' } } },
  });
  const tok = await token(run.driver);
  const act = (type: string, extra: object = {}) => call(tok, `/runs/${runId}/actions`, { actions: [{ clientId: randomUUID(), type, at: new Date().toISOString(), ...extra }] });
  const gps = (lat: number, lng: number) => call(tok, `/runs/${runId}/gps`, { points: [{ lat, lng, at: new Date().toISOString(), speed: 8 }] });
  const campus = { lat: run.university.campusLat, lng: run.university.campusLng };
  const morning = run.wave.type === 'morning';
  const path = run.stops.map((s) => ({ lat: s.point.lat, lng: s.point.lng, seq: s.seq + 1, pointId: s.pointId, name: s.point.nameAr ?? s.point.name }));
  const label = `${run.driver.nameAr ?? run.driver.name} (${morning ? 'ذهاب' : 'عودة'})`;

  const move = async (from: { lat: number; lng: number }, to: { lat: number; lng: number }, steps = 8) => {
    for (let i = 1; i <= steps; i++) {
      await gps(from.lat + ((to.lat - from.lat) * i) / steps, from.lng + ((to.lng - from.lng) * i) / steps);
      await sleep(STEP_MS);
    }
  };

  // Return runs: everyone boards on campus before leaving.
  await act('start', morning ? {} : { requestIds: run.requests.map((r) => r.id) });
  console.log(`▶ ${label}: started`);
  let pos = morning ? { lat: path[0].lat + 0.01, lng: path[0].lng - 0.01 } : campus;
  await gps(pos.lat, pos.lng);
  for (const stop of path) {
    await move(pos, stop);
    pos = stop;
    await act('arrive', { seq: stop.seq });
    console.log(`  ${label}: at ${stop.seq}. ${stop.name}`);
    await sleep(STEP_MS * 2);
    if (morning) {
      const riders = run.requests.filter((r) => r.pointId === stop.pointId).map((r) => r.id);
      if (riders.length) await act('board', { requestIds: riders });
    }
    await act('depart');
  }
  if (morning) await move(pos, campus);
  await act('end');
  console.log(`■ ${label}: finished`);
}

async function main() {
  const date = new Date(`${today()}T00:00:00Z`);
  const runs = await prisma.run.findMany({ where: { date, status: 'planned' }, select: { id: true } });
  if (!runs.length) {
    console.log('No dispatched runs for today. Press "Dispatch now" on the Dispatch page first, then run this again.');
    return;
  }
  console.log(`Driving ${runs.length} run(s) — open the dashboard's Live operations page.`);
  await Promise.all(runs.map((r) => drive(r.id).catch((e) => console.error(`run ${r.id}: ${(e as Error).message}`))));
}

main().finally(() => prisma.$disconnect());
