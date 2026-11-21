// Application bootstrap.
import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { join } from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.enableCors({
    origin: process.env.CORS_ORIGINS === '*' ? true : (process.env.CORS_ORIGINS || '*').split(','),
    credentials: true,
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.set('trust proxy', 1);

  // Serve locally-stored upload files when STORAGE_DRIVER=local.
  app.useStaticAssets(join(__dirname, '..', 'uploads'), { prefix: '/uploads' });

  await app.listen(process.env.PORT || 4000);
  new Logger('Bootstrap').log(`CHATE-MAHDI API listening on :${process.env.PORT || 4000}`);
}
bootstrap();
