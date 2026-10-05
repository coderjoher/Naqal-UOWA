# Naql Jamiat Warith — University Student Bus Platform

Shared bus platform for Warith Al-Anbiyaa University (Karbala), multi-tenant from day one.

## Stack

The PRD (§8) proposes Laravel. This project uses the following instead:

| Part | Technology | Replaces (PRD) |
|------|------------|----------------|
| API | **NestJS** (TypeScript), Prisma, PostgreSQL 16 + PostGIS | Laravel |
| Realtime | NestJS WebSocket gateway (Socket.IO + Redis adapter) | Laravel Reverb |
| Queues | BullMQ on Redis | Horizon |
| Dashboard | **React** + Vite + TypeScript, TanStack, Radix, Tailwind, MapLibre | Laravel dashboards |
| Mobile | **Flutter** — `student_app` (Android/iOS), `driver_app` (Android), custom `naql_ui` kit | same |
| Routing | Self-hosted OSRM | same |
| Push | Firebase Cloud Messaging | same |

```
apps/
  api/            NestJS
  dashboard/      React (office + super admin)
  student_app/    Flutter
  driver_app/     Flutter
packages/
  design-tokens/  tokens.json → CSS vars + Dart
  naql_ui/        Flutter UI kit
  naql_core/      Flutter API client + auth
docs/
  requirements.md   every PRD requirement with an ID
  phases/P0…P9      scope, tests, exit gate per phase
  design-system.md  visual language
  DEPLOY-ORACLE.md  free test server (Oracle Cloud ARM)
```

## Getting started

**Just want to try it?** Follow [docs/TESTING.md](docs/TESTING.md): one `docker compose` command
starts the dashboard (:8080), the student app (:8081) and the driver app (:8082) with demo data.

**Want it online for free?** [docs/DEPLOY-ORACLE.md](docs/DEPLOY-ORACLE.md) puts the whole system on
an Oracle Cloud *Always Free* ARM server with HTTPS, step by step.

Requirements: Node 22 + pnpm 10, Flutter 3.47, Docker (or local PostgreSQL 16 and Redis 7).

```bash
pnpm install
flutter pub get                       # resolves the Dart workspace (naql_ui, naql_core, both apps)

# Everything in containers (first start prepares the OSRM map and builds the Flutter apps):
docker compose up -d --build --wait   # dashboard :8080 · student app :8081 · driver app :8082 · API docs :3000/docs

# Or run the API and dashboard locally against your own PostgreSQL + Redis:
cd apps/api && cp .env.example .env && pnpm db:migrate && pnpm db:demo && pnpm start:dev
cd apps/dashboard && pnpm dev         # http://localhost:5173 (proxies /api to :3000)
cd apps/student_app && flutter run
```

Demo accounts are listed in [docs/TESTING.md](docs/TESTING.md#2-demo-accounts)
(`pnpm db:demo`; the minimal `pnpm db:seed` only creates `admin@naql.app` / `office@uowa.edu.iq`, password `password123`).

### Tests

| Where | Command | What |
|-------|---------|------|
| `apps/api` | `pnpm test:unit` / `pnpm test:cov` | Unit tests, coverage gate on auth + tenancy |
| `apps/api` | `pnpm test:int` | Integration + e2e on real PostgreSQL/Redis (`.env.test`) |
| `apps/dashboard` | `pnpm test` / `pnpm test:e2e` | Vitest components, Playwright browser tests |
| `packages/naql_ui` | `flutter test` | Golden (LTR + RTL) and widget tests |
| `apps/*_app`, `packages/naql_core` | `flutter test` | App smoke tests, API client tests |
| repo root | `pnpm check:phases` | Requirements ↔ phases ↔ tests traceability |

Design tokens live in `packages/design-tokens/tokens.json`; after editing run `pnpm tokens` and,
if colours changed, `flutter test --update-goldens` in `packages/naql_ui`.

## Running in production

Deployment, security, load tests, monitoring, backups and releases: [docs/OPERATIONS.md](docs/OPERATIONS.md).

## Phases

| Phase | Name | Main requirements | Tests |
|-------|------|-------------------|-------|
| [P0](docs/phases/P0-foundation.md) | Foundation | FD-*, NF-05, NF-11 | 10 |
| [P1](docs/phases/P1-tenant-configuration.md) | Universities & configuration | SA-01..03, TO-01/03/04/05, DS-01 | 9 |
| [P2](docs/phases/P2-identity-onboarding.md) | Identity & driver onboarding | ST-01/02/12, DR-01, TO-02 | 10 |
| [P3](docs/phases/P3-subscriptions-payments.md) | Subscriptions & cash payments | ST-03, TO-06, PA-02 | 9 |
| [P4](docs/phases/P4-requests-dispatch.md) | Ride requests & dispatch | ST-04/05/07/08, DR-02/03, DS-02..06 | 12 |
| [P5](docs/phases/P5-runs-realtime-tracking.md) | Runs, live tracking, notifications | DR-04..09, ST-06/09, TO-07 | 12 |
| [P6](docs/phases/P6-settlement-reporting.md) | Settlement & money reporting | SE-01/02, TO-09, DR-08, SA-04/05 | 9 |
| [P7](docs/phases/P7-should-haves.md) | Should-haves | ST-10/11, TO-08/10/11 | 6 |
| [P8](docs/phases/P8-hardening-pilot.md) | Hardening & pilot | NF-06, NF-08 | 4 |
| [P9](docs/phases/P9-pilot-fixes.md) | Pilot fixes | NF-16, NF-17 | 5 |

After P9, rollout follows PRD §10: **Pilot → Full launch → Second university**.

## How phases are enforced

```
node scripts/check-phases.mjs
```

The check runs in CI (`.github/workflows/phase-gates.yml`) and fails when:

- a PRD requirement is not assigned to exactly one phase;
- a phase has no tests, or a requirement in its scope has no test;
- a test has no pass criterion or an unknown layer;
- a phase is marked `Status: done` while an exit-gate box is unchecked, **or** while any of its
  test IDs is missing from the code.

Name each test with its ID so the checker can find it:

```ts
it('[T4-01] never mixes genders, overflows capacity or misses wave time', ...)
```
```dart
testWidgets('[T3-07] subscription card renders all states', ...)
```

Workflow for each phase: `planned` → `in-progress` → write the tests from the table → make them
pass in CI → tick the exit gate → set `Status: done`. The checker then keeps the phase honest.

## Open questions from the PRD that block phases

| Question | Blocks | Default until answered |
|----------|--------|------------------------|
| Q1 student count | P8 load targets | 10 000 students, 30 % adoption |
| Q2 university integration | P2 | `ManualProvider` (office verifies) |
| Q3 mixed-tier run pool | P4, P6 | Farthest-stop tier |
| Q4 calendar month vs 30 days | P3 | Calendar month |
| Q5 refunds | P3 | No refunds in v1 |
