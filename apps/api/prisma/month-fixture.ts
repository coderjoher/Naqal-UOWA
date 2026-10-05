/*
 * A finished month of service for one university, written straight to the database: students who
 * paid their subscriptions, drivers who drove morning runs on weekdays with a stored GPS track,
 * cash fares from pay-per-ride riders, and two runs that must not count (one never ended, one
 * with a teleporting track). Used by the settlement tests, the dashboard e2e test and the demo.
 */
import { Prisma, PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

export interface MonthFixture {
  month: string;
  tiers: { id: string; name: string }[];
  drivers: { id: string; name: string; phone: string }[];
  runs: number;
  badRunId: string;
  unfinishedRunId: string;
}

type Db = PrismaClient | Prisma.TransactionClient;

const CAMPUS_FALLBACK = { lat: 32.5847, lng: 44.0617 };
const POINTS = [
  { name: 'Al-Abbas Square', nameAr: 'ساحة العباس', lat: 32.6160, lng: 44.0240, tier: 0 },
  { name: 'Hay Al-Hussein', nameAr: 'حي الحسين', lat: 32.6050, lng: 44.0380, tier: 0 },
  { name: 'Hay Al-Askari', nameAr: 'حي العسكري', lat: 32.5600, lng: 44.0010, tier: 1 },
  { name: 'Al-Iskan', nameAr: 'الإسكان', lat: 32.5480, lng: 43.9880, tier: 1 },
];
const DRIVERS = [
  { name: 'Ali Hassan', nameAr: 'علي حسن', phone: '07801110001', plate: '12 ك 34567' },
  { name: 'Kadhim Jabbar', nameAr: 'كاظم جبار', phone: '07801110002', plate: '45 ك 12121' },
  { name: 'Mustafa Adel', nameAr: 'مصطفى عادل', phone: '07801110003', plate: '77 ك 90876' },
];

const days = (month: string) => {
  const [y, m] = month.split('-').map(Number);
  const n = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return Array.from({ length: n }, (_, i) => `${month}-${String(i + 1).padStart(2, '0')}`);
};

async function receipt(db: Db, universityId: string) {
  const rows = await db.$queryRaw<{ last: number }[]>`
    INSERT INTO receipt_counters (university_id, last) VALUES (${universityId}::uuid, 1)
    ON CONFLICT (university_id) DO UPDATE SET last = receipt_counters.last + 1
    RETURNING last`;
  return rows[0].last;
}

/** Straight-line track from a to b, one stored point a minute at ~30 km/h. */
function leg(a: { lat: number; lng: number }, b: { lat: number; lng: number }, t0: number) {
  const km = Math.hypot((b.lat - a.lat) * 110.57, (b.lng - a.lng) * 93.9);
  const minutes = Math.max(1, Math.ceil((km / 30) * 60));
  return Array.from({ length: minutes }, (_, i) => ({ lat: a.lat + ((b.lat - a.lat) * (i + 1)) / minutes, lng: a.lng + ((b.lng - a.lng) * (i + 1)) / minutes, at: new Date(t0 + (i + 1) * 60_000) }));
}

export async function seedMonth(db: Db, universityId: string, month: string, opts: { officeUserId?: string; passwordHash?: string; phoneSeries?: number; driverIds?: string[] } = {}): Promise<MonthFixture> {
  const uni = await db.university.findUniqueOrThrow({ where: { id: universityId } });
  const campus = { lat: uni.campusLat ?? CAMPUS_FALLBACK.lat, lng: uni.campusLng ?? CAMPUS_FALLBACK.lng };
  const hash = opts.passwordHash ?? (await bcrypt.hash('password123', 4));

  let tiers = await db.distanceTier.findMany({ where: { universityId }, orderBy: { minKm: 'asc' } });
  if (tiers.length === 0) {
    tiers = [
      await db.distanceTier.create({ data: { universityId, name: 'A', minKm: 0, maxKm: 5, subscriptionPrice: 50000, ridePrice: 1500 } }),
      await db.distanceTier.create({ data: { universityId, name: 'B', minKm: 5, maxKm: null, subscriptionPrice: 75000, ridePrice: 2500 } }),
    ];
  }
  tiers = tiers.slice(0, 2);
  const points = [];
  for (const p of POINTS) {
    const tier = tiers[Math.min(p.tier, tiers.length - 1)];
    points.push(
      (await db.gatheringPoint.findFirst({ where: { universityId, name: `${p.name} (S)` } })) ??
        (await db.gatheringPoint.create({ data: { universityId, name: `${p.name} (S)`, nameAr: p.nameAr, lat: p.lat, lng: p.lng, tierId: tier.id, tierOverridden: true } })),
    );
  }
  const wave =
    (await db.wave.findFirst({ where: { universityId, type: 'morning', minuteOfDay: 8 * 60 } })) ??
    (await db.wave.create({ data: { universityId, type: 'morning', minuteOfDay: 8 * 60, weekdays: 0b0011111, active: false } }));

  const office = opts.officeUserId ?? (await db.user.findFirstOrThrow({ where: { universityId, role: 'office' } })).id;
  const drivers: { id: string; name: string; phone: string }[] = [];
  // Existing drivers (the demo's) get the history; otherwise three fixture drivers are created.
  for (const id of opts.driverIds ?? []) {
    const u = await db.user.findUniqueOrThrow({ where: { id } });
    drivers.push({ id: u.id, name: u.nameAr ?? u.name, phone: u.loginPhone ?? '' });
  }
  for (const base of opts.driverIds?.length ? [] : DRIVERS) {
    // Separate phone series per university (sign-in phones are globally unique).
    const local = base.phone.replace('0780111', `0780${String(opts.phoneSeries ?? 111).padStart(3, '0')}`);
    const d = { ...base, phone: `+964${local.slice(1)}` };
    const user =
      (await db.user.findUnique({ where: { loginPhone: d.phone } })) ??
      (await db.user.create({ data: { universityId, role: 'driver', name: d.name, nameAr: d.nameAr, phone: d.phone, loginPhone: d.phone, gender: 'male' } }));
    await db.driverProfile.upsert({ where: { userId: user.id }, create: { userId: user.id, universityId, status: 'approved', vehicleType: 'coaster', plate: d.plate, seats: 14, modelYear: 2019 }, update: {} });
    drivers.push({ id: user.id, name: d.nameAr, phone: d.phone });
  }

  // Students: 12 per tier subscribed for the month, 4 paying per ride.
  const students = [];
  for (let i = 0; i < 32; i++) {
    const point = points[i % points.length];
    const sid = `S-${month.replace('-', '')}-${String(i + 1).padStart(2, '0')}`;
    const user =
      (await db.user.findFirst({ where: { universityId, studentId: sid } })) ??
      (await db.user.create({ data: { universityId, role: 'student', studentId: sid, name: `Student ${sid}`, gender: 'male', passwordHash: hash, defaultPointId: point.id } }));
    students.push({ user, point, subscriber: i < 28 });
  }
  const [y, m] = month.split('-').map(Number);
  const start = new Date(Date.UTC(y, m - 1, 1));
  const end = new Date(Date.UTC(y, m, 0));
  for (const s of students.filter((x) => x.subscriber)) {
    if (await db.subscription.findFirst({ where: { studentId: s.user.id, month, status: 'active' } })) continue;
    const tier = tiers.find((t) => t.id === s.point.tierId)!;
    const pay = await db.payment.create({
      data: { universityId, type: 'subscription', method: 'cash_office', amount: tier.subscriptionPrice, receiptNo: await receipt(db, universityId), studentId: s.user.id, collectedById: office, createdAt: new Date(start.getTime() + 6 * 3600_000) },
    });
    await db.subscription.create({ data: { universityId, studentId: s.user.id, tierId: tier.id, pointId: s.point.id, month, periodStart: start, periodEnd: end, price: tier.subscriptionPrice, paymentId: pay.id } });
  }

  // Runs: weekdays (Sun–Thu), driver i serves tier (i % 2). Each run picks up at two points.
  let runs = 0;
  let badRunId = '';
  let unfinishedRunId = '';
  const weekdays = days(month).filter((d) => new Date(`${d}T00:00:00Z`).getUTCDay() <= 4);
  for (const [di, date] of weekdays.entries()) {
    for (const [i, d] of drivers.entries()) {
      const tier = tiers[i % tiers.length];
      const stops = points.filter((p) => p.tierId === tier.id).slice(0, 2);
      if (stops.length === 0) continue;
      const existing = await db.run.findUnique({ where: { driverId_waveId_date: { driverId: d.id, waveId: wave.id, date: new Date(`${date}T00:00:00Z`) } } });
      if (existing) continue;
      const t0 = Date.parse(`${date}T00:00:00Z`) - 3 * 3600_000 + (7 * 60 + 5 + i * 3) * 60_000;
      const home = { lat: stops[0].lat + 0.01, lng: stops[0].lng - 0.008 };
      const track = [{ ...home, at: new Date(t0) }];
      const stopTimes: number[] = [];
      for (const s of [...stops, campus]) {
        const last = track[track.length - 1];
        track.push(...leg(last, s, last.at.getTime()));
        stopTimes.push(track[track.length - 1].at.getTime());
        track.push({ ...track[track.length - 1], at: new Date(track[track.length - 1].at.getTime() + 60_000) });
      }
      const isBad = di === 2 && i === 2;
      const isUnfinished = di === 3 && i === 1;
      if (isBad) track.splice(6, 1, { lat: track[5].lat + 0.25, lng: track[5].lng + 0.25, at: new Date(track[5].at.getTime() + 20_000) });
      const endedAt = track[track.length - 1].at;
      const run = await db.run.create({
        data: {
          universityId,
          driverId: d.id,
          waveId: wave.id,
          date: new Date(`${date}T00:00:00Z`),
          gender: 'male',
          tierId: tier.id,
          capacity: 14,
          status: isUnfinished ? 'started' : 'done',
          startedAt: new Date(t0),
          endedAt: isUnfinished ? null : endedAt,
          stops: { create: stops.map((p, k) => ({ universityId, seq: k, pointId: p.id, eta: new Date(stopTimes[k]), arrivedAt: new Date(stopTimes[k]), servedAt: new Date(stopTimes[k] + 60_000) })) },
        },
      });
      await db.runPosition.createMany({ data: (isUnfinished ? track.slice(0, 5) : track).map((p) => ({ universityId, runId: run.id, lat: p.lat, lng: p.lng, at: p.at })) });
      if (isBad) badRunId = run.id;
      if (isUnfinished) unfinishedRunId = run.id;
      runs++;

      // Riders: subscribers at these points, plus one pay-per-ride rider every other day.
      const riders = students.filter((s) => stops.some((p) => p.id === s.point.id)).filter((s, k) => s.subscriber ? (k + di) % 3 !== 0 : di % 2 === 0);
      for (const s of riders.slice(0, 14)) {
        const fare = s.subscriber ? 0 : tier.ridePrice;
        const req = await db.rideRequest.create({
          data: { universityId, studentId: s.user.id, waveId: wave.id, date: new Date(`${date}T00:00:00Z`), pointId: s.point.id, tierId: tier.id, gender: 'male', subscriber: s.subscriber, fare, status: isUnfinished ? 'assigned' : 'done', runId: run.id, boardedAt: new Date(t0 + 20 * 60_000) },
        });
        if (fare > 0 && !isUnfinished) {
          await db.payment.create({
            data: { universityId, type: 'cash_fare', method: 'cash_driver', amount: fare, receiptNo: await receipt(db, universityId), studentId: s.user.id, collectedById: d.id, runId: run.id, rideRequestId: req.id, createdAt: new Date(t0 + 25 * 60_000) },
          });
        }
      }
    }
  }
  return { month, tiers: tiers.map((t) => ({ id: t.id, name: t.name })), drivers, runs, badRunId, unfinishedRunId };
}
