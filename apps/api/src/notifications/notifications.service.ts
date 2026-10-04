import { Inject, Injectable, Logger } from '@nestjs/common';
import { LiveHub } from '../live/live.hub';
import { PrismaService, Tx } from '../prisma/prisma.service';
import { runAsTenant } from '../tenancy/tenant-context';
import { messageFor, NotificationDraft } from './rules';
import { PUSH_SENDER, PushSender } from './push';

/**
 * Outbox → delivery. Rows are written inside the business transaction (deduplicated by key);
 * delivery runs after commit: socket event to the user's room plus FCM push to their devices.
 */
@Injectable()
export class NotificationsService {
  private readonly log = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly hub: LiveHub,
    @Inject(PUSH_SENDER) private readonly push: PushSender,
  ) {}

  static async add(tx: Tx, universityId: string, drafts: NotificationDraft[], extra: Record<string, unknown> = {}) {
    if (!drafts.length) return;
    await tx.notification.createMany({
      data: drafts.map((d) => ({ universityId, userId: d.userId, kind: d.kind, dedupeKey: d.dedupeKey, data: { ...extra, ...d.data } as object })),
      skipDuplicates: true,
    });
  }

  async addNow(universityId: string, drafts: NotificationDraft[]) {
    if (!drafts.length) return;
    await runAsTenant(universityId, () => NotificationsService.add(this.prisma.db as unknown as Tx, universityId, drafts));
    await this.deliverPending(universityId);
  }

  /** Sends everything not delivered yet for this university. Safe to call repeatedly. */
  async deliverPending(universityId: string) {
    await runAsTenant(universityId, async () => {
      const db = this.prisma.db;
      const rows = await db.notification.findMany({ where: { pushedAt: null }, orderBy: { createdAt: 'asc' }, take: 200, include: { user: { select: { id: true } } } });
      if (!rows.length) return;
      const ids = rows.map((r) => r.id);
      // Claim first so concurrent callers never send twice.
      const claimed = await db.notification.updateMany({ where: { id: { in: ids }, pushedAt: null }, data: { pushedAt: new Date() } });
      if (claimed.count === 0) return;
      const tokens = await db.deviceToken.findMany({ where: { userId: { in: [...new Set(rows.map((r) => r.userId))] } } });
      for (const n of rows) {
        const payload = { id: n.id, kind: n.kind, data: n.data, createdAt: n.createdAt };
        this.hub.toUser(n.userId, 'notification', payload);
        const msg = messageFor({ kind: n.kind as NotificationDraft['kind'], data: n.data as Record<string, unknown> }, 'ar');
        for (const t of tokens.filter((x) => x.userId === n.userId)) {
          const r = await this.push.send({ token: t.token, title: msg.title, body: msg.body, data: { kind: n.kind, id: n.id, ...stringify(n.data) } });
          if (r === 'invalid-token') await db.deviceToken.delete({ where: { id: t.id } }).catch(() => undefined);
        }
      }
    }).catch((e) => this.log.warn(`delivery failed: ${(e as Error).message}`));
  }

  list(userId: string) {
    return this.prisma.db.notification.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 50, select: { id: true, kind: true, data: true, readAt: true, createdAt: true } });
  }

  async markRead(userId: string, ids: string[] | 'all') {
    const res = await this.prisma.db.notification.updateMany({ where: { userId, readAt: null, ...(ids === 'all' ? {} : { id: { in: ids } }) }, data: { readAt: new Date() } });
    return { updated: res.count };
  }

  async registerDevice(userId: string, universityId: string, token: string, platform: string) {
    const db = this.prisma.db;
    // A token belongs to one install; if another user signed in on it, it moves.
    await db.deviceToken.deleteMany({ where: { token, userId: { not: userId } } });
    await db.deviceToken.upsert({ where: { token }, create: { universityId, userId, token, platform }, update: { userId, platform } });
    return { ok: true };
  }
}

function stringify(data: unknown): Record<string, string> {
  return Object.fromEntries(Object.entries((data ?? {}) as Record<string, unknown>).map(([k, v]) => [k, String(v)]));
}
