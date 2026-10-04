import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LatLng } from '../geo/geo';

export interface Leg {
  distanceM: number;
  durationS: number;
}

export interface Matrix {
  /** durations[i][j] in seconds, distances[i][j] in metres; null when unreachable. */
  durations: (number | null)[][];
  distances: (number | null)[][];
}

/** Thin client for a self-hosted OSRM (driving profile). Coordinates are sent as lng,lat. */
@Injectable()
export class OsrmClient {
  private readonly log = new Logger(OsrmClient.name);
  constructor(private readonly config: ConfigService) {}

  private get base() {
    return this.config.getOrThrow<string>('OSRM_URL');
  }

  private coords(points: LatLng[]) {
    return points.map((p) => `${p.lng.toFixed(6)},${p.lat.toFixed(6)}`).join(';');
  }

  private async get<T>(path: string, timeoutMs: number): Promise<T> {
    let res: Response;
    try {
      res = await fetch(`${this.base}${path}`, { signal: AbortSignal.timeout(timeoutMs) });
    } catch (e) {
      this.log.warn(`OSRM unreachable: ${(e as Error).message}`);
      throw new ServiceUnavailableException('Routing service unavailable');
    }
    const body = (await res.json()) as { code?: string } & T;
    if (body.code !== 'Ok') throw new ServiceUnavailableException(`Routing failed: ${body.code}`);
    return body;
  }

  async route(from: LatLng, to: LatLng): Promise<Leg> {
    const body = await this.get<{ routes: { distance: number; duration: number }[] }>(
      `/route/v1/driving/${this.coords([from, to])}?overview=false`,
      5000,
    );
    return { distanceM: Math.round(body.routes[0].distance), durationS: Math.round(body.routes[0].duration) };
  }

  async table(points: LatLng[]): Promise<Matrix> {
    const body = await this.get<{ durations: (number | null)[][]; distances: (number | null)[][] }>(
      `/table/v1/driving/${this.coords(points)}?annotations=duration,distance`,
      30000,
    );
    return { durations: body.durations, distances: body.distances };
  }
}
