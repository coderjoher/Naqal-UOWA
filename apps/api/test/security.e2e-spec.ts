import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createApp, createUser, createUniversity, PASSWORD, raw, resetDb } from './helpers';

describe('P8 security hardening (e2e)', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    await resetDb();
    const uni = await createUniversity('warith');
    await createUser('office', uni.id, 'office@w.iq');
    await createUser('office', uni.id, 'other@w.iq');
    app = await createApp();
  });

  afterAll(async () => {
    await app.close();
    await raw.$disconnect();
  });

  it('[T8-03] auth endpoints are rate-limited per account; other accounts are not locked out', async () => {
    for (let i = 0; i < 10; i++) await http().post('/auth/login').send({ email: 'office@w.iq', password: 'wrong-password' }).expect(401);
    const blocked = await http().post('/auth/login').send({ email: 'office@w.iq', password: PASSWORD }).expect(429);
    expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(0);
    expect(blocked.body.message).toMatch(/Too many/);
    // Case and spaces do not get around it.
    await http().post('/auth/login').send({ email: ' OFFICE@w.iq ', password: PASSWORD }).expect(429);
    // A colleague behind the same IP still signs in.
    await http().post('/auth/login').send({ email: 'other@w.iq', password: PASSWORD }).expect(200);

    // Student sign-in and activation share the account limit (university + student number).
    for (let i = 0; i < 10; i++) await http().post('/auth/student/login').send({ university: 'warith', studentId: 'W-9', password: 'nope-nope' });
    await http().post('/auth/student/activate').send({ university: 'warith', studentId: 'W-9', code: '000000', password: 'whatever-123' }).expect(429);

    // Driver codes: one SMS a minute per phone (and at most 5 an hour), and wrong codes are cut
    // off after 10 tries.
    await http().post('/auth/driver/otp').send({ phone: '07801234567' }).expect(200);
    await http().post('/auth/driver/otp').send({ phone: '07801234567' }).expect(429);
    for (let i = 0; i < 10; i++) await http().post('/auth/driver/verify').send({ phone: '07801234568', code: '000000', university: 'warith' });
    await http().post('/auth/driver/verify').send({ phone: '07801234568', code: '000000', university: 'warith' }).expect(429);
  });

  it('[T8-03] responses carry security headers and leak no framework details', async () => {
    const res = await http().get('/public/universities').expect(200);
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-frame-options']).toBe('SAMEORIGIN');
    expect(res.headers['strict-transport-security']).toMatch(/max-age=/);
    expect(res.headers['referrer-policy']).toBe('no-referrer');
    expect(res.headers['x-powered-by']).toBeUndefined();
    // Unknown routes and bad input answer without stack traces.
    const missing = await http().get('/nope').expect(404);
    expect(JSON.stringify(missing.body)).not.toMatch(/at .*\.js|node_modules/);
    const bad = await http().post('/auth/login').send({ email: 'x', password: 1, extra: true }).expect(400);
    expect(JSON.stringify(bad.body)).not.toMatch(/node_modules/);
  });

  it('exposes Prometheus metrics, behind a token when one is configured', async () => {
    const m = await http().get('/metrics').expect(200);
    expect(m.text).toContain('naql_http_request_duration_seconds_bucket');
    // Labelled by route pattern, so ids in URLs never explode the series count.
    expect(m.text).toMatch(/naql_http_request_duration_seconds_count\{method="POST",route="\/auth\/login",status="429"\} 2/);
    expect(m.text).toContain('naql_queue_jobs');
    process.env.METRICS_TOKEN = 'scrape-secret';
    try {
      await http().get('/metrics').expect(401);
      await http().get('/metrics').set('authorization', 'Bearer scrape-secret').expect(200);
    } finally {
      delete process.env.METRICS_TOKEN;
    }
  });
});
