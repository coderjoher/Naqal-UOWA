import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import type { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { currentTenant, runAsSystem } from '../tenancy/tenant-context';
import { AuthUser, IS_PUBLIC } from './decorators';

interface JwtPayload {
  sub: string;
  role: Role;
  uid: string | null;
}

/**
 * Global guard: verifies the bearer token, confirms the user is still active and fills the
 * request's tenant store (NF-05, NF-11).
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [ctx.getHandler(), ctx.getClass()])) return true;

    const req = ctx.switchToHttp().getRequest();
    const [scheme, token] = (req.headers.authorization ?? '').split(' ');
    if (scheme !== 'Bearer' || !token) throw new UnauthorizedException();

    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync<JwtPayload>(token);
    } catch {
      throw new UnauthorizedException();
    }

    const user = await runAsSystem(() =>
      this.prisma.db.user.findUnique({ where: { id: payload.sub }, select: { id: true, role: true, universityId: true, status: true } }),
    );
    if (!user || user.status !== 'active') throw new UnauthorizedException();
    if (user.role !== 'super_admin' && !user.universityId) throw new UnauthorizedException();

    const authUser: AuthUser = { id: user.id, role: user.role, universityId: user.universityId };
    req.user = authUser;

    const store = currentTenant();
    if (!store) throw new Error('TenantMiddleware is not mounted');
    store.userId = user.id;
    store.role = user.role;
    if (user.role === 'super_admin') store.global = true;
    else store.universityId = user.universityId!;
    return true;
  }
}
