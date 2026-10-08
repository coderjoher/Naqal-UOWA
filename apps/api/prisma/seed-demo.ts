/*
 * Demo data for trying the whole system: Warith Al-Anbiyaa University in Karbala with tiers,
 * gathering points, waves every day, approved drivers available all week, students (some
 * subscribed) and open ride requests for the next wave.
 *
 * Runs once: skipped when the university already has tiers. Passwords are for demos only.
 *   pnpm db:demo
 */
import { DistanceTier, GatheringPoint, Gender, PrismaClient, Wave } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { Queue } from 'bullmq';
import { seedMonth } from './month-fixture';

const prisma = new PrismaClient();
const OFFICE_PASSWORD = 'password123';
const STUDENT_PASSWORD = 'student123';
const ACTIVATION_CODE = '246810';

const CAMPUS = { lat: 32.5847, lng: 44.0617 };
// Approximate Karbala neighbourhoods around the campus.
const POINTS: [string, string, number, number][] = [
  ['Bab Baghdad', 'باب بغداد', 32.6, 44.05],
  ['Al-Abbas Square', 'ساحة العباس', 32.616, 44.0249],
  ['Hay Al-Askari', 'حي العسكري', 32.63, 44.03],
  ['Hay Al-Hussein', 'حي الحسين', 32.62, 44.0],
  ['Hay Al-Ghadeer', 'حي الغدير', 32.585, 44.025],
  ['Al-Hindiya Road', 'طريق الهندية', 32.56, 44.1],
  ['Hay Al-Mulhaq', 'حي الملحق', 32.64, 43.99],
  ['Al-Hurr', 'الحر', 32.66, 43.93],
];
const TIERS = [
  { name: 'A', minKm: 0, maxKm: 5, subscriptionPrice: 40000, ridePrice: 1500 },
  { name: 'B', minKm: 5, maxKm: 10, subscriptionPrice: 60000, ridePrice: 2000 },
  { name: 'C', minKm: 10, maxKm: null, subscriptionPrice: 80000, ridePrice: 3000 },
];
const WAVES: ['morning' | 'return', number][] = [
  ['morning', 8 * 60],
  ['morning', 10 * 60],
  ['return', 14 * 60],
  ['return', 16 * 60],
];
const DRIVERS: [string, string, string, number][] = [
  ['Haider Abbas', 'حيدر عباس', '07800000001', 14],
  ['Sajjad Nasser', 'سجاد ناصر', '07800000002', 18],
  ['Mustafa Ali', 'مصطفى علي', '07800000003', 26],
  ['Karrar Hussein', 'كرار حسين', '07800000004', 14],
  ['Ahmed Falah', 'أحمد فلاح', '07800000005', 18],
  ['Murtadha Jasim', 'مرتضى جاسم', '07800000006', 26],
];
const FEMALE = ['زينب', 'مريم', 'فاطمة', 'نور', 'سارة', 'رقية', 'حوراء', 'زهراء', 'آيات', 'بتول', 'دعاء', 'هدى', 'ضحى', 'رسل', 'تبارك'];
const MALE = ['علي', 'حسين', 'محمد', 'عباس', 'حسن', 'جعفر', 'مهدي', 'كرار', 'منتظر', 'باقر', 'سجاد', 'أمير', 'يوسف', 'عمار', 'زيد'];
const FAMILY = ['الكربلائي', 'الموسوي', 'الحسيني', 'الطائي', 'الخفاجي', 'الجبوري', 'العبيدي', 'الشمري', 'الزبيدي', 'الأسدي'];

const km = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => {
  const r = Math.PI / 180;
  const h = Math.sin(((b.lat - a.lat) * r) / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(((b.lng - a.lng) * r) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
};
const baghdad = (plus = 0) => new Date(Date.now() + 3 * 3600_000 + plus * 86400_000);
const isoDate = (d: Date) => d.toISOString().slice(0, 10);
const dbDate = (s: string) => new Date(`${s}T00:00:00Z`);

async function main() {
  const passwordHash = await bcrypt.hash(OFFICE_PASSWORD, 10);
  const studentHash = await bcrypt.hash(STUDENT_PASSWORD, 10);
  const codeHash = await bcrypt.hash(ACTIVATION_CODE, 10);

  const uni = await prisma.university.upsert({
    where: { slug: 'warith' },
    update: {},
    create: { name: 'Warith Al-Anbiyaa University', nameAr: 'جامعة وارث الأنبياء', slug: 'warith', campusLat: CAMPUS.lat, campusLng: CAMPUS.lng, commissionPct: 10, waitlistMinutes: 30 },
  });
  if ((await prisma.distanceTier.count({ where: { universityId: uni.id } })) > 0) {
    // Stacks created before P6 get last month's history once (skipped when it already has runs).
    await seedLastMonth(uni.id);
    await seedTaxis(uni.id);
    console.log('Demo data already present — nothing else to do.');
    return;
  }
  const universityId = uni.id;
  await prisma.university.update({
    where: { id: universityId },
    data: {
      coverage: [
        [32.45, 43.85],
        [32.45, 44.25],
        [32.75, 44.25],
        [32.75, 43.85],
      ],
      officeNote: 'مكتب النقل — البناية ب، الطابق الأرضي، من 9 صباحاً حتى 1 ظهراً',
    },
  });

  for (const u of [
    { email: 'admin@naql.app', name: 'Platform Admin', role: 'super_admin' as const, universityId: null },
    { email: 'office@uowa.edu.iq', name: 'مكتب النقل', role: 'office' as const, universityId },
  ]) {
    await prisma.user.upsert({ where: { email: u.email }, update: {}, create: { ...u, passwordHash } });
  }
  const office = await prisma.user.findUniqueOrThrow({ where: { email: 'office@uowa.edu.iq' } });

  const tiers: DistanceTier[] = [];
  for (const t of TIERS) tiers.push(await prisma.distanceTier.create({ data: { ...t, universityId } }));
  const tierFor = (d: number) => tiers.find((t) => d >= t.minKm && (t.maxKm == null || d < t.maxKm))!;

  const points: GatheringPoint[] = [];
  for (const [name, nameAr, lat, lng] of POINTS) {
    const d = km({ lat, lng }, CAMPUS) * 1.3;
    points.push(await prisma.gatheringPoint.create({ data: { universityId, name, nameAr, lat, lng, distanceKm: Math.round(d * 10) / 10, tierId: tierFor(d).id } }));
  }

  const waves: Wave[] = [];
  for (const [type, minuteOfDay] of WAVES) waves.push(await prisma.wave.create({ data: { universityId, type, minuteOfDay, weekdays: 127 } }));

  await prisma.driverRequirementSet.upsert({
    where: { universityId },
    update: {},
    create: {
      universityId,
      documents: [
        { key: 'national_id', label: 'National ID card', labelAr: 'البطاقة الوطنية', required: true },
        { key: 'driving_licence', label: 'Driving licence', labelAr: 'إجازة السوق', required: true },
        { key: 'vehicle_registration', label: 'Vehicle registration (sanwiya)', labelAr: 'سنوية السيارة', required: true },
        { key: 'vehicle_photo', label: 'Vehicle photo (shown to students)', labelAr: 'صورة المركبة (تظهر للطلاب)', required: true },
      ],
      vehicleTypes: ['coaster', 'minibus', 'bus'],
      minSeats: 10,
      maxVehicleAgeYears: 15,
    },
  });

  // Approved drivers, available for every wave for the next 7 days.
  const days = Array.from({ length: 7 }, (_, i) => isoDate(baghdad(i)));
  for (const [i, [name, nameAr, phone, seats]] of DRIVERS.entries()) {
    const user = await prisma.user.create({
      data: { universityId, role: 'driver', name, nameAr, loginPhone: `+964${phone.slice(1)}`, phone: `+964${phone.slice(1)}`, gender: 'male' },
    });
    await prisma.driverProfile.create({
      data: { userId: user.id, universityId, status: 'approved', vehicleType: seats >= 26 ? 'bus' : 'coaster', plate: `${12340 + i} كربلاء`, seats, modelYear: 2018 + (i % 5), submittedAt: new Date(), reviewedAt: new Date(), reviewedById: office.id },
    });
    await prisma.driverAvailability.createMany({ data: days.flatMap((date) => waves.map((w) => ({ universityId, driverId: user.id, date: dbDate(date), waveId: w.id }))) });
  }
  // One application waiting for the office to review.
  const pending = await prisma.user.create({ data: { universityId, role: 'driver', name: 'Yasser Kadhim', nameAr: 'ياسر كاظم', loginPhone: '+9647800000009', phone: '+9647800000009', gender: 'male' } });
  await prisma.driverProfile.create({ data: { userId: pending.id, universityId, status: 'pending', vehicleType: 'minibus', plate: '55 ك 99887', seats: 16, modelYear: 2017, submittedAt: new Date() } });

  // 40 students: the first 30 are activated (password student123), the last 10 wait for an activation code.
  const month = isoDate(baghdad()).slice(0, 7);
  const [y, m] = month.split('-').map(Number);
  let receipt = 0;
  const students = [];
  for (let i = 0; i < 40; i++) {
    const gender: Gender = i % 2 === 0 ? 'female' : 'male';
    const first = (gender === 'female' ? FEMALE : MALE)[Math.floor(i / 2) % 15];
    const nameAr = `${first} ${FAMILY[i % FAMILY.length]}`;
    const studentId = `W-${1001 + i}`;
    const activated = i < 30;
    await prisma.rosterEntry.create({
      data: {
        universityId,
        studentId,
        name: nameAr,
        nameAr,
        gender,
        activatedAt: activated ? new Date() : null,
        activationCodeHash: activated ? null : codeHash,
        activationExpiresAt: activated ? null : new Date(Date.now() + 30 * 86400_000),
      },
    });
    if (!activated) continue;
    const point = points[i % points.length];
    const user = await prisma.user.create({ data: { universityId, role: 'student', studentId, name: nameAr, nameAr, gender, passwordHash: studentHash, defaultPointId: point.id } });
    students.push({ user, point });
    // Every other activated student has paid this month's subscription at the office.
    if (i % 2 === 0 && i > 0) {
      const tier = tiers.find((t) => t.id === point.tierId)!;
      const payment = await prisma.payment.create({
        data: { universityId, studentId: user.id, type: 'subscription', method: 'cash_office', amount: tier.subscriptionPrice, receiptNo: ++receipt, collectedById: office.id, note: 'demo' },
      });
      await prisma.subscription.create({
        data: { universityId, studentId: user.id, tierId: tier.id, pointId: point.id, month, periodStart: new Date(Date.UTC(y, m - 1, 1)), periodEnd: new Date(Date.UTC(y, m, 0)), price: tier.subscriptionPrice, paymentId: payment.id },
      });
    }
  }
  await prisma.receiptCounter.create({ data: { universityId, last: receipt } });

  // Open requests for the next morning wave that has not left yet (today or tomorrow), so the
  // office can press "Dispatch now" right away. W-1001 and W-1002 are left free to try the app.
  const now = baghdad();
  const minuteNow = now.getUTCHours() * 60 + now.getUTCMinutes();
  const morning = waves.filter((w) => w.type === 'morning');
  const next = morning.find((w) => w.minuteOfDay > minuteNow + 15);
  const wave = next ?? morning[0];
  const date = next ? isoDate(now) : isoDate(baghdad(1));
  for (const { user, point } of students.slice(2, 24)) {
    const sub = await prisma.subscription.findFirst({ where: { studentId: user.id } });
    const tier = tiers.find((t) => t.id === point.tierId)!;
    await prisma.rideRequest.create({
      data: { universityId, studentId: user.id, waveId: wave.id, date: dbDate(date), pointId: point.id, tierId: tier.id, gender: user.gender!, subscriber: !!sub, fare: sub ? 0 : tier.ridePrice },
    });
  }

  await seedLastMonth(universityId);
  await seedTaxis(universityId);

  await queueMatrixRebuild(universityId);

  console.log(`Demo data ready for ${uni.nameAr}.
  Dashboard:  office@uowa.edu.iq / ${OFFICE_PASSWORD}   (super admin: admin@naql.app / ${OFFICE_PASSWORD})
  Students:   W-1001 … W-1030 / ${STUDENT_PASSWORD}       (W-1031 … W-1040 activate with code ${ACTIVATION_CODE})
  Drivers:    07800000001 … 07800000006 (sign-in code is shown in the app in demo mode)
  Taxis:      07800000011 … 07800000013 (campus taxi drivers; go online in the driver app)
  22 open requests for ${String(wave.minuteOfDay / 60).padStart(2, '0')}:00 on ${date} are waiting for dispatch.`);
}

/** P10: campus taxis switched on, with three approved taxi drivers (added once, also to older stacks). */
const TAXIS = [
  ['Ali Kareem', 'علي كريم', '07800000011'],
  ['Hassan Jabbar', 'حسن جبار', '07800000012'],
  ['Abbas Muhsin', 'عباس محسن', '07800000013'],
] as const;

async function seedTaxis(universityId: string) {
  await prisma.university.update({ where: { id: universityId }, data: { taxiEnabled: true } });
  const office = await prisma.user.findFirst({ where: { universityId, role: 'office' } });
  for (const [i, [name, nameAr, phone]] of TAXIS.entries()) {
    const loginPhone = `+964${phone.slice(1)}`;
    if (await prisma.user.findUnique({ where: { loginPhone } })) continue;
    const user = await prisma.user.create({ data: { universityId, role: 'driver', name, nameAr, loginPhone, phone: loginPhone, gender: 'male' } });
    await prisma.driverProfile.create({
      data: { userId: user.id, universityId, status: 'approved', vehicleType: 'taxi', plate: `${45670 + i} كربلاء أجرة`, seats: 4, modelYear: 2019 + i, submittedAt: new Date(), reviewedAt: new Date(), reviewedById: office?.id },
    });
  }
}

/**
 * P6: last month already happened — runs with GPS tracks, subscriptions and cash fares for three
 * of the drivers, ready for the office to compute and approve the settlement.
 */
async function seedLastMonth(universityId: string) {
  const d = new Date(Date.now() + 3 * 3600_000);
  const m = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - 1, 1));
  const month = `${m.getUTCFullYear()}-${String(m.getUTCMonth() + 1).padStart(2, '0')}`;
  const from = new Date(`${month}-01T00:00:00Z`);
  if (await prisma.run.count({ where: { universityId, date: { gte: from, lt: new Date(Date.UTC(m.getUTCFullYear(), m.getUTCMonth() + 1, 1)) } } })) return;
  const office = await prisma.user.findFirstOrThrow({ where: { universityId, role: 'office' } });
  const history = await prisma.user.findMany({ where: { universityId, role: 'driver', driver: { status: 'approved' } }, orderBy: { loginPhone: 'asc' }, take: 3 });
  await seedMonth(prisma, universityId, month, { officeUserId: office.id, driverIds: history.map((x) => x.id) });

  // P7: students rated some of those rides and reported two problems.
  const done = await prisma.rideRequest.findMany({ where: { universityId, status: 'done', date: { gte: from } }, include: { run: true }, orderBy: [{ date: 'asc' }, { id: 'asc' }], take: 60 });
  const stars = [5, 4, 5, 3, 5, 4, 2, 5, 4, 5, 4, 5, 3, 5, 4];
  const comments: Record<number, string> = { 2: 'وصل متأخراً عشر دقائق', 3: 'السائق محترم جداً', 6: 'الحافلة كانت مزدحمة' };
  for (const [i, r] of done.filter((_, k) => k % 4 === 0).slice(0, stars.length).entries()) {
    await prisma.rideRating.create({ data: { universityId, requestId: r.id, studentId: r.studentId, driverId: r.run!.driverId, runId: r.runId!, stars: stars[i], comment: comments[stars[i] === 2 ? 2 : i] ?? null, createdAt: new Date(r.date.getTime() + 8 * 3600_000) } });
  }
  if (done[1]) {
    await prisma.problemReport.create({ data: { universityId, studentId: done[1].studentId, requestId: done[1].id, category: 'late', text: 'تأخرت الحافلة ربع ساعة عن موعد الصعود ووصلنا متأخرين للمحاضرة.' } });
    await prisma.problemReport.create({ data: { universityId, studentId: done[5]?.studentId ?? done[1].studentId, category: 'app', text: 'لم يصلني إشعار اقتراب الحافلة هذا الصباح.' } });
  }
  console.log(`  ${month} is ready to settle (Dashboard → التسوية الشهرية).`);
}

/** Ask the API's worker to build the OSRM travel-time matrix for the new points (DS-01). */
async function queueMatrixRebuild(universityId: string) {
  if (!process.env.REDIS_URL) return;
  const url = new URL(process.env.REDIS_URL);
  const queue = new Queue('routing', {
    connection: { host: url.hostname, port: Number(url.port || 6379), db: url.pathname.length > 1 ? Number(url.pathname.slice(1)) : 0 },
    prefix: process.env.QUEUE_PREFIX ?? 'naql',
  });
  await queue.add('travel-matrix.rebuild', { universityId }, { jobId: `matrix-${universityId}`, delay: 5000, attempts: 10, backoff: { type: 'exponential', delay: 10_000 }, removeOnComplete: true });
  await queue.close();
}

main().finally(() => prisma.$disconnect());
