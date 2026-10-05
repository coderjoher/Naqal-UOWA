/*
 * Loaded first by main.ts, before Nest and the HTTP/DB libraries, so they can be instrumented.
 * Everything is opt-in through the environment; with nothing set this file does nothing.
 *
 *   OTEL_EXPORTER_OTLP_ENDPOINT  OpenTelemetry traces (e.g. http://jaeger:4318) — HTTP, Express,
 *                                PostgreSQL, Redis and Socket.IO spans
 *   OTEL_SERVICE_NAME            defaults to naql-api
 *   SENTRY_DSN                   errors to Sentry (environment from SENTRY_ENVIRONMENT)
 */
import * as Sentry from '@sentry/node';

const otel = !!process.env.OTEL_EXPORTER_OTLP_ENDPOINT;

if (otel) {
  process.env.OTEL_SERVICE_NAME ??= 'naql-api';
  // Required lazily: the SDK and its instrumentations are heavy and only needed when tracing is on.
  /* eslint-disable @typescript-eslint/no-require-imports */
  const { NodeSDK } = require('@opentelemetry/sdk-node');
  const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
  const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
  /* eslint-enable @typescript-eslint/no-require-imports */
  const sdk = new NodeSDK({
    traceExporter: new OTLPTraceExporter(),
    instrumentations: [getNodeAutoInstrumentations({ '@opentelemetry/instrumentation-fs': { enabled: false } })],
  });
  sdk.start();
  process.on('SIGTERM', () => void sdk.shutdown());
}

if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.SENTRY_ENVIRONMENT ?? 'production',
    tracesSampleRate: 0,
    // The OpenTelemetry SDK above owns tracing when it is on.
    skipOpenTelemetrySetup: otel,
    // Never send request bodies (passwords, documents) or personal data.
    sendDefaultPii: false,
  });
}

export const sentryEnabled = !!process.env.SENTRY_DSN;
