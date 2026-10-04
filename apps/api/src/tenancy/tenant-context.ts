import { AsyncLocalStorage } from 'node:async_hooks';
import type { Role } from '@prisma/client';

/**
 * Per-request context. `universityId` is set for tenant users (student, driver, office).
 * `global` is set for the super admin and for trusted system code (login, jobs, seeds):
 * tenant models are then not filtered.
 */
export interface TenantStore {
  universityId?: string;
  global?: boolean;
  userId?: string;
  role?: Role;
}

export const tenantStorage = new AsyncLocalStorage<TenantStore>();

export const currentTenant = (): TenantStore | undefined => tenantStorage.getStore();

/*
 * Prisma queries are lazy: they execute when awaited, not when created. Both helpers therefore
 * await inside the context, otherwise `runAsSystem(() => db.user.findMany())` would run the
 * query after the context has already been left.
 */

/** Run trusted code that must see all universities (e.g. login lookup, background jobs). */
export function runAsSystem<T>(fn: () => T | PromiseLike<T>): Promise<T> {
  return tenantStorage.run({ global: true }, async () => await fn());
}

/** Run code in the context of one university (used by jobs and tests). */
export function runAsTenant<T>(universityId: string, fn: () => T | PromiseLike<T>): Promise<T> {
  return tenantStorage.run({ universityId }, async () => await fn());
}

export class TenantContextMissingError extends Error {
  constructor(model: string, operation: string) {
    super(`Tenant context missing for ${model}.${operation}; wrap the call in a request, runAsTenant() or runAsSystem().`);
    this.name = 'TenantContextMissingError';
  }
}

export class CrossTenantWriteError extends Error {
  constructor(model: string) {
    super(`Refusing to write ${model} for another university.`);
    this.name = 'CrossTenantWriteError';
  }
}
