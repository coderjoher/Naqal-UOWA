# Requirements catalogue

Source: *Naql Jamiat Warith — PRD v1.0 (4 Oct 2026)*. Every row below has a stable ID.
`scripts/check-phases.mjs` reads this table and fails CI if any ID is not scoped to exactly
one phase in `docs/phases/`, or is not covered by at least one test in that phase.

Priority: **M** = must have for v1, **S** = should have, **C** = could have.

## Foundation (engineering, not in the PRD)

| ID | Requirement | Pri. |
|----|-------------|------|
| FD-01 | Monorepo with `apps/api` (NestJS), `apps/dashboard` (React), `apps/student_app` and `apps/driver_app` (Flutter), shared packages | M |
| FD-02 | CI runs lint, type-check and every test suite on each push; a red suite blocks merge | M |
| FD-03 | Shared design tokens (one JSON source) generate CSS variables and Dart constants | M |
| FD-04 | Flutter UI kit `naql_ui` with custom components (no stock Material look) and golden tests | M |
| FD-05 | Dashboard UI kit built on headless primitives + tokens, with component tests | M |
| FD-06 | Local stack via Docker Compose: PostgreSQL, Redis, OSRM, API, dashboard | M |

## 3. Service model

| ID | Requirement | Pri. |
|----|-------------|------|
| SM-01 | Pickup only at fixed gathering points (no door-to-door) | M |
| SM-02 | Gender separation is mandatory: female students only on female-only buses; never mixed | M |
| SM-03 | Subscribers have priority over pay-per-ride students | M |
| SM-04 | No-show: driver waits a fixed, configurable time at a point, then continues; no penalty | M |

## 4. Pricing, payment and settlement

| ID | Requirement | Pri. |
|----|-------------|------|
| PA-01 | Prices by distance tier; each gathering point belongs to exactly one tier | M |
| PA-02 | Monthly subscription priced by the tier of the student's registered point; boarding at a farther tier costs the difference | M |
| PA-03 | Pay-per-ride priced by tier, paid in cash to the driver | M |
| PA-04 | Payment model is provider-agnostic so ZainCash / Qi can be added later without schema changes | S |
| SE-01 | Settlement formula: `payout = Pool_tier × (1 − c) × runs_driver/runs_tier − c × cash_fares_driver` | M |
| SE-02 | Only GPS-verified runs count (started, passed stops, ended on campus / last stop) | M |

## 5.1 Student app

| ID | Requirement | Pri. |
|----|-------------|------|
| ST-01 | Sign in with university credentials; verified against the university student system | M |
| ST-02 | Profile: gender (from university record), phone, default gathering point | M |
| ST-03 | View subscription status, tier, price, expiry; instructions to pay at the office | M |
| ST-04 | Request today's ride: choose wave and gathering point | M |
| ST-05 | See assignment: bus, driver name, plate, vehicle photo, pickup time | M |
| ST-06 | Live bus tracking on a map with ETA to the gathering point | M |
| ST-07 | Waitlist status with remaining time; notified on seat or cancellation | M |
| ST-08 | Cancel a request before pickup | M |
| ST-09 | Push notifications: assigned, bus approaching, bus arrived, cancelled | M |
| ST-10 | Ride history and payment history | S |
| ST-11 | Rate the ride and report a problem | S |
| ST-12 | Arabic (RTL) by default; English optional | M |

## 5.2 Driver app

| ID | Requirement | Pri. |
|----|-------------|------|
| DR-01 | Registration: personal details, licence, vehicle details, documents required by the office | M |
| DR-02 | Set availability for the coming days (which waves) | M |
| DR-03 | Receive today's runs: ordered stops, passenger list per stop, departure time | M |
| DR-04 | Start run / arrive at stop / end run | M |
| DR-05 | Stream GPS every ~5 s during a run; buffer offline and upload on reconnect | M |
| DR-06 | Turn-by-turn navigation via external maps app | S |
| DR-07 | Record a cash fare from a pay-per-ride student | M |
| DR-08 | Run count and estimated earnings for the month; past settlements | M |
| DR-09 | Live update when a new student is added to the run before it passes their point | M |

## 5.3 Transport office dashboard

| ID | Requirement | Pri. |
|----|-------------|------|
| TO-01 | Define driver requirements (documents, vehicle type, vehicle age) | M |
| TO-02 | Review, approve, suspend or reject drivers and vehicles | M |
| TO-03 | Manage gathering points on a map; assign each to a tier | M |
| TO-04 | Manage distance tiers and prices | M |
| TO-05 | Manage morning waves and return times per weekday | M |
| TO-06 | Record cash subscription payments, issue receipts, activate subscriptions | M |
| TO-07 | Live operations: all buses on a map, run status, waitlists | M |
| TO-08 | Manual override: move a student between buses, add an extra run | S |
| TO-09 | Monthly settlement: compute, review, approve, export PDF/Excel | M |
| TO-10 | Reports: subscribers, fulfilment, on-time rate, revenue per tier | S |
| TO-11 | Announcements to students | S |

## 5.4 Super admin dashboard

| ID | Requirement | Pri. |
|----|-------------|------|
| SA-01 | Onboard a university: name, campus location, integration settings, office accounts | M |
| SA-02 | Commission percentage per university | M |
| SA-03 | Waitlist duration per university | M |
| SA-04 | Cross-university revenue, commission and usage dashboard | M |
| SA-05 | Audit log of settings changes and settlement approvals | S |

## 6. Dispatch

| ID | Requirement | Pri. |
|----|-------------|------|
| DS-01 | Travel times between all points and campus precomputed with self-hosted OSRM; refreshed when points change | M |
| DS-02 | Wave planning job groups open requests by gender and tier and builds runs that fit capacity and arrive before wave time | M |
| DS-03 | Same-day insertion: cheapest insertion into a run with a free seat that has not passed the point; subscribers first | M |
| DS-04 | Waitlist for the configured duration; re-check on cancellation / new run; on expiry notify and cancel | M |
| DS-05 | Hard constraints: no gender mixing, no capacity overflow, no run that misses the wave time | M |
| DS-06 | Each run tagged with the tier of its farthest stop; keep runs within one tier where possible | M |

## 7. Non-functional

| ID | Requirement | Pri. |
|----|-------------|------|
| NF-01 | GPS points go to Redis GEO + WebSocket; only 1 point/min/run persisted | M |
| NF-02 | Each student subscribes only to their own bus channel | M |
| NF-03 | Heavy work (planning, notifications, settlement, reports) runs in background queues | M |
| NF-04 | Rarely changing data (points, tiers, schedules) cached in Redis | M |
| NF-05 | Every tenant table carries `university_id`; queries are always tenant-scoped | M |
| NF-06 | API p95 < 300 ms | M |
| NF-07 | Bus location visible to students within 3 s | M |
| NF-08 | k6 load test at 3× the expected morning peak passes before launch | M |
| NF-09 | Driver app buffers GPS and actions offline; no verified run is lost | M |
| NF-10 | Student app shows last known bus position with timestamp when offline | M |
| NF-11 | Role-based access; office users scoped to their university | M |
| NF-12 | Student location is never shared; only bus location is broadcast | M |
| NF-13 | Driver documents stored privately; every access logged | M |
| NF-14 | Money records (payments, cash fares, settlements) are immutable with audit trail | M |
| NF-15 | GPS anomaly detection (speed, path, stop arrival) flags suspicious runs for the office | S |
| NF-16 | Map tiles come from a configurable provider (one setting per app); the dashboard CSP allows only that host | M |
| NF-17 | Every input and action in the apps is reachable by screen readers (TalkBack / VoiceOver) | S |
