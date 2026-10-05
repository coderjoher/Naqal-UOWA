import { Injectable } from '@nestjs/common';
import { PrismaService, Tx } from '../prisma/prisma.service';
import { runAsSystem } from '../tenancy/tenant-context';
import { redact } from './audit.interceptor';

export { AuditedByHandler } from './audit.interceptor';

export interface AuditEntry {
  universityId: string | null;
  actorId: string;
  action: string;
  entity: string;
  entityId?: string | null;
  before?: unknown;
  after?: unknown;
}

/** Only the fields that changed, before and after (SA-05). */
export function diff(before: Record<string, unknown>, after: Record<string, unknown>, keys: string[]) {
  const b: Record<string, unknown> = {};
  const a: Record<string, unknown> = {};
  for (const k of keys) {
    const x = norm(before[k]);
    const y = norm(after[k]);
    if (JSON.stringify(x) !== JSON.stringify(y)) {
      b[k] = x;
      a[k] = y;
    }
  }
  return { before: b, after: a, changed: Object.keys(a).length > 0 };
}

const norm = (v: unknown) => (v && typeof v === 'object' && 'toFixed' in (v as object) ? Number(v) : typeof v === 'bigint' ? Number(v) : v ?? null);

/** SA-05: settings changes and settlement approvals, with what changed. */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async record(entry: AuditEntry, tx?: Tx) {
    const data = {
      universityId: entry.universityId,
      actorId: entry.actorId,
      action: entry.action,
      entity: entry.entity,
      entityId: entry.entityId ?? null,
      payload: redact({ before: entry.before ?? null, after: entry.after ?? null }) as object,
    };
    if (tx) return tx.auditEvent.create({ data });
    return runAsSystem(() => this.prisma.db.auditEvent.create({ data }));
  }

  /** Audit log viewer: newest first, filtered by actor, entity and date range. */
  async list(filter: { universityId?: string | null; actorId?: string; entity?: string; from?: string; to?: string; cursor?: string; limit?: number }) {
    const take = Math.min(Math.max(filter.limit ?? 50, 1), 200);
    const where: Record<string, unknown> = {};
    if (filter.universityId !== undefined) where.universityId = filter.universityId;
    if (filter.actorId) where.actorId = filter.actorId;
    if (filter.entity) where.entity = filter.entity;
    if (filter.from || filter.to) where.createdAt = { ...(filter.from ? { gte: new Date(filter.from) } : {}), ...(filter.to ? { lt: new Date(new Date(filter.to).getTime() + 86400_000) } : {}) };
    return runAsSystem(async () => {
      const rows = await this.prisma.db.auditEvent.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: take + 1,
        ...(filter.cursor ? { cursor: { id: filter.cursor }, skip: 1 } : {}),
      });
      const actors = await this.prisma.db.user.findMany({ where: { id: { in: [...new Set(rows.map((r) => r.actorId))] } }, select: { id: true, name: true, nameAr: true, role: true } });
      const byId = new Map(actors.map((a) => [a.id, a]));
      const items = rows.slice(0, take).map((r) => ({ ...r, actor: byId.get(r.actorId) ?? null }));
      return { items, next: rows.length > take ? items[items.length - 1].id : null };
    });
  }

  /** Distinct entity names, for the filter drop-down. */
  async entities(universityId?: string | null) {
    const rows = await runAsSystem(() =>
      this.prisma.db.auditEvent.findMany({ where: universityId !== undefined ? { universityId } : {}, distinct: ['entity'], select: { entity: true }, orderBy: { entity: 'asc' } }),
    );
    return rows.map((r) => r.entity);
  }
}
