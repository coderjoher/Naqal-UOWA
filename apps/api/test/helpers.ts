import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { setupApp } from '../src/setup-app';

/** Unscoped client for arranging test data. */
export const raw = new PrismaClient();

export const PASSWORD = 'password123';
let hash: string | undefined;

export async function resetDb() {
  await raw.$executeRawUnsafe('TRUNCATE audit_events, users, universities CASCADE');
}

export async function createUniversity(slug: string) {
  return raw.university.create({ data: { name: `Uni ${slug}`, slug, campusLat: 32.6, campusLng: 44.0 } });
}

export async function createUser(role: Role, universityId: string | null, email: string, extra: object = {}) {
  hash ??= await bcrypt.hash(PASSWORD, 4);
  return raw.user.create({ data: { role, universityId, email, name: email, passwordHash: hash, ...extra } });
}

export async function createApp(): Promise<INestApplication> {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = setupApp(moduleRef.createNestApplication());
  await app.init();
  return app;
}

export async function login(app: INestApplication, email: string): Promise<string> {
  const res = await request(app.getHttpServer()).post('/auth/login').send({ email, password: PASSWORD }).expect(200);
  return res.body.accessToken;
}
