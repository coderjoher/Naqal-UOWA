# P1 — Universities and transport configuration

Status: in-progress
Depends on: P0

## Goal

The super admin can onboard Warith Al-Anbiyaa University, and its transport office can configure
everything dispatch needs: driver requirements, tiers, gathering points and waves.

## Scope

- SA-01 Onboard a university
- SA-02 Commission per university
- SA-03 Waitlist duration per university
- TO-01 Driver requirements
- TO-03 Gathering points on a map, each in a tier
- TO-04 Distance tiers and prices
- TO-05 Waves per weekday
- PA-01 Each point belongs to exactly one tier
- SM-01 Fixed gathering points only
- DS-01 OSRM travel-time matrix, refreshed when points change
- NF-04 Points, tiers, waves cached in Redis

## Deliverables

- API modules `universities` (create with first office account, edit commission / waitlist /
  campus / service area), `tiers` (whole-set replace with contiguity validation), `gathering-points`,
  `waves`, `driver-requirements` (+ `registration-form` consumed by the driver app in P2), `routing`.
- `routing`: on any point change, one debounced BullMQ job `travel-matrix.rebuild` per university
  calls OSRM `/table` and stores the `travel_times` matrix (point ↔ point, point ↔ campus).
- Tier is derived from the point's OSRM road distance to campus (straight line × 1.3 if OSRM is
  down) and can be overridden by the office; changing tiers re-resolves automatic points.
- Service area is a `[lat, lng]` polygon on the university (JSON + point-in-polygon in the API);
  PostGIS is not needed yet and stays available in the compose image for later phases.
- Config reads (tiers, points, waves, requirements) are cached in Redis per university and
  invalidated on every write; a Redis outage falls back to the database.
- Dashboard: Universities (super admin, slide-over forms), Overview with setup checklist,
  Tiers editor, Points map (MapLibre, muted CARTO basemap, click to place), Waves, Driver
  requirements. Animated page transitions, buttons, lists and toasts.
- Tests use a deterministic fake OSRM (`apps/api/test/fake-osrm.ts`); the real Iraq extract is
  exercised in the CI `compose` job.

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T1-01 | e2e | SA-01 | Super admin creates a university with campus location and an office account; office user can log in and sees only it |
| T1-02 | unit | SA-02, SA-03 | Commission accepts 0–100 % with 2 decimals; waitlist minutes 1–240; invalid values rejected |
| T1-03 | e2e | TO-01 | Office defines required documents / vehicle type / max vehicle age; driver registration schema reflects them |
| T1-04 | unit | TO-04, PA-01 | Tier ranges must not overlap or leave gaps; each point resolves to exactly one tier |
| T1-05 | integration | TO-03, SM-01 | Creating a point stores geography, auto-assigns tier from distance, rejects points outside the coverage polygon |
| T1-06 | integration | DS-01 | Point change enqueues one rebuild job; job fills matrix for all point pairs + campus (fake OSRM in tests; real extract in the compose job) |
| T1-07 | unit | TO-05 | Waves: morning/return types, weekday mask, no duplicate time per type/day |
| T1-08 | integration | NF-04 | Reads hit Redis after first load; any write invalidates the matching key |
| T1-09 | playwright | TO-03, TO-04, TO-05 | Office user configures 3 tiers, 5 points on the map and 2 waves end to end in Arabic RTL |

## Exit gate

- [x] All P1 tests green in CI (PR #2)
- [x] Real Karbala OSRM extract builds a matrix for 50 points in < 30 s (CI `compose` job: 0.18 s)
- [ ] Transport office reviews the Points / Tiers / Waves screens and signs off
