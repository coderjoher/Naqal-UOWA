import { expect, test, type APIRequestContext } from '@playwright/test';

const API = 'http://localhost:3100';
// 1×1 PNG
const PNG = Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c63000100000500010d0a2db40000000049454e44ae426082', 'hex');

/** A driver applies through the real API, exactly as the driver app does. */
async function applyAsDriver(request: APIRequestContext, phone: string, name: string) {
  const { devCode } = await (await request.post(`${API}/auth/driver/otp`, { data: { phone } })).json();
  const { accessToken } = await (await request.post(`${API}/auth/driver/verify`, { data: { phone, code: devCode, university: 'warith' } })).json();
  const headers = { Authorization: `Bearer ${accessToken}` };
  expect((await request.patch(`${API}/drivers/me`, { headers, data: { name, vehicleType: 'coaster', plate: '45 ك 12345', seats: 20, modelYear: 2019 } })).ok()).toBe(true);
  for (const key of ['national_id', 'driving_licence', 'vehicle_registration', 'vehicle_photo']) {
    const r = await request.put(`${API}/drivers/me/documents/${key}`, { headers, multipart: { file: { name: `${key}.png`, mimeType: 'image/png', buffer: PNG } } });
    expect(r.ok()).toBe(true);
  }
  expect((await request.post(`${API}/drivers/me/submit`, { headers })).status()).toBe(200);
  return headers;
}

test('[T2-10] office reviews a pending driver, opens documents and approves; the driver sees the new status', async ({ page, request }) => {
  await page.route(/tile\.openstreetmap\.org/, (r) => r.fulfill({ status: 204, body: '' }));
  const driverHeaders = await applyAsDriver(request, '07805556677', 'حيدر كاظم');

  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { level: 1 })).toContainText('أهلاً');

  await page.getByRole('navigation', { name: 'main' }).getByRole('link', { name: 'السائقون' }).click();
  await expect(page.getByRole('tab', { name: /بانتظار المراجعة/ })).toHaveAttribute('aria-selected', 'true');
  await page.getByRole('button', { name: /حيدر كاظم/ }).click();

  const panel = page.getByRole('dialog');
  await expect(panel.getByText('بانتظار المراجعة').first()).toBeVisible();
  await panel.getByRole('button', { name: 'عرض' }).first().click();
  await expect(panel.getByRole('img', { name: 'البطاقة الوطنية' })).toBeVisible();
  await expect(panel.getByText('الرابط صالح لخمس دقائق')).toBeVisible();
  await page.screenshot({ path: 'test-results/office-driver-review.png' });

  await panel.getByRole('button', { name: 'اعتماد السائق' }).click();
  await expect(page.getByRole('status').filter({ hasText: 'تم تحديث حالة السائق' })).toBeVisible();
  await page.getByRole('tab', { name: /معتمدون/ }).click();
  await expect(page.getByRole('button', { name: /حيدر كاظم/ })).toBeVisible();

  const me = await (await request.get(`${API}/drivers/me`, { headers: driverHeaders })).json();
  expect(me.status).toBe('approved');
  expect((await request.get(`${API}/drivers/me/runs`, { headers: driverHeaders })).status()).toBe(200);
});

test('office imports the roster and issues an activation code that the student can use', async ({ page, request }) => {
  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { level: 1 })).toContainText('أهلاً');
  await page.getByRole('navigation', { name: 'main' }).getByRole('link', { name: 'الطلبة' }).click();

  await page.locator('#roster-file').setInputFiles({
    name: 'roster.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from('student_id,name,name_ar,gender\nW-2001,Zainab Kadhim,زينب كاظم,أنثى\nW-2002,Ali Hassan,علي حسن,ذكر\n'),
  });
  await page.getByRole('button', { name: 'استيراد', exact: true }).click();
  await expect(page.getByRole('cell', { name: 'زينب كاظم' })).toBeVisible();

  await page.getByRole('row', { name: /زينب كاظم/ }).getByRole('button', { name: 'إصدار رمز التفعيل' }).click();
  const code = (await page.getByRole('dialog').locator('p[dir="ltr"].font-mono').textContent())!.trim();
  expect(code).toMatch(/^\d{6}$/);

  const res = await request.post(`${API}/auth/student/activate`, { data: { university: 'warith', studentId: 'W-2001', code, password: 'student-pass-1' } });
  expect(res.status()).toBe(200);
  await page.keyboard.press('Escape');
  await page.reload();
  await expect(page.getByRole('row', { name: /زينب كاظم/ }).getByText('مفعّل')).toBeVisible();
});
