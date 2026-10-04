import { Injectable, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { tenantStorage } from './tenant-context';

/** Opens an empty tenant store for each request; the auth guard fills it in. */
@Injectable()
export class TenantMiddleware implements NestMiddleware {
  use(_req: Request, _res: Response, next: NextFunction) {
    tenantStorage.run({}, next);
  }
}
