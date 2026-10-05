// k6: month end (NF-08). While students and buses keep the API busy, the office computes the
// settlement draft, reviews it and reads the reports — the heaviest office work of the month.
//
//   k6 run -e DATA=/tmp/load.json -e API=http://localhost:3000 -e DURATION=10m scripts/load/month-end.js
//
// REST reads keep p95 < 300 ms (NF-06); the settlement computation is a batch job with its own
// budget (p95 < 10 s), and nothing may fail.
import http from 'k6/http';
import exec from 'k6/execution';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';

const data = JSON.parse(open(__ENV.DATA));
const API = (__ENV.API || 'http://localhost:3000').replace(/\/$/, '');
const DURATION = __ENV.DURATION || '10m';
const riders = new SharedArray('riders', () => data.riders);
const drivers = new SharedArray('drivers', () => data.drivers);

export const options = {
  scenarios: {
    background_gps: { executor: 'constant-arrival-rate', exec: 'gps', rate: Math.max(1, Math.round(drivers.length / 5)), timeUnit: '1s', duration: DURATION, preAllocatedVUs: 20, maxVUs: 200 },
    background_riders: { executor: 'constant-arrival-rate', exec: 'rider', rate: Math.max(1, Math.round(riders.length / 120)), timeUnit: '1s', duration: DURATION, preAllocatedVUs: 20, maxVUs: 200 },
    settlement: { executor: 'constant-vus', exec: 'settle', vus: 1, duration: DURATION },
    office_reads: { executor: 'constant-vus', exec: 'officeReads', vus: 3, duration: DURATION },
  },
  thresholds: {
    http_req_failed: ['rate<0.005'],
    checks: ['rate>0.995'],
    'http_req_duration{name:POST /settlements/:month/compute}': ['p(95)<10000'],
    'http_req_duration{name:GET /settlements/:month}': ['p(95)<300'],
    'http_req_duration{name:GET /reports}': ['p(95)<300'],
    'http_req_duration{name:GET /audit}': ['p(95)<300'],
    'http_req_duration{name:POST /runs/:id/gps}': ['p(95)<300'],
    'http_req_duration{name:GET /rides/me}': ['p(95)<300'],
  },
};

const named = (token, name) => ({ headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, tags: { name } });

export function gps() {
  const d = drivers[exec.scenario.iterationInTest % drivers.length];
  const [lat, lng] = d.stops[0];
  const r = http.post(`${API}/runs/${d.runId}/gps`, JSON.stringify({ points: [{ lat: lat + 0.005, lng, at: new Date().toISOString() }] }), named(d.token, 'POST /runs/:id/gps'));
  check(r, { 'gps accepted': (x) => x.status === 200 });
}

export function rider() {
  const s = riders[exec.scenario.iterationInTest % riders.length];
  check(http.get(`${API}/rides/me`, named(s.token, 'GET /rides/me')), { 'rides listed': (x) => x.status === 200 });
}

// The office recomputes the draft every 30 s while reviewing (before approval it may change).
export function settle() {
  const r = http.post(`${API}/settlements/${data.month}/compute`, null, { ...named(data.office, 'POST /settlements/:month/compute'), timeout: '60s' });
  check(r, { 'settlement computed': (x) => x.status === 200 && x.json('totals.pool') >= 0 });
  sleep(30);
}

export function officeReads() {
  check(http.get(`${API}/settlements/${data.month}`, named(data.office, 'GET /settlements/:month')), { 'settlement read': (x) => x.status === 200 });
  check(http.get(`${API}/reports?month=${data.month}`, named(data.office, 'GET /reports')), { 'report read': (x) => x.status === 200 });
  check(http.get(`${API}/audit`, named(data.office, 'GET /audit')), { 'audit read': (x) => x.status === 200 });
  sleep(5);
}
