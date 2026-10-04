# P2 — Student identity and driver onboarding

Status: in-progress
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

- `IdentityProvider` interface (`apps/api/src/identity`) with three adapters behind one contract:
  `HttpApiProvider` (registrar REST API, field mapping per university), `OidcProvider` (verifies
  the university SSO ID token against its JWKS) and `RosterProvider` (manual). Chosen per university
  by `integrationConfig.identity`; **defaults to manual** so the pilot is never blocked by Q2.
- Manual flow: the office imports the roster CSV and issues a one-time 6-digit activation code at
  the counter (hashed, 7 days, 5 attempts). The student activates once and sets a password.
- Gender and name always come from the university record and cannot be changed by the student.
- Drivers sign in with phone + SMS code (`SmsSender` interface; console sender until an SMS
  gateway is chosen; `OTP_DEV_ECHO=true` returns the code for testing). First sign-in creates a
  draft application in the chosen university.
- Driver application form is generated from the office's requirements (P1); documents are photos
  or PDFs (≤ 8 MB) stored on a private volume and readable only through HMAC-signed links that
  expire in 5 minutes; every link issuance is logged (`document_accesses`). An S3/MinIO backend
  can replace the disk store without changing callers (planned for P8).
- Review state machine: pending → approved | rejected, approved ↔ suspended; rejected drivers can
  edit and resubmit; only approved drivers reach run endpoints.
- Dashboard: Drivers (status tabs, review panel with inline document preview, approve / reject /
  suspend / reinstate with reason) and Students (CSV import, activation codes).
- Student app: welcome + language, university, sign-in / activation, default point, home,
  profile (read-only gender, phone, point, language). Driver app: welcome, university, phone,
  code, registration form with camera capture, status screens.
- Shared `packages/naql_app` (API address, secure token storage, preferences, language).

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T2-01 | contract | ST-01 | Each identity adapter satisfies the same contract suite (valid id, unknown id, network failure) |
| T2-02 | e2e | ST-01, ST-02 | Sign-in creates a user with gender from the provider; gender cannot be changed via the profile API |
| T2-03 | widget | ST-02 | Profile screen shows read-only gender, editable phone and default point picker |
| T2-04 | golden | ST-12 | Onboarding and home screens render correctly in ar (RTL) and en (LTR) |
| T2-05 | unit | ST-12 | Every key in `ar.arb` exists in `en.arb` and vice versa; no hard-coded user-facing strings (lint) |
| T2-06 | e2e | DR-01 | Registration fails until every requirement defined in TO-01 is provided |
| T2-07 | flutter-int | DR-01 | Driver completes registration with mocked camera (headless flow test; emulator run in P8) |
| T2-08 | e2e | TO-02 | State machine pending → approved / rejected; approved ↔ suspended; suspended drivers cannot log in to runs |
| T2-09 | security | NF-13 | Document objects are not publicly readable; signed URL expires in ≤ 5 min; access is logged with user and time |
| T2-10 | playwright | TO-02 | Office reviews a pending driver, opens documents, approves; driver status updates |

## Exit gate

- [ ] All P2 tests green in CI
- [ ] Q2 answered and the chosen identity adapter tested against the university's staging system (or ManualProvider confirmed for pilot)
- [ ] Arabic copy reviewed by a native speaker
