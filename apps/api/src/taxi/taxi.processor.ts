import { InjectQueue, Processor, WorkerHost } from '@nestjs/bullmq';
import { OnModuleInit } from '@nestjs/common';
import { Queue } from 'bullmq';
import { TaxiService } from './taxi.service';

export const TAXI_QUEUE = 'taxi';
export const TAXI_SWEEP = 'taxi.sweep';

/** Expires taxi requests nobody accepted, every 20 seconds (NF-03: off the request path). */
@Processor(TAXI_QUEUE)
export class TaxiProcessor extends WorkerHost implements OnModuleInit {
  constructor(
    private readonly taxi: TaxiService,
    @InjectQueue(TAXI_QUEUE) private readonly queue: Queue,
  ) {
    super();
  }

  async onModuleInit() {
    if (process.env.DISPATCH_TICK === 'off') return;
    await this.queue.upsertJobScheduler('taxi-sweep', { every: 20_000 }, { name: TAXI_SWEEP, opts: { removeOnComplete: true, removeOnFail: 20 } });
  }

  async process() {
    return this.taxi.expireDue();
  }
}
