import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigCache } from '../config-cache/config-cache.service';
import { PrismaService } from '../prisma/prisma.service';
import { RoutingService } from '../routing/routing.service';
import { currentTenant } from '../tenancy/tenant-context';
import { TierDto } from './tiers.dto';
import { resolveTier, validateTiers } from './tier-rules';

@Injectable()
export class TiersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: ConfigCache,
    private readonly routing: RoutingService,
  ) {}

  list(universityId: string) {
    return this.cache.get(universityId, 'tiers', () => this.prisma.db.distanceTier.findMany({ orderBy: { minKm: 'asc' } }));
  }

  /**
   * Replaces the whole tier set atomically, then re-resolves the tier of every point whose
   * tier was not overridden by the office.
   */
  async replace(universityId: string, input: TierDto[]) {
    const tiers = input.map((t) => ({ ...t, maxKm: t.maxKm ?? null }));
    const problems = validateTiers(tiers);
    if (problems.length) throw new BadRequestException(problems);

    const db = this.prisma.db;
    const result = await db.$transaction(async (tx) => {
      const existing = await tx.distanceTier.findMany({ where: { universityId } });
      const keepIds = new Set(tiers.filter((t) => t.id).map((t) => t.id!));
      for (const id of keepIds) {
        if (!existing.some((e) => e.id === id)) throw new BadRequestException(`Unknown tier ${id}`);
      }
      const saved = [];
      for (const t of tiers) {
        const data = { name: t.name.trim(), minKm: t.minKm, maxKm: t.maxKm, subscriptionPrice: t.subscriptionPrice, ridePrice: t.ridePrice };
        saved.push(
          t.id
            ? await tx.distanceTier.update({ where: { id: t.id, universityId }, data })
            : await tx.distanceTier.create({ data: { ...data, universityId } }),
        );
      }
      // Points: re-resolve automatic tiers; overridden points on a removed tier fall back to automatic.
      const removed = existing.filter((e) => !keepIds.has(e.id)).map((e) => e.id);
      const points = await tx.gatheringPoint.findMany({ where: { universityId } });
      for (const p of points) {
        const mustResolve = !p.tierOverridden || removed.includes(p.tierId);
        if (!mustResolve) continue;
        const km = p.distanceKm ?? 0;
        const tier = resolveTier(saved, km);
        if (tier.id !== p.tierId || removed.includes(p.tierId)) {
          await tx.gatheringPoint.update({ where: { id: p.id, universityId }, data: { tierId: tier.id, tierOverridden: false } });
        }
      }
      if (removed.length) await tx.distanceTier.deleteMany({ where: { id: { in: removed }, universityId } });
      return saved.sort((a, b) => a.minKm - b.minKm);
    });
    await this.cache.invalidate(universityId, 'tiers', 'points');
    void this.routing; // tiers do not change travel times
    return result;
  }
}

export function tenantUniversityId(): string {
  const id = currentTenant()?.universityId;
  if (!id) throw new BadRequestException('This action needs a university context');
  return id;
}
