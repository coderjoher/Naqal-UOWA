# P0 — Foundation

Status: planned
Depends on: —

## Goal

A runnable, tested skeleton for all four apps, with multi-tenancy and role-based access built in
from the first line of code, so every later phase only adds features.

## Scope

- FD-01 Monorepo layout
- FD-02 CI that blocks merge on any red suite
- FD-03 Shared design tokens → CSS + Dart
- FD-04 Flutter UI kit `naql_ui`
- FD-05 Dashboard UI kit
- FD-06 Docker Compose local stack
- NF-05 `university_id` on every tenant table, enforced in the data layer
- NF-11 Role-based access (`student`, `driver`, `office`, `super_admin`), office scoped to its university

## Deliverables

- `apps/api` — NestJS 11, Prisma + PostgreSQL 16, Redis, BullMQ, `@nestjs/config`, Pino logging,
  OpenAPI generated from DTOs. `TenantGuard` + Prisma client extension that injects
  `university_id` into every query. `AuditInterceptor` writes an audit event for every mutating
  admin request (consumed later by SA-05).
- `apps/dashboard` — React 19 + Vite + TypeScript, TanStack Router/Query, Tailwind wired to the
  token CSS variables, Radix primitives. RTL by default. Login screen + empty shell for both roles.
- `apps/student_app`, `apps/driver_app` — Flutter 3, Riverpod, go_router, both depending on
  `packages/naql_ui` and `packages/naql_core` (API client generated from OpenAPI, auth storage).
- `packages/design-tokens/tokens.json` + generator script.
- `docker-compose.yml` (postgres, redis, osrm with Karbala extract, api, dashboard).

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T0-01 | ci | FD-01, FD-02 | Workflow runs api, dashboard, student_app, driver_app jobs; a deliberately failing test makes the PR red |
| T0-02 | unit | FD-03 | Token generator output for CSS and Dart is byte-identical to committed files (no drift) |
| T0-03 | golden | FD-04 | Golden images for every `naql_ui` component in LTR and RTL, light theme |
| T0-04 | widget | FD-04 | `naql_ui` components never render Material ink splashes or default elevation shadows |
| T0-05 | dashboard | FD-05 | Vitest + Testing Library: Button, Input, Card, Badge, Table render with token classes and are keyboard accessible |
| T0-06 | integration | FD-06 | `docker compose up` then `/health` returns OK for db, redis and osrm within 60 s |
| T0-07 | integration | NF-05 | Data written for university A is invisible to every query made in the context of university B |
| T0-08 | unit | NF-05 | Prisma extension throws if a tenant model is queried without a tenant context |
| T0-09 | e2e | NF-11 | Each role gets 403 on endpoints of other roles; office user gets 404 for another university's resource ids |
| T0-10 | playwright | NF-11 | Dashboard routes redirect unauthenticated users to login and hide super-admin menus from office users |

## Exit gate

- [ ] All P0 tests green in CI on `main`
- [ ] API unit coverage ≥ 80 % lines on `auth` and `tenancy` modules
- [ ] `docker compose up` works on a clean machine following the README
- [ ] Design tokens reviewed against `docs/design-system.md`
