import { ConfigService } from '@nestjs/config';
import { StorageService } from './storage.service';

describe('StorageService signed links', () => {
  const s = new StorageService(new ConfigService({ JWT_SECRET: 'x'.repeat(32), STORAGE_DIR: '/tmp/naql-storage-test' }));

  it('[T2-09] links are capped at 5 minutes and stop working after expiry', () => {
    const now = Date.now();
    const { token, expiresAt } = s.sign('drivers/a/b', 'image/jpeg', 3600, now);
    expect(expiresAt.getTime() - now).toBeLessThanOrEqual(300_000);
    expect(s.verify(token, now)).toEqual({ key: 'drivers/a/b', mime: 'image/jpeg' });
    expect(s.verify(token, now + 301_000)).toBeNull();
  });

  it('[T2-09] tampered or foreign tokens are rejected', () => {
    const { token } = s.sign('drivers/a/b', 'image/jpeg');
    const [payload, sig] = token.split('.');
    const forged = Buffer.from(JSON.stringify({ k: 'drivers/other', m: 'image/jpeg', e: 9999999999 })).toString('base64url');
    expect(s.verify(`${forged}.${sig}`)).toBeNull();
    expect(s.verify(`${payload}.${sig.slice(0, -2)}xx`)).toBeNull();
    expect(s.verify('garbage')).toBeNull();
    const other = new StorageService(new ConfigService({ JWT_SECRET: 'y'.repeat(32), STORAGE_DIR: '/tmp/naql-storage-test' }));
    expect(other.verify(token)).toBeNull();
  });
});
