The access token (JWT, default TTL 12h) is kept in localStorage, so any XSS in the dashboard could read it. The nginx CSP (script-src 'self') mitigates this, but there is no refresh/rotation flow.
