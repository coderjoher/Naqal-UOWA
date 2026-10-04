import { expect, test, type APIRequestContext } from '@playwright/test';
import { execFileSync } from 'node:child_process';

const API = 'http://localhost:3100';

/** Office + one student with a gathering point, created through the real API. */
async function prepare(request: APIRequestContext) {
  const { accessToken: office } = await (await request.post(`${API}/auth/login`, { data: { email: 'office@uowa.edu.iq', password: 'password123' } })).json();
  const headers = { Authorization: `Bearer ${office}` };
  const tiers = await (await request.get(`${API}/tiers`, { headers })).json();
  if (tiers.length === 0) {
    await request.put(`${API}/tiers`, { headers, data: { tiers: [{ name: 'A', minKm: 0, maxKm: 5, subscriptionPrice: 40000, ridePrice: 1500 }, { name: 'B', minKm: 5, maxKm: null, subscriptionPrice: 60000, ridePrice: 2000 }] } });
  }
  const point = await (await request.post(`${API}/gathering-points`, { headers, data: { name: 'Al-Abbas Square', nameAr: 'ساحة العباس', lat: 32.616, lng: 44.025 } })).json();
  await request.post(`${API}/students/roster`, { headers, data: { rows: [{ studentId: 'W-3001', name: 'Zainab Kadhim', nameAr: 'زينب كاظم', gender: 'female' }] } });
  const { code } = await (await request.post(`${API}/students/W-3001/activation-code`, { headers })).json();
  const { accessToken: student } = await (await request.post(`${API}/auth/student/activate`, { data: { university: 'warith', studentId: 'W-3001', code, password: 'student-pass-1' } })).json();
  await request.patch(`${API}/students/me`, { headers: { Authorization: `Bearer ${student}` }, data: { defaultPointId: point.id } });
  return { student };
}

test('[T3-09] office records a payment and downloads a receipt PDF with student name, amount and receipt number', async ({ page, request }) => {
  const { student } = await prepare(request);

  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { level: 1 })).toContainText('أهلاً');
  await page.getByRole('navigation', { name: 'main' }).getByRole('link', { name: 'الاشتراكات' }).click();

  await page.getByLabel('الرقم الجامعي').fill('W-3001');
  await page.getByRole('button', { name: 'بحث' }).click();
  await expect(page.getByText('زينب كاظم')).toBeVisible();
  await page.getByRole('button', { name: 'تسجيل الدفع النقدي' }).click();
  await expect(page.getByText('تم تسجيل الدفعة وتفعيل الاشتراك').first()).toBeVisible();
  const receiptNo = (await page.getByTestId('receipt-no').textContent())!.trim();
  await page.screenshot({ path: 'test-results/office-subscription.png' });

  const [download] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'تنزيل الإيصال (PDF)' }).first().click()]);
  expect(download.suggestedFilename()).toBe(`receipt-${receiptNo}.pdf`);
  const file = await download.path();
  const text = execFileSync('pdftotext', ['-layout', file, '-']).toString().normalize('NFKC');
  expect(text).toMatch(new RegExp(`No\\. ${receiptNo}\\b`));
  expect(text).toContain('IQD');
  expect(text).toContain('W-3001');
  expect(text).toMatch(/زينب/);

  // The student sees the subscription immediately.
  const me = await (await request.get(`${API}/subscriptions/me`, { headers: { Authorization: `Bearer ${student}` } })).json();
  expect(me.status).toMatch(/active|expiring/);

  // The month list shows it, and it can be reversed with a reason.
  await expect(page.getByRole('cell', { name: `#${receiptNo}` })).toBeVisible();
  await page.getByRole('row', { name: new RegExp(`#${receiptNo}`) }).getByRole('button', { name: 'إلغاء الدفعة' }).click();
  await page.getByLabel('سبب الإلغاء').fill('دفع مرتين بالخطأ');
  await page.getByRole('dialog').getByRole('button', { name: 'إلغاء الدفعة' }).click();
  await expect(page.getByRole('row', { name: new RegExp(`#${receiptNo}`) }).getByText('ملغى')).toBeVisible();
});
