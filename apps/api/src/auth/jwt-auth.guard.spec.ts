import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { tenantStorage, TenantStore } from '../tenancy/tenant-context';
import { JwtAuthGuard } from './jwt-auth.guard';

const UNI = '00000000-0000-0000-0000-00000000000a';

function setup(dbUser: object | null, isPublic = false) {
  const reflector = new Reflector();
  jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(isPublic);
  const jwt = new JwtService({ secret: 'unit-test-secret' });
  const prisma = { db: { user: { findUnique: jest.fn().mockResolvedValue(dbUser) } } } as any;
  return { guard: new JwtAuthGuard(reflector, jwt, prisma), jwt };
}

function ctx(authorization?: string) {
  const req: any = { headers: { authorization } };
  const c = { getHandler: () => null, getClass: () => null, switchToHttp: () => ({ getRequest: () => req }) } as unknown as ExecutionContext;
  return { c, req };
}

async function inStore<T>(fn: (store: TenantStore) => Promise<T>) {
  const store: TenantStore = {};
  return tenantStorage.run(store, () => fn(store));
}

describe('JwtAuthGuard', () => {
  it('lets public routes through without a token', async () => {
    const { guard } = setup(null, true);
    await expect(guard.canActivate(ctx().c)).resolves.toBe(true);
  });

  it('rejects missing, malformed and invalid tokens', async () => {
    const { guard } = setup(null);
    await expect(guard.canActivate(ctx().c)).rejects.toThrow(UnauthorizedException);
    await expect(guard.canActivate(ctx('Basic abc').c)).rejects.toThrow(UnauthorizedException);
    await expect(guard.canActivate(ctx('Bearer not-a-jwt').c)).rejects.toThrow(UnauthorizedException);
  });

  it('rejects suspended or deleted users', async () => {
    for (const dbUser of [null, { id: 'u', role: 'office', universityId: UNI, status: 'suspended' }]) {
      const { guard, jwt } = setup(dbUser);
      const token = await jwt.signAsync({ sub: 'u', role: 'office', uid: UNI });
      await expect(inStore(() => guard.canActivate(ctx(`Bearer ${token}`).c))).rejects.toThrow(UnauthorizedException);
    }
  });

  it('rejects a tenant user without a university', async () => {
    const { guard, jwt } = setup({ id: 'u', role: 'student', universityId: null, status: 'active' });
    const token = await jwt.signAsync({ sub: 'u', role: 'student', uid: null });
    await expect(inStore(() => guard.canActivate(ctx(`Bearer ${token}`).c))).rejects.toThrow(UnauthorizedException);
  });

  it('fills the tenant store for a tenant user', async () => {
    const { guard, jwt } = setup({ id: 'u', role: 'office', universityId: UNI, status: 'active' });
    const token = await jwt.signAsync({ sub: 'u', role: 'office', uid: UNI });
    const { c, req } = ctx(`Bearer ${token}`);
    const store = await inStore(async (s) => {
      await guard.canActivate(c);
      return s;
    });
    expect(store).toEqual({ userId: 'u', role: 'office', universityId: UNI });
    expect(req.user).toEqual({ id: 'u', role: 'office', universityId: UNI });
  });

  it('marks the super admin as global', async () => {
    const { guard, jwt } = setup({ id: 'a', role: 'super_admin', universityId: null, status: 'active' });
    const token = await jwt.signAsync({ sub: 'a', role: 'super_admin', uid: null });
    const store = await inStore(async (s) => {
      await guard.canActivate(ctx(`Bearer ${token}`).c);
      return s;
    });
    expect(store.global).toBe(true);
    expect(store.universityId).toBeUndefined();
  });

  it('fails loudly if the tenant middleware is not mounted', async () => {
    const { guard, jwt } = setup({ id: 'u', role: 'office', universityId: UNI, status: 'active' });
    const token = await jwt.signAsync({ sub: 'u', role: 'office', uid: UNI });
    await expect(guard.canActivate(ctx(`Bearer ${token}`).c)).rejects.toThrow('TenantMiddleware is not mounted');
  });
});
