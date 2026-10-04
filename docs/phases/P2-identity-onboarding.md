# P2 — Student identity and driver onboarding

Status: planned
Depends on: P1

## Goal

Students sign in with their university account; drivers register with documents and are approved
by the office. Both apps are usable in Arabic RTL.

## Scope

- ST-01 University sign-in
- ST-02 Profile with gender from the university record
- ST-12 Arabic RTL default, English optional
- DR-01 Driver and vehicle registration
- TO-02 Approve / suspend / reject drivers and vehicles
- NF-13 Private driver documents with access log

## Deliverables

- `UniversityIdentityProvider` interface with adapters: `HttpApiProvider`, `OidcSsoProvider`,
  and `ManualProvider` (fallback from PRD risk table: office verifies at payment). Chosen per
  university via `integration_config`. **Blocked by open question Q2** — build `ManualProvider`
  first so the pilot is never blocked.
- Phone OTP is used only for the driver app.
- Documents stored in S3-compatible private bucket (MinIO locally), served via short-lived signed
  URLs; every URL issuance writes a `document_access` row.
- Student app: onboarding (language, sign-in, choose default point). Driver app: multi-step
  registration with camera capture for documents.
- Dashboard: Drivers queue with document viewer, approve/suspend/reject with reason.

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T2-01 | contract | ST-01 | Each identity adapter satisfies the same contract suite (valid id, unknown id, network failure) |
| T2-02 | e2e | ST-01, ST-02 | Sign-in creates a user with gender from the provider; gender cannot be changed via the profile API |
| T2-03 | widget | ST-02 | Profile screen shows read-only gender, editable phone and default point picker |
| T2-04 | golden | ST-12 | Onboarding and home screens render correctly in ar (RTL) and en (LTR) |
| T2-05 | unit | ST-12 | Every key in `ar.arb` exists in `en.arb` and vice versa; no hard-coded user-facing strings (lint) |
| T2-06 | e2e | DR-01 | Registration fails until every requirement defined in TO-01 is provided |
| T2-07 | flutter-int | DR-01 | Driver completes registration with mocked camera on Android emulator |
| T2-08 | e2e | TO-02 | State machine pending → approved / rejected; approved ↔ suspended; suspended drivers cannot log in to runs |
| T2-09 | security | NF-13 | Document objects are not publicly readable; signed URL expires in ≤ 5 min; access is logged with user and time |
| T2-10 | playwright | TO-02 | Office reviews a pending driver, opens documents, approves; driver status updates |

## Exit gate

- [ ] All P2 tests green in CI
- [ ] Q2 answered and the chosen identity adapter tested against the university's staging system (or ManualProvider confirmed for pilot)
- [ ] Arabic copy reviewed by a native speaker
