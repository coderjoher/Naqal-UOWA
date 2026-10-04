import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { Queue } from 'bullmq';
import { LatLng, haversineKm } from '../geo/geo';
import { OsrmClient } from './osrm.client';

export const ROUTING_QUEUE = 'routing';
export const REBUILD_MATRIX = 'travel-matrix.rebuild';

/** Road factor used only when OSRM is unreachable, so a point can still get a provisional tier. */
export const FALLBACK_ROAD_FACTOR = 1.3;

@Injectable()
export class RoutingService {
  private readonly log = new Logger(RoutingService.name);

  constructor(
    @InjectQueue(ROUTING_QUEUE) private readonly queue: Queue,
    private readonly osrm: OsrmClient,
  ) {}

  /**
   * Queue one matrix rebuild per university. Several point edits within the debounce window
   * collapse into a single job because the job id is fixed while it waits.
   */
  async scheduleMatrixRebuild(universityId: string, delayMs = 2000) {
    await this.queue.add(
      REBUILD_MATRIX,
      { universityId },
      { jobId: `matrix-${universityId}`, delay: delayMs, removeOnComplete: true, removeOnFail: 50, attempts: 3, backoff: { type: 'exponential', delay: 5000 } },
    );
  }

  /** Road distance/duration to campus; falls back to straight-line × road factor when OSRM is down. */
  async toCampus(point: LatLng, campus: LatLng): Promise<{ distanceKm: number; durationMin: number | null; approximate: boolean }> {
    try {
      const leg = await this.osrm.route(point, campus);
      return { distanceKm: leg.distanceM / 1000, durationMin: leg.durationS / 60, approximate: false };
    } catch {
      this.log.warn('OSRM unavailable, using straight-line distance for tier');
      return { distanceKm: haversineKm(point, campus) * FALLBACK_ROAD_FACTOR, durationMin: null, approximate: true };
    }
  }
}
