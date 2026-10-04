import { BullModule } from '@nestjs/bullmq';
import { Global, MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { AuditInterceptor } from './audit/audit.interceptor';
import { AuthModule } from './auth/auth.module';
import { ConfigCache } from './config-cache/config-cache.service';
import { DriverRequirementsController } from './driver-requirements/requirements.controller';
import { DriverRequirementsService } from './driver-requirements/requirements.service';
import { DISPATCH_QUEUE, DispatchEngine } from './dispatch/dispatch.engine';
import { DispatchProcessor } from './dispatch/dispatch.processor';
import { RidesController } from './dispatch/rides.controller';
import { RidesService } from './dispatch/rides.service';
import { DriversController } from './drivers/drivers.controller';
import { DriversService } from './drivers/drivers.service';
import { ConsoleSmsSender, OtpService, SMS_SENDER } from './drivers/otp.service';
import { StudentAuthController } from './identity/student-auth.controller';
import { StudentAuthService } from './identity/student-auth.service';
import { FilesController } from './storage/files.controller';
import { StorageService } from './storage/storage.service';
import { OfficeCashProvider, PAYMENT_PROVIDERS } from './payments/payment-provider';
import { PaymentsService } from './payments/payments.service';
import { StudentsController } from './students/students.controller';
import { SubscriptionsController } from './subscriptions/subscriptions.controller';
import { SubscriptionsService } from './subscriptions/subscriptions.service';
import { StudentsService } from './students/students.service';
import { PointsController } from './gathering-points/points.controller';
import { PointsService } from './gathering-points/points.service';
import { HealthController } from './health/health.controller';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { RoutingModule } from './routing/routing.module';
import { TenantMiddleware } from './tenancy/tenant.middleware';
import { TiersController } from './tiers/tiers.controller';
import { TiersService } from './tiers/tiers.service';
import { UniversitiesController } from './universities/universities.controller';
import { UniversitiesService } from './universities/universities.service';
import { UsersController } from './users/users.controller';
import { WavesController } from './waves/waves.controller';
import { WavesService } from './waves/waves.service';

@Global()
@Module({ providers: [ConfigCache], exports: [ConfigCache] })
class CacheModule {}

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const url = new URL(config.getOrThrow<string>('REDIS_URL'));
        return {
          connection: {
            host: url.hostname,
            port: Number(url.port || 6379),
            password: url.password || undefined,
            db: url.pathname.length > 1 ? Number(url.pathname.slice(1)) : 0,
          },
          prefix: config.get('QUEUE_PREFIX', 'naql'),
        };
      },
    }),
    BullModule.registerQueue({ name: DISPATCH_QUEUE }),
    PrismaModule,
    RedisModule,
    CacheModule,
    RoutingModule,
    AuthModule,
  ],
  controllers: [
    HealthController,
    UniversitiesController,
    UsersController,
    TiersController,
    PointsController,
    WavesController,
    DriverRequirementsController,
    StudentAuthController,
    StudentsController,
    DriversController,
    FilesController,
    SubscriptionsController,
    RidesController,
  ],
  providers: [
    { provide: APP_INTERCEPTOR, useClass: AuditInterceptor },
    UniversitiesService,
    TiersService,
    PointsService,
    WavesService,
    DriverRequirementsService,
    StudentAuthService,
    StudentsService,
    DriversService,
    OtpService,
    StorageService,
    { provide: SMS_SENDER, useClass: ConsoleSmsSender },
    { provide: PAYMENT_PROVIDERS, useValue: [new OfficeCashProvider()] },
    DispatchEngine,
    DispatchProcessor,
    RidesService,
    PaymentsService,
    SubscriptionsService,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(TenantMiddleware).forRoutes('*path');
  }
}
