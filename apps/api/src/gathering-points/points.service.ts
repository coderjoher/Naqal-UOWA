import { BadRequestException, Injectable, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import { ConfigCache } from '../config-cache/config-cache.service';
import { insidePolygon, isPolygon } from '../geo/geo';
import { PrismaService } from '../prisma/prisma.service';
import { RoutingService } from '../routing/routing.service';
import { resolveTier } from '../tiers/tier-rules';
import { CreatePointDto, UpdatePointDto } from './points.dto';

@Injectable()
export class PointsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: ConfigCache,
    private readonly routing: RoutingService,
  ) {}

  list(universityId: string) {
    return this.cache.get(universityId, 'points', () =>
      this.prisma.db.gatheringPoint.findMany({ orderBy: [{ active: 'desc' }, { distanceKm: 'asc' }], include: { tier: { select: { id: true, name: true } } } }),
    );
  }

  private async context(universityId: string) {
    const uni = await this.prisma.db.university.findUniqueOrThrow({ where: { id: universityId } });
    const tiers = await this.prisma.db.distanceTier.findMany({ orderBy: { minKm: 'asc' } });
    if (tiers.length === 0) throw new UnprocessableEntityException('Define distance tiers before adding gathering points');
    return { uni, tiers };
  }

  private assertInside(uni: { coverage: unknown }, lat: number, lng: number) {
    const polygon = isPolygon(uni.coverage) ? uni.coverage : [];
    if (!insidePolygon({ lat, lng }, polygon)) throw new UnprocessableEntityException('The point is outside the service area');
  }

  private assertTier(tiers: { id: string }[], tierId: string) {
    if (!tiers.some((t) => t.id === tierId)) throw new BadRequestException('Unknown tier');
  }

  async create(universityId: string, dto: CreatePointDto) {
    const { uni, tiers } = await this.context(universityId);
    this.assertInside(uni, dto.lat, dto.lng);
    if (dto.tierId) this.assertTier(tiers, dto.tierId);
    const leg = await this.routing.toCampus(dto, { lat: uni.campusLat, lng: uni.campusLng });
    const auto = resolveTier(tiers, leg.distanceKm);
    const point = await this.prisma.db.gatheringPoint.create({
      data: {
        universityId,
        name: dto.name.trim(),
        nameAr: dto.nameAr?.trim(),
        lat: dto.lat,
        lng: dto.lng,
        distanceKm: round(leg.distanceKm, 2),
        durationMin: leg.durationMin === null ? null : round(leg.durationMin, 1),
        tierId: dto.tierId ?? auto.id,
        tierOverridden: !!dto.tierId && dto.tierId !== auto.id,
      },
    });
    await this.changed(universityId);
    return point;
  }

  async update(universityId: string, id: string, dto: UpdatePointDto) {
    const existing = await this.prisma.db.gatheringPoint.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException();
    const { uni, tiers } = await this.context(universityId);
    const lat = dto.lat ?? existing.lat;
    const lng = dto.lng ?? existing.lng;
    const moved = lat !== existing.lat || lng !== existing.lng;
    if (moved) this.assertInside(uni, lat, lng);

    let distanceKm = existing.distanceKm;
    let durationMin = existing.durationMin;
    if (moved || distanceKm === null) {
      const leg = await this.routing.toCampus({ lat, lng }, { lat: uni.campusLat, lng: uni.campusLng });
      distanceKm = round(leg.distanceKm, 2);
      durationMin = leg.durationMin === null ? null : round(leg.durationMin, 1);
    }
    const auto = resolveTier(tiers, distanceKm ?? 0);
    let tierId = existing.tierOverridden ? existing.tierId : auto.id;
    let tierOverridden = existing.tierOverridden;
    if (dto.tierId === null) {
      tierId = auto.id;
      tierOverridden = false;
    } else if (dto.tierId !== undefined) {
      this.assertTier(tiers, dto.tierId);
      tierId = dto.tierId;
      tierOverridden = dto.tierId !== auto.id;
    }

    const point = await this.prisma.db.gatheringPoint.update({
      where: { id },
      data: { name: dto.name?.trim(), nameAr: dto.nameAr?.trim(), lat, lng, distanceKm, durationMin, tierId, tierOverridden, active: dto.active },
    });
    await this.changed(universityId, moved || dto.active !== undefined);
    return point;
  }

  /** Points are never hard-deleted (requests and runs will reference them); they are deactivated. */
  async deactivate(universityId: string, id: string) {
    return this.update(universityId, id, { active: false });
  }

  private async changed(universityId: string, matrixAffected = true) {
    await this.cache.invalidate(universityId, 'points');
    if (matrixAffected) await this.routing.scheduleMatrixRebuild(universityId);
  }
}

const round = (n: number, d: number) => Math.round(n * 10 ** d) / 10 ** d;
