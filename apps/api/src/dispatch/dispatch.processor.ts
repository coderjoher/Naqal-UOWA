import { InjectQueue, Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger, OnModuleInit } from '@nestjs/common';
import { Job, Queue } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service';
import { runAsSystem } from '../tenancy/tenant-context';
import { baghdadDate, runsOn, secondsInto } from './clock';
import { DISPATCH_QUEUE, DispatchEngine, PLAN_LEAD_MIN, WAITLIST_EXPIRE, WAITLIST_RECHECK, WAVE_PLAN, WAVE_TICK, WaveRef } from './dispatch.engine';

/** NF-03: planning, re-checks and expiries run in BullMQ workers, never on the request path. */
@Processor(DISPATCH_QUEUE)
export class DispatchProcessor extends WorkerHost implements OnModuleInit {
  private readonly log = new Logger(DispatchProcessor.name);

  constructor(
    private readonly engine: DispatchEngine,
    private readonly prisma: PrismaService,
    @InjectQueue(DISPATCH_QUEUE) private readonly queue: Queue,
  ) {
    super();
  }

  async onModuleInit() {
    if (process.env.DISPATCH_TICK === 'off') return;
    // Once a minute: plan every wave whose planning time has come.
    await this.queue.upsertJobScheduler('wave-tick', { every: 60_000 }, { name: WAVE_TICK, opts: { removeOnComplete: true, removeOnFail: 20 } });
  }

  async process(job: Job<WaveRef & { requestId?: string }>) {
    switch (job.name) {
      case WAVE_PLAN:
        return this.engine.plan(job.data);
      case WAITLIST_RECHECK:
      case WAITLIST_EXPIRE:
        return this.engine.recheck(job.data);
      case WAVE_TICK:
        return this.tick();
    }
  }

  /** Finds waves due for planning (wave time − lead) today that have no plan yet. */
  async tick(now = this.engine.now()) {
    // Today and tomorrow: a wave just after midnight is due for planning the evening before.
    const dates = [baghdadDate(now), baghdadDate(now, 1)];
    const due = await runAsSystem(async () => {
      const waves = await this.prisma.db.wave.findMany({ where: { active: true }, include: { plans: { where: { date: { in: dates.map((d) => new Date(`${d}T00:00:00Z`)) } } } } });
      return dates.flatMap((date) => {
        const at = secondsInto(date, now);
        return waves
          .filter((w) => runsOn(w.weekdays, date) && !w.plans.some((p) => p.date.toISOString().startsWith(date)) && at >= w.minuteOfDay * 60 - PLAN_LEAD_MIN * 60 && at < w.minuteOfDay * 60)
          .map((w) => ({ ...w, date }));
      });
    });
    for (const w of due) await this.engine.enqueuePlan({ universityId: w.universityId, waveId: w.id, date: w.date });
    if (due.length) this.log.log(`Tick: queued ${due.length} wave plan(s)`);
    return { queued: due.length };
  }
}
