# P3 — Subscriptions and cash payments

Status: planned
Depends on: P2

## Goal

The office records a cash subscription payment and the student's subscription is active in the app
instantly. Every money record is immutable.

## Scope

- ST-03 Subscription status, tier, price, expiry and pay-at-office instructions
- TO-06 Record cash payment, issue receipt, activate subscription
- PA-02 Price by registered point's tier; farther boarding costs the difference
- PA-04 Provider-agnostic payment model
- NF-14 Immutable money records with audit trail

## Deliverables

- `payments` table with `method` (`cash_office`, `cash_driver`, later `zaincash`, `qi`),
  `type` (`subscription`, `cash_fare`, `tier_difference`), sequential per-university `receipt_no`.
- Corrections are made with reversal rows only. A PostgreSQL trigger rejects `UPDATE`/`DELETE`
  on `payments` and `settlement_lines`.
- Subscription period: **open question Q4** — default to calendar month and keep the rule in one
  `SubscriptionPeriodPolicy` class. Refunds (Q5) are not supported in v1.
- Dashboard: student search → record payment → printable receipt (A6 PDF, Arabic).
- Student app: Subscription card (status chip, tier, price, expiry, office hours + location).
- Push + in-app refresh within 5 s of activation.

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T3-01 | e2e | TO-06 | Recording a payment creates payment + active subscription + receipt number in one transaction |
| T3-02 | unit | TO-06 | Receipt numbers are unique and gap-free per university under 50 concurrent writes |
| T3-03 | unit | PA-02 | Price = tier of registered point; boarding at farther tier returns the exact difference; nearer tier costs 0 |
| T3-04 | unit | PA-02 | `SubscriptionPeriodPolicy` computes start/expiry for calendar month across year end and February |
| T3-05 | contract | PA-04 | A fake electronic provider plugs in via the `PaymentProvider` interface with no schema change |
| T3-06 | integration | NF-14 | `UPDATE` and `DELETE` on payments fail at DB level; reversal row nets the balance to zero and is audited |
| T3-07 | widget | ST-03 | Subscription card renders active, expiring-soon (≤ 3 days), expired and none states |
| T3-08 | flutter-int | ST-03 | App shows the subscription as active within 5 s of the office recording the payment |
| T3-09 | playwright | TO-06 | Office records a payment and downloads a receipt PDF containing student name, amount, receipt no. |

## Exit gate

- [ ] All P3 tests green in CI
- [ ] Q4 (calendar month vs 30 days) decided by the office and policy matches
- [ ] Office staff run a dry-run of 20 payments on staging without help
