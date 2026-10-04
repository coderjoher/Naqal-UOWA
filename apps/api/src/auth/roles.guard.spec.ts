import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from './roles.guard';

const ctx = (user?: object) =>
  ({ getHandler: () => null, getClass: () => null, switchToHttp: () => ({ getRequest: () => ({ user }) }) }) as unknown as ExecutionContext;

describe('RolesGuard', () => {
  const reflector = new Reflector();
  const guard = new RolesGuard(reflector);

  it('allows any authenticated user when no roles are declared', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(undefined);
    expect(guard.canActivate(ctx({ role: 'student' }))).toBe(true);
  });

  it('allows a listed role and forbids others', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['office']);
    expect(guard.canActivate(ctx({ role: 'office' }))).toBe(true);
    expect(() => guard.canActivate(ctx({ role: 'student' }))).toThrow(ForbiddenException);
    expect(() => guard.canActivate(ctx(undefined))).toThrow(ForbiddenException);
  });
});
