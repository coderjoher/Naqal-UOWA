# P5 — Runs, realtime tracking and notifications

Status: planned
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

- NestJS WebSocket gateway (Socket.IO + Redis adapter) replacing Laravel Reverb in the PRD.
  Rooms: `run:{id}` (students on that run only), `ops:{universityId}` (office).
- GPS ingest: driver emits `gps` → `GEOADD` + publish to room; a sampler persists 1 point/min.
- ETA = OSRM matrix remaining legs + live offset from the last point.
- Driver app: drift-backed local queue for GPS + actions with idempotency keys; background location
  service; "Arrived" starts the no-show countdown; cash fare quick entry (tier price prefilled).
- FCM notifications: assigned, approaching (ETA ≤ 5 min), arrived, cancelled.
- Dashboard Live Ops: MapLibre with bus markers, run list with status, waitlist panel.

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

- [ ] All P5 tests green in CI
- [ ] Field test: one real bus, one full morning in Karbala, no lost run, ETA error ≤ 3 min median
- [ ] Battery drain on driver app ≤ 8 %/hour on a mid-range Android device
