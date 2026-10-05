import './observability/instrument';
import cluster from 'node:cluster';
import { createServer } from 'node:http';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { AggregatorRegistry, register } from 'prom-client';
import { AppModule } from './app.module';
import { setupApp } from './setup-app';

/**
 * NF-08: one process per core with API_WORKERS (default 1). Workers share the port; realtime
 * events cross workers through the Redis Socket.IO adapter, queues and rate limits live in Redis.
 * Clients use the WebSocket transport, so no sticky sessions are needed.
 */
const WORKERS = Math.max(1, Number(process.env.API_WORKERS ?? 1));

async function bootstrap() {
  const app = setupApp(await NestFactory.create<NestExpressApplication>(AppModule));
  // Behind nginx / a load balancer: the client IP (rate limits) comes from X-Forwarded-For.
  app.set('trust proxy', Number(process.env.TRUST_PROXY_HOPS ?? 1));
  app.enableCors({ origin: process.env.CORS_ORIGIN?.split(',') ?? true });
  app.enableShutdownHooks();

  const doc = new DocumentBuilder().setTitle('Naql Jamiat Warith API').setVersion('0.1').addBearerAuth().build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, doc), { jsonDocumentUrl: 'docs/openapi.json' });

  await app.listen(process.env.PORT ?? 3000);
}

/** Prometheus endpoint on METRICS_PORT (default 9464): all workers' metrics in one scrape. */
function serveMetrics(collect: () => Promise<string>, contentType: string) {
  const port = Number(process.env.METRICS_PORT ?? 9464);
  createServer(async (req, res) => {
    const want = process.env.METRICS_TOKEN;
    if (req.url !== '/metrics' || (want && req.headers.authorization !== `Bearer ${want}`)) {
      res.writeHead(req.url === '/metrics' ? 401 : 404).end();
      return;
    }
    try {
      const body = await collect();
      res.writeHead(200, { 'content-type': contentType }).end(body);
    } catch (e) {
      res.writeHead(500).end((e as Error).message);
    }
  })
    // Another local API already serves metrics on this port: carry on without them.
    .on('error', (e) => console.warn(`Metrics port ${port} unavailable: ${e.message}`))
    .listen(port);
}

if (WORKERS > 1 && cluster.isPrimary) {
  for (let i = 0; i < WORKERS; i++) cluster.fork();
  cluster.on('exit', (w, code) => {
    console.error(`API worker ${w.process.pid} exited (${code}); starting a new one`);
    cluster.fork();
  });
  const aggregator = new AggregatorRegistry();
  serveMetrics(() => aggregator.clusterMetrics(), aggregator.contentType);
} else {
  // prom-client answers the primary's metrics requests only once a worker has created an
  // AggregatorRegistry (that is what installs its IPC listener).
  if (cluster.isWorker) new AggregatorRegistry();
  if (WORKERS === 1) serveMetrics(() => register.metrics(), register.contentType);
  bootstrap();
}
