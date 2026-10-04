import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createApp, createUniversity, createUser, login, raw, resetDb } from './helpers';

type Who = 'student' | 'driver' | 'office' | 'super_admin';

/** Expected status per endpoint and role (NF-11). */
const MATRIX: { method: 'get' | 'post'; path: string; allowed: Who[]; body?: object }[] = [
  { method: 'get', path: '/me', allowed: ['student', 'driver', 'office', 'super_admin'] },
  { method: 'get', path: '/students/me', allowed: ['student'] },
  { method: 'get', path: '/drivers/me', allowed: ['driver'] },
  { method: 'get', path: '/users', allowed: ['office'] },
  { method: 'get', path: '/universities', allowed: ['super_admin'] },
  { method: 'get', path: '/universities/current', allowed: ['student', 'driver', 'office'] },
  {
    method: 'post',
    path: '/universities',
    allowed: ['super_admin'],
    body: { name: 'New', slug: 'new-uni', campusLat: 32.6, campusLng: 44.02 },
  },
];

describe('auth and role-based access (e2e)', () => {
  let app: INestApplication;
  const tokens = {} as Record<Who | 'officeB', string>;
  let uniA: string;
  let studentB: string;

  beforeAll(async () => {
    await resetDb();
    uniA = (await createUniversity('uni-a')).id;
    const uniB = (await createUniversity('uni-b')).id;
    await createUser('super_admin', null, 'admin@naql.app');
    await createUser('office', uniA, 'office@a.iq');
    await createUser('student', uniA, 'student@a.iq', { gender: 'female' });
    await createUser('driver', uniA, 'driver@a.iq');
    await createUser('office', uniB, 'office@b.iq');
    studentB = (await createUser('student', uniB, 'student@b.iq')).id;
    app = await createApp();
    tokens.super_admin = await login(app, 'admin@naql.app');
    tokens.office = await login(app, 'office@a.iq');
    tokens.student = await login(app, 'student@a.iq');
    tokens.driver = await login(app, 'driver@a.iq');
    tokens.officeB = await login(app, 'office@b.iq');
  });
  afterAll(async () => {
    await app.close();
    await raw.$disconnect();
  });

  const http = () => request(app.getHttpServer());

  it('[T0-09] each role gets 403 on endpoints of other roles', async () => {
    for (const ep of MATRIX) {
      for (const who of ['student', 'driver', 'office', 'super_admin'] as Who[]) {
        const res = await http()[ep.method](ep.path).set('Authorization', `Bearer ${tokens[who]}`).send(ep.body);
        const expected = ep.allowed.includes(who) ? (ep.method === 'post' ? 201 : 200) : 403;
        expect({ ep: `${ep.method} ${ep.path}`, who, status: res.status }).toEqual({ ep: `${ep.method} ${ep.path}`, who, status: expected });
        if (ep.method === 'post' && res.status === 201) await raw.university.delete({ where: { id: res.body.id } });
      }
    }
  });

  it('[T0-09] office user gets 404 for another university resource id', async () => {
    await http().get(`/users/${studentB}`).set('Authorization', `Bearer ${tokens.office}`).expect(404);
    await http().get(`/users/${studentB}`).set('Authorization', `Bearer ${tokens.officeB}`).expect(200);
  });

  it('[T0-09] office lists only its own university users', async () => {
    const res = await http().get('/users').set('Authorization', `Bearer ${tokens.office}`).expect(200);
    expect(res.body.map((u: any) => u.email).sort()).toEqual(['driver@a.iq', 'office@a.iq', 'student@a.iq']);
    expect(res.body.every((u: any) => u.universityId === uniA)).toBe(true);
    expect(res.body[0].passwordHash).toBeUndefined();
  });

  it('[T0-09] missing, invalid and suspended-user tokens get 401', async () => {
    await http().get('/me').expect(401);
    await http().get('/me').set('Authorization', 'Bearer nope').expect(401);
    await raw.user.update({ where: { email: 'driver@a.iq' }, data: { status: 'suspended' } });
    await http().get('/me').set('Authorization', `Bearer ${tokens.driver}`).expect(401);
    await http().post('/auth/login').send({ email: 'driver@a.iq', password: 'password123' }).expect(401);
    await raw.user.update({ where: { email: 'driver@a.iq' }, data: { status: 'active' } });
  });

  it('rejects wrong passwords and invalid payloads', async () => {
    await http().post('/auth/login').send({ email: 'office@a.iq', password: 'wrong-password' }).expect(401);
    await http().post('/auth/login').send({ email: 'not-an-email', password: 'x' }).expect(400);
    await http().post('/universities').set('Authorization', `Bearer ${tokens.super_admin}`).send({ name: 'x', slug: 'BAD SLUG', campusLat: 999, campusLng: 0 }).expect(400);
  });

  it('writes an audit event for admin mutations, linked to the affected university', async () => {
    const res = await http()
      .post('/universities')
      .set('Authorization', `Bearer ${tokens.super_admin}`)
      .send({ name: 'Audited', slug: 'audited', campusLat: 32.6, campusLng: 44.02 })
      .expect(201);
    const events = await raw.auditEvent.findMany({ where: { entityId: res.body.id } });
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ action: 'POST /universities', entity: 'Universities', universityId: res.body.id });
  });
});
