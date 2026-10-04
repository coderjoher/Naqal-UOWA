import { Prisma } from '@prisma/client';
import { TENANT_MODELS } from './tenant-models';
import { CrossTenantWriteError, TenantContextMissingError, TenantStore, currentTenant } from './tenant-context';

type Args = Record<string, any>;

const WHERE_OPS = new Set([
  'findUnique', 'findUniqueOrThrow', 'findFirst', 'findFirstOrThrow', 'findMany',
  'count', 'aggregate', 'groupBy', 'update', 'updateMany', 'updateManyAndReturn',
  'delete', 'deleteMany',
]);

function withTenantData(model: string, data: Args, universityId: string): Args {
  if (data.universityId !== undefined && data.universityId !== universityId) {
    throw new CrossTenantWriteError(model);
  }
  return { ...data, universityId };
}

/**
 * Returns the query args with the tenant filter applied. Pure function so it can be unit
 * tested without a database.
 */
export function scopeArgs(model: string, operation: string, args: Args | undefined, ctx: TenantStore | undefined): Args | undefined {
  if (!TENANT_MODELS.has(model)) return args;
  if (!ctx || (!ctx.global && !ctx.universityId)) throw new TenantContextMissingError(model, operation);
  if (ctx.global) return args;

  const universityId = ctx.universityId!;
  const a: Args = { ...(args ?? {}) };

  if (WHERE_OPS.has(operation)) {
    a.where = { ...(a.where ?? {}), universityId };
  }
  if (operation === 'update' || operation === 'updateMany' || operation === 'updateManyAndReturn') {
    if (a.data && a.data.universityId !== undefined && a.data.universityId !== universityId) {
      throw new CrossTenantWriteError(model);
    }
  }
  if (operation === 'create') a.data = withTenantData(model, a.data ?? {}, universityId);
  if (operation === 'createMany' || operation === 'createManyAndReturn') {
    const rows = Array.isArray(a.data) ? a.data : [a.data];
    a.data = rows.map((r: Args) => withTenantData(model, r, universityId));
  }
  if (operation === 'upsert') {
    a.where = { ...(a.where ?? {}), universityId };
    a.create = withTenantData(model, a.create ?? {}, universityId);
  }
  return a;
}

/** Prisma client extension applying `scopeArgs` to every model operation. */
export const tenantExtension = Prisma.defineExtension({
  name: 'tenant-scope',
  query: {
    $allModels: {
      async $allOperations({ model, operation, args, query }) {
        return query(scopeArgs(model, operation, args as Args, currentTenant()) as any);
      },
    },
  },
});
