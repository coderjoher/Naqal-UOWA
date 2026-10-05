import { CallHandler, ExecutionContext, Injectable, NestInterceptor, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Observable, concatMap } from 'rxjs';
import { PrismaService } from '../prisma/prisma.service';
import { runAsSystem } from '../tenancy/tenant-context';
import type { AuthUser } from '../auth/decorators';

/** The handler records its own audit row (with before/after); the interceptor skips it. */
const AUDITED_BY_HANDLER = 'auditedByHandler';
export const AuditedByHandler = () => SetMetadata(AUDITED_BY_HANDLER, true);

const MUTATING = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);
const ADMIN_ROLES = new Set(['office', 'super_admin']);
const SECRET_KEYS = /password|token|secret/i;

export function redact(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, SECRET_KEYS.test(k) ? '[redacted]' : redact(v)]),
    );
  }
  return value;
}

/** For super admin actions: the university the changed record belongs to, if any. */
function universityOf(entity: string, result: any): string | null {
  if (entity === 'Universities' && typeof result?.id === 'string') return result.id;
  return typeof result?.universityId === 'string' ? result.universityId : null;
}

/** Records every successful mutating request by office / super admin users (feeds SA-05). */
@Injectable()
export class AuditInterceptor implements NestInterceptor {
  constructor(
    private readonly prisma: PrismaService,
    private readonly reflector: Reflector,
  ) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = ctx.switchToHttp().getRequest();
    const user: AuthUser | undefined = req.user;
    if (!MUTATING.has(req.method) || !user || !ADMIN_ROLES.has(user.role)) return next.handle();
    if (this.reflector.getAllAndOverride<boolean>(AUDITED_BY_HANDLER, [ctx.getHandler(), ctx.getClass()])) return next.handle();

    const entity = ctx.getClass().name.replace(/Controller$/, '');
    return next.handle().pipe(
      concatMap(async (result: any) => {
        await runAsSystem(() =>
          this.prisma.db.auditEvent.create({
            data: {
              universityId: user.universityId ?? universityOf(entity, result),
              actorId: user.id,
              action: `${req.method} ${req.route?.path ?? req.path}`,
              entity,
              entityId: typeof result?.id === 'string' ? result.id : null,
              payload: redact(req.body ?? null) as any,
            },
          }),
        );
        return result;
      }),
    );
  }
}
