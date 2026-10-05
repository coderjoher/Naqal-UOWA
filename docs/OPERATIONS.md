# Running Naql in production

Everything here is about P8: the measures that make the system ready for the pilot. Docker Compose
is the reference deployment; each section says what to set and how to check it.

## 1. Deploy

```bash
cp .env.example .env        # or export the variables below
DEMO=false docker compose up -d --build --wait
docker compose --profile https --profile backup --profile observability up -d
```

| Variable | What |
|----------|------|
| `JWT_SECRET` | Long random string (≥ 32 characters). Never the default. |
| `DEMO=false` | No demo data, real SMS codes (nothing shown on screen). |
| `API_WORKERS` | API processes, one per CPU core (default 2). Workers share sockets through Redis. |
| `DASHBOARD_DOMAIN`, `STUDENT_DOMAIN`, `DRIVER_DOMAIN`, `ACME_EMAIL` | HTTPS with automatic Let's Encrypt certificates (`https` profile, Caddy). |
| `METRICS_TOKEN` | Bearer token required to read `/metrics` (and `:9464/metrics`). |
| `SENTRY_DSN` | API errors to Sentry. The dashboard takes `VITE_SENTRY_DSN` at build time, the apps `--dart-define=SENTRY_DSN=…`. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OpenTelemetry traces (e.g. `http://jaeger:4318` with the `observability` profile). |
| `BACKUP_REMOTE` | rclone destination for off-site copies of the nightly backup (e.g. `s3:naql-backups`). |
| `TRUST_PROXY_HOPS` | Proxies in front of the API (default 1), so rate limits see the real client IP. |

## 2. Security (NF-11, NF-13 — T8-03)

- **Sign-in rate limits** (Redis, shared by all workers): 10 attempts per account per 10 minutes
  (staff email, or university + student number), 300 per IP; driver codes 1 per minute and 5 per
  hour per phone, 10 wrong codes per 10 minutes. Answers are `429` with `Retry-After`.
- **Headers**: the API sends HSTS, `nosniff`, frame and referrer policies (helmet). The dashboard
  adds a strict Content-Security-Policy; the Flutter web apps send the same hardening headers.
- **OWASP ZAP** baseline scans of the dashboard and the API run in CI on every pull request (job
  *Docker Compose stack*); the build fails on any high-risk finding. Reports are in the run's
  artifacts (`zap-reports`).
- Documents stay private (signed links, every access logged); student locations are never sent
  anywhere (only buses broadcast).

## 3. Performance (NF-06, NF-08 — T8-01, T8-02)

The **Load test** workflow (Actions → *Load test* → *Run workflow*) prepares a morning peak and
measures it:

- `scripts/load/morning-peak.js` (k6): every bus posts GPS every 5 s, every student on a bus
  checks their ride and the bus about once a minute, students still asking for seats, the office
  watching dispatch and live operations. Thresholds: errors < 0.5 %, **p95 < 300 ms per endpoint**.
- `apps/api/scripts/load/sockets.ts`: one socket per student on a bus (6 000 at 3×); fails above
  0.5 % connection errors or a ping → student p95 above 3 s.
- After the peak the dispatch queue must drain (no growing backlog).
- `scripts/load/month-end.js`: settlement computed every 30 s and reports read while the buses
  keep running.

Inputs: `scale` (3 = launch gate: 450 buses, 6 000 students), `duration` (30m), `api_url` (empty =
start the API on the runner; set it plus the `STAGING_DATABASE_URL` / `STAGING_JWT_SECRET` secrets
to test staging), `workers`. It also runs weekly, and for one minute at 0.2× on pull requests that
change the load scripts.

> On a shared 4-core runner the load generators (k6 and 6 000 sockets) take about half the CPU, so
> the 3× latency gate must be judged on staging or a larger runner (`LOAD_RUNNER` repository
> variable). Locally on 4 cores: 0 errors and all 6 000 sockets stable at 3×; p95 within 300 ms up
> to the expected peak (1×).

What makes it fast enough: one process per core (`API_WORKERS`), verified tokens and user status
cached for 10 s, the dispatch board and live operations served from a 5-second
stale-while-revalidate cache (the office's own changes show immediately), one stored GPS point per
minute, and photo links reused instead of re-issued on every refresh.

## 4. Monitoring

`docker compose --profile observability up -d` starts:

- **Prometheus** (`:9090`) scraping `api:9464` — request rate and p95 per route, 5xx rate, dispatch
  queue depth, sockets, event-loop lag, memory, CPU. Alerts in `infra/observability/alerts.yml`:
  p95 > 300 ms for 10 min, errors > 0.5 %, dispatch backlog, API down.
- **Grafana** (`:3001`) with the *Naql API* dashboard already loaded.
- **Jaeger** (`:16686`) for traces when `OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318`.
- **Sentry** for the API, dashboard and apps when the DSNs are set.

## 5. Backups

`docker compose --profile backup up -d backup` takes a compressed `pg_dump` every night at 03:00
Baghdad time into `./backups` (14 days kept, optionally copied off-site with rclone), and checks
each file is a readable archive.

**Weekly restore drill** (exit gate: under 1 hour):

```bash
docker compose --profile backup run --rm backup restore-drill
```

It restores the newest backup into a scratch database, checks row counts, the immutability
triggers and the migration history, prints the payments total and the time taken, then drops the
scratch database. CI runs a backup + restore drill on every pull request.

## 6. Full-day smoke (T8-04)

```bash
API=https://office.naql.example/api node scripts/smoke/full-day.mjs
```

Against a stack with demo data (CI runs it on the compose stack): office plans a wave → the driver
signs in and drives the run with GPS (a realistic 30–40 minutes replayed with device timestamps) →
a student sees the bus → the driver records a cash fare → the month's settlement draft counts the
run as GPS-verified and includes the cash.

## 7. Releases

Push a tag `v1.2.3` (or run *Release* by hand):

- **Google Play internal track** — both apps as signed app bundles. Secrets:
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
  `PLAY_SERVICE_ACCOUNT_JSON`, `API_URL`.
- **TestFlight** — the student app. Secrets: `IOS_P12_BASE64`, `IOS_P12_PASSWORD`,
  `IOS_PROVISIONING_PROFILE_BASE64`, `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`
  (and the Apple team set in the Xcode project).

Jobs whose secrets are missing are skipped with a notice. The dashboard is served over HTTPS by the
`https` profile.
