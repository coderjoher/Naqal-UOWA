import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { baghdadDate, secondsInto } from '../src/dispatch/clock';
import { DispatchEngine } from '../src/dispatch/dispatch.engine';
import { PUSH_SENDER, PushMessage, PushSender } from '../src/notifications/push';
import { auth, createApp, createConfiguredUniversity, createUser, login, raw, resetDb } from './helpers';

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

describe('P7 overrides, feedback, history and announcements (e2e)', () => {
  let app: INestApplication;
  let engine: DispatchEngine;
  let uniId: string;
  let office: string;
  let wave: { id: string; date: string };
  const pushed: PushMessage[] = [];
  const http = () => request(app.getHttpServer());
  const tokens: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const points: Record<string, string> = {};
  const males = ['m1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7'];

  beforeAll(async () => {
    await resetDb();
    uniId = (await createConfiguredUniversity('warith')).id;
    const tier = await raw.distanceTier.create({ data: { universityId: uniId, name: 'A', minKm: 0, maxKm: null, subscriptionPrice: 40000, ridePrice: 1500 } });
    points.bab = (await raw.gatheringPoint.create({ data: { universityId: uniId, name: 'Bab Baghdad', nameAr: 'باب بغداد', lat: 32.6, lng: 44.05, tierId: tier.id } })).id;
    points.abbas = (await raw.gatheringPoint.create({ data: { universityId: uniId, name: 'Al-Abbas Square', nameAr: 'ساحة العباس', lat: 32.616, lng: 44.0249, tierId: tier.id } })).id;
    const s = slot(150);
    wave = { id: (await raw.wave.create({ data: { universityId: uniId, type: 'morning', minuteOfDay: s.minute, weekdays: 127 } })).id, date: s.date };

    await createUser('office', uniId, 'office@w.iq', { name: 'مكتب النقل' });
    for (const [key, seats, offered] of [['d1', 3, true], ['d2', 3, true], ['d4', 3, true], ['d3', 20, false]] as const) {
      const u = await createUser('driver', uniId, `${key}@w.iq`, { name: `Driver ${key}`, nameAr: `السائق ${key}`, loginPhone: `+96478000001${key.slice(1)}` });
      await raw.driverProfile.create({ data: { userId: u.id, universityId: uniId, status: 'approved', vehicleType: 'coaster', plate: `${key}-1`, seats } });
      if (offered) await raw.driverAvailability.create({ data: { universityId: uniId, driverId: u.id, waveId: wave.id, date: new Date(`${wave.date}T00:00:00Z`) } });
      ids[key] = u.id;
    }
    for (const key of [...males, 'f1', 'idle']) {
      const point = key === 'm7' || key === 'idle' ? points.bab : points.abbas;
      ids[key] = (await createUser('student', uniId, `${key}@w.iq`, { name: key, nameAr: `طالب ${key}`, studentId: `W-${key}`, gender: key === 'f1' ? 'female' : 'male', defaultPointId: point })).id;
    }
    await createUser('student', uniId, 'gone@w.iq', { studentId: 'W-gone', gender: 'male', status: 'suspended', defaultPointId: points.abbas });

    app = await createApp();
    engine = app.get(DispatchEngine);
    const sender = app.get<PushSender>(PUSH_SENDER);
    jest.spyOn(sender, 'send').mockImplementation(async (m) => {
      pushed.push(m);
      return 'sent';
    });
    office = await login(app, 'office@w.iq');
    for (const k of [...males, 'f1', 'idle', 'd1', 'd2', 'd3', 'd4']) tokens[k] = await login(app, `${k}@w.iq`);

    // Everyone but "idle" asks for the wave, then it is dispatched: 3 buses of 3 seats.
    for (const k of [...males, 'f1']) await http().post('/rides').set(auth(tokens[k])).send({ waveId: wave.id, date: wave.date }).expect(201);
    await engine.plan({ universityId: uniId, waveId: wave.id, date: wave.date });
  });

  afterAll(async () => {
    await app.close();
    await raw.$disconnect();
  });

  const board = async () => (await http().get(`/dispatch?date=${wave.date}`).set(auth(office)).expect(200)).body.find((w: any) => w.waveId === wave.id);
  const riders = (run: any): string[] => run.stops.flatMap((s: any) => s.passengers.map((p: any) => p.requestId));

  it('[T7-03] a manual move re-validates gender, capacity and wave time and notifies the student and both drivers', async () => {
    // 7 men on three 3-seat buses; the one woman waits (no female-only bus offered).
    const b = await board();
    const male = b.runs.filter((r: any) => r.gender === 'male');
    expect(male).toHaveLength(3);
    expect(b.waitlist.map((w: any) => w.studentId)).toEqual(['W-f1']);
    const full = male.filter((r: any) => r.booked === r.capacity);
    const roomy = male.find((r: any) => r.booked < r.capacity);
    expect(full).toHaveLength(2);

    // Full bus: refused, nothing changes.
    await http().post('/dispatch/move').set(auth(office)).send({ requestId: riders(full[0])[0], runId: full[1].id }).expect(409).expect((r) => expect(r.body.message).toMatch(/full/));
    await http().post('/dispatch/move').set(auth(office)).send({ requestId: riders(full[0])[0], runId: full[0].id }).expect(409);

    // An extra female-only bus (a driver who did not offer the wave) takes the waiting student.
    const free = (await http().get(`/dispatch/free-drivers?waveId=${wave.id}&date=${wave.date}`).set(auth(office)).expect(200)).body;
    expect(free.map((d: any) => d.id)).toEqual([ids.d3]);
    await http().post('/dispatch/extra-run').set(auth(office)).send({ waveId: wave.id, date: wave.date, driverId: ids.d1, gender: 'female' }).expect(409);
    const extra = (await http().post('/dispatch/extra-run').set(auth(office)).send({ waveId: wave.id, date: wave.date, driverId: ids.d3, gender: 'female' }).expect(200)).body;
    expect(extra.placed).toBe(1);
    const after = await board();
    expect(after.waitlist).toHaveLength(0);
    const femaleBus = after.runs.find((r: any) => r.id === extra.runId);
    expect(femaleBus).toMatchObject({ driverId: ids.d3, gender: 'female', femaleOnly: true });
    expect(await raw.notification.findFirst({ where: { userId: ids.f1, kind: 'ride.assigned' } })).toBeTruthy();

    // A man cannot be moved onto the female-only bus.
    await http().post('/dispatch/move').set(auth(office)).send({ requestId: riders(full[0])[0], runId: extra.runId }).expect(409).expect((r) => expect(r.body.message).toMatch(/Female-only/));

    // Room on the third bus: the move goes through.
    const moving = riders(full[0])[0];
    const student = (await raw.rideRequest.findUniqueOrThrow({ where: { id: moving } })).studentId;
    await http().post('/dispatch/move').set(auth(office)).send({ requestId: moving, runId: roomy.id }).expect(200);
    const final = await board();
    expect(riders(final.runs.find((r: any) => r.id === roomy.id))).toContain(moving);
    expect(riders(final.runs.find((r: any) => r.id === full[0].id))).not.toContain(moving);
    const who = Object.keys(ids).find((k) => ids[k] === student)!;
    const ride = (await http().get('/rides/me').set(auth(tokens[who])).expect(200)).body.find((r: any) => r.id === moving);
    expect(ride.assignment.runId).toBe(roomy.id);

    const notes = await raw.notification.findMany({ where: { OR: [{ kind: 'ride.moved' }, { kind: 'run.changed' }] } });
    expect(notes.find((n) => n.kind === 'ride.moved')).toMatchObject({ userId: student, data: expect.objectContaining({ runId: roomy.id }) });
    expect(notes.filter((n) => n.kind === 'run.changed' && (n.data as any).change !== 'extra').map((n) => n.userId).sort()).toEqual([full[0].driverId, roomy.driverId].sort());
  });

  it('[T7-02] rating 1–5 once per ride; problem reports reach the office inbox', async () => {
    const b = await board();
    const req = riders(b.runs.find((r: any) => r.gender === 'female'))[0];
    await http().post(`/rides/${req}/rating`).set(auth(tokens.f1)).send({ stars: 5 }).expect(409); // not finished yet
    await raw.rideRequest.update({ where: { id: req }, data: { status: 'done', boardedAt: new Date() } });

    await http().post(`/rides/${req}/rating`).set(auth(tokens.f1)).send({ stars: 6 }).expect(400);
    await http().post(`/rides/${req}/rating`).set(auth(tokens.f1)).send({ stars: 0 }).expect(400);
    await http().post(`/rides/${req}/rating`).set(auth(tokens.m1)).send({ stars: 4 }).expect(403);
    const rating = (await http().post(`/rides/${req}/rating`).set(auth(tokens.f1)).send({ stars: 4, comment: 'السائق ممتاز' }).expect(201)).body;
    expect(rating).toMatchObject({ stars: 4, comment: 'السائق ممتاز' });
    await http().post(`/rides/${req}/rating`).set(auth(tokens.f1)).send({ stars: 1 }).expect(409);
    const ratings = (await http().get('/inbox/ratings').set(auth(office)).expect(200)).body;
    expect(ratings.recent).toHaveLength(1);
    expect(ratings.drivers[0]).toMatchObject({ average: 4, count: 1 });

    // Report a problem about that ride → office inbox → answer → student notified.
    await http().post('/problems').set(auth(tokens.f1)).send({ category: 'weather', text: 'x' }).expect(400);
    const p = (await http().post('/problems').set(auth(tokens.f1)).send({ category: 'late', text: 'تأخرت الحافلة ١٥ دقيقة', requestId: req }).expect(201)).body;
    await http().post('/problems').set(auth(tokens.m1)).send({ category: 'late', text: 'not my ride', requestId: req }).expect(400);
    const inbox = (await http().get('/inbox/problems?status=open').set(auth(office)).expect(200)).body;
    expect(inbox).toHaveLength(1);
    expect(inbox[0]).toMatchObject({ id: p.id, category: 'late', status: 'open', student: { studentId: 'W-f1' }, ride: { date: wave.date } });
    await http().get('/inbox/problems').set(auth(tokens.f1)).expect(403);

    await http().patch(`/problems/${p.id}`).set(auth(office)).send({ reply: 'نعتذر، تمت مخاطبة السائق.' }).expect(200);
    await http().patch(`/problems/${p.id}`).set(auth(office)).send({ reply: 'again' }).expect(409);
    expect((await http().get('/problems/me').set(auth(tokens.f1)).expect(200)).body[0]).toMatchObject({ status: 'resolved', reply: 'نعتذر، تمت مخاطبة السائق.' });
    expect(await raw.notification.findFirst({ where: { userId: ids.f1, kind: 'problem.answered' } })).toBeTruthy();

    // ST-10: the finished ride is in the history with its rating; nothing left to rate.
    const hist = (await http().get('/rides/history').set(auth(tokens.f1)).expect(200)).body;
    expect(hist.items[0]).toMatchObject({ id: req, status: 'done', rating: 4, canRate: false });
  });

  it('ST-10: ride and payment history page with a cursor, newest first', async () => {
    const office0 = await raw.user.findFirstOrThrow({ where: { role: 'office' } });
    for (let i = 0; i < 25; i++) {
      await raw.payment.create({ data: { universityId: uniId, studentId: ids.idle, type: 'cash_fare', method: 'cash_driver', amount: 1500, receiptNo: 1000 + i, collectedById: office0.id, createdAt: new Date(Date.UTC(2026, 8, 1 + i)) } });
    }
    const first = (await http().get('/payments/me').set(auth(tokens.idle)).expect(200)).body;
    expect(first.items).toHaveLength(20);
    expect(first.next).toBeTruthy();
    expect(first.items[0].receiptNo).toBe(1024);
    const second = (await http().get(`/payments/me?cursor=${first.next}`).set(auth(tokens.idle)).expect(200)).body;
    expect(second.items.map((p: any) => p.receiptNo)).toEqual([1004, 1003, 1002, 1001, 1000]);
    expect(second.next).toBeNull();
    expect((await http().get('/rides/history').set(auth(tokens.idle)).expect(200)).body).toEqual({ items: [], next: null });
  });

  it('[T7-06] an announcement targets all students or a wave / point and arrives as push and in-app banner', async () => {
    for (const k of ['m1', 'idle', 'f1']) await http().post('/devices').set(auth(tokens[k])).send({ token: `device-token-for-${k}-0123456789`, platform: 'android' }).expect(200);
    pushed.length = 0;

    // All students: every active one (9), never the suspended account.
    expect((await http().post('/announcements/preview').set(auth(office)).send({ title: 'tt', body: 'bb', target: 'all' }).expect(200)).body.recipients).toBe(9);
    // One wave on one date: the 7 men still riding it ("idle" never asked; f1's ride is finished).
    expect((await http().post('/announcements/preview').set(auth(office)).send({ title: 'tt', body: 'bb', target: 'wave', waveId: wave.id, date: wave.date }).expect(200)).body.recipients).toBe(7);
    await http().post('/announcements').set(auth(office)).send({ title: 'tt', body: 'bb', target: 'wave' }).expect(400);

    const a = (await http().post('/announcements').set(auth(office)).send({ title: 'تغيير مكان التجمع', body: 'نقطة باب بغداد تنتقل ٥٠ متراً شمالاً اليوم.', target: 'point', pointId: points.bab }).expect(201)).body;
    // Point: students who live there (m7, idle).
    expect(a.recipients).toBe(2);
    const banner = (await http().get('/announcements/active').set(auth(tokens.idle)).expect(200)).body;
    expect(banner).toEqual([expect.objectContaining({ announcementId: a.id, title: 'تغيير مكان التجمع' })]);
    expect((await http().get('/announcements/active').set(auth(tokens.m1)).expect(200)).body).toEqual([]);
    expect(pushed.map((p) => p.token)).toEqual(['device-token-for-idle-0123456789']);
    expect(pushed[0]).toMatchObject({ title: 'تغيير مكان التجمع', body: 'نقطة باب بغداد تنتقل ٥٠ متراً شمالاً اليوم.' });

    // Dismissing the banner marks it read; it stays in the notification list.
    await http().post('/notifications/read').set(auth(tokens.idle)).send({ ids: [banner[0].id] }).expect(200);
    expect((await http().get('/announcements/active').set(auth(tokens.idle)).expect(200)).body).toEqual([]);

    pushed.length = 0;
    const all = (await http().post('/announcements').set(auth(office)).send({ title: 'عطلة رسمية', body: 'لا رحلات يوم الخميس.', target: 'all', days: 2 }).expect(201)).body;
    expect(all.recipients).toBe(9);
    expect(pushed.map((p) => p.token).sort()).toEqual(['device-token-for-f1-0123456789', 'device-token-for-idle-0123456789', 'device-token-for-m1-0123456789']);
    expect((await http().get('/announcements').set(auth(office)).expect(200)).body.map((x: any) => x.target)).toEqual(['all', 'point']);
  });
});
