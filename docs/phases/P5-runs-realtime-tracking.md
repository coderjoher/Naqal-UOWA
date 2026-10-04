# P5 — Runs, realtime tracking and notifications

Status: in-progress
Depends on: P4

## Goal

Drivers run their routes with GPS streaming. Students see their own bus live with an ETA, and the
office sees every bus. This must work on weak Iraqi mobile networks.

## Scope

- DR-04 Start run / arrive at stop / end run
- DR-05 GPS every ~5 s with offline buffer
- DR-06 Hand-off to external maps app
- DR-07 Record cash fare
- DR-09 Live passenger additions
- ST-06 Live bus on map with ETA
- ST-09 Push notifications
- TO-07 Live operations view
- SM-04 Fixed no-show wait time
- PA-03 Pay-per-ride priced by tier, cash to driver
- NF-01 Redis GEO + WebSocket; persist 1 point/min/run
- NF-02 Per-bus channel subscriptions
- NF-07 Location visible within 3 s
- NF-09 Driver offline buffering
- NF-10 Last known position with timestamp
- NF-12 Student location never shared

## Deliverables

- **Realtime:** NestJS Socket.IO gateway at `/live` (replaces Laravel Reverb), with the Redis adapter so every API
  instance reaches every socket. Rooms: `run:{id}` (a student may join only the run they ride on,
  NF-02), `ops:{universityId}` (office), `driver:{id}`, `user:{id}`. Broadcasts carry only the bus:
  `runId, lat, lng, at, speed, heading, etas` (NF-12).
- **GPS ingest** (`LiveService`): socket `gps` or `POST /runs/:id/gps` (batches after an offline gap).
  - Redis `GEOADD` + last point + broadcast.
  - One stored row per run per minute through a Redis `SET NX` bucket, also for late points (NF-01).
  - Older points never move the bus backwards.
  - Measured (T5-06): 150 buses × 5 s, 2 000 sockets, p95 10 ms.
- **ETA:** the live leg is straight line × 1.3 at 30 km/h; later legs come from the OSRM matrix, plus dwell.
- **Run state machine** (pure `run-rules.ts`): `planned → started → at_stop → started … → done`.
  - Actions arrive via `POST /runs/:id/actions`, each with a client id, applied once (`run_events`) under the wave lock shared with dispatch.
  - Return runs board on campus before leaving.
- **SM-04:** `universities.no_show_wait_minutes` (default 3). Leaving a stop before the wait while riders are missing is refused (409 with `waitLeftS`); after it, missing riders become `no_show` with no penalty.
- **DR-07 / PA-03:** `POST /runs/:id/fares` writes an immutable `cash_fare` / `cash_driver` payment at the ride's fare (tier price, or the tier difference for subscribers).
  - It is linked to the run, the ride and the driver.
  - It is idempotent: there is one fare per ride, and the client key is unique.
- **DR-09:** any dispatch change emits `run:updated` to the driver, the run room and the office.
- **ST-09 notifications:**
  - Pure rules with stable dedupe keys (`assigned:<ride>:<run>`, `approaching:<ride>`, `arrived:<ride>`, `cancelled:<ride>`), stored once (unique key).
  - After commit, each is delivered over the socket and by FCM HTTP v1 (`FCM_SERVICE_ACCOUNT`; without it, push is logged).
  - Apps register with `POST /devices`. The list is `GET /notifications/me`, and `POST /notifications/read` marks it read.
- **Driver app:**
  - Offline-first `SyncQueue` (naql_core) persisted in preferences: GPS, actions and fares in order, batched, with idempotent retries (NF-09).
  - geolocator foreground service every 5 s.
  - One big action per state: start, I'm at the stop, board riders, collect cash, wait countdown, leave, finish.
  - Navigation hand-off to Google Maps or Waze (DR-06), live refresh on `run:updated`, and a "waiting to send" indicator.
- **Student app:**
  - Track screen (flutter_map, CARTO light tiles) showing the bus gliding, the student's stop, and the ETA ("arrives in 4 min", "the bus is at your stop", "you are on the bus").
  - Last known position with "updated X ago" when the connection drops (NF-10).
  - Notifications tab.
- **Dashboard:** Live operations page (TO-07) with MapLibre bus markers updated live, run list with status, progress and boarded count, waitlist, and connection state.
- **Demo:** `pnpm simulate` (or `docker compose exec api npx ts-node scripts/simulate.ts`) drives today's dispatched runs through the API, so the live views can be tried without a bus.

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T5-01 | e2e | DR-04 | Run state machine scheduled → started → at_stop → … → ended; illegal transitions rejected |
| T5-02 | unit | SM-04 | No-show timer uses the configured wait and marks passenger `no_show` without penalty |
| T5-03 | flutter-int | DR-05, NF-09 | Airplane mode for 10 min during a run: all GPS points and actions sync on reconnect with no duplicates |
| T5-04 | integration | NF-01 | 1 000 pings for one run produce Redis GEO updates and ≈ 1 persisted row per minute |
| T5-05 | integration | NF-02, NF-12 | A student socket can join only its own run room; no event payload ever contains student coordinates |
| T5-06 | integration | NF-07 | Ping → student socket receive latency p95 < 3 s with 150 buses × 5 s and 2 000 sockets (k6 ws) |
| T5-07 | widget | ST-06, NF-10 | Map shows bus + ETA; when the socket drops shows last known position with "updated X ago" |
| T5-08 | unit | ST-09 | Notification rules fire exactly once per event (assigned, approaching, arrived, cancelled) |
| T5-09 | e2e | DR-07, PA-03 | Cash fare uses tier price, creates immutable payment linked to run + driver; idempotent on retry |
| T5-10 | integration | DR-09 | Inserting a request into an active run pushes an updated stop list to the driver within 3 s |
| T5-11 | widget | DR-06 | "Navigate" opens Google Maps / Waze intent with next stop coordinates |
| T5-12 | playwright | TO-07 | Live Ops map shows simulated buses moving and run statuses updating |

## Exit gate

- [x] All P5 tests green in CI (PR #7)
- [ ] Field test: one real bus, one full morning in Karbala, no lost run, ETA error ≤ 3 min median
- [ ] Battery drain on driver app ≤ 8 %/hour on a mid-range Android device
