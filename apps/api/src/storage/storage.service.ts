import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';

export const MAX_LINK_TTL_S = 300;

/**
 * Private file storage for driver documents (NF-13). Files live outside any public path and are
 * only readable through short-lived HMAC-signed links served by the API (`GET /files/:token`).
 * An S3/MinIO adapter can replace the disk backend later without changing callers.
 */
@Injectable()
export class StorageService implements OnModuleInit {
  private root: string;
  private secret: string;

  constructor(config: ConfigService) {
    this.root = resolve(config.get('STORAGE_DIR', './storage'));
    this.secret = config.get('STORAGE_SECRET') ?? `${config.getOrThrow<string>('JWT_SECRET')}:files`;
  }

  async onModuleInit() {
    await mkdir(this.root, { recursive: true, mode: 0o700 });
  }

  async put(prefix: string, data: Buffer): Promise<string> {
    const key = `${prefix.replace(/[^a-zA-Z0-9/_-]/g, '')}/${randomUUID()}`;
    const path = join(this.root, key);
    await mkdir(join(path, '..'), { recursive: true, mode: 0o700 });
    await writeFile(path, data, { mode: 0o600 });
    return key;
  }

  read(key: string): Promise<Buffer> {
    const path = resolve(this.root, key);
    if (!path.startsWith(this.root + '/')) throw new Error('Invalid storage key');
    return readFile(path);
  }

  private mac(payload: string) {
    return createHmac('sha256', this.secret).update(payload).digest('base64url');
  }

  /** Signed link token valid for `ttlS` seconds (capped at 5 minutes). */
  sign(key: string, mime: string, ttlS = MAX_LINK_TTL_S, now = Date.now()) {
    const exp = Math.floor(now / 1000) + Math.min(ttlS, MAX_LINK_TTL_S);
    const payload = Buffer.from(JSON.stringify({ k: key, m: mime, e: exp })).toString('base64url');
    return { token: `${payload}.${this.mac(payload)}`, expiresAt: new Date(exp * 1000) };
  }

  /** Returns the key and mime type if the token is authentic and unexpired, otherwise null. */
  verify(token: string, now = Date.now()): { key: string; mime: string } | null {
    const [payload, sig] = token.split('.');
    if (!payload || !sig) return null;
    const expected = Buffer.from(this.mac(payload));
    const given = Buffer.from(sig);
    if (expected.length !== given.length || !timingSafeEqual(expected, given)) return null;
    try {
      const { k, m, e } = JSON.parse(Buffer.from(payload, 'base64url').toString()) as { k: string; m: string; e: number };
      if (e * 1000 < now) return null;
      return { key: k, mime: m };
    } catch {
      return null;
    }
  }
}
