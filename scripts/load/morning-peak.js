// k6: the morning peak (NF-08 / NF-06). Run against a stack prepared by
// apps/api/scripts/load/prepare.ts, together with apps/api/scripts/load/sockets.ts for the
// student sockets.
//
//   k6 run -e DATA=/tmp/load.json -e API=http://localhost:3000 -e DURATION=30m scripts/load/morning-peak.js
//
// [T8-01] At 3× the peak (SCALE=3 data: 450 buses, 6 000 students) for 30 minutes the error rate
//         stays under 0.5 % — and, checked by the workflow afterwards, the dispatch queue does not
//         keep growing after the peak.
// [T8-02] Every REST endpoint keeps p95 < 300 ms under that load (one threshold per endpoint).
import http from 'k6/http';
import exec from 'k6/execution';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';

const data = JSON.parse(open(__ENV.DATA));
const API = (__ENV.API || 'http://localhost:3000').replace(/\/$/, '');
const DURATION = __ENV.DURATION || '30m';
const seconds = (d) => Number(d.replace(/[a-z]+$/, '')) * ({ s: 1, m: 60, h: 3600 }[d.match(/[a-z]+$/)[0]] || 1);
const SECONDS = seconds(DURATION);

const drivers = new SharedArray('drivers', () => data.drivers);
const riders = new SharedArray('riders', () => data.riders);
const fresh = new SharedArray('fresh', () => data.fresh);

const ENDPOINTS = [
  'POST /runs/:id/gps',
  'GET /rides/me',
  'GET /rides/:id/track',
  'GET /notifications/me',
  'GET /subscriptions/me',
  'GET /rides/options',
  'POST /rides',
  'GET /dispatch',
  'GET /live/runs',
];

const rate = (perSecond) => Math.max(1, Math.round(perSecond));
const vus = (perSecond) => Math.max(5, Math.ceil(perSecond * 0.5));

export const options = {
  discardResponseBodies: false,
  scenarios: {
    // Every bus sends a GPS point every 5 s.
    gps: { executor: 'constant-arrival-rate', exec: 'gps', rate: rate(drivers.length / 5), timeUnit: '1s', duration: DURATION, preAllocatedVUs: vus(drivers.length / 5), maxVUs: vus(drivers.length / 5) * 4 },
    // Students on a bus check their ride, the bus and their notifications about once a minute.
    riders: { executor: 'constant-arrival-rate', exec: 'rider', rate: rate(riders.length / 60), timeUnit: '1s', duration: DURATION, preAllocatedVUs: vus(riders.length / 60) * 2, maxVUs: vus(riders.length / 60) * 8 },
    // Students still asking for a seat (each once), spread over the test.
    requests: { executor: 'constant-arrival-rate', exec: 'request', rate: Math.max(1, Math.ceil(fresh.length / SECONDS)), timeUnit: '1s', duration: DURATION, preAllocatedVUs: 5, maxVUs: 40 },
    // The transport office watches dispatch and live operations.
    office: { executor: 'constant-vus', exec: 'office', vus: Math.max(2, Math.round(3 * data.scale)), duration: DURATION },
  },
  thresholds: {
    http_req_failed: ['rate<0.005'],
    checks: ['rate>0.995'],
    ...Object.fromEntries(ENDPOINTS.map((e) => [`http_req_duration{name:${e}}`, ['p(95)<300']])),
  },
};

const auth = (token) => ({ headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' } });
const named = (token, name) => ({ ...auth(token), tags: { name } });

export function gps() {
  const d = drivers[exec.scenario.iterationInTest % drivers.length];
  const [lat, lng] = d.stops[Math.floor(Date.now() / 60000) % d.stops.length];
  // A few hundred metres from the next stop: realistic, and no "bus is here" storms.
  const p = { lat: lat + 0.004 + Math.random() * 0.002, lng: lng + 0.004, at: new Date().toISOString(), speed: 8 };
  const r = http.post(`${API}/runs/${d.runId}/gps`, JSON.stringify({ points: [p] }), named(d.token, 'POST /runs/:id/gps'));
  check(r, { 'gps accepted': (x) => x.status === 200 });
}

export function rider() {
  const s = riders[exec.scenario.iterationInTest % riders.length];
  const mine = http.get(`${API}/rides/me`, named(s.token, 'GET /rides/me'));
  check(mine, { 'rides listed': (x) => x.status === 200 });
  const ride = mine.status === 200 ? (mine.json() || [])[0] : null;
  if (ride) check(http.get(`${API}/rides/${ride.id}/track`, named(s.token, 'GET /rides/:id/track')), { 'tracking': (x) => x.status === 200 });
  if (exec.scenario.iterationInTest % 3 === 0) check(http.get(`${API}/notifications/me`, named(s.token, 'GET /notifications/me')), { 'notifications': (x) => x.status === 200 });
  if (exec.scenario.iterationInTest % 5 === 0) check(http.get(`${API}/subscriptions/me`, named(s.token, 'GET /subscriptions/me')), { 'subscription': (x) => x.status === 200 });
}

export function request() {
  const i = exec.scenario.iterationInTest;
  const s = fresh[i % fresh.length];
  check(http.get(`${API}/rides/options`, named(s.token, 'GET /rides/options')), { 'options': (x) => x.status === 200 });
  // Each student asks once; after everyone has, the scenario keeps loading the options screen.
  if (i < fresh.length) {
    const r = http.post(`${API}/rides`, JSON.stringify({ waveId: data.laterWaveId, date: data.date }), named(s.token, 'POST /rides'));
    check(r, { 'ride requested': (x) => x.status === 201 });
  }
}

export function office() {
  check(http.get(`${API}/dispatch?date=${data.date}`, named(data.office, 'GET /dispatch')), { 'dispatch board': (x) => x.status === 200 });
  check(http.get(`${API}/live/runs?date=${data.date}`, named(data.office, 'GET /live/runs')), { 'live runs': (x) => x.status === 200 });
  // The pages refresh every 5 s.
  sleep(5);
}
