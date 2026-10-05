import { INestApplication, ValidationPipe } from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';
import helmet from 'helmet';
import { SentryExceptionFilter } from './observability/sentry.filter';
import { RedisIoAdapter } from './live/redis-io.adapter';

/** Shared between main.ts and the e2e tests so both run the same pipeline. */
export function setupApp<T extends INestApplication>(app: T): T {
  // NF-11/T8-03 security headers. The API serves JSON (and Swagger UI at /docs, which needs its
  // inline scripts), so the content security policy lives on the web apps' nginx instead.
  app.use(helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.useGlobalFilters(new SentryExceptionFilter(app.get(HttpAdapterHost).httpAdapter));
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  if (process.env.REDIS_URL) app.useWebSocketAdapter(new RedisIoAdapter(app, process.env.REDIS_URL));
  return app;
}
