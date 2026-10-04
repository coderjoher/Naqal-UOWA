import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { AuditInterceptor } from './audit/audit.interceptor';
import { AuthModule } from './auth/auth.module';
import { HealthController } from './health/health.controller';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { TenantMiddleware } from './tenancy/tenant.middleware';
import { UniversitiesController } from './universities/universities.controller';
import { UsersController } from './users/users.controller';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), PrismaModule, RedisModule, AuthModule],
  controllers: [HealthController, UniversitiesController, UsersController],
  providers: [{ provide: APP_INTERCEPTOR, useClass: AuditInterceptor }],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(TenantMiddleware).forRoutes('*path');
  }
}
