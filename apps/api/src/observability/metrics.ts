import { InjectQueue } from '@nestjs/bullmq';
import { Controller, Get, Header, Injectable, NestMiddleware, OnModuleInit, Req, UnauthorizedException } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { Queue } from 'bullmq';
import type { NextFunction, Request, Response } from 'express';
import { Counter, Gauge, Histogram, collectDefaultMetrics, register } from 'prom-client';
import { Public } from '../auth/decorators';
import { DISPATCH_QUEUE } from '../dispatch/dispatch.engine';
import { LiveHub } from '../live/live.hub';

/**
 * Prometheus metrics (NF-06 / NF-08 dashboards) in prom-client's global registry, so that in
 * cluster mode (API_WORKERS > 1) the primary process can aggregate all workers (see main.ts).
 */
collectDefaultMetrics({ prefix: 'naql_' });

export const httpDuration = new Histogram({
  name: 'naql_http_request_duration_seconds',
  help: 'REST request duration by route (the route pattern, not the raw URL)',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1, 2, 5],
});

export const httpErrors = new Counter({ name: 'naql_http_errors_total', help: '5xx responses', labelNames: ['route'] });

let sources: { queue: Queue; hub: LiveHub } | null = null;

new Gauge({
  name: 'naql_queue_jobs',
  help: 'Dispatch queue jobs by state',
  labelNames: ['state'],
  // Every worker sees the same Redis queue: report it once, not once per worker.
  aggregator: 'max',
  async collect() {
    if (!sources) return;
    const counts = await sources.queue.getJobCounts('waiting', 'active', 'delayed', 'failed').catch(() => ({}) as Record<string, number>);
    for (const [state, n] of Object.entries(counts)) this.set({ state }, n);
  },
});

new Gauge({
  name: 'naql_live_sockets',
  help: 'Connected realtime sockets',
  collect() {
    this.set(sources?.hub.socketCount() ?? 0);
  },
});

/** Times every request; the route label comes from the matched handler (low cardinality). */
@Injectable()
export class MetricsMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const end = httpDuration.startTimer();
    res.on('finish', () => {
      const route = (req as Request & { route?: { path?: string } }).route?.path ?? 'unmatched';
      if (route === '/metrics') return;
      end({ method: req.method, route, status: String(res.statusCode) });
      if (res.statusCode >= 500) httpErrors.inc({ route });
    });
    next();
  }
}

@ApiExcludeController()
@Controller()
export class MetricsController implements OnModuleInit {
  constructor(
    @InjectQueue(DISPATCH_QUEUE) private readonly queue: Queue,
    private readonly hub: LiveHub,
  ) {}

  onModuleInit() {
    sources = { queue: this.queue, hub: this.hub };
  }

  /**
   * This process's metrics. When METRICS_TOKEN is set, a matching bearer token is required.
   * In cluster mode scrape the primary's aggregated endpoint instead (METRICS_PORT).
   */
  @Public()
  @Get('metrics')
  @Header('content-type', register.contentType)
  async metrics(@Req() req: Request) {
    const want = process.env.METRICS_TOKEN;
    if (want && req.headers.authorization !== `Bearer ${want}`) throw new UnauthorizedException();
    return register.metrics();
  }
}
