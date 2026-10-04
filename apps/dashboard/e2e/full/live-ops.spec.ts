import { expect, test, type APIRequestContext } from '@playwright/test';

const API = 'http://localhost:3100';
const PNG = Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c63000100000500010d0a2db40000000049454e44ae426082', 'hex');

/** A wave 150 minutes from now (Baghdad); tomorrow's date when that crosses midnight. */
function slot() {
  const now = new Date(Date.now() + 3 * 3600_000);
  let minute = now.getUTCHours() * 60 + now.getUTCMinutes() + 155;
  let plus = 0;
  if (minute >= 24 * 60) {
    minute -= 24 * 60;
    plus = 1;
  }
  const date = new Date(Date.now() + 3 * 3600_000 + plus * 86400_000).toISOString().slice(0, 10);
  return { time: `${String(Math.floor(minute / 60)).padStart(2, '0')}:${String(minute % 60).padStart(2, '0')}`, date, plus };
}

async function prepare(request: APIRequestContext) {
  const login = async (email: string) => ({ Authorization: `Bearer ${(await (await request.post(`${API}/auth/login`, { data: { email, password: 'password123' } })).json()).accessToken}` });
  const office = await login('office@uowa.edu.iq');
  if ((await (await request.get(`${API}/tiers`, { headers: office })).json()).length === 0) {
    await request.put(`${API}/tiers`, { headers: office, data: { tiers: [{ name: 'A', minKm: 0, maxKm: 5, subscriptionPrice: 40000, ridePrice: 1500 }, { name: 'B', minKm: 5, maxKm: null, subscriptionPrice: 60000, ridePrice: 2000 }] } });
  }
  const point = await (await request.post(`${API}/gathering-points`, { headers: office, data: { name: 'Hay Al-Ghadeer', nameAr: 'حي الغدير', lat: 32.585, lng: 44.025 } })).json();
  const s = slot();
  const wave = await (await request.post(`${API}/waves`, { headers: office, data: { type: 'morning', time: s.time, weekdays: 127 } })).json();
  expect(wave.id).toBeTruthy();

  // One approved driver who offers the wave.
  const phone = '07809990022';
  const { devCode } = await (await request.post(`${API}/auth/driver/otp`, { data: { phone } })).json();
  const verified = await (await request.post(`${API}/auth/driver/verify`, { data: { phone, code: devCode, university: 'warith' } })).json();
  const driver = { Authorization: `Bearer ${verified.accessToken}` };
  await request.patch(`${API}/drivers/me`, { headers: driver, data: { name: 'مرتضى كريم', vehicleType: 'coaster', plate: '88 ك 13579', seats: 14, modelYear: 2020 } });
  for (const key of ['national_id', 'driving_licence', 'vehicle_registration', 'vehicle_photo']) {
    await request.put(`${API}/drivers/me/documents/${key}`, { headers: driver, multipart: { file: { name: `${key}.png`, mimeType: 'image/png', buffer: PNG } } });
  }
  await request.post(`${API}/drivers/me/submit`, { headers: driver });
  expect((await request.post(`${API}/drivers/${verified.user.id}/approve`, { headers: office, data: {} })).ok()).toBe(true);
  expect((await request.put(`${API}/drivers/me/availability`, { headers: driver, data: { date: s.date, waveIds: [wave.id] } })).ok()).toBe(true);

  // Two students request the wave.
  await request.post(`${API}/students/roster`, {
    headers: office,
    data: { rows: [{ studentId: 'W-5001', name: 'Hadi Saleh', nameAr: 'هادي صالح', gender: 'male' }, { studentId: 'W-5002', name: 'Ammar Jawad', nameAr: 'عمار جواد', gender: 'male' }] },
  });
  for (const id of ['W-5001', 'W-5002']) {
    const { code } = await (await request.post(`${API}/students/${id}/activation-code`, { headers: office })).json();
    const { accessToken } = await (await request.post(`${API}/auth/student/activate`, { data: { university: 'warith', studentId: id, code, password: 'student-pass-1' } })).json();
    const student = { Authorization: `Bearer ${accessToken}` };
    await request.patch(`${API}/students/me`, { headers: student, data: { defaultPointId: point.id } });
    expect((await request.post(`${API}/rides`, { headers: student, data: { waveId: wave.id, date: s.date } })).status()).toBe(201);
  }
  return { ...s, office, driver, waveId: wave.id };
}


test('[T5-12] live ops map shows a simulated bus moving and its run status updating', async ({ page, request }) => {
  await page.route(/basemaps\.cartocdn\.com/, (r) => r.fulfill({ status: 204, body: '' }));
  const s = await prepare(request);
  // Dispatch the wave through the API, then the driver starts the run.
  await request.post(`${API}/dispatch/plan`, { headers: s.office, data: { waveId: s.waveId, date: s.date } });
  let runId = '';
  await expect
    .poll(async () => {
      const runs = await (await request.get(`${API}/drivers/me/runs?date=${s.date}`, { headers: s.driver })).json();
      runId = runs[0]?.id ?? '';
      return runId;
    }, { timeout: 20_000 })
    .not.toBe('');
  const act = (type: string, extra: object = {}) => request.post(`${API}/runs/${runId}/actions`, { headers: s.driver, data: { actions: [{ clientId: `${type}-${Date.now()}`, type, ...extra }] } });
  const gps = (lat: number, lng: number) => request.post(`${API}/runs/${runId}/gps`, { headers: s.driver, data: { points: [{ lat, lng, at: new Date().toISOString() }] } });
  expect((await act('start')).ok()).toBe(true);
  await gps(32.6, 44.0);

  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
  await page.getByRole('navigation', { name: 'main' }).getByRole('link', { name: 'التشغيل المباشر' }).click();
  await expect(page.getByText('مباشر', { exact: true })).toBeVisible({ timeout: 15_000 });

  const row = page.getByTestId('live-run').filter({ hasText: 'مرتضى كريم' });
  await expect(row.getByText('في الطريق')).toBeVisible();
  const bus = page.getByRole('button', { name: /مرتضى كريم/ }).and(page.locator('.naql-pin--bus'));
  await expect(bus).toBeVisible({ timeout: 15_000 });
  const before = (await bus.boundingBox())!;

  // The bus drives towards campus: the marker moves without reloading the page.
  for (const [lat, lng] of [
    [32.595, 44.02],
    [32.59, 44.04],
  ]) {
    await gps(lat, lng);
    await page.waitForTimeout(1200);
  }
  const after = (await bus.boundingBox())!;
  expect(Math.hypot(after.x - before.x, after.y - before.y)).toBeGreaterThan(20);

  // Status changes arrive live as well.
  expect((await act('arrive', { seq: 1 })).ok()).toBe(true);
  await expect(row.getByText('في محطة')).toBeVisible({ timeout: 10_000 });
  await row.click();
  await expect(page.getByRole('button', { name: /1\. حي الغدير/ })).toBeVisible();
  // Every pin stays a positioned MapLibre marker inside the map (not just present in the DOM).
  const mapBox = (await page.getByRole('application', { name: 'خريطة الحافلات' }).boundingBox())!;
  for (const box of await page.locator('.naql-pin').evaluateAll((els) => els.map((e) => ({ cls: e.className, ...e.getBoundingClientRect().toJSON() })))) {
    expect(box.cls).toContain('maplibregl-marker');
    expect(box.x).toBeGreaterThanOrEqual(mapBox.x - 1);
    expect(box.x + box.width).toBeLessThanOrEqual(mapBox.x + mapBox.width + 1);
  }
  await page.screenshot({ path: 'test-results/office-live-ops.png', fullPage: true });
});
