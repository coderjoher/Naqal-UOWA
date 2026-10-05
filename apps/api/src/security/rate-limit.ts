import { CanActivate, ExecutionContext, HttpException, HttpStatus, Inject, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import Redis from 'ioredis';
import { REDIS } from '../redis/redis.module';

/**
 * NF-13 / T8-03: brute-force protection for sign-in endpoints. Fixed windows in Redis, shared by
 * every API instance. Each rule counts per client IP, optionally combined with an account
 * identifier from the body (so one attacker cannot lock out everyone behind the same NAT).
 */
export interface RateRule {
  /** Counter name. */
  name: string;
  /** Requests allowed per window. */
  limit: number;
  windowS: number;
  /** Body fields that identify the account (joined); omit to count per IP only. */
  by?: string[];
}

const RATE_LIMIT = 'rateLimit';
export const RateLimit = (...rules: RateRule[]) => SetMetadata(RATE_LIMIT, rules);

/** Env override for load tests and local runs: RATE_LIMIT_FACTOR=10 allows ten times more. */
const factor = () => Math.max(Number(process.env.RATE_LIMIT_FACTOR ?? 1) || 1, 1);

export class TooManyRequestsException extends HttpException {
  constructor(retryAfterS: number) {
    super({ statusCode: 429, message: 'Too many attempts. Try again later.', retryAfterS }, HttpStatus.TOO_MANY_REQUESTS);
  }
}

@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const rules = this.reflector.get<RateRule[] | undefined>(RATE_LIMIT, ctx.getHandler());
    if (!rules?.length) return true;
    const req = ctx.switchToHttp().getRequest();
    const res = ctx.switchToHttp().getResponse();
    if (this.redis.status === 'wait') await this.redis.connect();
    const ip = String(req.ip ?? req.socket?.remoteAddress ?? 'unknown');
    const now = Math.floor(Date.now() / 1000);
    for (const r of rules) {
      const id = r.by ? r.by.map((f) => String(req.body?.[f] ?? '').trim().toLowerCase()).join('|') : '';
      const window = Math.floor(now / r.windowS);
      const key = `rl:${r.name}:${ip}:${id}:${window}`;
      const [[, count]] = (await this.redis.multi().incr(key).expire(key, r.windowS + 5).exec()) as [[null, number], unknown];
      if (count > r.limit * factor()) {
        const retry = (window + 1) * r.windowS - now;
        res.setHeader?.('Retry-After', String(retry));
        throw new TooManyRequestsException(retry);
      }
    }
    return true;
  }
}

/** Limits used by the sign-in endpoints. */
export const LOGIN_LIMITS: RateRule[] = [
  { name: 'login-account', limit: 10, windowS: 600, by: ['email', 'studentId', 'university'] },
  { name: 'login-ip', limit: 300, windowS: 600 },
];
export const OTP_SEND_LIMITS: RateRule[] = [
  { name: 'otp-phone', limit: 5, windowS: 3600, by: ['phone'] },
  { name: 'otp-ip', limit: 60, windowS: 3600 },
];
export const OTP_VERIFY_LIMITS: RateRule[] = [
  { name: 'otp-verify', limit: 10, windowS: 600, by: ['phone'] },
  { name: 'otp-verify-ip', limit: 300, windowS: 600 },
];
