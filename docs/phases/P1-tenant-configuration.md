# P1 — Universities and transport configuration

Status: planned
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

- API modules `universities`, `tiers`, `gathering-points`, `waves`, `driver-requirements`, `routing`.
- `routing` job: on point create/update/delete, enqueue `travel-matrix.rebuild` (BullMQ) that calls
  OSRM `/table` and stores a `travel_times` matrix (point ↔ point, point ↔ campus).
- Dashboard pages: Universities (super admin), Settings → Tiers, Points (MapLibre map with
  click-to-place + tier colour), Waves (weekday grid), Driver requirements (dynamic form builder).
- Tier is derived from the point's OSRM distance to campus and can be overridden by the office.

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T1-01 | e2e | SA-01 | Super admin creates a university with campus location and an office account; office user can log in and sees only it |
| T1-02 | unit | SA-02, SA-03 | Commission accepts 0–100 % with 2 decimals; waitlist minutes 1–240; invalid values rejected |
| T1-03 | e2e | TO-01 | Office defines required documents / vehicle type / max vehicle age; driver registration schema reflects them |
| T1-04 | unit | TO-04, PA-01 | Tier ranges must not overlap or leave gaps; each point resolves to exactly one tier |
| T1-05 | integration | TO-03, SM-01 | Creating a point stores geography, auto-assigns tier from distance, rejects points outside the coverage polygon |
| T1-06 | integration | DS-01 | Point change enqueues one rebuild job; job fills matrix for all point pairs + campus using an OSRM test container |
| T1-07 | unit | TO-05 | Waves: morning/return types, weekday mask, no duplicate time per type/day |
| T1-08 | integration | NF-04 | Reads hit Redis after first load; any write invalidates the matching key |
| T1-09 | playwright | TO-03, TO-04, TO-05 | Office user configures 3 tiers, 5 points on the map and 2 waves end to end in Arabic RTL |

## Exit gate

- [ ] All P1 tests green in CI
- [ ] Real Karbala OSRM extract builds a matrix for 50 points in < 30 s
- [ ] Transport office reviews the Points / Tiers / Waves screens and signs off
