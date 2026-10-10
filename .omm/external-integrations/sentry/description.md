Error reporting, opt-in per surface:
- API: apps/api/src/observability/instrument.ts initialises @sentry/node when SENTRY_DSN is set (sendDefaultPii false, tracesSampleRate 0, environment from SENTRY_ENVIRONMENT); sentry.filter.ts captures only non-4xx exceptions.
- Dashboard: apps/dashboard/src/main.tsx lazy-loads @sentry/react when VITE_SENTRY_DSN is set at build time.
- Flutter: packages/naql_app/lib/src/bootstrap.dart initialises the `sentry` package when --dart-define=SENTRY_DSN is set (release.yml passes secrets.SENTRY_DSN_APPS).
