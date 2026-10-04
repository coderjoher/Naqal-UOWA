import { BullModule } from '@nestjs/bullmq';
import { Global, Module } from '@nestjs/common';
import { OsrmClient } from './osrm.client';
import { ROUTING_QUEUE, RoutingService } from './routing.service';
import { TravelMatrixProcessor } from './travel-matrix.processor';

@Global()
@Module({
  imports: [BullModule.registerQueue({ name: ROUTING_QUEUE })],
  providers: [OsrmClient, RoutingService, TravelMatrixProcessor],
  exports: [OsrmClient, RoutingService],
})
export class RoutingModule {}
