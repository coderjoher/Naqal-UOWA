import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { tenantExtension } from '../tenancy/tenant-scope';

export function createPrisma() {
  return new PrismaClient().$extends(tenantExtension);
}
export type TenantPrisma = ReturnType<typeof createPrisma>;

/**
 * Exposes the tenant-scoped client as `db`. Raw SQL ($queryRaw) bypasses the tenant filter
 * and must always include `university_id` explicitly.
 */
@Injectable()
export class PrismaService implements OnModuleInit, OnModuleDestroy {
  readonly db: TenantPrisma = createPrisma();

  async onModuleInit() {
    await this.db.$connect();
  }

  async onModuleDestroy() {
    await this.db.$disconnect();
  }
}

/** The client handed to `db.$transaction(async (tx) => …)` callbacks (tenant-scoped like `db`). */
export type Tx = Omit<TenantPrisma, '$extends' | '$transaction' | '$connect' | '$disconnect' | '$on'>;
