import { Inject, Injectable, Logger } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS } from '../redis/redis.module';

export type ConfigKind = 'tiers' | 'points' | 'waves' | 'driver-requirements';

/**
 * Redis cache for rarely changing configuration (NF-04). Reads fall back to the loader when
 * Redis is unavailable, so a cache outage never breaks the API.
 */
@Injectable()
export class ConfigCache {
  private readonly log = new Logger(ConfigCache.name);
  static readonly TTL_S = 3600;

  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  static key(universityId: string, kind: ConfigKind) {
    return `cfg:${universityId}:${kind}`;
  }

  private async ready() {
    if (this.redis.status === 'wait') await this.redis.connect();
  }

  async get<T>(universityId: string, kind: ConfigKind, load: () => Promise<T>): Promise<T> {
    const key = ConfigCache.key(universityId, kind);
    try {
      await this.ready();
      const hit = await this.redis.get(key);
      if (hit !== null) return JSON.parse(hit) as T;
    } catch (e) {
      this.log.warn(`cache read failed: ${(e as Error).message}`);
    }
    const value = await load();
    try {
      await this.redis.set(key, JSON.stringify(value), 'EX', ConfigCache.TTL_S);
    } catch {
      /* cache is best-effort */
    }
    return value;
  }

  async invalidate(universityId: string, ...kinds: ConfigKind[]) {
    try {
      await this.ready();
      await this.redis.del(...kinds.map((k) => ConfigCache.key(universityId, k)));
    } catch (e) {
      this.log.warn(`cache invalidate failed: ${(e as Error).message}`);
    }
  }
}
