import { tokenCache, userCache } from './user-cache';

describe('auth caches (NF-06)', () => {
  afterEach(() => delete process.env.AUTH_CACHE_MS);

  it('remembers a user for the cache time and forgets on request', async () => {
    process.env.AUTH_CACHE_MS = '60000';
    const load = jest.fn(async () => ({ id: 'u1', role: 'student' as const, universityId: 'x', status: 'active' as const }));
    await userCache.get('u1', load);
    await userCache.get('u1', load);
    expect(load).toHaveBeenCalledTimes(1);
    userCache.forget('u1');
    await userCache.get('u1', load);
    expect(load).toHaveBeenCalledTimes(2);
  });

  it('reuses a verified token until it expires; AUTH_CACHE_MS=0 turns both caches off', async () => {
    process.env.AUTH_CACHE_MS = '60000';
    const exp = Math.floor(Date.now() / 1000) + 3600;
    const verify = jest.fn(async () => ({ sub: 'u1', exp }));
    await tokenCache.verify('tok-a', verify);
    await tokenCache.verify('tok-a', verify);
    expect(verify).toHaveBeenCalledTimes(1);

    const expired = jest.fn(async () => ({ sub: 'u1', exp: Math.floor(Date.now() / 1000) - 1 }));
    await tokenCache.verify('tok-b', expired);
    await tokenCache.verify('tok-b', expired);
    expect(expired).toHaveBeenCalledTimes(2);

    process.env.AUTH_CACHE_MS = '0';
    await tokenCache.verify('tok-a', verify);
    expect(verify).toHaveBeenCalledTimes(2);
  });
});
