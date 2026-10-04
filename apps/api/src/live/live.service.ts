import { BadRequestException, ConflictException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import Redis from 'ioredis';
import { NotificationsService } from '../notifications/notifications.service';
import { notificationsFor, RiderAtStop } from '../notifications/rules';
import { PrismaService } from '../prisma/prisma.service';
import { REDIS } from '../redis/redis.module';
import { runAsTenant } from '../tenancy/tenant-context';
import { etas, RouteStop } from './eta';
import { BusPosition, LiveHub } from './live.hub';

export interface GpsPoint {
  lat: number;
  lng: number;
  /** ISO time on the device; buffered points arrive late with their original time. */
  at: string;
  speed?: number | null;
  heading?: number | null;
}

interface Route {
  universityId: string;
  driverId: string;
  status: string;
  stops: RouteStop[];
  riders: RiderAtStop[];
  legs: Map<string, number>;
  until: number;
}

const ROUTE_TTL_MS = 15_000;
/** Persisted points are deduplicated per run and minute (NF-01); keys outlive any offline gap. */
const BUCKET_TTL_S = 6 * 3600;

const key = {
  last: (runId: string) => `live:last:${runId}`,
  geo: (universityId: string) => `live:geo:${universityId}`,
  bucket: (runId: string, minute: number) => `live:pos:${runId}:${minute}`,
};

/**
 * NF-01: live GPS goes to Redis (GEO set + last point) and out over WebSocket; only one point per
 * run per minute is written to PostgreSQL. Points are accepted only from the run's own driver
 * while the run is under way.
 */
@Injectable()
export class LiveService {
  private readonly routes = new Map<string, Route>();

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    private readonly hub: LiveHub,
    private readonly notifications: NotificationsService,
  ) {}

  private async ready() {
    if (this.redis.status === 'wait') await this.redis.connect();
  }

  /** Drop the cached route after stops, riders or status change. */
  invalidate(runId: string) {
    this.routes.delete(runId);
  }

  async ingest(driverId: string, universityId: string, runId: string, raw: GpsPoint[]) {
    const points = sanitize(raw);
    if (!points.length) throw new BadRequestException('No valid GPS points');
    const route = await this.route(universityId, runId);
    if (route.driverId !== driverId) throw new ForbiddenException('Not your run');
    if (route.status !== 'started' && route.status !== 'at_stop') throw new ConflictException('The run is not under way');
    await this.ready();

    // One stored row per minute of driving, also for points that were buffered offline.
    const pipe = this.redis.pipeline();
    for (const p of points) pipe.set(key.bucket(runId, Math.floor(p.at.getTime() / 60_000)), '1', 'EX', BUCKET_TTL_S, 'NX');
    const results = (await pipe.exec()) ?? [];
    const rows = points.filter((_, i) => results[i]?.[1] === 'OK');

    const latest = points[points.length - 1];
    const prevAt = Number((await this.redis.hget(key.last(runId), 'at')) ?? 0);
    let broadcast: BusPosition | null = null;
    if (latest.at.getTime() > prevAt) {
      broadcast = {
        runId,
        lat: latest.lat,
        lng: latest.lng,
        at: latest.at.toISOString(),
        speed: latest.speed,
        heading: latest.heading,
        etas: etas(latest, route.stops, (a, b) => route.legs.get(`${a}|${b}`)),
      };
      await this.redis
        .multi()
        .hset(key.last(runId), { lat: latest.lat, lng: latest.lng, at: latest.at.getTime(), speed: latest.speed ?? '', heading: latest.heading ?? '' })
        .expire(key.last(runId), 24 * 3600)
        .geoadd(key.geo(universityId), latest.lng, latest.lat, runId)
        .exec();
      this.hub.bus(universityId, broadcast);
    }

    if (rows.length) {
      await runAsTenant(universityId, () =>
        this.prisma.db.runPosition.createMany({ data: rows.map((p) => ({ universityId, runId, lat: p.lat, lng: p.lng, speed: p.speed, heading: p.heading, at: p.at })) }),
      );
    }
    // ST-09: "your bus is about 5 minutes away" — once per ride (dedupe key).
    if (broadcast) await this.notifications.addNow(universityId, notificationsFor({ type: 'eta', runId, etas: broadcast.etas, riders: route.riders }));
    return { accepted: points.length, persisted: rows.length, live: !!broadcast };
  }

  /** NF-10: last known position with its time (Redis, else the last stored point). */
  async last(universityId: string, runId: string): Promise<BusPosition | null> {
    await this.ready();
    const h = await this.redis.hgetall(key.last(runId));
    let pos: { lat: number; lng: number; at: Date; speed: number | null; heading: number | null } | null = null;
    if (h.at) pos = { lat: Number(h.lat), lng: Number(h.lng), at: new Date(Number(h.at)), speed: h.speed ? Number(h.speed) : null, heading: h.heading ? Number(h.heading) : null };
    else {
      const row = await runAsTenant(universityId, () => this.prisma.db.runPosition.findFirst({ where: { runId }, orderBy: { at: 'desc' } }));
      if (row) pos = { lat: row.lat, lng: row.lng, at: row.at, speed: row.speed, heading: row.heading };
    }
    if (!pos) return null;
    const route = await this.route(universityId, runId);
    return { runId, lat: pos.lat, lng: pos.lng, at: pos.at.toISOString(), speed: pos.speed, heading: pos.heading, etas: etas(pos, route.stops, (a, b) => route.legs.get(`${a}|${b}`)) };
  }

  private async route(universityId: string, runId: string): Promise<Route> {
    const hit = this.routes.get(runId);
    if (hit && hit.until > Date.now()) return hit;
    const route = await runAsTenant(universityId, async () => {
      const run = await this.prisma.db.run.findUnique({
        where: { id: runId },
        include: { stops: { orderBy: { seq: 'asc' }, include: { point: true } }, requests: { where: { status: 'assigned', boardedAt: null }, select: { id: true, studentId: true, pointId: true } } },
      });
      if (!run) throw new NotFoundException('Run not found');
      const ids = run.stops.map((s) => s.pointId);
      const legs = await this.prisma.db.travelTime.findMany({ where: { fromKey: { in: ids }, toKey: { in: ids } } });
      const seqOf = new Map(run.stops.map((s) => [s.pointId, s.seq + 1]));
      return {
        universityId,
        driverId: run.driverId,
        status: run.status,
        stops: run.stops.map((s) => ({ seq: s.seq + 1, pointId: s.pointId, lat: s.point.lat, lng: s.point.lng, served: !!s.servedAt })),
        riders: run.requests.map((r) => ({ requestId: r.id, studentId: r.studentId, seq: seqOf.get(r.pointId) ?? 0 })),
        legs: new Map(legs.map((l) => [`${l.fromKey}|${l.toKey}`, l.durationS])),
        until: Date.now() + ROUTE_TTL_MS,
      };
    });
    this.routes.set(runId, route);
    return route;
  }
}

function sanitize(raw: GpsPoint[]) {
  const now = Date.now();
  return (Array.isArray(raw) ? raw : [])
    .filter((p) => p && Number.isFinite(p.lat) && Number.isFinite(p.lng) && Math.abs(p.lat) <= 90 && Math.abs(p.lng) <= 180)
    .map((p) => {
      const t = Date.parse(p.at);
      // Device clocks drift: never accept the future, and fall back to now for unparsable times.
      const at = new Date(Number.isFinite(t) ? Math.min(t, now) : now);
      return { lat: p.lat, lng: p.lng, at, speed: Number.isFinite(p.speed) ? (p.speed as number) : null, heading: Number.isFinite(p.heading) ? (p.heading as number) : null };
    })
    .sort((a, b) => a.at.getTime() - b.at.getTime())
    .slice(-2000);
}
