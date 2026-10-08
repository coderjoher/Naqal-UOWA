import { getQueueToken } from '@nestjs/bullmq';
import { INestApplication } from '@nestjs/common';
import { Queue } from 'bullmq';
import request from 'supertest';
import { baghdadDate, secondsInto } from '../src/dispatch/clock';
import { DISPATCH_QUEUE, DispatchEngine, WAITLIST_EXPIRE, WAVE_TICK } from '../src/dispatch/dispatch.engine';
import { auth, createApp, createConfiguredUniversity, createUser, login, raw, resetDb } from './helpers';

/** Polls until `fn` returns a truthy value (workers run asynchronously). */
async function waitFor<T>(fn: () => Promise<T>, what: string, ms = 15_000): Promise<NonNullable<T>> {
  const end = Date.now() + ms;
  for (;;) {
    const v = await fn();
    if (v) return v as NonNullable<T>;
    if (Date.now() > end) throw new Error(`Timed out waiting for ${what}`);
    await new Promise((r) => setTimeout(r, 150));
  }
}

/** A wave `minutesAhead` from now (Baghdad), on today's date or tomorrow's if it crosses midnight. */
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

describe('P4 ride requests and dispatch (e2e)', () => {
  let app: INestApplication;
  let queue: Queue;
  let uniId: string;
  let office: string;
  const http = () => request(app.getHttpServer());
  const tokens: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const points: Record<string, string> = {};
  let wave: { id: string; date: string };

  beforeAll(async () => {
    await resetDb();
    uniId = (await createConfiguredUniversity('warith')).id;
    await raw.university.update({ where: { id: uniId }, data: { waitlistMinutes: 20 } });
    const near = await raw.distanceTier.create({ data: { universityId: uniId, name: 'A', minKm: 0, maxKm: 5, subscriptionPrice: 40000, ridePrice: 1500 } });
    const mid = await raw.distanceTier.create({ data: { universityId: uniId, name: 'B', minKm: 5, maxKm: null, subscriptionPrice: 60000, ridePrice: 2000 } });
    points.bab = (await raw.gatheringPoint.create({ data: { universityId: uniId, name: 'Bab Baghdad', nameAr: 'باب بغداد', lat: 32.6, lng: 44.05, tierId: near.id } })).id;
    points.abbas = (await raw.gatheringPoint.create({ data: { universityId: uniId, name: 'Al-Abbas Square', nameAr: 'ساحة العباس', lat: 32.616, lng: 44.0249, tierId: mid.id } })).id;
    points.hussein = (await raw.gatheringPoint.create({ data: { universityId: uniId, name: 'Hay Al-Hussein', nameAr: 'حي الحسين', lat: 32.62, lng: 44.0, tierId: mid.id } })).id;

    const s = slot(150);
    wave = { id: (await raw.wave.create({ data: { universityId: uniId, type: 'morning', minuteOfDay: s.minute, weekdays: 127 } })).id, date: s.date };

    const officeUser = await createUser('office', uniId, 'office@w.iq');
    for (const [key, seats] of [['d1', 4], ['d2', 4], ['d3', 30]] as const) {
      const u = await createUser('driver', uniId, `${key}@w.iq`, { name: `Driver ${key}`, nameAr: `السائق ${key}`, loginPhone: `+96478000000${key.slice(1)}` });
      await raw.driverProfile.create({ data: { userId: u.id, universityId: uniId, status: 'approved', vehicleType: 'coaster', plate: `${key}-123 كربلاء`, seats } });
      ids[key] = u.id;
    }
    const students: [string, 'male' | 'female', string][] = [
      ['ali', 'male', points.abbas],
      ['omar', 'male', points.hussein],
      ['hasan', 'male', points.bab],
      ['karim', 'male', points.abbas],
      ['zainab', 'female', points.abbas],
      ['late', 'male', points.abbas],
      ['nogender', 'male', points.abbas],
    ];
    for (const [key, gender, point] of students) {
      const u = await createUser('student', uniId, `${key}@w.iq`, { name: key, nameAr: `طالب ${key}`, studentId: `W-${key}`, gender: key === 'nogender' ? null : gender, defaultPointId: point });
      ids[key] = u.id;
    }
    // Ali subscribes (tier B, his point) — he rides for free.
    const pay = await raw.payment.create({ data: { universityId: uniId, studentId: ids.ali, type: 'subscription', method: 'cash_office', amount: 60000, receiptNo: 1, collectedById: officeUser.id } });
    const month = wave.date.slice(0, 7);
    const [y, m] = month.split('-').map(Number);
    await raw.subscription.create({ data: { universityId: uniId, studentId: ids.ali, tierId: mid.id, pointId: points.abbas, month, periodStart: new Date(Date.UTC(y, m - 1, 1)), periodEnd: new Date(Date.UTC(y, m, 0)), price: 60000, paymentId: pay.id } });

    app = await createApp();
    queue = app.get<Queue>(getQueueToken(DISPATCH_QUEUE));
    office = await login(app, 'office@w.iq');
    for (const k of [...students.map((x) => x[0]), 'd1', 'd2', 'd3']) tokens[k] = await login(app, `${k}@w.iq`);
  });

  afterAll(async () => {
    await app.close();
    await raw.$disconnect();
  });

  const board = async () => (await http().get(`/dispatch?date=${wave.date}`).set(auth(office)).expect(200)).body.find((w: any) => w.waveId === wave.id);
  const myRide = async (who: string) => (await http().get('/rides/me').set(auth(tokens[who])).expect(200)).body.find((r: any) => r.wave.id === wave.id && r.status !== 'cancelled');

  it('[T4-09] availability decides which drivers get runs; a driver sees ordered stops with passengers', async () => {
    const days = (await http().get('/drivers/me/availability').set(auth(tokens.d1)).expect(200)).body;
    expect(days).toHaveLength(7);
    const day = days.find((d: any) => d.date === wave.date);
    expect(day.waves.find((w: any) => w.waveId === wave.id)).toMatchObject({ available: false, locked: false });

    // d1 and d2 offer the wave; d3 (the biggest bus) does not.
    for (const d of ['d1', 'd2']) {
      const r = await http().put('/drivers/me/availability').set(auth(tokens[d])).send({ date: wave.date, waveIds: [wave.id] }).expect(200);
      expect(r.body.waves.find((w: any) => w.waveId === wave.id).available).toBe(true);
    }
    await http().put('/drivers/me/availability').set(auth(tokens.d1)).send({ date: '2001-01-01', waveIds: [] }).expect(400);

    // Requests before planning stay open.
    for (const s of ['ali', 'omar', 'hasan', 'zainab']) {
      const r = await http().post('/rides').set(auth(tokens[s])).send({ waveId: wave.id, date: wave.date }).expect(201);
      expect(r.body.status).toBe('open');
    }
    expect((await http().post('/rides').set(auth(tokens.ali)).send({ waveId: wave.id, date: wave.date }).expect(409)).body.message).toMatch(/already/);
    await http().post('/rides').set(auth(tokens.nogender)).send({ waveId: wave.id, date: wave.date }).expect(422);
    const ali = await myRide('ali');
    expect(ali).toMatchObject({ subscriber: true, fare: 0 });
    expect(await myRide('hasan')).toMatchObject({ subscriber: false, fare: 1500 });

    await http().post('/dispatch/plan').set(auth(office)).send({ waveId: wave.id, date: wave.date }).expect(202);
    const planned = await waitFor(async () => {
      const b = await board();
      return b.planned ? b : null;
    }, 'wave plan');
    expect(planned.counts).toMatchObject({ assigned: 4, open: 0, waitlisted: 0 });
    // Gender separation: one male run and one female-only run, only on available drivers.
    expect(planned.runs).toHaveLength(2);
    expect(planned.runs.map((r: any) => r.gender).sort()).toEqual(['female', 'male']);
    expect(planned.runs.map((r: any) => r.driverName).every((n: string) => n !== 'السائق d3')).toBe(true);
    expect((await http().get(`/drivers/me/runs?date=${wave.date}`).set(auth(tokens.d3)).expect(200)).body).toEqual([]);

    // The male run: ordered stops (far → near), passengers and ETAs per stop.
    const mine = [
      ...(await http().get(`/drivers/me/runs?date=${wave.date}`).set(auth(tokens.d1)).expect(200)).body,
      ...(await http().get(`/drivers/me/runs?date=${wave.date}`).set(auth(tokens.d2)).expect(200)).body,
    ];
    const male = mine.find((r: any) => r.gender === 'male');
    expect(male.stops.map((s: any) => s.point.name)).toEqual(['Hay Al-Hussein', 'Al-Abbas Square', 'Bab Baghdad']);
    expect(male.stops.map((s: any) => s.seq)).toEqual([1, 2, 3]);
    expect(male.stops.map((s: any) => s.passengers.map((p: any) => p.name))).toEqual([['طالب omar'], ['طالب ali'], ['طالب hasan']]);
    const etas = male.stops.map((s: any) => Date.parse(s.eta));
    expect([...etas].sort()).toEqual(etas);
    expect(male.stops[2].cashToCollect).toBe(1500);
    expect(male.departAt).toBe(male.stops[0].eta);

    // Planned waves are locked for availability changes.
    await http().put('/drivers/me/availability').set(auth(tokens.d1)).send({ date: wave.date, waveIds: [] }).expect(409);

    // ST-05: the student sees bus, driver, plate and pickup time.
    const omar = await myRide('omar');
    expect(omar.status).toBe('assigned');
    expect(omar.assignment).toMatchObject({ plate: expect.stringContaining('كربلاء'), stopNumber: 1, stops: 3 });
    expect(Date.parse(omar.assignment.pickupAt)).toBe(etas[0]);
  });

  it('[T4-07] request path is fast; insertion, waitlist and expiry run in workers', async () => {
    // The male bus (4 seats) has 3 riders: Karim fills it through a worker re-check.
    const t0 = performance.now();
    await http().post('/rides').set(auth(tokens.karim)).send({ waveId: wave.id, date: wave.date }).expect(201);
    expect(performance.now() - t0).toBeLessThan(100);
    await waitFor(async () => (await myRide('karim'))?.status === 'assigned', 'karim assigned');

    // The bus is full now: the next rider is waitlisted with a deadline (DS-04).
    await http().post('/rides').set(auth(tokens.late)).send({ waveId: wave.id, date: wave.date }).expect(201);
    const late = await waitFor(async () => {
      const r = await myRide('late');
      return r?.status === 'waitlisted' ? r : null;
    }, 'late waitlisted');
    const until = Date.parse(late.waitlistedUntil);
    expect(until - Date.now()).toBeGreaterThan(19 * 60_000);
    expect(until - Date.now()).toBeLessThanOrEqual(20 * 60_000);
    expect(await raw.notification.count({ where: { userId: ids.late, kind: 'ride.waitlisted' } })).toBe(1);

    // waitlist.expire: once the deadline passes, the worker cancels and notifies.
    const req = await raw.rideRequest.findFirstOrThrow({ where: { studentId: ids.late, status: 'waitlisted' } });
    await raw.rideRequest.update({ where: { id: req.id }, data: { waitlistedUntil: new Date(Date.now() - 1000) } });
    await queue.add(WAITLIST_EXPIRE, { universityId: uniId, waveId: wave.id, date: wave.date, requestId: req.id });
    await waitFor(async () => (await raw.rideRequest.findUniqueOrThrow({ where: { id: req.id } })).status === 'cancelled', 'expiry');
    expect(await raw.rideRequest.findUniqueOrThrow({ where: { id: req.id } })).toMatchObject({ cancelReason: 'expired' });
    expect(await raw.notification.count({ where: { userId: ids.late, kind: 'ride.expired' } })).toBe(1);

    // wave.plan: the minute tick plans waves whose planning time has come.
    const soon = slot(30);
    const w2 = await raw.wave.create({ data: { universityId: uniId, type: 'morning', minuteOfDay: soon.minute, weekdays: 127 } });
    await queue.add(WAVE_TICK, {});
    await waitFor(async () => raw.wavePlan.findUnique({ where: { waveId_date: { waveId: w2.id, date: new Date(`${soon.date}T00:00:00Z`) } } }), 'tick plan');
  });

  it('[T4-08] cancelling before pickup frees the seat; after pickup it is refused', async () => {
    // Late asks again and waits; Hasan cancels; the freed seat goes to Late.
    await http().post('/rides').set(auth(tokens.late)).send({ waveId: wave.id, date: wave.date }).expect(201);
    await waitFor(async () => (await myRide('late'))?.status === 'waitlisted', 'late waitlisted again');
    const hasan = await myRide('hasan');
    const res = await http().post(`/rides/${hasan.id}/cancel`).set(auth(tokens.hasan)).expect(200);
    expect(res.body).toMatchObject({ status: 'cancelled', cancelReason: 'student', assignment: null });
    await waitFor(async () => (await myRide('late'))?.status === 'assigned', 'late seated after cancel');
    // Bab Baghdad lost its only rider, so the stop is gone from the run. The office board may lag
    // one refresh behind riders' own actions (it is polled every 5 s), so wait for it.
    const maleRun = async () => (await board()).runs.find((r: any) => r.gender === 'male');
    const male = await waitFor(async () => {
      const r = await maleRun();
      return r.stops.length === 2 ? r : null;
    }, 'board shows the shorter run');
    expect(male.stops.map((s: any) => s.point.name)).toEqual(['Hay Al-Hussein', 'Al-Abbas Square']);
    expect(male.booked).toBe(4);

    // Omar has boarded: cancelling now is refused.
    const omar = await myRide('omar');
    await raw.rideRequest.update({ where: { id: omar.id }, data: { boardedAt: new Date() } });
    expect((await http().post(`/rides/${omar.id}/cancel`).set(auth(tokens.omar)).expect(409)).body.message).toMatch(/picked up/);
    // Someone else's request is not found; a closed one cannot be cancelled twice.
    await http().post(`/rides/${omar.id}/cancel`).set(auth(tokens.ali)).expect(404);
    await http().post(`/rides/${hasan.id}/cancel`).set(auth(tokens.hasan)).expect(409);
  });

  it('a ride finished while a waitlist re-check is running is never flipped back to assigned', async () => {
    const engine = app.get(DispatchEngine);
    const omar = await myRide('omar');
    expect(omar.status).toBe('assigned');
    // The re-check loads the plan, then the ride ends (driver finished it) before the plan is saved.
    const load = (engine as any).load.bind(engine);
    const spy = jest.spyOn(engine as any, 'load').mockImplementationOnce(async (...args: unknown[]) => {
      const state = await load(...args);
      await raw.rideRequest.update({ where: { id: omar.id }, data: { status: 'done' } });
      return state;
    });
    await engine.recheck({ universityId: uniId, waveId: wave.id, date: wave.date });
    spy.mockRestore();
    expect((await raw.rideRequest.findUniqueOrThrow({ where: { id: omar.id } })).status).toBe('done');
  });
});
