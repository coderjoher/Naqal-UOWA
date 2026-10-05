/**
 * NF-06: a small stale-while-revalidate cache for heavy read models that office pages poll
 * (dispatch board, live operations). A value younger than `freshMs` is served as is; an older one
 * is still served immediately while one background refresh replaces it; concurrent misses share
 * one load.
 */
export class SwrCache<T> {
  private readonly entries = new Map<string, { value: T; at: number }>();
  private readonly loading = new Map<string, Promise<T>>();

  constructor(
    private readonly freshMs: number,
    private readonly maxEntries = 200,
  ) {}

  async get(key: string, load: () => Promise<T>): Promise<T> {
    const hit = this.entries.get(key);
    if (hit) {
      if (Date.now() - hit.at > this.freshMs) void this.refresh(key, load).catch(() => undefined);
      return hit.value;
    }
    return this.refresh(key, load);
  }

  /**
   * Entries whose key starts with `prefix` (e.g. a university id): `hard` drops them so the next
   * read waits for fresh data (the office's own action); otherwise they are only marked stale, so
   * a burst of student and driver activity never makes office pages wait.
   */
  invalidate(prefix: string, hard = false) {
    for (const [k, e] of [...this.entries]) {
      if (!k.startsWith(prefix)) continue;
      if (hard) this.entries.delete(k);
      else e.at = 0;
    }
  }

  private refresh(key: string, load: () => Promise<T>): Promise<T> {
    const running = this.loading.get(key);
    if (running) return running;
    const p = load()
      .then((value) => {
        if (this.entries.size >= this.maxEntries) this.entries.delete(this.entries.keys().next().value!);
        this.entries.set(key, { value, at: Date.now() });
        return value;
      })
      .finally(() => this.loading.delete(key));
    this.loading.set(key, p);
    return p;
  }
}

/** Shared by the dispatch board and live operations; invalidated by every dispatch change. */
export const officeViews = new SwrCache<unknown>(5000);
