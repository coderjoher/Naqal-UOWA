/*
 * NF-08 load test data: a separate "loadtest" university with the morning peak already under way
 * — buses on the road (runs started), students on board who track them, students who still have
 * to ask for a ride, and an office user — plus signed tokens for k6 and the socket swarm.
 *
 *   SCALE=3 npx ts-node scripts/load/prepare.ts > /tmp/load.json
 *
 * SCALE=1 is the expected morning peak (PRD: 150 buses, 2 000 students tracking); the launch
 * gate runs SCALE=3. Each run creates its own university (slug loadtest-<id>).
 */
import { PrismaClient } from '@prisma/client';
import { SignJWT } from 'jose';
import { randomUUID } from 'node:crypto';
import { calendarMonth } from '../../src/subscriptions/period-policy';

const SCALE = Number(process.env.SCALE ?? 1);
const BUSES = Math.round(150 * SCALE);
const RIDERS = Math.round(2000 * SCALE);
const FRESH = Math.round(1000 * SCALE);
const prisma = new PrismaClient();
const secret = new TextEncoder().encode(process.env.JWT_SECRET!);
const sign = (sub: string, role: string, uid: string) => new SignJWT({ role, uid }).setProtectedHeader({ alg: 'HS256' }).setSubject(sub).setIssuedAt().setExpirationTime('6h').sign(secret);
const baghdad = () => new Date(Date.now() + 3 * 3600_000);
const chunks = <T>(xs: T[], n = 5000) => Array.from({ length: Math.ceil(xs.length / n) }, (_, i) => xs.slice(i * n, i * n + n));

const CAMPUS = { lat: 32.5847, lng: 44.0617 };
// A ring of gathering points 3–9 km around campus.
const POINTS = Array.from({ length: 24 }, (_, i) => {
  const a = (i / 24) * 2 * Math.PI;
  const r = 0.03 + (i % 3) * 0.02;
  return { name: `L${i}`, lat: CAMPUS.lat + r * Math.sin(a), lng: CAMPUS.lng + r * Math.cos(a) };
});

async function main() {
  // A university of its own per run, so repeated runs never pile onto the same day's board.
  const tag = randomUUID().slice(0, 8);
  const uni = await prisma.university.create({
    data: { name: `Load test ${tag}`, slug: `loadtest-${tag}`, campusLat: CAMPUS.lat, campusLng: CAMPUS.lng, commissionPct: 10, waitlistMinutes: 30 },
  });
  const universityId = uni.id;
  const tier = await prisma.distanceTier.create({ data: { universityId, name: 'A', minKm: 0, maxKm: null, subscriptionPrice: 50000, ridePrice: 1500 } });
  await prisma.gatheringPoint.createMany({ data: POINTS.map((p) => ({ universityId, ...p, tierId: tier.id, tierOverridden: true })) });
  const points = await prisma.gatheringPoint.findMany({ where: { universityId }, orderBy: { name: 'asc' } });

  // Waves: the morning one under way (arrive in 45 min) and a later one students still ask for.
  const now = baghdad();
  const minute = (now.getUTCHours() * 60 + now.getUTCMinutes()) % (24 * 60);
  const date = new Date(`${now.toISOString().slice(0, 10)}T00:00:00Z`);
  const peak = await prisma.wave.create({ data: { universityId, type: 'morning', minuteOfDay: Math.min(minute + 45, 24 * 60 - 1), weekdays: 127 } });
  const later = await prisma.wave.create({ data: { universityId, type: 'return', minuteOfDay: Math.min(minute + 180, 24 * 60 - 1), weekdays: 127 } });
  // Mark the peak wave planned straight away, before the API's minute tick plans it itself.
  await prisma.wavePlan.createMany({ data: [{ universityId, waveId: peak.id, date }], skipDuplicates: true });

  const office = await prisma.user.create({ data: { universityId, role: 'office', name: 'Load office', email: `office@${tag}.loadtest.naql` } });

  const drivers = Array.from({ length: BUSES }, (_, i) => ({ id: randomUUID(), universityId, role: 'driver' as const, name: `Driver ${i}`, gender: 'male' as const }));
  const riders = Array.from({ length: RIDERS }, (_, i) => ({ id: randomUUID(), universityId, role: 'student' as const, name: `Rider ${i}`, studentId: `LR-${tag}-${i}`, gender: 'male' as const, defaultPointId: points[i % points.length].id }));
  const fresh = Array.from({ length: FRESH }, (_, i) => ({ id: randomUUID(), universityId, role: 'student' as const, name: `Fresh ${i}`, studentId: `LF-${tag}-${i}`, gender: 'male' as const, defaultPointId: points[i % points.length].id }));
  for (const c of chunks([...drivers, ...riders, ...fresh])) await prisma.user.createMany({ data: c });
  for (const c of chunks(drivers)) await prisma.driverProfile.createMany({ data: c.map((d) => ({ userId: d.id, universityId, status: 'approved' as const, vehicleType: 'coaster', plate: d.name, seats: 16 })) });

  // Each bus: 4 stops, started 10 minutes ago, riders spread over its stops.
  const perBus = Math.ceil(RIDERS / BUSES);
  const runs = drivers.map((d) => ({ id: randomUUID(), universityId, driverId: d.id, waveId: peak.id, date, gender: 'male' as const, tierId: tier.id, capacity: Math.max(16, perBus), status: 'started' as const, startedAt: new Date(Date.now() - 600_000) }));
  for (const c of chunks(runs)) await prisma.run.createMany({ data: c });
  const stopsOf = (i: number) => [0, 1, 2, 3].map((k) => points[(i * 4 + k) % points.length]);
  await prisma.runStop.createMany({ data: runs.flatMap((r, i) => stopsOf(i).map((p, k) => ({ universityId, runId: r.id, seq: k, pointId: p.id, eta: new Date(Date.now() + (k + 1) * 8 * 60_000) }))) });
  for (const c of chunks(riders.map((s, i) => ({ universityId, studentId: s.id, waveId: peak.id, date, pointId: stopsOf(i % BUSES)[i % 4].id, tierId: tier.id, gender: 'male' as const, subscriber: true, fare: 0, status: 'assigned' as const, runId: runs[i % BUSES].id }))))
    await prisma.rideRequest.createMany({ data: c });

  // Subscriptions for the riders (month-end settlement has a pool to share).
  const month = now.toISOString().slice(0, 7);
  const period = calendarMonth(month);
  const counter = await prisma.$queryRaw<{ last: number }[]>`
    INSERT INTO receipt_counters (university_id, last) VALUES (${universityId}::uuid, ${riders.length})
    ON CONFLICT (university_id) DO UPDATE SET last = receipt_counters.last + ${riders.length} RETURNING last`;
  const first = counter[0].last - riders.length + 1;
  const pays = riders.map((s, i) => ({ id: randomUUID(), universityId, type: 'subscription' as const, method: 'cash_office' as const, amount: tier.subscriptionPrice, receiptNo: first + i, studentId: s.id, collectedById: office.id }));
  for (const c of chunks(pays)) await prisma.payment.createMany({ data: c });
  for (const c of chunks(riders.map((s, i) => ({ universityId, studentId: s.id, tierId: tier.id, pointId: s.defaultPointId, month, periodStart: period.start, periodEnd: period.end, price: tier.subscriptionPrice, paymentId: pays[i].id }))))
    await prisma.subscription.createMany({ data: c });

  const out = {
    scale: SCALE,
    date: date.toISOString().slice(0, 10),
    month,
    laterWaveId: later.id,
    office: await sign(office.id, 'office', universityId),
    drivers: await Promise.all(runs.map(async (r, i) => ({ token: await sign(drivers[i].id, 'driver', universityId), runId: r.id, stops: stopsOf(i).map((p) => [p.lat, p.lng]) }))),
    riders: await Promise.all(riders.map(async (s, i) => ({ token: await sign(s.id, 'student', universityId), runId: runs[i % BUSES].id }))),
    fresh: await Promise.all(fresh.map(async (s) => ({ token: await sign(s.id, 'student', universityId) }))),
  };
  process.stdout.write(JSON.stringify(out));
  process.stderr.write(`Load data: ${BUSES} buses, ${RIDERS} riders, ${FRESH} students to request (scale ${SCALE})\n`);
}

main().finally(() => prisma.$disconnect());
