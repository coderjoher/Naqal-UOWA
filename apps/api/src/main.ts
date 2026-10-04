import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { setupApp } from './setup-app';

async function bootstrap() {
  const app = setupApp(await NestFactory.create(AppModule));
  app.enableCors({ origin: process.env.CORS_ORIGIN?.split(',') ?? true });
  app.enableShutdownHooks();

  const doc = new DocumentBuilder().setTitle('Naql Jamiat Warith API').setVersion('0.1').addBearerAuth().build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, doc), { jsonDocumentUrl: 'docs/openapi.json' });

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
