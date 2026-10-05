import { SwrCache } from './swr-cache';

describe('SwrCache (NF-06)', () => {
  it('serves fresh values, refreshes stale ones in the background and shares concurrent loads', async () => {
    jest.useFakeTimers({ now: 0 });
    const c = new SwrCache<number>(1000);
    let n = 0;
    const load = jest.fn(async () => ++n);
    expect(await Promise.all([c.get('u1:d', load), c.get('u1:d', load)])).toEqual([1, 1]);
    expect(load).toHaveBeenCalledTimes(1);
    expect(await c.get('u1:d', load)).toBe(1);
    jest.setSystemTime(1500);
    expect(await c.get('u1:d', load)).toBe(1); // stale served at once…
    await Promise.resolve();
    await Promise.resolve();
    expect(await c.get('u1:d', load)).toBe(2); // …and replaced
    c.invalidate('u1:', true);
    expect(await c.get('u1:d', load)).toBe(3);
    // Soft: the stale value is served once more while the refresh runs.
    c.invalidate('u1:');
    expect(await c.get('u1:d', load)).toBe(3);
    await Promise.resolve();
    await Promise.resolve();
    expect(await c.get('u1:d', load)).toBe(4);
    jest.useRealTimers();
  });

  it('a failed load is not cached', async () => {
    const c = new SwrCache<number>(1000);
    await expect(c.get('k', async () => Promise.reject(new Error('db down')))).rejects.toThrow('db down');
    expect(await c.get('k', async () => 7)).toBe(7);
  });
});
