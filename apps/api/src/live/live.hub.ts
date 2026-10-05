import { Injectable } from '@nestjs/common';
import type { Server } from 'socket.io';

/** Socket.IO rooms. Students only ever join `run:{id}` of their own ride (NF-02). */
export const rooms = {
  run: (id: string) => `run:${id}`,
  ops: (universityId: string) => `ops:${universityId}`,
  user: (id: string) => `user:${id}`,
  driver: (id: string) => `driver:${id}`,
};

/** Live bus position as broadcast. Only the bus — never a student's location (NF-12). */
export interface BusPosition {
  runId: string;
  lat: number;
  lng: number;
  at: string;
  speed: number | null;
  heading: number | null;
  /** Seconds to each remaining stop, by stop number (1-based). */
  etas: { seq: number; seconds: number }[];
}

/**
 * Thin emitter used by services. The gateway registers the server on start; without it (unit
 * tests, workers) emits are dropped. With the Redis adapter, emits reach every API instance.
 */
@Injectable()
export class LiveHub {
  private server: Server | null = null;

  attach(server: Server) {
    this.server = server;
  }

  /** Sockets connected to this instance (the gateway's namespace). */
  socketCount(): number {
    const sockets = (this.server as unknown as { sockets?: { size?: number } } | null)?.sockets;
    return typeof sockets?.size === 'number' ? sockets.size : 0;
  }

  bus(universityId: string, pos: BusPosition) {
    this.server?.to(rooms.run(pos.runId)).to(rooms.ops(universityId)).emit('bus', pos);
  }

  runStatus(universityId: string, runId: string, driverId: string, payload: { status: string; seq?: number | null }) {
    this.server?.to(rooms.run(runId)).to(rooms.ops(universityId)).to(rooms.driver(driverId)).emit('run', { runId, ...payload });
  }

  /** DR-09: stops or riders changed (insertion, cancellation); clients refetch the run. */
  runChanged(universityId: string, runId: string, driverId: string) {
    this.server?.to(rooms.run(runId)).to(rooms.ops(universityId)).to(rooms.driver(driverId)).emit('run:updated', { runId });
  }

  toUser(userId: string, event: string, payload: unknown) {
    this.server?.to(rooms.user(userId)).emit(event, payload);
  }
}
