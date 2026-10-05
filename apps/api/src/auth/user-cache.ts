import type { Role, UserStatus } from '@prisma/client';

export interface CachedUser {
  id: string;
  role: Role;
  universityId: string | null;
  status: UserStatus;
}

/**
 * NF-06: the auth guard checks on every request that the user still exists and is active. At the
 * morning peak that is hundreds of identical lookups a second, so answers are kept briefly
 * (AUTH_CACHE_MS, default 10 s; 0 turns it off). A suspension made through the API is forgotten
 * at once on that process; on other API workers it takes effect within the cache time.
 */
class UserCache {
  private readonly entries = new Map<string, { user: CachedUser | null; until: number }>();
  private readonly ttl = () => Number(process.env.AUTH_CACHE_MS ?? 10_000);

  async get(id: string, load: () => Promise<CachedUser | null>): Promise<CachedUser | null> {
    const ttl = this.ttl();
    if (ttl <= 0) return load();
    const hit = this.entries.get(id);
    if (hit && hit.until > Date.now()) return hit.user;
    const user = await load();
    if (this.entries.size > 50_000) this.entries.clear();
    this.entries.set(id, { user, until: Date.now() + ttl });
    return user;
  }

  forget(id: string) {
    this.entries.delete(id);
  }
}

export const userCache = new UserCache();

/**
 * Verified access tokens until they expire. Checking an HMAC signature is cheap but not free, and
 * the same token arrives with every request a phone makes; a token string that verified once is
 * still valid until its `exp`. Off together with the user cache (AUTH_CACHE_MS=0).
 */
class TokenCache {
  private readonly entries = new Map<string, { payload: Record<string, unknown>; exp: number }>();

  async verify<T extends Record<string, unknown>>(token: string, verify: () => Promise<T>): Promise<T> {
    if (Number(process.env.AUTH_CACHE_MS ?? 10_000) <= 0) return verify();
    const hit = this.entries.get(token);
    if (hit && hit.exp > Date.now()) return hit.payload as T;
    const payload = await verify();
    const exp = typeof payload.exp === 'number' ? payload.exp * 1000 : Date.now() + 60_000;
    if (this.entries.size > 50_000) this.entries.clear();
    this.entries.set(token, { payload, exp });
    return payload;
  }
}

export const tokenCache = new TokenCache();
