import { ArgumentsHost, Catch, HttpException } from '@nestjs/common';
import { BaseExceptionFilter } from '@nestjs/core';
import * as Sentry from '@sentry/node';

/** Unexpected errors (not 4xx answers) go to Sentry when SENTRY_DSN is set; responses are unchanged. */
@Catch()
export class SentryExceptionFilter extends BaseExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    if (process.env.SENTRY_DSN && !(exception instanceof HttpException && exception.getStatus() < 500)) Sentry.captureException(exception);
    super.catch(exception, host);
  }
}
