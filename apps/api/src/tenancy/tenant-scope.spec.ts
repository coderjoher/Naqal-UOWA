import { scopeArgs } from './tenant-scope';
import { CrossTenantWriteError, TenantContextMissingError, currentTenant, runAsSystem, runAsTenant } from './tenant-context';

const A = '00000000-0000-0000-0000-00000000000a';
const B = '00000000-0000-0000-0000-00000000000b';

describe('tenant scope', () => {
  it('[T0-08] throws when a tenant model is queried without a tenant context', () => {
    expect(() => scopeArgs('User', 'findMany', {}, undefined)).toThrow(TenantContextMissingError);
    expect(() => scopeArgs('User', 'findMany', {}, {})).toThrow(TenantContextMissingError);
    expect(() => scopeArgs('AuditEvent', 'create', { data: {} }, {})).toThrow(TenantContextMissingError);
  });

  it('[T0-08] leaves non-tenant models alone', () => {
    const args = { where: { slug: 'x' } };
    expect(scopeArgs('University', 'findMany', args, undefined)).toBe(args);
  });

  it('adds universityId to every read, update and delete filter', () => {
    for (const op of ['findUnique', 'findFirst', 'findMany', 'count', 'aggregate', 'groupBy', 'update', 'updateMany', 'delete', 'deleteMany']) {
      expect(scopeArgs('User', op, { where: { id: 'u1' } }, { universityId: A })).toMatchObject({ where: { id: 'u1', universityId: A } });
    }
    expect(scopeArgs('User', 'findMany', undefined, { universityId: A })).toEqual({ where: { universityId: A } });
  });

  it('stamps universityId on create, createMany and upsert', () => {
    expect(scopeArgs('User', 'create', { data: { name: 'x' } }, { universityId: A })).toEqual({ data: { name: 'x', universityId: A } });
    expect(scopeArgs('User', 'createMany', { data: [{ name: 'x' }, { name: 'y' }] }, { universityId: A })!.data).toEqual([
      { name: 'x', universityId: A },
      { name: 'y', universityId: A },
    ]);
    expect(scopeArgs('User', 'createMany', { data: { name: 'x' } }, { universityId: A })!.data).toEqual([{ name: 'x', universityId: A }]);
    expect(scopeArgs('User', 'upsert', { where: { id: 'u' }, create: { name: 'x' }, update: {} }, { universityId: A })).toMatchObject({
      where: { id: 'u', universityId: A },
      create: { name: 'x', universityId: A },
    });
  });

  it('refuses writes that target another university', () => {
    expect(() => scopeArgs('User', 'create', { data: { universityId: B } }, { universityId: A })).toThrow(CrossTenantWriteError);
    expect(() => scopeArgs('User', 'update', { where: { id: 'u' }, data: { universityId: B } }, { universityId: A })).toThrow(CrossTenantWriteError);
  });

  it('does not filter in global (super admin / system) context', () => {
    const args = { where: { id: 'u' } };
    expect(scopeArgs('User', 'findMany', args, { global: true })).toBe(args);
  });

  it('runAsSystem and runAsTenant set the async context', async () => {
    expect(currentTenant()).toBeUndefined();
    expect(await runAsSystem(() => currentTenant())).toEqual({ global: true });
    expect(await runAsTenant(A, () => currentTenant())).toEqual({ universityId: A });
  });

  it('lazy thenables (like PrismaPromise) are resolved inside the context', async () => {
    // Mimics PrismaPromise: work happens on .then(), not on creation.
    const lazy = { then: (resolve: (v: unknown) => void) => resolve(currentTenant()) };
    expect(await runAsTenant(A, () => lazy)).toEqual({ universityId: A });
    expect(await runAsSystem(() => lazy)).toEqual({ global: true });
  });
});
