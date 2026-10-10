Per-university student verification, selected from `integrationConfig.identity` on the university record (apps/api/src/identity/identity.factory.ts):
- `manual` (default): RosterProvider — office-uploaded roster with hashed activation codes; no external call.
- `http`: HttpApiProvider POSTs {studentId, password} to the university's REST endpoint with an optional API-key header, maps response fields by dotted paths, 8 s timeout.
- `oidc`: OidcProvider verifies a university SSO ID token against a remote JWKS (issuer, audience, claim mapping) using jose.
Network failures raise ProviderUnavailableError (university unreachable) distinct from "not verified".
