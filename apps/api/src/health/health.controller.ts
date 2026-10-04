import { Controller, Get, HttpStatus, Inject, Res } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import Redis from 'ioredis';
import { Public } from '../auth/decorators';
import { PrismaService } from '../prisma/prisma.service';
import { REDIS } from '../redis/redis.module';

type Check = 'ok' | 'down';

async function check(fn: () => Promise<unknown>, ms = 2000): Promise<Check> {
  let timer: NodeJS.Timeout | undefined;
  try {
    await Promise.race([fn(), new Promise((_, rej) => (timer = setTimeout(() => rej(new Error('timeout')), ms)))]);
    return 'ok';
  } catch {
    return 'down';
  } finally {
    clearTimeout(timer);
  }
}

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    private readonly config: ConfigService,
  ) {}

  @Public()
  @Get()
  async health(@Res({ passthrough: true }) res: Response) {
    const osrm = this.config.getOrThrow<string>('OSRM_URL');
    const checks = {
      db: await check(() => this.prisma.db.$queryRaw`SELECT 1`),
      redis: await check(async () => {
        if (this.redis.status === 'wait') await this.redis.connect();
        if ((await this.redis.ping()) !== 'PONG') throw new Error('no pong');
      }),
      // Any point pair inside Karbala; OSRM answers code "Ok" when the extract is loaded.
      osrm: await check(async () => {
        const r = await fetch(`${osrm}/route/v1/driving/44.0249,32.6160;44.0300,32.6200?overview=false`, { signal: AbortSignal.timeout(2000) });
        const body = (await r.json()) as { code?: string };
        if (body.code !== 'Ok') throw new Error('osrm not ready');
      }),
    };
    const ok = Object.values(checks).every((c) => c === 'ok');
    res.status(ok ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE);
    return { status: ok ? 'ok' : 'degraded', checks };
  }
}
