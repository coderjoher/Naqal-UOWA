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
  phases/P0…P8      scope, tests, exit gate per phase
  design-system.md  visual language
```

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

After P8, rollout follows PRD §10: **Pilot → Full launch → Second university**.

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
