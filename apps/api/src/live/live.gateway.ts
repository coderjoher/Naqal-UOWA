import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayInit, SubscribeMessage, WebSocketGateway, WebSocketServer, WsException } from '@nestjs/websockets';
import type { Role } from '@prisma/client';
import type { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';
import { runAsSystem, runAsTenant } from '../tenancy/tenant-context';
import { LiveHub, rooms } from './live.hub';
import { GpsPoint, LiveService } from './live.service';

interface SocketUser {
  id: string;
  role: Role;
  universityId: string;
}

/**
 * Realtime channel (replaces Laravel Reverb from the PRD). Clients connect to `/live` with
 * `auth: { token }`. Everyone gets their personal room; office staff get the university's ops
 * room; a student may join only the run they ride on (NF-02).
 */
@WebSocketGateway({ namespace: '/live', cors: { origin: true }, transports: ['websocket', 'polling'] })
export class LiveGateway implements OnGatewayInit, OnGatewayConnection {
  private readonly log = new Logger(LiveGateway.name);
  @WebSocketServer() server!: Server;

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly hub: LiveHub,
    private readonly live: LiveService,
  ) {}

  afterInit(server: Server) {
    this.hub.attach(server);
  }

  async handleConnection(socket: Socket) {
    try {
      const token = (socket.handshake.auth?.token as string | undefined) ?? String(socket.handshake.query?.token ?? '');
      const payload = await this.jwt.verifyAsync<{ sub: string }>(token);
      const user = await runAsSystem(() => this.prisma.db.user.findUnique({ where: { id: payload.sub }, select: { id: true, role: true, universityId: true, status: true } }));
      if (!user || user.status !== 'active' || !user.universityId) throw new Error('inactive');
      const me: SocketUser = { id: user.id, role: user.role, universityId: user.universityId };
      socket.data.user = me;
      await socket.join(rooms.user(me.id));
      if (me.role === 'office') await socket.join(rooms.ops(me.universityId));
      if (me.role === 'driver') await socket.join(rooms.driver(me.id));
      socket.emit('ready', { userId: me.id, role: me.role });
    } catch {
      socket.emit('error', { message: 'Unauthorized' });
      socket.disconnect(true);
    }
  }

  /** Join a run's room; the reply carries the last known position (NF-10). */
  @SubscribeMessage('join')
  async join(@ConnectedSocket() socket: Socket, @MessageBody() body: { runId?: string }) {
    const me = socket.data.user as SocketUser | undefined;
    const runId = body?.runId;
    if (!me || !runId || !/^[0-9a-f-]{36}$/i.test(runId)) throw new WsException('Bad request');
    const allowed = await runAsTenant(me.universityId, async () => {
      const db = this.prisma.db;
      if (me.role === 'office') return !!(await db.run.findUnique({ where: { id: runId }, select: { id: true } }));
      if (me.role === 'driver') return !!(await db.run.findFirst({ where: { id: runId, driverId: me.id }, select: { id: true } }));
      if (me.role === 'student') return !!(await db.rideRequest.findFirst({ where: { runId, studentId: me.id, status: { in: ['assigned', 'done'] } }, select: { id: true } }));
      return false;
    });
    if (!allowed) return { ok: false, error: 'forbidden' };
    await socket.join(rooms.run(runId));
    return { ok: true, bus: await this.live.last(me.universityId, runId) };
  }

  @SubscribeMessage('leave')
  async leave(@ConnectedSocket() socket: Socket, @MessageBody() body: { runId?: string }) {
    if (body?.runId) await socket.leave(rooms.run(body.runId));
    return { ok: true };
  }

  /** DR-05: drivers stream GPS here (or POST /runs/:id/gps for buffered batches). */
  @SubscribeMessage('gps')
  async gps(@ConnectedSocket() socket: Socket, @MessageBody() body: { runId?: string; points?: GpsPoint[] } & Partial<GpsPoint>) {
    const me = socket.data.user as SocketUser | undefined;
    if (!me || me.role !== 'driver' || !body?.runId) return { ok: false, error: 'forbidden' };
    const points = body.points ?? [{ lat: body.lat!, lng: body.lng!, at: body.at ?? new Date().toISOString(), speed: body.speed, heading: body.heading }];
    try {
      return { ok: true, ...(await this.live.ingest(me.id, me.universityId, body.runId, points)) };
    } catch (e) {
      this.log.debug(`gps rejected: ${(e as Error).message}`);
      return { ok: false, error: (e as Error).message };
    }
  }
}
