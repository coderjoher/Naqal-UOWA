import { INestApplication, ValidationPipe } from '@nestjs/common';
import { RedisIoAdapter } from './live/redis-io.adapter';

/** Shared between main.ts and the e2e tests so both run the same pipeline. */
export function setupApp(app: INestApplication) {
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  if (process.env.REDIS_URL) app.useWebSocketAdapter(new RedisIoAdapter(app, process.env.REDIS_URL));
  return app;
}
