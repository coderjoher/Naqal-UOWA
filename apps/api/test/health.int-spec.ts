import { INestApplication } from '@nestjs/common';
import { createServer, Server } from 'node:http';
import request from 'supertest';
import { createApp, raw } from './helpers';

/** Minimal OSRM stand-in so the health check can be exercised without the 1 GB extract. */
function fakeOsrm(port: number): Promise<Server> {
  const server = createServer((req, res) => {
    res.setHeader('content-type', 'application/json');
    res.end(JSON.stringify(req.url?.startsWith('/route/v1/driving/') ? { code: 'Ok', routes: [] } : { code: 'InvalidUrl' }));
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}

describe('health', () => {
  let app: INestApplication;
  beforeAll(async () => (app = await createApp()));
  afterAll(async () => {
    await app.close();
    await raw.$disconnect();
  });

  it('[T0-06] /health reports db, redis and osrm OK when all are up', async () => {
    const osrm = await fakeOsrm(Number(new URL(process.env.OSRM_URL!).port));
    try {
      const res = await request(app.getHttpServer()).get('/health').expect(200);
      expect(res.body).toEqual({ status: 'ok', checks: { db: 'ok', redis: 'ok', osrm: 'ok' } });
    } finally {
      osrm.closeAllConnections();
      osrm.close();
    }
  });

  it('[T0-06] /health returns 503 and names the failing dependency', async () => {
    const res = await request(app.getHttpServer()).get('/health').expect(503);
    expect(res.body).toEqual({ status: 'degraded', checks: { db: 'ok', redis: 'ok', osrm: 'down' } });
  });
});
