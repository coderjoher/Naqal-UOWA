# P6 — Settlement and money reporting

Status: planned
Depends on: P5

## Goal

At month end the office computes, reviews, approves and exports driver payouts. The payouts are
exact, reproducible and based only on GPS-verified runs.

## Scope

- SE-01 Payout formula
- SE-02 Only GPS-verified runs count
- TO-09 Compute, review, approve, export PDF/Excel
- DR-08 Driver earnings estimate and past settlements
- SA-04 Cross-university revenue / commission / usage
- SA-05 Audit log of settings and settlement approvals
- NF-15 GPS anomaly flags

## Deliverables

- All money in integer IQD (`bigint`). Rounding: floor per driver, and the remainder is reported as
  `rounding_residual` on the settlement, so totals always reconcile.
- `run_verification` service: started, visited every stop within 150 m, ended on campus or at the
  last stop, and speed plausible. Failing runs are `unverified` and listed for office review.
- Settlement job → draft → office approves (immutable from here) → PDF (Arabic) + XLSX export.
- Driver app Earnings screen: verified runs this month, estimated payout, past settlements.
- Super admin Overview: revenue, commission, active subscribers, fulfilment per university.
- Audit log viewer with filters (actor, entity, date).

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T6-01 | unit | SE-01 | PRD worked example: pool 6 000 000, c = 10 %, 50/400 runs, 100 000 cash → payout 665 000 IQD exactly |
| T6-02 | unit | SE-01 | Property test: Σ payouts + Σ commission + residual = Σ pools across random months |
| T6-03 | unit | SE-02 | Runs that skip a stop, end elsewhere or have impossible speeds are excluded |
| T6-04 | integration | TO-09 | Approved settlement cannot be recomputed or edited; re-run produces an identical draft before approval |
| T6-05 | playwright | TO-09 | Office reviews, approves and downloads PDF and XLSX; totals in files match the screen |
| T6-06 | widget | DR-08 | Earnings screen shows runs, estimate and past settlements; estimate equals API draft |
| T6-07 | e2e | SA-04 | Overview totals equal the sum of per-university settlements and payments |
| T6-08 | e2e | SA-05 | Changing commission / waitlist / approving settlement each create an audit row with before/after |
| T6-09 | unit | NF-15 | Synthetic teleport, too-fast and off-path tracks are flagged; normal fixture tracks are not |

## Exit gate

- [ ] All P6 tests green in CI
- [ ] Settlement for a full simulated month reviewed line by line with the transport office
- [ ] Commission amounts confirmed by the super admin
