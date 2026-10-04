import { INestApplicationContext } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';
import type { ServerOptions } from 'socket.io';

/** Socket.IO over Redis pub/sub so every API instance reaches every socket (NF-01). */
export class RedisIoAdapter extends IoAdapter {
  private pub?: Redis;
  private sub?: Redis;

  constructor(app: INestApplicationContext, private readonly url: string) {
    super(app);
  }

  createIOServer(port: number, options?: ServerOptions) {
    const server = super.createIOServer(port, options);
    this.pub ??= new Redis(this.url, { maxRetriesPerRequest: null });
    this.sub ??= this.pub.duplicate();
    server.adapter(createAdapter(this.pub, this.sub, { key: `${process.env.QUEUE_PREFIX ?? 'naql'}:io` }));
    return server;
  }

  async dispose() {
    this.pub?.disconnect();
    this.sub?.disconnect();
  }
}
