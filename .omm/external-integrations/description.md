Everything outside the Naql codebase that the system talks to, plus the self-hosted runtime it is deployed on (child group `hosting`). All third-party integrations are opt-in via environment variables or build-time defines and degrade gracefully when unset:
- Map tiles: OpenStreetMap by default (dashboard MapLibre via VITE_MAP_TILES, Flutter via --dart-define=MAP_TILES), replaceable by a keyed provider (e.g. MapTiler).
- Routing data: Geofabrik Iraq extract feeding a self-hosted OSRM.
- Student identity: per-university provider (manual roster, university HTTP API, or OIDC/SSO).
- Push: Firebase Cloud Messaging HTTP v1 when FCM_SERVICE_ACCOUNT is set; otherwise logged.
- SMS: interface only; no real gateway bound.
- Error reporting: Sentry for API, dashboard and Flutter apps.
- Public HTTPS: DuckDNS hostnames + Caddy with Let's Encrypt.
- Off-site backups: rclone to any remote (e.g. S3).
- CI/CD: GitHub Actions (CI, demo APK release, Play/TestFlight release, load and nightly tests).
