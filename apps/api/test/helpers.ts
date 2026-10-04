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
  await raw.$executeRawUnsafe(
    'TRUNCATE subscriptions, payments, receipt_counters, otp_codes, document_accesses, driver_documents, driver_profiles, roster_entries, travel_times, gathering_points, distance_tiers, waves, driver_requirement_sets, audit_events, users, universities CASCADE',
  );
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

/** Karbala test geography: campus and a service-area square around the city. */
export const CAMPUS = { lat: 32.5847, lng: 44.0617 };
export const KARBALA_SQUARE: [number, number][] = [
  [32.45, 43.85],
  [32.45, 44.25],
  [32.75, 44.25],
  [32.75, 43.85],
];

export async function createConfiguredUniversity(slug: string) {
  return raw.university.create({ data: { name: `Uni ${slug}`, slug, campusLat: CAMPUS.lat, campusLng: CAMPUS.lng, coverage: KARBALA_SQUARE } });
}

export const auth = (token: string) => ({ Authorization: `Bearer ${token}` });
