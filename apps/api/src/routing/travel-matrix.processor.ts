import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service';
import { runAsTenant } from '../tenancy/tenant-context';
import { OsrmClient } from './osrm.client';
import { REBUILD_MATRIX, ROUTING_QUEUE } from './routing.service';

export const CAMPUS_KEY = 'campus';

/** Rebuilds the full point × point (+ campus) travel matrix of one university (DS-01). */
@Processor(ROUTING_QUEUE)
export class TravelMatrixProcessor extends WorkerHost {
  private readonly log = new Logger(TravelMatrixProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly osrm: OsrmClient,
  ) {
    super();
  }

  async process(job: Job<{ universityId: string }>) {
    if (job.name !== REBUILD_MATRIX) return;
    return rebuildMatrix(this.prisma, this.osrm, job.data.universityId, this.log);
  }
}

export async function rebuildMatrix(prisma: PrismaService, osrm: OsrmClient, universityId: string, log?: Logger) {
  return runAsTenant(universityId, async () => {
    const db = prisma.db;
    const uni = await db.university.findUniqueOrThrow({ where: { id: universityId } });
    const points = await db.gatheringPoint.findMany({ where: { active: true }, orderBy: { createdAt: 'asc' } });
    const nodes = [{ key: CAMPUS_KEY, lat: uni.campusLat, lng: uni.campusLng }, ...points.map((p) => ({ key: p.id, lat: p.lat, lng: p.lng }))];

    const rows: { universityId: string; fromKey: string; toKey: string; durationS: number; distanceM: number }[] = [];
    if (nodes.length > 1) {
      const m = await osrm.table(nodes);
      nodes.forEach((from, i) =>
        nodes.forEach((to, j) => {
          if (i === j) return;
          const d = m.durations[i]?.[j];
          const dist = m.distances[i]?.[j];
          if (d == null || dist == null) return; // unreachable pairs are simply absent
          rows.push({ universityId, fromKey: from.key, toKey: to.key, durationS: Math.round(d), distanceM: Math.round(dist) });
        }),
      );
    }
    await db.$transaction([db.travelTime.deleteMany({}), db.travelTime.createMany({ data: rows })]);
    log?.log(`Travel matrix for ${universityId}: ${nodes.length} nodes, ${rows.length} pairs`);
    return { nodes: nodes.length, pairs: rows.length };
  });
}
