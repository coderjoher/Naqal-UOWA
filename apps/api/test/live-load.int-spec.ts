import { INestApplication } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import Redis from 'ioredis';
import { randomUUID } from 'node:crypto';
import { AddressInfo } from 'node:net';
import { io, Socket } from 'socket.io-client';
import { createApp, createConfiguredUniversity, raw, resetDb } from './helpers';

/**
 * T5-06 (NF-07): GPS ping → student socket latency, p95 < 3 s, with 150 buses pinging every 5 s
 * and 2 000 student sockets. Scale and duration can be lowered locally with LOAD_* variables.
 */
const BUSES = Number(process.env.LOAD_BUSES ?? 150);
const STUDENTS = Number(process.env.LOAD_SOCKETS ?? 2000);
const SECONDS = Number(process.env.LOAD_SECONDS ?? 30);
const INTERVAL_MS = 5000;

describe('[T5-06] live latency under load', () => {
  let app: INestApplication;
  const sockets: Socket[] = [];
  const redis = new Redis(process.env.REDIS_URL!);

  afterAll(async () => {
    sockets.forEach((s) => s.disconnect());
    await app?.close();
    redis.disconnect();
    await raw.$disconnect();
  });

  it(`ping → student p95 < 3 s with ${BUSES} buses × 5 s and ${STUDENTS} sockets`, async () => {
    await resetDb();
    await redis.flushdb();
    const uni = await createConfiguredUniversity('warith');
    const tier = await raw.distanceTier.create({ data: { universityId: uni.id, name: 'A', minKm: 0, maxKm: null, subscriptionPrice: 40000, ridePrice: 1500 } });
    const point = await raw.gatheringPoint.create({ data: { universityId: uni.id, name: 'P', lat: 32.6, lng: 44.05, tierId: tier.id } });
    const wave = await raw.wave.create({ data: { universityId: uni.id, type: 'morning', minuteOfDay: 23 * 60 + 59, weekdays: 127 } });
    const date = new Date(`${new Date().toISOString().slice(0, 10)}T00:00:00Z`);

    const drivers = Array.from({ length: BUSES }, (_, i) => ({ id: randomUUID(), universityId: uni.id, role: 'driver' as const, name: `d${i}`, loginPhone: `+96477${String(i).padStart(8, '0')}` }));
    const students = Array.from({ length: STUDENTS }, (_, i) => ({ id: randomUUID(), universityId: uni.id, role: 'student' as const, name: `s${i}`, studentId: `L-${i}`, gender: 'male' as const }));
    await raw.user.createMany({ data: [...drivers, ...students] });
    const runs = drivers.map((d) => ({ id: randomUUID(), universityId: uni.id, driverId: d.id, waveId: wave.id, date, gender: 'male' as const, tierId: tier.id, capacity: Math.ceil(STUDENTS / BUSES) + 1, status: 'started' as const }));
    await raw.run.createMany({ data: runs });
    await raw.runStop.createMany({ data: runs.map((r) => ({ universityId: uni.id, runId: r.id, seq: 0, pointId: point.id, eta: new Date(Date.now() + 3600_000) })) });
    await raw.rideRequest.createMany({
      data: students.map((s, i) => ({ universityId: uni.id, studentId: s.id, waveId: wave.id, date, pointId: point.id, tierId: tier.id, gender: 'male' as const, subscriber: true, fare: 0, status: 'assigned' as const, runId: runs[i % BUSES].id })),
    });

    app = await createApp();
    await app.listen(0);
    const url = `http://127.0.0.1:${(app.getHttpServer().address() as AddressInfo).port}/live`;
    const jwt = app.get(JwtService);
    const token = (u: { id: string; role: string }) => jwt.signAsync({ sub: u.id, role: u.role, uid: uni.id });
    const connect = async (u: { id: string; role: string }) => {
      const s = io(url, { auth: { token: await token(u) }, transports: ['websocket'], reconnection: false, forceNew: true });
      sockets.push(s);
      await new Promise<void>((resolve, reject) => {
        s.once('ready', () => resolve());
        s.once('connect_error', reject);
      });
      return s;
    };

    const latencies: number[] = [];
    for (let i = 0; i < STUDENTS; i += 100) {
      await Promise.all(
        students.slice(i, i + 100).map(async (st, k) => {
          const s = await connect(st);
          const ack = await s.emitWithAck('join', { runId: runs[(i + k) % BUSES].id });
          if (!ack.ok) throw new Error('join refused');
          s.on('bus', (m: { at: string }) => latencies.push(Date.now() - Date.parse(m.at)));
        }),
      );
    }
    const driverSockets = await Promise.all(drivers.map((d) => connect(d)));

    // Each bus pings every 5 s, spread evenly across the interval (far from its stop: no notifications).
    const end = Date.now() + SECONDS * 1000;
    let sent = 0;
    await Promise.all(
      driverSockets.map(async (s, i) => {
        await new Promise((r) => setTimeout(r, (i * INTERVAL_MS) / BUSES));
        while (Date.now() < end) {
          const t = Date.now();
          s.emit('gps', { runId: runs[i].id, lat: 33.0 + Math.random() * 0.01, lng: 44.5, at: new Date().toISOString() });
          sent++;
          await new Promise((r) => setTimeout(r, Math.max(0, INTERVAL_MS - (Date.now() - t))));
        }
      }),
    );
    await new Promise((r) => setTimeout(r, 3000)); // let the last pings arrive

    latencies.sort((a, b) => a - b);
    const p95 = latencies[Math.floor(latencies.length * 0.95)];
    const expected = sent * (STUDENTS / BUSES);
    console.log(`T5-06: ${sent} pings, ${latencies.length}/${Math.round(expected)} deliveries, p50 ${latencies[Math.floor(latencies.length / 2)]} ms, p95 ${p95} ms, max ${latencies[latencies.length - 1]} ms`);
    expect(latencies.length).toBeGreaterThan(expected * 0.99);
    expect(p95).toBeLessThan(3000);
  }, 300_000);
});
