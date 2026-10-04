import { INestApplication } from '@nestjs/common';
import { createServer, Server } from 'node:http';
import { AddressInfo } from 'node:net';
import request from 'supertest';
import { auth, createApp, createConfiguredUniversity, createUser, login, raw, resetDb } from './helpers';

describe('P2 student identity (e2e)', () => {
  let app: INestApplication;
  let office: string;
  let uniApi: Server;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    await resetDb();
    const warith = await createConfiguredUniversity('warith'); // manual roster (default)
    await createUser('office', warith.id, 'office@w.iq');
    // A university whose registrar exposes an HTTP API.
    uniApi = createServer((req, res) => {
      let raw = '';
      req.on('data', (c) => (raw += c));
      req.on('end', () => {
        const { studentId, password } = JSON.parse(raw);
        res.setHeader('content-type', 'application/json');
        if (studentId === '2024001' && password === 'uni-pass') return res.end(JSON.stringify({ name: 'Hussein Ali', gender: 'M' }));
        res.statusCode = 401;
        res.end('{}');
      });
    });
    await new Promise<void>((r) => uniApi.listen(0, '127.0.0.1', () => r()));
    const port = (uniApi.address() as AddressInfo).port;
    const kufa = await createConfiguredUniversity('kufa');
    await raw.university.update({ where: { id: kufa.id }, data: { integrationConfig: { identity: { type: 'http', url: `http://127.0.0.1:${port}/verify` } } } });
    app = await createApp();
    office = await login(app, 'office@w.iq');
  });

  afterAll(async () => {
    await app.close();
    uniApi.close();
    await raw.$disconnect();
  });

  it('lists universities with their sign-in method for the apps', async () => {
    const res = await http().get('/public/universities').expect(200);
    expect(res.body).toEqual(
      expect.arrayContaining([expect.objectContaining({ slug: 'warith', studentSignIn: 'manual' }), expect.objectContaining({ slug: 'kufa', studentSignIn: 'http' })]),
    );
    expect(JSON.stringify(res.body)).not.toContain('127.0.0.1'); // integration URLs are not exposed
  });

  it('[T2-02] manual university: roster → activation code → sign-in creates the student with gender from the roster', async () => {
    await http()
      .post('/students/roster')
      .set(auth(office))
      .send({ rows: [{ studentId: 'W-1001', name: 'Zainab Kadhim', nameAr: 'زينب كاظم', gender: 'female' }, { studentId: 'W-1002', name: 'Ali Hassan', gender: 'male' }] })
      .expect(201, { created: 2, updated: 0 });

    // Without a code the student cannot get in.
    await http().post('/auth/student/activate').send({ university: 'warith', studentId: 'W-1001', code: '000000', password: 'my-password-1' }).expect(401);

    const { code } = (await http().post('/students/W-1001/activation-code').set(auth(office)).expect(201)).body;
    expect(code).toMatch(/^\d{6}$/);
    const act = await http().post('/auth/student/activate').send({ university: 'warith', studentId: 'W-1001', code, password: 'my-password-1' }).expect(200);
    expect(act.body.user.role).toBe('student');
    // Code is single-use.
    await http().post('/auth/student/activate').send({ university: 'warith', studentId: 'W-1001', code, password: 'other-password' }).expect(401);

    const signIn = await http().post('/auth/student/login').send({ university: 'warith', studentId: 'W-1001', password: 'my-password-1' }).expect(200);
    const me = (await http().get('/students/me').set(auth(signIn.body.accessToken)).expect(200)).body;
    expect(me).toMatchObject({ studentId: 'W-1001', name: 'Zainab Kadhim', nameAr: 'زينب كاظم', gender: 'female' });

    await http().post('/auth/student/login').send({ university: 'warith', studentId: 'W-1001', password: 'wrong-password' }).expect(401);
    const roster = (await http().get('/students').set(auth(office)).expect(200)).body;
    expect(roster.find((r: any) => r.studentId === 'W-1001')).toMatchObject({ activated: true, activationPending: false });
  });

  it('[T2-02] gender cannot be changed through the profile API; phone and default point can', async () => {
    const token = (await http().post('/auth/student/login').send({ university: 'warith', studentId: 'W-1001', password: 'my-password-1' }).expect(200)).body.accessToken;
    await http().patch('/students/me').set(auth(token)).send({ gender: 'male' }).expect(400);
    await http().patch('/students/me').set(auth(token)).send({ name: 'Someone else' }).expect(400);
    const tier = await raw.distanceTier.create({ data: { universityId: (await raw.university.findUniqueOrThrow({ where: { slug: 'warith' } })).id, name: 'A', minKm: 0, maxKm: null, subscriptionPrice: 50000, ridePrice: 2000 } });
    const point = await raw.gatheringPoint.create({ data: { universityId: tier.universityId, name: 'Al-Abbas Square', nameAr: 'ساحة العباس', lat: 32.616, lng: 44.025, tierId: tier.id } });
    const updated = (await http().patch('/students/me').set(auth(token)).send({ phone: '0770 123 4567', defaultPointId: point.id }).expect(200)).body;
    expect(updated).toMatchObject({ gender: 'female', phone: '+9647701234567', defaultPoint: { id: point.id, nameAr: 'ساحة العباس' } });
    await raw.gatheringPoint.update({ where: { id: point.id }, data: { active: false } });
    await http().patch('/students/me').set(auth(token)).send({ defaultPointId: point.id }).expect(400);
  });

  it('[T2-02] HTTP-API university: first sign-in creates the student from the registrar record', async () => {
    const res = await http().post('/auth/student/login').send({ university: 'kufa', studentId: '2024001', password: 'uni-pass' }).expect(200);
    const me = (await http().get('/students/me').set(auth(res.body.accessToken)).expect(200)).body;
    expect(me).toMatchObject({ studentId: '2024001', name: 'Hussein Ali', gender: 'male' });
    await http().post('/auth/student/login').send({ university: 'kufa', studentId: '2024001', password: 'nope' }).expect(401);
    // No local password is stored for registrar-verified students.
    expect((await raw.user.findFirstOrThrow({ where: { studentId: '2024001' } })).passwordHash).toBeNull();
  });

  it('roster updates follow through to existing accounts; students from another university are invisible', async () => {
    await http().post('/students/roster').set(auth(office)).send({ rows: [{ studentId: 'W-1001', name: 'Zainab K. Hassan', gender: 'female' }] }).expect(201, { created: 0, updated: 1 });
    expect((await raw.user.findFirstOrThrow({ where: { studentId: 'W-1001' } })).name).toBe('Zainab K. Hassan');
    const list = (await http().get('/students').set(auth(office)).expect(200)).body;
    expect(list.map((s: any) => s.studentId)).toEqual(['W-1001', 'W-1002']);
    await http().post('/students/2024001/activation-code').set(auth(office)).expect(404);
  });
});

describe('P2 driver onboarding (e2e)', () => {
  let app: INestApplication;
  let office: string;
  let otherOffice: string;
  let driver: string;
  let driverId: string;
  const http = () => request(app.getHttpServer());
  const PNG = Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c63000100000500010d0a2db40000000049454e44ae426082', 'hex');

  beforeAll(async () => {
    await resetDb();
    const warith = await createConfiguredUniversity('warith');
    const other = await createConfiguredUniversity('other');
    await createUser('office', warith.id, 'office@w.iq');
    await createUser('office', other.id, 'office@o.iq');
    app = await createApp();
    office = await login(app, 'office@w.iq');
    otherOffice = await login(app, 'office@o.iq');
  });

  afterAll(async () => {
    await app.close();
    await raw.$disconnect();
  });

  it('phone sign-in creates a draft driver in the chosen university', async () => {
    await http().post('/auth/driver/otp').send({ phone: '0123' }).expect(400);
    const { devCode } = (await http().post('/auth/driver/otp').send({ phone: '07801112233' }).expect(200)).body;
    await http().post('/auth/driver/otp').send({ phone: '07801112233' }).expect(429); // resend throttled
    await http().post('/auth/driver/verify').send({ phone: '07801112233', code: '000000', university: 'warith' }).expect(401);
    const res = await http().post('/auth/driver/verify').send({ phone: '+964 780 111 2233', code: devCode, university: 'warith' }).expect(200);
    driver = res.body.accessToken;
    driverId = res.body.user.id;
    const me = (await http().get('/drivers/me').set(auth(driver)).expect(200)).body;
    expect(me.status).toBe('draft');
    expect(me.application.phone).toBe('+9647801112233');
    expect(me.form.map((f: any) => f.key)).toContain('doc_driving_licence');
  });

  it('[T2-06] submission fails until every requirement from TO-01 is provided', async () => {
    let res = await http().post('/drivers/me/submit').set(auth(driver)).expect(422);
    expect(res.body.missing).toEqual(['name', 'vehicle_type', 'plate', 'seats', 'model_year', 'doc_national_id', 'doc_driving_licence', 'doc_vehicle_registration']);

    await http().patch('/drivers/me').set(auth(driver)).send({ name: 'علي حسن', vehicleType: 'coaster', plate: '45 ك 12345', seats: 20, modelYear: 2019 }).expect(200);
    await http().put('/drivers/me/documents/national_id').set(auth(driver)).attach('file', PNG, { filename: 'id.png', contentType: 'image/png' }).expect(200);
    res = await http().post('/drivers/me/submit').set(auth(driver)).expect(422);
    expect(res.body.missing).toEqual(['doc_driving_licence', 'doc_vehicle_registration']);

    // Wrong file type and unknown document keys are refused.
    await http().put('/drivers/me/documents/driving_licence').set(auth(driver)).attach('file', Buffer.from('MZ'), { filename: 'x.exe', contentType: 'application/x-msdownload' }).expect(422);
    await http().put('/drivers/me/documents/selfie').set(auth(driver)).attach('file', PNG, { filename: 'a.png', contentType: 'image/png' }).expect(400);

    for (const key of ['driving_licence', 'vehicle_registration']) {
      await http().put(`/drivers/me/documents/${key}`).set(auth(driver)).attach('file', PNG, { filename: `${key}.png`, contentType: 'image/png' }).expect(200);
    }
    const ok = (await http().post('/drivers/me/submit').set(auth(driver)).expect(200)).body;
    expect(ok).toMatchObject({ status: 'pending', missing: [] });
    // Locked while under review.
    await http().patch('/drivers/me').set(auth(driver)).send({ seats: 30 }).expect(409);
  });

  it('[T2-09] documents are private: unguessable, only via short-lived signed links, every access logged', async () => {
    // Not reachable without a link, and other universities cannot get one.
    await http().post(`/drivers/${driverId}/documents/driving_licence/link`).set(auth(otherOffice)).expect(404);
    await http().post(`/drivers/${driverId}/documents/driving_licence/link`).set(auth(driver)).expect(403);

    const link = (await http().post(`/drivers/${driverId}/documents/driving_licence/link`).set(auth(office)).expect(200)).body;
    expect(new Date(link.expiresAt).getTime() - Date.now()).toBeLessThanOrEqual(300_000);
    const file = await http().get(link.url).expect(200);
    expect(file.headers['content-type']).toBe('image/png');
    expect(file.headers['cache-control']).toContain('no-store');
    expect(Buffer.compare(file.body, PNG)).toBe(0);

    await http().get(link.url.replace(/.$/, (c: string) => (c === 'a' ? 'b' : 'a'))).expect(404);
    await http().get('/files/not-a-token').expect(404);

    const officeUser = await raw.user.findFirstOrThrow({ where: { email: 'office@w.iq' } });
    const log = await raw.documentAccess.findMany({ where: { userId: officeUser.id } });
    expect(log).toHaveLength(1);
    expect(log[0].expiresAt.getTime()).toBe(new Date(link.expiresAt).getTime());
  });

  it('[T2-08] pending → approved | rejected; approved ↔ suspended; suspended drivers cannot reach runs', async () => {
    await http().get('/drivers/me/runs').set(auth(driver)).expect(403); // pending
    await http().post(`/drivers/${driverId}/suspend`).set(auth(office)).send({ note: 'x' }).expect(409); // not approved yet
    await http().post(`/drivers/${driverId}/approve`).set(auth(otherOffice)).send({}).expect(404);
    await http().post(`/drivers/${driverId}/approve`).set(auth(office)).send({}).expect(200, { id: driverId, status: 'approved' });
    await http().get('/drivers/me/runs').set(auth(driver)).expect(200, []);

    await http().post(`/drivers/${driverId}/suspend`).set(auth(office)).send({}).expect(400); // reason required
    await http().post(`/drivers/${driverId}/suspend`).set(auth(office)).send({ note: 'Late three times this week' }).expect(200);
    const blocked = await http().get('/drivers/me/runs').set(auth(driver)).expect(403);
    expect(blocked.body.message).toContain('suspended');
    expect((await http().get('/drivers/me').set(auth(driver)).expect(200)).body).toMatchObject({ status: 'suspended', reviewNote: 'Late three times this week' });

    await http().post(`/drivers/${driverId}/reinstate`).set(auth(office)).send({}).expect(200);
    await http().get('/drivers/me/runs').set(auth(driver)).expect(200);

    // Reject path: a second driver gets rejected, can fix and resubmit.
    const { devCode } = (await http().post('/auth/driver/otp').send({ phone: '07809998877' }).expect(200)).body;
    const d2 = (await http().post('/auth/driver/verify').send({ phone: '07809998877', code: devCode, university: 'warith' }).expect(200)).body;
    await raw.driverProfile.update({ where: { userId: d2.user.id }, data: { status: 'pending' } });
    await http().post(`/drivers/${d2.user.id}/reject`).set(auth(office)).send({ note: 'Licence photo unreadable' }).expect(200, { id: d2.user.id, status: 'rejected' });
    await http().post(`/drivers/${d2.user.id}/approve`).set(auth(office)).send({}).expect(409);
    await http().patch('/drivers/me').set(auth(d2.accessToken)).send({ seats: 14 }).expect(200); // editable again

    const pendingList = (await http().get('/drivers?status=approved').set(auth(office)).expect(200)).body;
    expect(pendingList.map((d: any) => d.id)).toEqual([driverId]);
    expect((await http().get('/drivers').set(auth(otherOffice)).expect(200)).body).toEqual([]);
  });
});
