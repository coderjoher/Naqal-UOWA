# P4 — Ride requests and dispatch

Status: in-progress
Depends on: P3

## Goal

Students request a ride for today, the dispatcher puts them on a bus or a waitlist, and
drivers see their runs, while the hard constraints always hold.

## Scope

- ST-04 Request today's ride (wave + point)
- ST-05 See assignment (bus, driver, plate, photo, pickup time)
- ST-07 Waitlist status with remaining time
- ST-08 Cancel before pickup
- DR-02 Driver availability for coming days
- DR-03 Today's runs with ordered stops and passengers
- DS-02 Wave planning job
- DS-03 Cheapest insertion for same-day requests, subscribers first
- DS-04 Waitlist with re-check and expiry
- DS-05 Hard constraints
- DS-06 Run tier = farthest stop tier; keep runs single-tier where possible
- SM-02 Gender separation
- SM-03 Subscriber priority
- NF-03 Heavy work in background queues

## Deliverables

- `apps/api/src/dispatch/domain/` — **pure TypeScript** (no Nest/Prisma imports): `planWave()`,
  `insertRequest()` (cheapest insertion, subscriber bumping), `cancelRequest()`,
  `recheckWaitlist()`. Times are seconds after Baghdad midnight; travel times come from the P1
  OSRM matrix (straight line × 1.3 at 30 km/h when a pair is missing).
- Rules: morning runs are timed backwards to arrive 10 min before the wave; a ride lasts at most
  45 min; a bus never goes back to a stop it has passed; return runs take riders only before
  leaving campus; served stops are frozen; boarded riders are never moved or bumped.
- `DispatchEngine` loads one wave/date, runs the domain and writes runs, stops and requests in one
  transaction under a PostgreSQL advisory lock per wave and date.
- BullMQ queue `dispatch`: `wave.tick` every minute queues `wave.plan` at T − 60 min;
  `waitlist.recheck` after every new request (once planned) and every cancellation;
  `waitlist.expire` as a delayed job per waitlisted request. The request path only writes the
  request (T4-07: < 100 ms).
- Request states `open → assigned | waitlisted → cancelled | done`; one live request per student,
  wave and date (partial unique index). Fare per ride: 0 for subscribers in their tier, the tier
  difference when boarding farther, the ride price for pay-per-ride (PA-02, PA-03).
- Q3 default: a run counts toward its farthest-stop tier (DS-06), stored on the run.
- Outbox table `notifications` (`ride.assigned`, `ride.waitlisted`, `ride.bumped`,
  `ride.expired`); push delivery comes in P5.
- API: `GET /rides/options`, `POST /rides`, `GET /rides/me`, `POST /rides/:id/cancel`,
  `GET|PUT /drivers/me/availability`, `GET /drivers/me/runs?date=`, `GET /dispatch?date=`,
  `POST /dispatch/plan`.
- Vehicle photo (`vehicle_photo`) is now a default required driver document; students get a
  short-lived, logged link to it (ST-05, NF-13).
- Student app: request sheet (wave chips for today/tomorrow, point picker), assignment card
  (pickup time, bus, driver, plate, photo, stop n of m, cash to pay), waitlist countdown, pending
  card, cancel with confirmation. Polls every 5 s while waiting.
- Driver app: Today (runs with departure, stops, seats, cash), Run detail (timeline of stops,
  riders per stop, 56 dp rows), Schedule tab (next 7 days, one toggle per wave, locked once planned).
- Dashboard: Dispatch page (today/tomorrow, counts per wave, dispatch now / re-check, buses with
  ordered stops and load, waitlist). Full-stack Playwright test drives it through the worker.
- Nightly workflow runs T4-01 with 100 000 cases and a fresh seed.

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T4-01 | unit | DS-05, SM-02 | Property test (fast-check, 10 000 random scenarios): no run ever has mixed gender, overflows capacity or arrives after wave time |
| T4-02 | unit | DS-02 | `planWave` groups by gender and tier and uses the fewest runs for fixture cities (golden JSON fixtures) |
| T4-03 | unit | DS-03 | Insertion picks the smallest detour among runs with a free seat that have not passed the point |
| T4-04 | unit | DS-03, SM-03 | When one seat remains and a subscriber and pay-per-ride student compete, the subscriber gets it, and a pay-per-ride waitlister is bumped before a subscriber |
| T4-05 | unit | DS-04 | Waitlisted request is assigned on a cancellation; expires exactly at configured minutes with notification event |
| T4-06 | unit | DS-06 | Run tier = tier of farthest stop; single-tier solution preferred when cost difference ≤ threshold |
| T4-07 | integration | NF-03 | `wave.plan`, `waitlist.recheck`, `waitlist.expire` run in BullMQ workers; API request path returns < 100 ms without waiting for planning |
| T4-08 | e2e | ST-04, ST-08 | Request → assigned → cancel before pickup frees the seat; cancel after pickup rejected |
| T4-09 | e2e | DR-02, DR-03 | Driver availability drives which drivers get runs; driver gets ordered stops with passenger list |
| T4-10 | widget | ST-05, ST-07 | Assignment card shows bus, driver, plate, photo, pickup time; waitlist card counts down and updates |
| T4-11 | flutter-int | ST-04, ST-05 | Student requests a ride against a seeded API and sees the assignment |
| T4-12 | widget | DR-03 | Driver run screen lists stops in order with passenger counts, large touch targets (≥ 56 dp) |

## Exit gate

- [ ] All P4 tests green in CI
- [ ] Property test T4-01 runs with a fixed seed in CI and 100 000 cases nightly
- [ ] Simulation of one real morning (seed data: 500 requests, 30 buses) assigns ≥ 95 % with zero constraint violations
- [ ] Q3 answered or default rule accepted in writing by the office
