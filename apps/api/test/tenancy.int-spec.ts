import { Prisma } from '@prisma/client';
import { createPrisma } from '../src/prisma/prisma.service';
import { CrossTenantWriteError, TenantContextMissingError, runAsSystem, runAsTenant } from '../src/tenancy/tenant-context';
import { createUniversity, createUser, raw, resetDb } from './helpers';

describe('tenant isolation (real PostgreSQL)', () => {
  const db = createPrisma();
  let A: string, B: string, userB: string;

  beforeAll(async () => {
    await resetDb();
    A = (await createUniversity('uni-a')).id;
    B = (await createUniversity('uni-b')).id;
    await createUser('student', A, 'a1@a.iq');
    await createUser('student', A, 'a2@a.iq');
    userB = (await createUser('student', B, 'b1@b.iq')).id;
  });
  afterAll(async () => {
    await db.$disconnect();
    await raw.$disconnect();
  });

  it('[T0-07] data of university B is invisible to every read in the context of A', async () => {
    await runAsTenant(A, async () => {
      const all = await db.user.findMany();
      expect(all.map((u) => u.email).sort()).toEqual(['a1@a.iq', 'a2@a.iq']);
      expect(await db.user.count()).toBe(2);
      expect(await db.user.findUnique({ where: { id: userB } })).toBeNull();
      expect(await db.user.findFirst({ where: { email: 'b1@b.iq' } })).toBeNull();
      expect(await db.user.findUnique({ where: { email: 'b1@b.iq' } })).toBeNull();
      const grouped = await db.user.groupBy({ by: ['universityId'], _count: true });
      expect(grouped).toEqual([{ universityId: A, _count: 2 }]);
    });
  });

  it('[T0-07] updates and deletes from A cannot touch B', async () => {
    await runAsTenant(A, async () => {
      await expect(db.user.update({ where: { id: userB }, data: { name: 'hacked' } })).rejects.toBeInstanceOf(Prisma.PrismaClientKnownRequestError);
      expect((await db.user.updateMany({ data: { phone: '0770' } })).count).toBe(2);
      await expect(db.user.delete({ where: { id: userB } })).rejects.toBeInstanceOf(Prisma.PrismaClientKnownRequestError);
      expect((await db.user.deleteMany({ where: { email: 'b1@b.iq' } })).count).toBe(0);
    });
    const b = await raw.user.findUniqueOrThrow({ where: { id: userB } });
    expect(b.name).toBe('b1@b.iq');
    expect(b.phone).toBeNull();
  });

  it('[T0-07] creates are stamped with the current university and cannot target another', async () => {
    const created = await runAsTenant(A, () => db.user.create({ data: { role: 'student', name: 'new', email: 'new@a.iq' } }));
    expect(created.universityId).toBe(A);
    await expect(runAsTenant(A, () => db.user.create({ data: { role: 'student', name: 'x', universityId: B } }))).rejects.toBeInstanceOf(CrossTenantWriteError);
  });

  it('[T0-08] the real client throws without a tenant context and works in system context', async () => {
    await expect(db.user.findMany()).rejects.toBeInstanceOf(TenantContextMissingError);
    await expect(db.auditEvent.count()).rejects.toBeInstanceOf(TenantContextMissingError);
    expect(await runAsSystem(() => db.user.count())).toBe(4);
  });
});
