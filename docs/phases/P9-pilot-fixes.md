# P9 — Pilot fixes

Status: in-progress
Depends on: P8

## Goal

Fix what a walk through every screen with demo data turned up before the pilot. Two requirements
are new (NF-16, NF-17); the other fixes tighten requirements of earlier phases, which the tests
below cover again.

## Scope

- NF-16 Maps: the free CARTO basemap now answers "API KEY REQUIRED" instead of a map, so the dashboard
  maps and the student tracking map showed no streets. Tiles now come from one build setting with a
  working default.
- Live operations: a bus last heard from long ago read "2543081 s ago", and a run a driver never
  ended stayed "on the road" on every later day.
- NF-17 Driver app: the sign-in code field was invisible to screen readers; the earnings card read
  "−0 IQD" when no cash commission was due.

## Built

- **Map tiles** — dashboard `VITE_MAP_TILES` / `VITE_MAP_ATTRIBUTION` (build args), apps
  `--dart-define=MAP_TILES` / `MAP_ATTRIBUTION`. Default: OpenStreetMap (no key, fine for the pilot;
  its usage policy forbids heavy use, so full launch sets a keyed provider — OPERATIONS.md §8). The
  dashboard Dockerfile writes the tile host into the CSP (`__MAP_ORIGINS__`), so the policy allows
  exactly that host. The student map shows the provider's credit.
- **Live operations** — "updated … ago" in seconds, minutes, hours or days; only runs dated today
  or yesterday count as on the road. Older unfinished runs already go to the office's settlement
  review (`not_completed`).
- **Accessibility** — the hidden code field keeps its semantics (`alwaysIncludeSemantics`), so
  TalkBack / VoiceOver and SMS autofill reach it.
- **Earnings** — a zero cash commission reads "0 IQD".
- **Dashboard overview** — the loading placeholder of a KPI card is no longer a `<div>` inside a
  `<p>` (invalid HTML React warned about).

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T9-01 | widget | NF-17, DR-04 | The code field is a text field in the semantics tree (screen readers, autofill) |
| T9-02 | unit | TO-07 | "Updated … ago" uses the largest whole unit (s, min, h, days) |
| T9-03 | e2e | TO-07 | A run left open from an earlier day is not listed as on the road |
| T9-04 | widget | DR-08 | A zero cash commission reads "0 IQD", never "−0" |
| T9-05 | ci | NF-16, ST-06, TO-03 | No tile host hard-coded outside the map settings; the deployed dashboard CSP allows the configured host |

## Exit gate

- [x] All P9 tests green in CI (PR #11)
- [ ] Maps show streets on the dashboard (points, live operations) and the student tracking screen
