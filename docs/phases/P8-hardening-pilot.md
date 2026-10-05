# P8 — Hardening and pilot readiness

Status: in-progress
Depends on: P6 (P7 optional)

## Goal

Prove the performance targets, run security and release checks, then start the PRD's rollout
phase 0 (pilot).

## Scope

- NF-06 API p95 < 300 ms
- NF-08 k6 load test at 3× morning peak

## Deliverables

- k6 scenarios: morning peak (requests + GPS + 6 000 sockets = 3 × 2 000), settlement month-end.
- Observability: OpenTelemetry traces, Prometheus metrics, Grafana dashboard, Sentry for all apps.
- Backups: nightly PostgreSQL dump + weekly restore drill.
- Release: Play Store internal track (both apps), TestFlight (student), dashboard behind HTTPS.

## Built

See [docs/OPERATIONS.md](../OPERATIONS.md) for how to run each piece.

- Load: `scripts/load/morning-peak.js` and `month-end.js` (k6), `apps/api/scripts/load/prepare.ts`
  (peak data and tokens), `apps/api/scripts/load/sockets.ts` (6 000 student sockets); workflow
  `.github/workflows/load.yml` (manual / weekly / PR self-check, staging target supported).
- Performance: API cluster mode (`API_WORKERS`), token and user-status caches, stale-while-
  revalidate cache for the dispatch board and live operations, photo-link reuse.
- Security: Redis rate limits on every sign-in endpoint, helmet headers on the API, CSP and
  hardening headers on the web apps, ZAP baseline in CI.
- Observability: Prometheus metrics (aggregated across workers on `:9464`), alert rules, Grafana
  dashboard, OpenTelemetry tracing (Jaeger), Sentry for API, dashboard and apps — all opt-in.
- Backups: nightly `pg_dump` service with retention and off-site copy, restore drill script (run in
  CI on every pull request).
- Release: Play internal track (both apps) and TestFlight (student app) workflow; HTTPS with Caddy.
- Full-day smoke script run against the compose stack in CI.

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T8-01 | load | NF-08 | k6 at 3× peak for 30 min: error rate < 0.5 %, no queue backlog growing after the peak |
| T8-02 | load | NF-06 | p95 < 300 ms on every REST endpoint under T8-01 load |
| T8-03 | security | NF-11, NF-13 | OWASP ZAP baseline on API and dashboard: no high findings; rate limits on auth endpoints |
| T8-04 | e2e | NF-08 | Full-day smoke script on staging (plan wave → runs → tracking → cash fare → settlement draft) |

## Exit gate

- [ ] All P8 tests green
- [ ] Restore drill completed in < 1 h
- [ ] Every earlier phase's exit gate is checked
- [ ] Pilot (PRD §10 phase 0) starts; exit criterion: one full month's settlement matches office records
