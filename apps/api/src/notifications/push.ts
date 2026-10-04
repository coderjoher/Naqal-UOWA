import { Logger } from '@nestjs/common';
import { importPKCS8, SignJWT } from 'jose';

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}

export interface PushSender {
  send(m: PushMessage): Promise<'sent' | 'invalid-token' | 'failed'>;
}

export const PUSH_SENDER = Symbol('PUSH_SENDER');

/** Development: logs instead of sending. In-app delivery (socket + list) still works. */
export class LogPushSender implements PushSender {
  private readonly log = new Logger('Push');
  async send(m: PushMessage) {
    this.log.debug(`push → ${m.token.slice(0, 8)}…: ${m.title}`);
    return 'sent' as const;
  }
}

/**
 * Firebase Cloud Messaging HTTP v1 with a service account (FCM_SERVICE_ACCOUNT = the JSON key).
 * The OAuth token is cached until shortly before it expires.
 */
export class FcmPushSender implements PushSender {
  private readonly log = new Logger('FCM');
  private token: { value: string; until: number } | null = null;

  constructor(
    private readonly account: { project_id: string; client_email: string; private_key: string },
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  private async accessToken() {
    if (this.token && this.token.until > Date.now() + 60_000) return this.token.value;
    const key = await importPKCS8(this.account.private_key, 'RS256');
    const now = Math.floor(Date.now() / 1000);
    const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuer(this.account.client_email)
      .setAudience('https://oauth2.googleapis.com/token')
      .setIssuedAt(now)
      .setExpirationTime(now + 3600)
      .sign(key);
    const res = await this.fetchFn('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    });
    if (!res.ok) throw new Error(`FCM auth failed: ${res.status}`);
    const body = (await res.json()) as { access_token: string; expires_in: number };
    this.token = { value: body.access_token, until: Date.now() + body.expires_in * 1000 };
    return body.access_token;
  }

  async send(m: PushMessage) {
    try {
      const res = await this.fetchFn(`https://fcm.googleapis.com/v1/projects/${this.account.project_id}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${await this.accessToken()}`, 'content-type': 'application/json' },
        body: JSON.stringify({ message: { token: m.token, notification: { title: m.title, body: m.body }, data: m.data, android: { priority: 'high' } } }),
      });
      if (res.status === 404 || res.status === 400) return 'invalid-token' as const;
      return res.ok ? ('sent' as const) : ('failed' as const);
    } catch (e) {
      this.log.warn(`FCM send failed: ${(e as Error).message}`);
      return 'failed' as const;
    }
  }
}

export function pushSenderFromEnv(): PushSender {
  const raw = process.env.FCM_SERVICE_ACCOUNT;
  if (!raw) return new LogPushSender();
  return new FcmPushSender(JSON.parse(raw));
}
