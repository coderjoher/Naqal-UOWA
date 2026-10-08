import { INestApplication } from '@nestjs/common';
import Redis from 'ioredis';
import { AddressInfo } from 'node:net';
import { io, Socket } from 'socket.io-client';
import request from 'supertest';
import { monthOf } from '../src/subscriptions/period-policy';
import { fareFor } from '../src/taxi/taxi-rules';
import { TaxiService } from '../src/taxi/taxi.service';
import { auth, CAMPUS, createApp, createConfiguredUniversity, createUser, login, raw, resetDb } from './helpers';

let seq = 0;
const cid = () => `taxi-${Date.now()}-${++seq}`;
/** Bab Baghdad, Karbala: about 4.3 km from campus in a straight line. */
const HOME = { lat: 32.6013, lng: 44.0508 };

describe('P10 campus taxis (e2e)', () => {
  let app: INestApplication;
  let url: string;
  let uniId: string;
  let taxi: TaxiService;
  const redis = new Redis(process.env.REDIS_URL!);
  const http = () => request(app.getHttpServer());
  const tokens: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const sockets: Socket[] = [];

  const connect = (token: string) =>
    new Promise<Socket>((resolve, reject) => {
      const s = io(`${url}/live`, { auth: { token }, transports: ['websocket'], reconnection: false, forceNew: true });
      sockets.push(s);
      s.once('ready', () => resolve(s));
      s.once('connect_error', reject);
    });
  const next = <T>(s: Socket, event: string, ms = 5000) =>
    new Promise<T>((resolve, reject) => {
      const t = setTimeout(() => reject(new Error(`no ${event}`)), ms);
      s.once(event, (v: T) => {
        clearTimeout(t);
        resolve(v);
      });
    });
  const online = (who: string, p: { lat: number; lng: number }) => http().post('/taxi/driver/online').set(auth(tokens[who])).send(p);
  const book = (who = 'ali', body: object = {}) => http().post('/taxi/rides').set(auth(tokens[who])).send({ direction: 'to_campus', ...HOME, label: 'قرب جامع باب بغداد', clientId: cid(), ...body });

  beforeAll(async () => {
    await resetDb();
    await redis.flushdb();
    uniId = (await createConfiguredUniversity('warith')).id;
    await raw.university.update({ where: { id: uniId }, data: { taxiEnabled: true, taxiBaseFare: 2000, taxiPerKm: 500, taxiMinFare: 3000, taxiOfferSeconds: 120, commissionPct: 10 } });
    await createUser('office', uniId, 'office@w.iq');
    for (const [d, type, seats] of [
      ['t1', 'taxi', 4],
      ['t2', 'taxi', 4],
      ['far', 'taxi', 4],
      ['bus', 'coaster', 14],
    ] as const) {
      const u = await createUser('driver', uniId, `${d}@w.iq`, { name: d, nameAr: `السائق ${d}`, loginPhone: `+9647800000${String(++seq).padStart(3, '0')}` });
      await raw.driverProfile.create({ data: { userId: u.id, universityId: uniId, status: 'approved', vehicleType: type, plate: `${d}-77`, seats } });
      ids[d] = u.id;
    }
    for (const s of ['ali', 'sara']) ids[s] = (await createUser('student', uniId, `${s}@w.iq`, { name: s, studentId: `W-${s}`, gender: 'male', phone: '+9647701110000' })).id;

    app = await createApp();
    await app.listen(0);
    url = `http://127.0.0.1:${(app.getHttpServer().address() as AddressInfo).port}`;
    taxi = app.get(TaxiService);
    for (const who of ['office', 't1', 't2', 'far', 'bus', 'ali', 'sara']) tokens[who] = await login(app, `${who}@w.iq`);
  });

  afterAll(async () => {
    for (const s of sockets) s.disconnect();
    redis.disconnect();
    await app.close();
    await raw.$disconnect();
  });

  it('[T10-05] the fare is quoted before booking; offers reach nearby online taxis only and show the area, not the exact point', async () => {
    // Bus drivers cannot go online as taxis; a far-away taxi is online but out of range.
    await online('bus', HOME).expect(403);
    await online('t1', { lat: 32.605, lng: 44.045 }).expect(200);
    await online('t2', { lat: 32.59, lng: 44.06 }).expect(200);
    await online('far', { lat: 33.3, lng: 44.4 }).expect(200);

    const q = (await http().get('/taxi/quote').query({ direction: 'to_campus', ...HOME }).set(auth(tokens.ali)).expect(200)).body;
    expect(q.fare).toBe(fareFor(q.distanceKm, { baseFare: 2000, perKm: 500, minFare: 3000 }));
    expect(q.fare % 250).toBe(0);
    expect(q.taxisNearby).toBe(2);
    await http().get('/taxi/quote').query({ direction: 'to_campus', lat: 33.3, lng: 44.4 }).set(auth(tokens.ali)).expect(422);

    const s1 = await connect(tokens.t1);
    const sFar = await connect(tokens.far);
    let farGot = false;
    sFar.on('taxi:offer', () => (farGot = true));
    const offered = next<{ id: string; area: { lat: number; lng: number }; fare: number }>(s1, 'taxi:offer');
    const ride = (await book().expect(201)).body;
    expect(ride).toMatchObject({ status: 'requested', fare: q.fare, driver: null });
    const card = await offered;
    expect(card.id).toBe(ride.id);
    expect(card.fare).toBe(q.fare);
    expect(card.area).not.toEqual(HOME);
    expect(JSON.stringify(card)).not.toContain('جامع');
    const list = (await http().get('/taxi/driver/offers').set(auth(tokens.t2)).expect(200)).body;
    expect(list.map((o: { id: string }) => o.id)).toEqual([ride.id]);
    expect(list[0]).not.toHaveProperty('lat');
    expect((await http().get('/taxi/driver/offers').set(auth(tokens.far)).expect(200)).body).toEqual([]);
    expect(farGot).toBe(false);

    // One active ride per student; a retried request returns the same ride.
    await book().expect(409);
    const dup = (await http().post('/taxi/rides').set(auth(tokens.sara)).send({ direction: 'from_campus', ...HOME, clientId: 'same-key-123' }).expect(201)).body;
    expect((await http().post('/taxi/rides').set(auth(tokens.sara)).send({ direction: 'from_campus', ...HOME, clientId: 'same-key-123' }).expect(201)).body.id).toBe(dup.id);
    await http().post(`/taxi/rides/${dup.id}/cancel`).set(auth(tokens.sara)).expect(200);
  });

  it('[T10-06] two drivers accept at once: exactly one wins; the student then sees the car, its position and ETA', async () => {
    const { active } = (await http().get('/taxi/rides/me').set(auth(tokens.ali)).expect(200)).body;
    const s = await connect(tokens.ali);
    const accepted = next<{ kind: string }>(s, 'notification');
    const [a, b] = await Promise.all([http().post(`/taxi/rides/${active.id}/accept`).set(auth(tokens.t1)), http().post(`/taxi/rides/${active.id}/accept`).set(auth(tokens.t2))]);
    expect([a.status, b.status].sort()).toEqual([200, 409]);
    const winner = a.status === 200 ? 't1' : 't2';
    const loser = winner === 't1' ? 't2' : 't1';
    expect((await accepted).kind).toBe('taxi.accepted');
    const mine = (a.status === 200 ? a : b).body;
    expect(mine).toMatchObject({ status: 'accepted', pickup: HOME, dropoff: CAMPUS, student: { phone: '+9647701110000' } });

    // The loser cannot touch it; the winner's position is forwarded to the student.
    await http().post(`/taxi/rides/${active.id}/arrive`).set(auth(tokens[loser])).expect(404);
    const pos = next<{ rideId: string; etaMin: number }>(s, 'taxi:position');
    await online(winner, { lat: 32.598, lng: 44.048 }).expect(200);
    expect(await pos).toMatchObject({ rideId: active.id });
    const view = (await http().get(`/taxi/rides/${active.id}`).set(auth(tokens.ali)).expect(200)).body;
    expect(view).toMatchObject({ status: 'accepted', driver: { id: ids[winner], plate: `${winner}-77` }, taxi: { lat: 32.598, lng: 44.048 } });
    expect(view.etaMin).toBeGreaterThan(0);
    // A busy driver gets no new offers and cannot take a second ride.
    expect((await online(winner, { lat: 32.598, lng: 44.048 }).expect(200)).body.offers).toEqual([]);
  });

  it('[T10-07] a driver who gives up puts the ride back on offer; unanswered requests expire and the student hears', async () => {
    const { active } = (await http().get('/taxi/rides/me').set(auth(tokens.ali)).expect(200)).body;
    const driver = active.driver.id === ids.t1 ? 't1' : 't2';
    await http().post(`/taxi/rides/${active.id}/cancel`).set(auth(tokens[driver])).expect(200);
    const back = (await http().get(`/taxi/rides/${active.id}`).set(auth(tokens.ali)).expect(200)).body;
    expect(back).toMatchObject({ status: 'requested', driver: null });

    // Nobody accepts: the sweep expires it after the offer window.
    const real = taxi.now.bind(taxi);
    taxi.now = () => new Date(Date.now() + 121_000);
    try {
      expect((await taxi.expireDue()).expired).toBe(1);
      expect((await taxi.expireDue()).expired).toBe(0);
    } finally {
      taxi.now = real;
    }
    expect((await http().get(`/taxi/rides/${active.id}`).set(auth(tokens.ali)).expect(200)).body.status).toBe('expired');
    const n = await raw.notification.findMany({ where: { userId: ids.ali, kind: 'taxi.expired' } });
    expect(n).toHaveLength(1);
    await http().post(`/taxi/rides/${active.id}/accept`).set(auth(tokens.t1)).expect(409);
  });

  it('[T10-08] ending the trip records the cash fare once; it counts as driver cash in the monthly settlement', async () => {
    await online('t1', { lat: 32.605, lng: 44.045 }).expect(200);
    const ride = (await book('ali', { direction: 'from_campus' }).expect(201)).body;
    await http().post(`/taxi/rides/${ride.id}/accept`).set(auth(tokens.t1)).expect(200);
    await http().post(`/taxi/rides/${ride.id}/end`).set(auth(tokens.t1)).expect(409);
    await http().post(`/taxi/rides/${ride.id}/arrive`).set(auth(tokens.t1)).expect(200);
    // The student cancels at the pickup point: nothing is charged. Book again and finish it.
    await http().post(`/taxi/rides/${ride.id}/cancel`).set(auth(tokens.ali)).expect(200);
    expect(await raw.payment.count({ where: { taxiRideId: ride.id } })).toBe(0);

    const again = (await book('ali', { direction: 'from_campus' }).expect(201)).body;
    await http().post(`/taxi/rides/${again.id}/accept`).set(auth(tokens.t1)).expect(200);
    await http().post(`/taxi/rides/${again.id}/start`).set(auth(tokens.t1)).expect(200);
    const [e1, e2] = await Promise.all([http().post(`/taxi/rides/${again.id}/end`).set(auth(tokens.t1)), http().post(`/taxi/rides/${again.id}/end`).set(auth(tokens.t1))]);
    expect([e1.status, e2.status]).toContain(200);
    const pays = await raw.payment.findMany({ where: { taxiRideId: again.id } });
    expect(pays).toHaveLength(1);
    expect(pays[0]).toMatchObject({ type: 'cash_fare', method: 'cash_driver', amount: again.fare, collectedById: ids.t1, studentId: ids.ali });
    expect((await http().get(`/taxi/rides/${again.id}`).set(auth(tokens.ali)).expect(200)).body).toMatchObject({ status: 'done', driver: { phone: null } });

    const month = monthOf(new Date());
    const s = (await http().post(`/settlements/${month}/compute`).set(auth(tokens.office)).expect(200)).body;
    const line = s.lines.find((l: { driverId: string }) => l.driverId === ids.t1);
    expect(line).toMatchObject({ runs: 0, cash: again.fare, cashCommission: Math.round(again.fare * 0.1), payout: -Math.round(again.fare * 0.1) });

    const hist = (await http().get('/taxi/driver/rides').set(auth(tokens.t1)).expect(200)).body;
    expect(hist).toMatchObject({ trips: 1, cash: again.fare });
    const ov = (await http().get('/taxi/overview').set(auth(tokens.office)).expect(200)).body;
    expect(ov.kpis).toMatchObject({ done: 1, cash: again.fare, unserved: 1 });
    expect(ov.online.map((o: { driverId: string }) => o.driverId)).toContain(ids.t1);
  });

  it('[T10-09] taxi drivers stay out of bus dispatch; the office controls the tariff and the on/off switch', async () => {
    const days = (await http().get('/drivers/me/availability').set(auth(tokens.t1)).expect(200)).body;
    await http().put('/drivers/me/availability').set(auth(tokens.t1)).send({ date: days[0].date, waveIds: [] }).expect(403);

    await http().patch('/taxi/settings').set(auth(tokens.ali)).send({ taxiPerKm: 1 }).expect(403);
    const st = (await http().patch('/taxi/settings').set(auth(tokens.office)).send({ taxiPerKm: 750, taxiBaseFare: 2500, taxiMinFare: 3500 }).expect(200)).body;
    expect(st).toMatchObject({ taxiEnabled: true, taxiPerKm: 750, taxiBaseFare: 2500, taxiMinFare: 3500 });
    const q = (await http().get('/taxi/quote').query({ direction: 'to_campus', ...HOME }).set(auth(tokens.sara)).expect(200)).body;
    expect(q.fare).toBe(fareFor(q.distanceKm, { baseFare: 2500, perKm: 750, minFare: 3500 }));

    await http().patch('/taxi/settings').set(auth(tokens.office)).send({ taxiEnabled: false }).expect(200);
    await http().get('/taxi/quote').query({ direction: 'to_campus', ...HOME }).set(auth(tokens.sara)).expect(422);
    await online('t1', HOME).expect(422);
    expect((await http().get('/students/me').set(auth(tokens.sara)).expect(200)).body.taxiEnabled).toBe(false);
  });
});
