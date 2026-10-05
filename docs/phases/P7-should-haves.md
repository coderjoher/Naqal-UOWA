# P7 — Should-have features

Status: in-progress
Depends on: P6

## Goal

Add the PRD's **S**-priority features. They do not block the pilot, so this phase can run in
parallel with P8 if capacity allows.

## Scope

- ST-10 Ride and payment history
- ST-11 Rate ride and report a problem
- TO-08 Manual override (move student, add extra run)
- TO-10 Reports
- TO-11 Announcements

## Built

- **ST-10** `GET /rides/history`, `GET /payments/me` (cursor pages of 20, newest first). Student
  app **رحلاتي** tab: rides and payments, loads the next page as the list scrolls, empty / error /
  retry states.
- **ST-11** `POST /rides/:id/rating` (1–5, once, finished rides only), `POST /problems`. Student app:
  rate from the history, report a problem from a ride or the profile. Dashboard **البلاغات
  والتقييمات**: answer and close reports (the student is notified), average rating per driver.
- **TO-08** `POST /dispatch/move` re-runs the hard constraints on the target bus (gender, seats,
  arrival by the wave time, ride length) and notifies the student and both drivers;
  `POST /dispatch/extra-run` adds a bus that takes the waitlist (subscribers first). Dashboard:
  move a student from any stop of a run; "add a bus" on the waitlist.
- **TO-10** `reports/metrics.ts` (definitions in the file header), `GET /reports`,
  `GET /reports/export.csv`. Dashboard **التقارير** with month and tier filters.
- **TO-11** `POST /announcements` to all students, one wave on a date, or one gathering point;
  push + in-app banner on Home until dismissed or expired. Dashboard **الإعلانات** with a live
  recipient count.

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T7-01 | widget | ST-10 | History lists rides and payments with infinite scroll, empty and error states |
| T7-02 | e2e | ST-11 | Rating 1–5 once per ride; problem reports reach the office inbox |
| T7-03 | e2e | TO-08 | Manual move re-validates hard constraints (gender, capacity, wave time) and notifies student and both drivers |
| T7-04 | unit | TO-10 | Fulfilment, on-time, waitlist-expiry and renewal metrics match hand-computed fixtures |
| T7-05 | playwright | TO-10 | Reports page filters by month and tier and exports CSV |
| T7-06 | e2e | TO-11 | Announcement targets all students or a wave/point; delivered as push + in-app banner |

## Exit gate

- [x] All P7 tests green in CI (PR #9)
- [ ] Office confirms report numbers against its own spreadsheet for one month
