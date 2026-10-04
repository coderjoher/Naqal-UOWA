import { INestApplication } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import { PaymentProvider } from '../src/payments/payment-provider';
import { PaymentsService } from '../src/payments/payments.service';
import { createPrisma } from '../src/prisma/prisma.service';
import { runAsTenant } from '../src/tenancy/tenant-context';
import { auth, createApp, createConfiguredUniversity, createUser, login, raw, resetDb } from './helpers';

describe('P3 subscriptions and cash payments (e2e)', () => {
  let app: INestApplication;
  let office: string;
  let student: string;
  let uniId: string;
  let studentUserId: string;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    await resetDb();
    uniId = (await createConfiguredUniversity('warith')).id;
    await raw.university.update({ where: { id: uniId }, data: { nameAr: 'جامعة وارث الأنبياء', officeNote: 'مكتب النقل — البناية ب، الطابق الأرضي، ٩–١' } });
    const tierB = await raw.distanceTier.create({ data: { universityId: uniId, name: 'B', minKm: 0, maxKm: null, subscriptionPrice: 60000, ridePrice: 2000 } });
    const point = await raw.gatheringPoint.create({ data: { universityId: uniId, name: 'Al-Abbas Square', nameAr: 'ساحة العباس', lat: 32.616, lng: 44.025, tierId: tierB.id, distanceKm: 4.8 } });
    await createUser('office', uniId, 'office@w.iq', { name: 'حسن المكتب' });
    studentUserId = (await createUser('student', uniId, 'zainab@w.iq', { studentId: 'W-1001', name: 'Zainab Kadhim', nameAr: 'زينب كاظم', gender: 'female', defaultPointId: point.id })).id;
    await createUser('student', uniId, 'nopoint@w.iq', { studentId: 'W-1002', name: 'No Point' });
    app = await createApp();
    office = await login(app, 'office@w.iq');
    student = await login(app, 'zainab@w.iq');
  });

  afterAll(async () => {
    await app.close();
    await raw.$disconnect();
  });

  it('[T3-01] recording a payment creates payment + active subscription + receipt number in one transaction', async () => {
    expect((await http().get('/subscriptions/me').set(auth(student)).expect(200)).body).toMatchObject({ status: 'none', price: 60000, tierName: 'B' });
    const preview = (await http().get('/subscriptions/preview?studentId=W-1001&month=2026-10').set(auth(office)).expect(200)).body;
    expect(preview).toMatchObject({ student: { nameAr: 'زينب كاظم', gender: 'female' }, tier: { name: 'B' }, price: 60000, month: '2026-10', alreadySubscribed: false });
    await http().get('/subscriptions/preview?studentId=NOPE').set(auth(office)).expect(404);

    const res = await http().post('/subscriptions').set(auth(office)).send({ studentId: 'W-1001', month: '2026-10' }).expect(201);
    expect(res.body.payment).toMatchObject({ receiptNo: 1, amount: 60000 });
    expect(res.body.subscription).toMatchObject({ month: '2026-10', price: 60000, status: 'active' });

    const pay = await raw.payment.findUniqueOrThrow({ where: { id: res.body.payment.id } });
    expect(pay).toMatchObject({ type: 'subscription', method: 'cash_office', studentId: studentUserId, universityId: uniId });

    // Same month twice → conflict, and nothing new is written (no receipt number consumed).
    await http().post('/subscriptions').set(auth(office)).send({ studentId: 'W-1001', month: '2026-10' }).expect(409);
    expect(await raw.payment.count()).toBe(1);
    expect((await raw.receiptCounter.findUniqueOrThrow({ where: { universityId: uniId } })).last).toBe(1);

    // A student without a gathering point cannot be charged yet.
    await http().post('/subscriptions').set(auth(office)).send({ studentId: 'W-1002', month: '2026-10' }).expect(400);
    await http().post('/subscriptions').set(auth(student)).send({ studentId: 'W-1001' }).expect(403);
  });

  it('[T3-09] the receipt PDF names the student, the amount and the receipt number', async () => {
    const pay = await raw.payment.findFirstOrThrow({ where: { receiptNo: 1 } });
    const res = await http().get(`/payments/${pay.id}/receipt.pdf`).set(auth(office)).buffer(true).parse((r, cb) => {
      const chunks: Buffer[] = [];
      r.on('data', (c: Buffer) => chunks.push(c));
      r.on('end', () => cb(null, Buffer.concat(chunks)));
    }).expect(200);
    expect(res.headers['content-type']).toBe('application/pdf');
    const dir = mkdtempSync(join(tmpdir(), 'receipt-'));
    writeFileSync(join(dir, 'r.pdf'), res.body);
    const text = execFileSync('pdftotext', ['-layout', join(dir, 'r.pdf'), '-']).toString();
    expect(text).toContain('60,000 IQD');
    expect(text).toMatch(/No\. 1\b/);
    expect(text).toContain('W-1001');
    // Arabic name is present (letters are shaped, so compare without joining forms).
    expect(text.normalize('NFKC')).toMatch(/زينب/);
  });

  it('[T3-02] receipt numbers stay unique and gap-free under 50 concurrent payments', async () => {
    const db = createPrisma();
    const payments = new PaymentsService({ db } as never, [{ method: 'cash_office', collect: async () => ({ externalRef: null }) }]);
    const officeUser = await raw.user.findFirstOrThrow({ where: { email: 'office@w.iq' } });
    const before = (await raw.receiptCounter.findUniqueOrThrow({ where: { universityId: uniId } })).last;
    await Promise.all(
      Array.from({ length: 50 }, (_, i) =>
        runAsTenant(uniId, () =>
          db.$transaction((tx) => payments.record(tx, { universityId: uniId, type: 'cash_fare', method: 'cash_office', amount: 2000, collectedById: officeUser.id, reference: `fare-${i}` })),
        ),
      ),
    );
    const numbers = (await raw.payment.findMany({ where: { universityId: uniId, type: 'cash_fare' }, select: { receiptNo: true } })).map((p) => p.receiptNo).sort((a, b) => a - b);
    expect(numbers).toEqual(Array.from({ length: 50 }, (_, i) => before + 1 + i));
    await db.$disconnect();
  });

  it('[T3-05] an electronic provider plugs in through PaymentProvider with no schema change', async () => {
    const charged: string[] = [];
    const zainCash: PaymentProvider = { method: 'zaincash', collect: async (amount, ref) => (charged.push(`${ref}:${amount}`), { externalRef: 'ZC-778899' }) };
    const db = createPrisma();
    const payments = new PaymentsService({ db } as never, [zainCash]);
    const officeUser = await raw.user.findFirstOrThrow({ where: { email: 'office@w.iq' } });
    const p = await runAsTenant(uniId, () =>
      db.$transaction((tx) => payments.record(tx, { universityId: uniId, type: 'subscription', method: 'zaincash', amount: 60000, studentId: studentUserId, collectedById: officeUser.id, reference: 'sub:test' })),
    );
    expect(p).toMatchObject({ method: 'zaincash', externalRef: 'ZC-778899', amount: 60000 });
    expect(charged).toEqual(['sub:test:60000']);
    expect(() => payments.provider('qi')).toThrow('not enabled');
    await db.$disconnect();
  });

  it('[T3-06] payments cannot be updated or deleted at the database level; a reversal nets to zero and is audited', async () => {
    const original = await raw.payment.findFirstOrThrow({ where: { receiptNo: 1 } });
    await expect(raw.payment.update({ where: { id: original.id }, data: { amount: 1 } })).rejects.toThrow(/immutable/);
    await expect(raw.payment.delete({ where: { id: original.id } })).rejects.toThrow(/immutable/);
    await expect(raw.$executeRawUnsafe(`UPDATE payments SET amount = 1 WHERE id = '${original.id}'`)).rejects.toBeInstanceOf(Prisma.PrismaClientKnownRequestError);

    await http().post(`/payments/${original.id}/reverse`).set(auth(office)).send({ reason: '' }).expect(400);
    const rev = (await http().post(`/payments/${original.id}/reverse`).set(auth(office)).send({ reason: 'Paid twice by mistake' }).expect(200)).body;
    expect(rev).toMatchObject({ amount: -60000, reversesPaymentId: original.id });
    await http().post(`/payments/${original.id}/reverse`).set(auth(office)).send({ reason: 'again' }).expect(409);
    await http().post(`/payments/${rev.id}/reverse`).set(auth(office)).send({ reason: 'undo' }).expect(400);

    const pair = await raw.payment.aggregate({ where: { OR: [{ id: original.id }, { reversesPaymentId: original.id }] }, _sum: { amount: true } });
    expect(pair._sum.amount).toBe(0);
    expect((await raw.payment.findUniqueOrThrow({ where: { id: original.id } })).amount).toBe(60000); // untouched
    expect((await raw.subscription.findFirstOrThrow({ where: { paymentId: original.id } })).status).toBe('cancelled');
    const audit = await raw.auditEvent.findFirst({ where: { action: 'POST /payments/:id/reverse' } });
    expect(audit?.payload).toMatchObject({ reason: 'Paid twice by mistake' });

    expect((await http().get('/subscriptions/me').set(auth(student)).expect(200)).body.status).toMatch(/none|expired/);
  });

  it('ST-03: the student sees status, tier, price, expiry and where to pay', async () => {
    const now = new Date();
    const month = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
    await http().post('/subscriptions').set(auth(office)).send({ studentId: 'W-1001', month }).expect(201);
    const me = (await http().get('/subscriptions/me').set(auth(student)).expect(200)).body;
    expect(me).toMatchObject({ status: expect.stringMatching(/active|expiring/), tierName: 'B', price: 60000, current: { month, price: 60000 } });
    expect(me.daysLeft).toBeGreaterThan(0);
    expect(me.payAt.officeNote).toContain('مكتب النقل');
  });
});
