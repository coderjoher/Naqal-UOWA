#!/usr/bin/env node
// [T8-04] Full-day smoke test against a running stack with the demo data (docker compose, or
// staging): plan a wave → a driver runs it with GPS → a student tracks the bus → the driver takes a
// cash fare → the month's settlement draft counts the run (GPS-verified) and the cash.
//
//   node scripts/smoke/full-day.mjs                      (API at http://localhost:3000)
//   API=https://staging.example/api node scripts/smoke/full-day.mjs
//
// Needs the demo accounts and OTP_DEV_ECHO=true (driver sign-in codes are returned by the API).
// Exits 1 with the failing step on any error. Node 22+, no dependencies.

const API = (process.env.API ?? 'http://localhost:3000').replace(/\/$/, '');
const OFFICE = { email: process.env.OFFICE_EMAIL ?? 'office@uowa.edu.iq', password: process.env.OFFICE_PASSWORD ?? 'password123' };
const STUDENT_PASSWORD = process.env.STUDENT_PASSWORD ?? 'student123';
const started = Date.now();
let step = 'start';

const log = (msg) => console.log(`${((Date.now() - started) / 1000).toFixed(1).padStart(6)} s  ${msg}`);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const uuid = () => crypto.randomUUID();

async function call(method, path, { token, body, ok = [200, 201] } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : null;
  if (!ok.includes(res.status)) throw new Error(`${method} ${path} → ${res.status} ${text.slice(0, 300)}`);
  return json;
}

async function waitFor(fn, what, ms = 60_000) {
  const end = Date.now() + ms;
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() > end) throw new Error(`timed out waiting for ${what}`);
    await sleep(1000);
  }
}

/** Straight line from a to b in `n` GPS points. */
const leg = (a, b, n = 4) => Array.from({ length: n }, (_, i) => ({ lat: a.lat + ((b.lat - a.lat) * (i + 1)) / n, lng: a.lng + ((b.lng - a.lng) * (i + 1)) / n }));

async function main() {
  step = 'office signs in';
  const office = (await call('POST', '/auth/login', { body: OFFICE })).accessToken;
  const uni = await call('GET', '/universities/current', { token: office });
  const campus = { lat: uni.campusLat, lng: uni.campusLng };
  log(`office signed in (${uni.nameAr ?? uni.name})`);

  step = 'find a wave with open requests';
  const baghdad = (plus) => new Date(Date.now() + 3 * 3600_000 + plus * 86400_000).toISOString().slice(0, 10);
  let date;
  let wave;
  for (const d of [baghdad(0), baghdad(1)]) {
    const board = await call('GET', `/dispatch?date=${d}`, { token: office });
    wave = board.find((w) => w.type === 'morning' && (w.counts.open > 0 || w.runs.length > 0));
    if (wave) {
      date = d;
      break;
    }
  }
  if (!wave) throw new Error('no morning wave with requests today or tomorrow (load the demo data)');
  log(`wave ${wave.time} on ${date}: ${wave.counts.open} open requests`);

  step = 'plan the wave';
  await call('POST', '/dispatch/plan', { token: office, body: { waveId: wave.waveId, date }, ok: [202] });
  const planned = await waitFor(async () => {
    const w = (await call('GET', `/dispatch?date=${date}`, { token: office })).find((x) => x.waveId === wave.waveId);
    return w?.planned && w.runs.length ? w : null;
  }, 'the wave to be planned');
  // Prefer a bus that has a pay-per-ride rider, to exercise the cash fare.
  const run = planned.runs.find((r) => r.stops.some((s) => s.passengers.some((p) => p.fare > 0))) ?? planned.runs[0];
  const riders = run.stops.flatMap((s) => s.passengers);
  log(`planned: ${planned.runs.length} buses; following ${run.driverName} with ${riders.length} riders over ${run.stops.length} stops`);

  step = 'driver signs in';
  const drivers = await call('GET', '/drivers?status=approved', { token: office });
  const phone = drivers.find((d) => d.id === run.driverId)?.phone;
  if (!phone) throw new Error('the bus driver has no phone number');
  // One code a minute per phone: if one was just sent (another test), wait for the next.
  let sent = await fetch(`${API}/auth/driver/otp`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ phone }) });
  if (sent.status === 429) {
    log('a code was sent to this driver a moment ago; waiting a minute');
    await sleep(61_000);
    sent = await fetch(`${API}/auth/driver/otp`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ phone }) });
  }
  if (!sent.ok) throw new Error(`POST /auth/driver/otp → ${sent.status} ${await sent.text()}`);
  const { devCode } = await sent.json();
  if (!devCode) throw new Error('no sign-in code returned: the API must run with OTP_DEV_ECHO=true');
  const driver = (await call('POST', '/auth/driver/verify', { body: { phone, code: devCode } })).accessToken;
  log('driver signed in');

  step = 'student signs in';
  const watcher = riders.find((p) => p.studentId?.startsWith('W-')) ?? riders[0];
  const student = (await call('POST', '/auth/student/login', { body: { university: uni.slug, studentId: watcher.studentId, password: STUDENT_PASSWORD } })).accessToken;
  log(`student ${watcher.studentId} signed in`);

  step = 'drive the run';
  // The run is replayed on a realistic clock that ends now: ~30 km/h between stops and a minute at
  // each one, with device timestamps in the past — like a phone uploading what it buffered — so
  // the GPS check sees plausible speeds.
  const act = (type, at, extra = {}) => call('POST', `/runs/${run.id}/actions`, { token: driver, body: { actions: [{ clientId: uuid(), type, at: new Date(at).toISOString(), ...extra }] } });
  const gps = (p, at) => call('POST', `/runs/${run.id}/gps`, { token: driver, body: { points: [{ lat: p.lat, lng: p.lng, at: new Date(at).toISOString(), speed: 8 }] } });
  const detail = await call('GET', `/runs/${run.id}`, { token: driver });
  const stops = detail.stops.map((s) => ({ seq: s.seq, lat: s.point.lat, lng: s.point.lng, passengers: s.passengers }));
  const km = (a, b) => Math.hypot((b.lat - a.lat) * 110.57, (b.lng - a.lng) * 93.9);
  const route = [{ lat: stops[0].lat + 0.01, lng: stops[0].lng - 0.01 }, ...stops, campus];
  const legSeconds = (a, b) => Math.max(60, Math.round((km(a, b) / 30) * 3600));
  const total = route.slice(1).reduce((t, p, i) => t + legSeconds(route[i], p) + 60, 0);
  let t = Date.now() - total * 1000 - 5000;

  await act('start', t);
  let pos = route[0];
  await gps(pos, t);
  let fare = 0;
  let tracked = false;
  const drive = async (to) => {
    const secs = legSeconds(pos, to);
    const n = Math.max(2, Math.ceil(secs / 30));
    for (const [i, p] of leg(pos, to, n).entries()) await gps(p, t + ((i + 1) * secs * 1000) / n);
    t += secs * 1000;
    pos = to;
  };
  for (const s of stops) {
    await drive(s);
    await act('arrive', t, { seq: s.seq });
    const boarding = s.passengers.map((p) => p.requestId);
    if (boarding.length) await act('board', t + 20_000, { requestIds: boarding });
    for (const p of s.passengers.filter((x) => x.fare > 0)) {
      await call('POST', `/runs/${run.id}/fares`, { token: driver, body: { requestId: p.requestId, clientId: uuid() } });
      fare += p.fare;
    }
    t += 60_000;
    await act('depart', t);
    if (!tracked) {
      step = 'student tracks the bus';
      const ride = (await call('GET', '/rides/me', { token: student })).find((r) => r.id === watcher.requestId);
      const track = await call('GET', `/rides/${ride.id}/track`, { token: student });
      if (!track.bus) throw new Error('the student sees no bus position');
      tracked = true;
      log(`student sees the bus at ${track.bus.lat.toFixed(4)}, ${track.bus.lng.toFixed(4)}`);
      step = 'drive the run';
    }
    log(`stop ${s.seq}: ${boarding.length} boarded`);
  }
  await drive(campus);
  const ended = await act('end', t);
  if (ended.run.status !== 'done') throw new Error(`run ended as ${ended.run.status}`);
  log(`run finished (${Math.round(total / 60)} min replayed); cash collected ${fare.toLocaleString('en-US')} IQD`);

  step = 'settlement draft';
  const month = date.slice(0, 7);
  const settlement = await call('POST', `/settlements/${month}/compute`, { token: office, ok: [200, 409] });
  if (settlement?.status === 'approved' || settlement?.statusCode === 409) throw new Error(`${month} is already approved; use a stack where it is not`);
  const { review } = await call('GET', `/settlements/${month}`, { token: office });
  if (review.some((r) => r.id === run.id)) throw new Error(`the run failed the GPS check: ${JSON.stringify(review.find((r) => r.id === run.id).flags)}`);
  const line = settlement.lines.find((l) => l.driverId === run.driverId);
  if (!line || line.runs < 1) throw new Error('the driver has no counted run in the settlement draft');
  if (line.cash < fare) throw new Error(`settlement cash ${line.cash} < collected ${fare}`);
  const sum = settlement.totals;
  if (sum.payout + sum.commission + sum.unallocated + sum.residual !== sum.pool) throw new Error('settlement totals do not balance');
  log(`settlement ${month} draft: driver counted ${line.runs} run(s), cash ${line.cash}, payout ${line.payout}`);
  log('full-day smoke passed');
}

main().catch((e) => {
  console.error(`FAILED at "${step}": ${e.message}`);
  process.exit(1);
});
