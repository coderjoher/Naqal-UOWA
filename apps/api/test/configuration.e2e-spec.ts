import { getQueueToken } from '@nestjs/bullmq';
import { INestApplication } from '@nestjs/common';
import { Queue } from 'bullmq';
import Redis from 'ioredis';
import { Server } from 'node:http';
import request from 'supertest';
import { ConfigCache } from '../src/config-cache/config-cache.service';
import { ROUTING_QUEUE } from '../src/routing/routing.service';
import { startFakeOsrm } from './fake-osrm';
import { auth, CAMPUS, createApp, createConfiguredUniversity, createUser, KARBALA_SQUARE, login, raw, resetDb } from './helpers';

const TIERS = [
  { name: 'A', minKm: 0, maxKm: 5, subscriptionPrice: 40000, ridePrice: 1500 },
  { name: 'B', minKm: 5, maxKm: 15, subscriptionPrice: 60000, ridePrice: 2000 },
  { name: 'C', minKm: 15, maxKm: null, subscriptionPrice: 80000, ridePrice: 3000 },
];
// Real Karbala places (approximate) at increasing distance from Warith campus.
const NEAR = { name: 'Bab Baghdad', nameAr: 'باب بغداد', lat: 32.6, lng: 44.05 };
const MID = { name: 'Al-Abbas Square', nameAr: 'ساحة العباس', lat: 32.616, lng: 44.0249 };
const FAR = { name: 'Al-Hurr', nameAr: 'الحر', lat: 32.66, lng: 43.93 };

describe('P1 configuration (e2e)', () => {
  let app: INestApplication;
  let osrm: Server;
  let admin: string;
  let office: string;
  let student: string;
  let otherOffice: string;
  let uniId: string;
  const redis = new Redis(process.env.REDIS_URL!);
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    await resetDb();
    await redis.flushdb();
    osrm = await startFakeOsrm(Number(new URL(process.env.OSRM_URL!).port));
    await createUser('super_admin', null, 'admin@naql.app');
    uniId = (await createConfiguredUniversity('warith')).id;
    const other = await createConfiguredUniversity('other');
    await createUser('office', uniId, 'office@w.iq');
    await createUser('student', uniId, 'student@w.iq');
    await createUser('office', other.id, 'office@o.iq');
    app = await createApp();
    admin = await login(app, 'admin@naql.app');
    office = await login(app, 'office@w.iq');
    student = await login(app, 'student@w.iq');
    otherOffice = await login(app, 'office@o.iq');
  });

  afterAll(async () => {
    await app.close();
    osrm.closeAllConnections();
    osrm.close();
    redis.disconnect();
    await raw.$disconnect();
  });

  it('[T1-01] super admin creates a university with campus and office account; the office sees only it', async () => {
    const res = await http()
      .post('/universities')
      .set(auth(admin))
      .send({
        name: 'Kufa University',
        nameAr: 'جامعة الكوفة',
        slug: 'kufa',
        campusLat: 32.03,
        campusLng: 44.37,
        coverage: [[31.9, 44.2], [31.9, 44.5], [32.1, 44.5], [32.1, 44.2]],
        commissionPct: 12.5,
        waitlistMinutes: 20,
        officeAccount: { name: 'Kufa office', email: 'Office@Kufa.edu.iq', password: 'a-long-password' },
      })
      .expect(201);
    expect(res.body).toMatchObject({ slug: 'kufa', commissionPct: '12.5', waitlistMinutes: 20 });

    const kufaOffice = (await http().post('/auth/login').send({ email: 'office@kufa.edu.iq', password: 'a-long-password' }).expect(200)).body.accessToken;
    const current = await http().get('/universities/current').set(auth(kufaOffice)).expect(200);
    expect(current.body.id).toBe(res.body.id);
    const users = await http().get('/users').set(auth(kufaOffice)).expect(200);
    expect(users.body.map((u: any) => u.email)).toEqual(['office@kufa.edu.iq']);
    await http().get('/tiers').set(auth(kufaOffice)).expect(200, []);

    await http().post('/universities').set(auth(admin)).send({ name: 'Dup', slug: 'kufa', campusLat: 32, campusLng: 44 }).expect(409);
  });

  it('[T1-02] super admin sets commission and waitlist duration; others cannot', async () => {
    await http().patch(`/universities/${uniId}`).set(auth(admin)).send({ commissionPct: 10, waitlistMinutes: 45 }).expect(200);
    const u = await raw.university.findUniqueOrThrow({ where: { id: uniId } });
    expect(Number(u.commissionPct)).toBe(10);
    expect(u.waitlistMinutes).toBe(45);
    await http().patch(`/universities/${uniId}`).set(auth(admin)).send({ commissionPct: 101 }).expect(400);
    await http().patch(`/universities/${uniId}`).set(auth(office)).send({ commissionPct: 0 }).expect(403);
    const audit = await raw.auditEvent.findFirst({ where: { action: 'PATCH /universities/:id' } });
    expect(audit?.universityId).toBe(uniId);
  });

  it('[T1-03] office defines driver requirements and the registration form reflects them', async () => {
    const before = await http().get('/driver-requirements/registration-form').set(auth(office)).expect(200);
    expect(before.body.map((f: any) => f.key)).toContain('doc_driving_licence');

    await http()
      .put('/driver-requirements')
      .set(auth(office))
      .send({
        documents: [
          { key: 'driving_licence', label: 'Driving licence', labelAr: 'إجازة السوق', required: true },
          { key: 'criminal_record', label: 'Criminal record check', labelAr: 'عدم محكومية', required: true },
        ],
        vehicleTypes: ['coaster'],
        minSeats: 14,
        maxVehicleAgeYears: 10,
      })
      .expect(200);

    const form = (await http().get('/driver-requirements/registration-form').set(auth(office)).expect(200)).body;
    const byKey = Object.fromEntries(form.map((f: any) => [f.key, f]));
    expect(byKey.doc_criminal_record).toMatchObject({ kind: 'document', required: true, labelAr: 'عدم محكومية' });
    expect(byKey.doc_national_id).toBeUndefined();
    expect(byKey.vehicle_type.options).toEqual(['coaster']);
    expect(byKey.seats.min).toBe(14);
    expect(byKey.model_year.min).toBe(new Date().getFullYear() - 10);

    await http().put('/driver-requirements').set(auth(office)).send({ documents: [{ key: 'a_doc', label: 'x', required: true }, { key: 'a_doc', label: 'y', required: true }], vehicleTypes: ['coaster'], minSeats: 10, maxVehicleAgeYears: 10 }).expect(400);
    await http().put('/driver-requirements').set(auth(student)).send({}).expect(403);
    // other university still sees defaults
    const other = (await http().get('/driver-requirements').set(auth(otherOffice)).expect(200)).body;
    expect(other.documents.map((d: any) => d.key)).toContain('national_id');
  });

  it('[T1-04] tier set must be contiguous; valid set is saved in order', async () => {
    await http().put('/tiers').set(auth(office)).send({ tiers: [TIERS[0], { ...TIERS[1], minKm: 6 }, TIERS[2]] }).expect(400);
    const res = await http().put('/tiers').set(auth(office)).send({ tiers: [TIERS[2], TIERS[0], TIERS[1]] }).expect(200);
    expect(res.body.map((t: any) => t.name)).toEqual(['A', 'B', 'C']);
  });

  it('[T1-05] a new point gets its geography, an automatic tier from road distance, and must be inside the service area', async () => {
    const near = (await http().post('/gathering-points').set(auth(office)).send(NEAR).expect(201)).body;
    const mid = (await http().post('/gathering-points').set(auth(office)).send(MID).expect(201)).body;
    const far = (await http().post('/gathering-points').set(auth(office)).send(FAR).expect(201)).body;
    const tiers = await raw.distanceTier.findMany({ where: { universityId: uniId } });
    const tierName = (id: string) => tiers.find((t) => t.id === id)!.name;
    expect(near.distanceKm).toBeGreaterThan(0);
    expect(near.distanceKm).toBeLessThan(5);
    expect(tierName(near.tierId)).toBe('A');
    expect(tierName(mid.tierId)).toBe('B');
    expect(tierName(far.tierId)).toBe('C');
    expect(far.durationMin).toBeGreaterThan(near.durationMin);

    // Baghdad is outside the Karbala service area
    await http().post('/gathering-points').set(auth(office)).send({ name: 'Baghdad', lat: 33.31, lng: 44.36 }).expect(422);

    // override and reset
    const tierC = tiers.find((t) => t.name === 'C')!;
    const over = (await http().patch(`/gathering-points/${near.id}`).set(auth(office)).send({ tierId: tierC.id }).expect(200)).body;
    expect(over).toMatchObject({ tierId: tierC.id, tierOverridden: true });
    const reset = (await http().patch(`/gathering-points/${near.id}`).set(auth(office)).send({ tierId: null }).expect(200)).body;
    expect(reset.tierOverridden).toBe(false);
    expect(tierName(reset.tierId)).toBe('A');

    // students can read points, never write them; other universities never see them
    await http().get('/gathering-points').set(auth(student)).expect(200);
    await http().post('/gathering-points').set(auth(student)).send(NEAR).expect(403);
    expect((await http().get('/gathering-points').set(auth(otherOffice)).expect(200)).body).toEqual([]);
    await http().patch(`/gathering-points/${near.id}`).set(auth(otherOffice)).send({ name: 'x' }).expect(404);
  });

  it('[T1-06] point changes enqueue one rebuild job; the job fills the matrix for all point pairs + campus', async () => {
    const queue = app.get<Queue>(getQueueToken(ROUTING_QUEUE));
    // Several edits in quick succession collapse into one waiting job.
    const pts = await raw.gatheringPoint.findMany({ where: { universityId: uniId } });
    await Promise.all(pts.map((p) => http().patch(`/gathering-points/${p.id}`).set(auth(office)).send({ lat: p.lat + 0.001 }).expect(200)));
    const waiting = (await queue.getJobs(['delayed', 'waiting', 'active'])).filter((j) => j.data.universityId === uniId);
    expect(waiting.length).toBeLessThanOrEqual(1);

    const n = pts.length + 1; // + campus
    await waitFor(async () => (await raw.travelTime.count({ where: { universityId: uniId } })) === n * (n - 1), 15000);
    const campusToFar = await raw.travelTime.findFirst({ where: { universityId: uniId, fromKey: 'campus' }, orderBy: { distanceM: 'desc' } });
    expect(campusToFar!.durationS).toBeGreaterThan(0);

    // deactivating a point rebuilds without it
    await http().delete(`/gathering-points/${pts[0].id}`).set(auth(office)).expect(200);
    await waitFor(async () => (await raw.travelTime.count({ where: { universityId: uniId } })) === (n - 1) * (n - 2), 15000);
    expect(await raw.travelTime.count({ where: { universityId: uniId, OR: [{ fromKey: pts[0].id }, { toKey: pts[0].id }] } })).toBe(0);
  });

  it('[T1-07] waves: create, reject duplicate time on an overlapping day, allow other days', async () => {
    const SUN_TO_THU = 0b0011111;
    const w = (await http().post('/waves').set(auth(office)).send({ type: 'morning', time: '08:00', weekdays: SUN_TO_THU }).expect(201)).body;
    expect(w).toMatchObject({ time: '08:00', minuteOfDay: 480, weekdays: SUN_TO_THU });
    await http().post('/waves').set(auth(office)).send({ type: 'morning', time: '08:00', weekdays: 0b0000001 }).expect(409);
    await http().post('/waves').set(auth(office)).send({ type: 'morning', time: '08:00', weekdays: 0b1000000 }).expect(201); // Saturday only
    await http().post('/waves').set(auth(office)).send({ type: 'return', time: '14:00', weekdays: SUN_TO_THU }).expect(201);
    await http().post('/waves').set(auth(office)).send({ type: 'return', time: '25:00', weekdays: 1 }).expect(400);
    await http().patch(`/waves/${w.id}`).set(auth(office)).send({ active: false }).expect(200);
    const list = (await http().get('/waves').set(auth(student)).expect(200)).body;
    expect(list.map((x: any) => `${x.type} ${x.time} ${x.active}`)).toEqual(['morning 08:00 false', 'morning 08:00 true', 'return 14:00 true']);
  });

  it('[T1-08] configuration reads are served from Redis and every write invalidates them', async () => {
    const key = ConfigCache.key(uniId, 'tiers');
    await redis.del(key);
    const first = (await http().get('/tiers').set(auth(student)).expect(200)).body;
    expect(await redis.exists(key)).toBe(1);

    // Change the database behind the API's back: a cached read must not see it.
    await raw.distanceTier.updateMany({ where: { universityId: uniId, name: 'A' }, data: { ridePrice: 9999 } });
    const cached = (await http().get('/tiers').set(auth(student)).expect(200)).body;
    expect(cached).toEqual(first);

    // A write through the API invalidates the key.
    const tiers = first.map((t: any) => ({ id: t.id, name: t.name, minKm: t.minKm, maxKm: t.maxKm, subscriptionPrice: t.subscriptionPrice, ridePrice: t.name === 'A' ? 1750 : t.ridePrice }));
    await http().put('/tiers').set(auth(office)).send({ tiers }).expect(200);
    expect(await redis.exists(key)).toBe(0);
    const fresh = (await http().get('/tiers').set(auth(student)).expect(200)).body;
    expect(fresh.find((t: any) => t.name === 'A').ridePrice).toBe(1750);

    for (const [kind, path] of [['points', '/gathering-points'], ['waves', '/waves']] as const) {
      await http().get(path).set(auth(student)).expect(200);
      expect(await redis.exists(ConfigCache.key(uniId, kind))).toBe(1);
    }
    await http().post('/waves').set(auth(office)).send({ type: 'morning', time: '10:00', weekdays: 1 }).expect(201);
    expect(await redis.exists(ConfigCache.key(uniId, 'waves'))).toBe(0);
  });

  it('removing a tier moves its points to the tier that now covers them', async () => {
    const current = (await http().get('/tiers').set(auth(office)).expect(200)).body;
    const a = current.find((t: any) => t.name === 'A');
    const c = current.find((t: any) => t.name === 'C');
    // Merge B into C: C now starts at 5 km.
    await http()
      .put('/tiers')
      .set(auth(office))
      .send({ tiers: [{ ...pick(a) }, { ...pick(c), minKm: 5 }] })
      .expect(200);
    const points = await raw.gatheringPoint.findMany({ where: { universityId: uniId } });
    expect(new Set(points.map((p) => p.tierId))).toEqual(new Set([a.id, c.id].filter((id) => points.some((p) => p.tierId === id))));
    expect(await raw.distanceTier.count({ where: { universityId: uniId } })).toBe(2);
  });
});

function pick(t: any) {
  return { id: t.id, name: t.name, minKm: t.minKm, maxKm: t.maxKm, subscriptionPrice: t.subscriptionPrice, ridePrice: t.ridePrice };
}

async function waitFor(check: () => Promise<boolean>, timeoutMs: number) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error('condition not met in time');
}
void CAMPUS;
void KARBALA_SQUARE;
