# P7 — Should-have features

Status: planned
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

- [ ] All P7 tests green in CI
- [ ] Office confirms report numbers against its own spreadsheet for one month
