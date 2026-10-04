import { INestApplication } from '@nestjs/common';
import Redis from 'ioredis';
import { AddressInfo } from 'node:net';
import { io, Socket } from 'socket.io-client';
import request from 'supertest';
import { baghdadDate, secondsInto } from '../src/dispatch/clock';
import { DispatchEngine } from '../src/dispatch/dispatch.engine';
import { auth, createApp, createConfiguredUniversity, createUser, login, raw, resetDb } from './helpers';

async function waitFor<T>(fn: () => Promise<T> | T, what: string, ms = 10_000): Promise<NonNullable<T>> {
  const end = Date.now() + ms;
  for (;;) {
    const v = await fn();
    if (v) return v as NonNullable<T>;
    if (Date.now() > end) throw new Error(`Timed out waiting for ${what}`);
    await new Promise((r) => setTimeout(r, 100));
  }
}

function slot(minutesAhead: number) {
  const now = new Date();
  const today = baghdadDate(now);
  let minute = Math.floor(secondsInto(today, now) / 60) + minutesAhead;
  let date = today;
  if (minute >= 24 * 60) {
    minute -= 24 * 60;
    date = baghdadDate(now, 1);
  }
  return { minute, date };
}

let seq = 0;
const cid = () => `client-${Date.now()}-${++seq}`;

describe('P5 runs, live tracking and notifications (e2e)', () => {
  let app: INestApplication;
  let url: string;
  let uniId: string;
  const redis = new Redis(process.env.REDIS_URL!);
  const http = () => request(app.getHttpServer());
  const tokens: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const sockets: Socket[] = [];
  let wave: { id: string; date: string };
  let maleRun: string;
  let femaleRun: string;

  const connect = (token: string) =>
    new Promise<Socket>((resolve, reject) => {
      const s = io(`${url}/live`, { auth: { token }, transports: ['websocket'], reconnection: false, forceNew: true });
      sockets.push(s);
      s.once('ready', () => resolve(s));
      s.once('connect_error', reject);
      s.once('error', reject);
    });
  const act = (who: string, runId: string, actions: object[]) => http().post(`/runs/${runId}/actions`).set(auth(tokens[who])).send({ actions });
  const run = async (who: string, runId: string) => (await http().get(`/runs/${runId}`).set(auth(tokens[who])).expect(200)).body;

  beforeAll(async () => {
    await resetDb();
    await redis.flushdb();
    uniId = (await createConfiguredUniversity('warith')).id;
    await raw.university.update({ where: { id: uniId }, data: { noShowWaitMinutes: 3 } });
    const tier = await raw.distanceTier.create({ data: { universityId: uniId, name: 'B', minKm: 0, maxKm: null, subscriptionPrice: 60000, ridePrice: 2000 } });
    const far = await raw.gatheringPoint.create({ data: { universityId: uniId, name: 'Hay Al-Hussein', nameAr: 'حي الحسين', lat: 32.62, lng: 44.0, tierId: tier.id } });
    const near = await raw.gatheringPoint.create({ data: { universityId: uniId, name: 'Bab Baghdad', nameAr: 'باب بغداد', lat: 32.6, lng: 44.05, tierId: tier.id } });
    const mid = await raw.gatheringPoint.create({ data: { universityId: uniId, name: 'Al-Abbas Square', nameAr: 'ساحة العباس', lat: 32.616, lng: 44.0249, tierId: tier.id } });
    ids.far = far.id;
    ids.near = near.id;
    ids.mid = mid.id;
    const s = slot(150);
    wave = { id: (await raw.wave.create({ data: { universityId: uniId, type: 'morning', minuteOfDay: s.minute, weekdays: 127 } })).id, date: s.date };

    await createUser('office', uniId, 'office@w.iq');
    for (const d of ['d1', 'd2']) {
      const u = await createUser('driver', uniId, `${d}@w.iq`, { name: d, nameAr: `السائق ${d}`, loginPhone: `+96478000000${d.slice(1)}` });
      await raw.driverProfile.create({ data: { userId: u.id, universityId: uniId, status: 'approved', vehicleType: 'coaster', plate: `${d}-1`, seats: 14 } });
      await raw.driverAvailability.create({ data: { universityId: uniId, driverId: u.id, date: new Date(`${wave.date}T00:00:00Z`), waveId: wave.id } });
      ids[d] = u.id;
    }
    for (const [key, gender, point] of [
      ['ali', 'male', far.id],
      ['omar', 'male', near.id],
      ['zainab', 'female', far.id],
      ['late', 'male', mid.id],
      ['outsider', 'male', near.id],
    ] as const) {
      ids[key] = (await createUser('student', uniId, `${key}@w.iq`, { name: key, nameAr: `طالب ${key}`, studentId: `W-${key}`, gender, defaultPointId: point })).id;
    }
    app = await createApp();
    await app.listen(0);
    url = `http://127.0.0.1:${(app.getHttpServer().address() as AddressInfo).port}`;
    for (const k of ['office', 'd1', 'd2', 'ali', 'omar', 'zainab', 'late', 'outsider']) tokens[k] = await login(app, `${k}@w.iq`);

    for (const k of ['ali', 'omar', 'zainab']) await http().post('/rides').set(auth(tokens[k])).send({ waveId: wave.id, date: wave.date }).expect(201);
    // Omar rides on his subscription (nothing to pay); Ali pays per ride.
    await raw.rideRequest.updateMany({ where: { studentId: ids.omar }, data: { fare: 0, subscriber: true } });
    await app.get(DispatchEngine).plan({ universityId: uniId, waveId: wave.id, date: wave.date });
    const runs = await raw.run.findMany({ where: { waveId: wave.id } });
    maleRun = runs.find((r) => r.gender === 'male')!.id;
    femaleRun = runs.find((r) => r.gender === 'female')!.id;
    // dm drives the male bus, df the female-only bus (whichever driver the planner chose).
    const dm = runs.find((r) => r.id === maleRun)!.driverId === ids.d1 ? 'd1' : 'd2';
    const df = dm === 'd1' ? 'd2' : 'd1';
    Object.assign(tokens, { dm: tokens[dm], df: tokens[df] });
    Object.assign(ids, { dm: ids[dm], df: ids[df] });
  });

  afterAll(async () => {
    sockets.forEach((s) => s.disconnect());
    await app.close();
    redis.disconnect();
    await raw.$disconnect();
  });

  it('[T5-05] a student joins only their own run; broadcasts carry only the bus position', async () => {
    const ali = await connect(tokens.ali);
    const zainab = await connect(tokens.zainab);
    const outsider = await connect(tokens.outsider);
    const office = await connect(tokens.office);
    expect(await ali.emitWithAck('join', { runId: maleRun })).toMatchObject({ ok: true });
    expect(await zainab.emitWithAck('join', { runId: maleRun })).toEqual({ ok: false, error: 'forbidden' }); // another bus
    expect(await outsider.emitWithAck('join', { runId: maleRun })).toEqual({ ok: false, error: 'forbidden' }); // no ride
    expect(await zainab.emitWithAck('join', { runId: femaleRun })).toMatchObject({ ok: true });
    // A bad token never gets in.
    await expect(connect('not-a-token')).rejects.toBeTruthy();

    // Students cannot stream positions.
    expect(await ali.emitWithAck('gps', { runId: maleRun, lat: 32.6, lng: 44.0 })).toEqual({ ok: false, error: 'forbidden' });

    await act('dm', maleRun, [{ clientId: cid(), type: 'start' }]).expect(200);
    const got: object[] = [];
    const seenByZainab: object[] = [];
    ali.on('bus', (m) => got.push(m));
    zainab.on('bus', (m) => seenByZainab.push(m));
    const officeGot = new Promise((r) => office.once('bus', r));
    const d1 = await connect(tokens.dm);
    expect(await d1.emitWithAck('gps', { runId: maleRun, lat: 32.63, lng: 43.99, at: new Date().toISOString(), speed: 8.3 })).toMatchObject({ ok: true, live: true });
    await waitFor(() => got.length > 0, 'bus event');
    await officeGot;
    const msg = got[0] as Record<string, unknown>;
    expect(Object.keys(msg).sort()).toEqual(['at', 'etas', 'heading', 'lat', 'lng', 'runId', 'speed']);
    expect(msg).toMatchObject({ runId: maleRun, lat: 32.63, lng: 43.99 });
    expect(JSON.stringify(msg)).not.toMatch(/student|name|phone|W-/);
    expect(seenByZainab).toEqual([]); // other bus' room
    // Another driver cannot report this bus.
    const d2 = await connect(tokens.df);
    expect(await d2.emitWithAck('gps', { runId: maleRun, lat: 1, lng: 1 })).toMatchObject({ ok: false });
  });

  it('[T5-04] 1 000 pings update Redis GEO live and store about one row per minute', async () => {
    await raw.runPosition.deleteMany({ where: { runId: maleRun } });
    const buckets = await redis.keys(`live:pos:${maleRun}:*`);
    if (buckets.length) await redis.del(...buckets);
    await redis.del(`live:last:${maleRun}`); // older than T5-05's live ping otherwise
    const start = Date.now() - 1000 * 5000; // 1 000 pings 5 s apart ending now (83 min)
    const points = Array.from({ length: 1000 }, (_, i) => ({ lat: 32.62 + i * 1e-5, lng: 44.0 + i * 1e-5, at: new Date(start + i * 5000).toISOString() }));
    for (let i = 0; i < 1000; i += 100) await http().post(`/runs/${maleRun}/gps`).set(auth(tokens.dm)).send({ points: points.slice(i, i + 100) }).expect(200);
    const stored = await raw.runPosition.count({ where: { runId: maleRun } });
    const minutes = Math.floor((start + 999 * 5000) / 60_000) - Math.floor(start / 60_000) + 1;
    expect(stored).toBe(minutes); // one per minute bucket (≈ 84)
    expect(stored).toBeGreaterThan(80);
    expect(stored).toBeLessThan(90);
    // Re-sending the same batch (offline retry) stores nothing new.
    await http().post(`/runs/${maleRun}/gps`).set(auth(tokens.dm)).send({ points: points.slice(900) }).expect(200);
    expect(await raw.runPosition.count({ where: { runId: maleRun } })).toBe(stored);
    const [pos] = await redis.geopos(`live:geo:${uniId}`, maleRun);
    expect(Number(pos![1])).toBeCloseTo(points[999].lat, 4);
    expect(Number(pos![0])).toBeCloseTo(points[999].lng, 4);
    // NF-10: last known position with its time.
    const track = (await http().get(`/rides/${(await raw.rideRequest.findFirstOrThrow({ where: { studentId: ids.ali } })).id}/track`).set(auth(tokens.ali)).expect(200)).body;
    expect(track.bus).toMatchObject({ runId: maleRun, at: points[999].at });
    expect(track.stop).toMatchObject({ seq: 1, name: 'Hay Al-Hussein' });
  });

  it('[T5-10] a rider added to the active run reaches the driver within 3 s', async () => {
    const d1 = await connect(tokens.dm);
    const updated = new Promise<{ runId: string }>((r) => d1.once('run:updated', r));
    const t0 = Date.now();
    await http().post('/rides').set(auth(tokens.late)).send({ waveId: wave.id, date: wave.date }).expect(201);
    const evt = await Promise.race([updated, new Promise<never>((_, rej) => setTimeout(() => rej(new Error('no run:updated within 3 s')), 3000))]);
    expect(evt.runId).toBe(maleRun);
    expect(Date.now() - t0).toBeLessThan(3000);
    const view = await run('dm', maleRun);
    expect(view.stops.map((s: { point: { name: string } }) => s.point.name)).toEqual(['Hay Al-Hussein', 'Al-Abbas Square', 'Bab Baghdad']);
    expect(view.stops[1].passengers[0].name).toBe('طالب late');
  });

  it('[T5-01] run state machine with idempotent actions; illegal transitions are rejected', async () => {
    const minutesAgo = (m: number) => new Date(Date.now() - m * 60_000).toISOString();
    await act('dm', maleRun, [{ clientId: cid(), type: 'start' }]).expect(409); // already started
    await act('dm', maleRun, [{ clientId: cid(), type: 'end' }]).expect(409); // stops left
    await act('dm', maleRun, [{ clientId: cid(), type: 'depart' }]).expect(409); // not at a stop
    await act('df', maleRun, [{ clientId: cid(), type: 'arrive' }]).expect(403); // not their bus
    await act('dm', maleRun, [{ clientId: cid(), type: 'arrive', seq: 2 }]).expect(409); // stop 1 comes first

    const ali = (await raw.rideRequest.findFirstOrThrow({ where: { studentId: ids.ali } })).id;
    const late = (await raw.rideRequest.findFirstOrThrow({ where: { studentId: ids.late } })).id;
    const omar = (await raw.rideRequest.findFirstOrThrow({ where: { studentId: ids.omar } })).id;
    const arrive1 = { clientId: cid(), type: 'arrive', seq: 1, at: minutesAgo(10) };
    let res = await act('dm', maleRun, [arrive1, { clientId: cid(), type: 'board', requestIds: [ali], at: minutesAgo(9) }]).expect(200);
    expect(res.body.run.status).toBe('at_stop');
    // The same arrive again (offline retry) is ignored.
    res = await act('dm', maleRun, [arrive1]).expect(200);
    expect(res.body.results).toEqual([{ clientId: arrive1.clientId, applied: false }]);
    // Riders of another stop cannot board here.
    await act('dm', maleRun, [{ clientId: cid(), type: 'board', requestIds: [omar] }]).expect(400);
    await act('dm', maleRun, [{ clientId: cid(), type: 'depart', at: minutesAgo(8) }]).expect(200);

    // Stop 2: Late does not come. Leaving before the 3-minute wait is refused, after it Late is a no-show.
    await act('dm', maleRun, [{ clientId: cid(), type: 'arrive', seq: 2 }]).expect(200);
    const early = await act('dm', maleRun, [{ clientId: cid(), type: 'depart' }]).expect(409);
    expect(early.body.waitLeftS).toBeGreaterThan(170);
    await raw.runStop.updateMany({ where: { runId: maleRun, seq: 1 }, data: { arrivedAt: new Date(Date.now() - 4 * 60_000) } });
    await act('dm', maleRun, [{ clientId: cid(), type: 'depart' }]).expect(200);
    expect((await raw.rideRequest.findUniqueOrThrow({ where: { id: late } })).status).toBe('no_show');

    await act('dm', maleRun, [
      { clientId: cid(), type: 'arrive', seq: 3 },
      { clientId: cid(), type: 'board', requestIds: [omar] },
      { clientId: cid(), type: 'depart' },
      { clientId: cid(), type: 'end' },
    ]).expect(200);
    const done = await run('dm', maleRun);
    expect(done.status).toBe('done');
    expect(done.stops.flatMap((s: { passengers: { status: string }[] }) => s.passengers.map((p) => p.status))).toEqual(['done', 'no_show', 'done']);
    await act('dm', maleRun, [{ clientId: cid(), type: 'arrive' }]).expect(409); // finished
    // start + 9 accepted actions; refused and repeated actions leave no event.
    expect(await raw.runEvent.count({ where: { runId: maleRun } })).toBe(10);

    // ST-09: Ali and Omar were told the bus arrived, once each.
    const kinds = await raw.notification.findMany({ where: { kind: 'ride.arrived' }, select: { userId: true } });
    expect(kinds.map((k) => k.userId).sort()).toEqual([ids.ali, ids.late, ids.omar].sort());
  });

  it('[T5-09] cash fare: tier price, immutable payment linked to run and driver, idempotent', async () => {
    const ali = (await raw.rideRequest.findFirstOrThrow({ where: { studentId: ids.ali } })).id;
    const omar = (await raw.rideRequest.findFirstOrThrow({ where: { studentId: ids.omar } })).id;
    const key = cid();
    const first = (await http().post(`/runs/${maleRun}/fares`).set(auth(tokens.dm)).send({ requestId: ali, clientId: key }).expect(200)).body;
    expect(first.duplicate).toBe(false);
    expect(first.payment).toMatchObject({ type: 'cash_fare', method: 'cash_driver', amount: 2000, runId: maleRun, collectedById: ids.dm, studentId: ids.ali, rideRequestId: ali });
    expect(first.payment.receiptNo).toBeGreaterThan(0);
    // Retry with the same key, and a second tap with a new key: still one payment.
    const again = (await http().post(`/runs/${maleRun}/fares`).set(auth(tokens.dm)).send({ requestId: ali, clientId: key }).expect(200)).body;
    const tap2 = (await http().post(`/runs/${maleRun}/fares`).set(auth(tokens.dm)).send({ requestId: ali, clientId: cid() }).expect(200)).body;
    expect([again.payment.id, tap2.payment.id]).toEqual([first.payment.id, first.payment.id]);
    expect(await raw.payment.count({ where: { type: 'cash_fare' } })).toBe(1);
    // Subscribers pay nothing; other drivers cannot record on this run.
    await http().post(`/runs/${maleRun}/fares`).set(auth(tokens.dm)).send({ requestId: omar, clientId: cid() }).expect(400);
    await http().post(`/runs/${maleRun}/fares`).set(auth(tokens.df)).send({ requestId: ali, clientId: cid() }).expect(200); // idempotent hit returns the existing one
    // Money rows are immutable.
    await expect(raw.payment.update({ where: { id: first.payment.id }, data: { amount: 1 } })).rejects.toThrow(/immutable|not allowed|forbid/i);
    expect((await run('dm', maleRun)).stops[0].passengers[0].paid).toBe(true);
  });

  it('[T5-08] approaching fires once from live ETAs; notifications are listed and marked read', async () => {
    const z = await connect(tokens.zainab);
    const notes: { kind: string }[] = [];
    z.on('notification', (n) => notes.push(n));
    await act('df', femaleRun, [{ clientId: cid(), type: 'start' }]).expect(200);
    // Two pings close to Zainab's stop (about 1 km away).
    for (let i = 0; i < 2; i++) {
      await http()
        .post(`/runs/${femaleRun}/gps`)
        .set(auth(tokens.df))
        .send({ points: [{ lat: 32.629, lng: 44.0, at: new Date(Date.now() - 1000 + i * 500).toISOString() }] })
        .expect(200);
    }
    await waitFor(() => notes.some((n) => n.kind === 'ride.approaching'), 'approaching notification');
    const list = (await http().get('/notifications/me').set(auth(tokens.zainab)).expect(200)).body;
    expect(list.filter((n: { kind: string }) => n.kind === 'ride.approaching')).toHaveLength(1);
    expect(list.map((n: { kind: string }) => n.kind)).toContain('ride.assigned');
    await http().post('/notifications/read').set(auth(tokens.zainab)).send({}).expect(200);
    expect((await http().get('/notifications/me').set(auth(tokens.zainab)).expect(200)).body.every((n: { readAt: string | null }) => n.readAt)).toBe(true);
    await http().post('/devices').set(auth(tokens.zainab)).send({ token: 'fcm-token-'.padEnd(40, 'x'), platform: 'android' }).expect(200);
    expect(await raw.deviceToken.count({ where: { userId: ids.zainab } })).toBe(1);
  });

  it('[T5-12 API] office live snapshot lists runs with status and last position', async () => {
    const snap = (await http().get(`/live/runs?date=${wave.date}`).set(auth(tokens.office)).expect(200)).body;
    expect(snap.map((r: { status: string }) => r.status).sort()).toEqual(['done', 'started']);
    const female = snap.find((r: { runId: string }) => r.runId === femaleRun);
    expect(female.bus).toMatchObject({ lat: 32.629 });
    expect(female.femaleOnly).toBe(true);
    await http().get(`/live/runs`).set(auth(tokens.ali)).expect(403);
  });
});
