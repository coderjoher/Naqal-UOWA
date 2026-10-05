import { INestApplication } from '@nestjs/common';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import ExcelJS from 'exceljs';
import { MonthFixture, seedMonth } from '../prisma/month-fixture';
import { auth, createApp, createConfiguredUniversity, createUser, login, raw, resetDb } from './helpers';

const MONTH = '2026-09';
const binary = (r: request.Test) =>
  r.buffer(true).parse((res, cb) => {
    const chunks: Buffer[] = [];
    res.on('data', (c: Buffer) => chunks.push(c));
    res.on('end', () => cb(null, Buffer.concat(chunks)));
  });

describe('P6 settlement and money reporting (e2e)', () => {
  let app: INestApplication;
  let office: string;
  let admin: string;
  let uniId: string;
  let otherId: string;
  let fx: MonthFixture;
  let fx2: MonthFixture;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    await resetDb();
    uniId = (await createConfiguredUniversity('warith')).id;
    await raw.university.update({ where: { id: uniId }, data: { nameAr: 'جامعة وارث الأنبياء', commissionPct: 10 } });
    otherId = (await createConfiguredUniversity('kerbala')).id;
    await raw.university.update({ where: { id: otherId }, data: { commissionPct: 7.5 } });
    const officeUser = await createUser('office', uniId, 'office@w.iq', { name: 'مكتب النقل' });
    const otherOffice = await createUser('office', otherId, 'office@k.iq');
    await createUser('super_admin', null, 'admin@naql.app');
    fx = await seedMonth(raw, uniId, MONTH, { officeUserId: officeUser.id });
    fx2 = await seedMonth(raw, otherId, MONTH, { officeUserId: otherOffice.id, phoneSeries: 222 });
    app = await createApp();
    office = await login(app, 'office@w.iq');
    admin = await login(app, 'admin@naql.app');
  });

  afterAll(async () => {
    await app.close();
    await raw.$disconnect();
  });

  it('[T6-04] an approved settlement cannot be recomputed or edited; before approval a re-run gives an identical draft', async () => {
    expect((await http().get(`/settlements/${MONTH}`).set(auth(office)).expect(200)).body.settlement).toBeNull();
    const first = (await http().post(`/settlements/${MONTH}/compute`).set(auth(office)).expect(200)).body;
    expect(first.status).toBe('draft');
    expect(first.excludedRuns).toBe(2);
    expect(first.lines).toHaveLength(3);
    const t = first.totals;
    expect(t.payout + t.commission + t.unallocated + t.residual).toBe(t.pool);

    // The teleporting run and the unfinished run were flagged for review and do not count.
    const { review } = (await http().get(`/settlements/${MONTH}`).set(auth(office)).expect(200)).body;
    expect(review.map((r: { id: string }) => r.id).sort()).toEqual([fx.badRunId, fx.unfinishedRunId].sort());
    expect(review.find((r: { id: string }) => r.id === fx.badRunId).flags).toContain('teleport');
    expect(review.every((r: { counted: boolean }) => !r.counted)).toBe(true);

    const again = (await http().post(`/settlements/${MONTH}/compute`).set(auth(office)).expect(200)).body;
    const strip = (s: typeof first) => ({ ...s, id: undefined, computedAt: undefined });
    expect(strip(again)).toEqual(strip(first));

    // Office decides the teleporting run counts after all (GPS glitch): needs a note, changes the draft.
    await http().patch(`/runs/${fx.badRunId}/verdict`).set(auth(office)).send({ verdict: true }).expect(400);
    await http().patch(`/runs/${fx.badRunId}/verdict`).set(auth(office)).send({ verdict: true, note: 'GPS glitch, students confirmed the trip' }).expect(200);
    const withVerdict = (await http().post(`/settlements/${MONTH}/compute`).set(auth(office)).expect(200)).body;
    expect(withVerdict.excludedRuns).toBe(1);

    await http().post(`/settlements/${MONTH}/approve`).set(auth(office)).expect(200);
    await http().post(`/settlements/${MONTH}/approve`).set(auth(office)).expect(409);
    await http().post(`/settlements/${MONTH}/compute`).set(auth(office)).expect(409);
    await http().patch(`/runs/${fx.badRunId}/verdict`).set(auth(office)).send({ verdict: null }).expect(409);
    const approved = (await http().get(`/settlements/${MONTH}`).set(auth(office)).expect(200)).body.settlement;
    expect(approved).toMatchObject({ status: 'approved', totals: withVerdict.totals });

    // The database itself refuses to change an approved settlement or its lines.
    const s = await raw.settlement.findFirstOrThrow({ where: { universityId: uniId, month: MONTH } });
    await expect(raw.settlement.update({ where: { id: s.id }, data: { totalPayout: 1n } })).rejects.toThrow(/immutable/);
    await expect(raw.settlementLine.updateMany({ where: { settlementId: s.id }, data: { payout: 0n } })).rejects.toThrow(/immutable/);
    await expect(raw.settlementLine.deleteMany({ where: { settlementId: s.id } })).rejects.toThrow(/immutable/);
    await expect(raw.settlement.delete({ where: { id: s.id } })).rejects.toThrow(/immutable/);
  });

  it('exports the approved month as PDF and XLSX with the same totals', async () => {
    const s = (await http().get(`/settlements/${MONTH}`).set(auth(office)).expect(200)).body.settlement;
    const pdf = await binary(http().get(`/settlements/${MONTH}/export.pdf`).set(auth(office))).expect(200);
    expect(pdf.headers['content-type']).toBe('application/pdf');
    const dir = mkdtempSync(join(tmpdir(), 'settlement-'));
    writeFileSync(join(dir, 's.pdf'), pdf.body);
    const text = execFileSync('pdftotext', ['-layout', join(dir, 's.pdf'), '-']).toString();
    expect(text).toContain(s.totals.payout.toLocaleString('en-US'));
    expect(text).toContain('APPROVED');

    const xlsx = await binary(http().get(`/settlements/${MONTH}/export.xlsx`).set(auth(office))).expect(200);
    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(xlsx.body);
    const sheet = wb.getWorksheet('Drivers')!;
    const payouts: number[] = [];
    sheet.eachRow((row, i) => {
      if (i > 1 && i < sheet.rowCount) payouts.push(Number(row.getCell(6).value));
    });
    expect(payouts.reduce((a, b) => a + b, 0)).toBe(s.totals.payout);
    expect(Number(sheet.getRow(sheet.rowCount).getCell(6).value)).toBe(s.totals.payout);
  });

  it('[T6-07] overview totals equal the sum of per-university settlements and payments', async () => {
    await http().get(`/admin/overview?month=${MONTH}`).set(auth(office)).expect(403);
    const o = (await http().get(`/admin/overview?month=${MONTH}`).set(auth(admin)).expect(200)).body;
    expect(o.universities).toHaveLength(2);
    const [w, k] = [uniId, otherId].map((id) => o.universities.find((u: { universityId: string }) => u.universityId === id));
    const approved = await raw.settlement.findFirstOrThrow({ where: { universityId: uniId, month: MONTH } });
    expect(w).toMatchObject({ settlement: 'approved', commission: Number(approved.totalCommission), payout: Number(approved.totalPayout), subscribers: 28 });
    expect(k.settlement).toBe('estimate');

    for (const u of o.universities) {
      const pays = await raw.payment.aggregate({ where: { universityId: u.universityId, createdAt: { gte: new Date('2026-08-31T21:00:00Z'), lt: new Date('2026-09-30T21:00:00Z') } }, _sum: { amount: true } });
      expect(u.revenue.total).toBe(pays._sum.amount);
      expect(u.revenue.subscriptions + u.revenue.cashFares + u.revenue.tierDifference).toBe(u.revenue.total);
    }
    const sum = (f: (u: any) => number) => o.universities.reduce((a: number, u: any) => a + f(u), 0);
    expect(o.totals.revenue).toBe(sum((u) => u.revenue.total));
    expect(o.totals.commission).toBe(sum((u) => u.commission));
    expect(o.totals.payout).toBe(sum((u) => u.payout));
    expect(o.totals.subscribers).toBe(56);
    expect(o.totals.runs).toBe(fx.runs + fx2.runs - 2);
  });

  it('[T6-08] changing commission / waitlist and approving a settlement each create an audit row with before/after', async () => {
    await http().patch(`/universities/${uniId}`).set(auth(admin)).send({ commissionPct: 12.5 }).expect(200);
    await http().patch(`/universities/${uniId}`).set(auth(admin)).send({ waitlistMinutes: 45 }).expect(200);

    const rows = await raw.auditEvent.findMany({ where: { universityId: uniId }, orderBy: { createdAt: 'asc' } });
    const commission = rows.find((r) => r.action === 'university.update' && (r.payload as any).after.commissionPct !== undefined)!;
    expect(commission.payload).toEqual({ before: { commissionPct: 10 }, after: { commissionPct: 12.5 } });
    const waitlist = rows.find((r) => r.action === 'university.update' && (r.payload as any).after.waitlistMinutes !== undefined)!;
    expect(waitlist.payload).toEqual({ before: { waitlistMinutes: 30 }, after: { waitlistMinutes: 45 } });
    const approval = rows.find((r) => r.action === 'settlement.approve')!;
    expect(approval.payload).toMatchObject({ before: { month: MONTH, status: 'draft' }, after: { month: MONTH, status: 'approved' } });
    expect(rows.find((r) => r.action === 'run.verdict')!.payload).toMatchObject({ before: { officeVerdict: null }, after: { officeVerdict: true } });
    // Exactly one row per change (the generic interceptor does not add a second one).
    expect(rows.filter((r) => r.entity === 'Universities')).toHaveLength(2);

    // Audit log viewer: filter by entity; office sees only its university.
    const list = (await http().get('/audit?entity=Settlement').set(auth(office)).expect(200)).body;
    expect(list.items.every((r: { entity: string }) => r.entity === 'Settlement')).toBe(true);
    expect(list.items[0]).toMatchObject({ action: 'settlement.approve', actor: { name: 'مكتب النقل' } });
    const all = (await http().get('/audit').set(auth(admin)).expect(200)).body.items;
    expect(all.length).toBeGreaterThanOrEqual(4);
    const officeView = (await http().get('/audit').set(auth(office)).expect(200)).body.items;
    expect(officeView.every((r: { universityId: string }) => r.universityId === uniId)).toBe(true);
    expect((await http().get('/audit/entities').set(auth(office)).expect(200)).body).toEqual(expect.arrayContaining(['Settlement', 'Universities', 'Run']));
  });

  it('DR-08: driver earnings show runs, the approved amount and nothing from other drivers', async () => {
    const user = await raw.user.findUniqueOrThrow({ where: { id: fx.drivers[0].id } });
    const { accessToken } = await createDriverToken(app, user.loginPhone!);
    const e = (await http().get(`/drivers/me/earnings?month=${MONTH}`).set(auth(accessToken)).expect(200)).body;
    const line = await raw.settlementLine.findFirstOrThrow({ where: { driverId: user.id } });
    expect(e).toMatchObject({ month: MONTH, source: 'approved', runs: line.runs, estimate: Number(line.payout) });
    expect(e.list.filter((r: { counted: boolean }) => r.counted)).toHaveLength(line.runs);
    // The next month: nothing yet, and the approved month is listed as a past settlement.
    const next = (await http().get('/drivers/me/earnings?month=2026-10').set(auth(accessToken)).expect(200)).body;
    expect(next).toMatchObject({ source: 'estimate', runs: 0, estimate: 0 });
    expect(next.past).toEqual([expect.objectContaining({ month: MONTH, payout: Number(line.payout) })]);
  });
});

async function createDriverToken(app: INestApplication, phone: string) {
  const http = request(app.getHttpServer());
  const { devCode } = (await http.post('/auth/driver/otp').send({ phone }).expect(200)).body;
  return (await request(app.getHttpServer()).post('/auth/driver/verify').send({ phone, code: devCode, university: 'warith' }).expect(200)).body;
}
