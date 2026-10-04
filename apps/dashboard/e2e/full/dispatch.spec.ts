import { expect, test, type APIRequestContext } from '@playwright/test';

const API = 'http://localhost:3100';
const PNG = Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c63000100000500010d0a2db40000000049454e44ae426082', 'hex');

/** A wave 150 minutes from now (Baghdad); tomorrow's date when that crosses midnight. */
function slot() {
  const now = new Date(Date.now() + 3 * 3600_000);
  let minute = now.getUTCHours() * 60 + now.getUTCMinutes() + 150;
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
  const point = await (await request.post(`${API}/gathering-points`, { headers: office, data: { name: 'Hay Al-Askari', nameAr: 'حي العسكري', lat: 32.63, lng: 44.03 } })).json();
  const s = slot();
  const wave = await (await request.post(`${API}/waves`, { headers: office, data: { type: 'morning', time: s.time, weekdays: 127 } })).json();
  expect(wave.id).toBeTruthy();

  // One approved driver who offers the wave.
  const phone = '07809990011';
  const { devCode } = await (await request.post(`${API}/auth/driver/otp`, { data: { phone } })).json();
  const verified = await (await request.post(`${API}/auth/driver/verify`, { data: { phone, code: devCode, university: 'warith' } })).json();
  const driver = { Authorization: `Bearer ${verified.accessToken}` };
  await request.patch(`${API}/drivers/me`, { headers: driver, data: { name: 'سجاد ناصر', vehicleType: 'coaster', plate: '77 ك 24680', seats: 14, modelYear: 2020 } });
  for (const key of ['national_id', 'driving_licence', 'vehicle_registration', 'vehicle_photo']) {
    await request.put(`${API}/drivers/me/documents/${key}`, { headers: driver, multipart: { file: { name: `${key}.png`, mimeType: 'image/png', buffer: PNG } } });
  }
  await request.post(`${API}/drivers/me/submit`, { headers: driver });
  expect((await request.post(`${API}/drivers/${verified.user.id}/approve`, { headers: office, data: {} })).ok()).toBe(true);
  expect((await request.put(`${API}/drivers/me/availability`, { headers: driver, data: { date: s.date, waveIds: [wave.id] } })).ok()).toBe(true);

  // Two students request the wave.
  await request.post(`${API}/students/roster`, {
    headers: office,
    data: { rows: [{ studentId: 'W-4001', name: 'Ali Kareem', nameAr: 'علي كريم', gender: 'male' }, { studentId: 'W-4002', name: 'Omar Saad', nameAr: 'عمر سعد', gender: 'male' }] },
  });
  for (const id of ['W-4001', 'W-4002']) {
    const { code } = await (await request.post(`${API}/students/${id}/activation-code`, { headers: office })).json();
    const { accessToken } = await (await request.post(`${API}/auth/student/activate`, { data: { university: 'warith', studentId: id, code, password: 'student-pass-1' } })).json();
    const student = { Authorization: `Bearer ${accessToken}` };
    await request.patch(`${API}/students/me`, { headers: student, data: { defaultPointId: point.id } });
    expect((await request.post(`${API}/rides`, { headers: student, data: { waveId: wave.id, date: s.date } })).status()).toBe(201);
  }
  return s;
}

test('office dispatches a wave and sees the bus with its stops (full stack, BullMQ worker)', async ({ page, request }) => {
  const s = await prepare(request);
  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { level: 1 })).toContainText('أهلاً');
  await page.getByRole('navigation', { name: 'main' }).getByRole('link', { name: 'التوزيع' }).click();
  if (s.plus) await page.getByRole('tab', { name: 'غداً' }).click();

  const card = page.getByTestId(`wave-${s.time}`);
  await expect(card.getByText('بانتظار التوزيع')).toBeVisible();
  await card.getByRole('button', { name: 'وزّع الآن' }).click();
  // The worker plans the wave; the board refreshes on its own.
  const run = card.getByTestId('run');
  await expect(run).toBeVisible({ timeout: 20_000 });
  await expect(run.getByText('سجاد ناصر')).toBeVisible();
  await expect(run.getByText('حي العسكري')).toBeVisible();
  await expect(run.getByText('2/14')).toBeVisible();
  await expect(card.getByText('تم التوزيع')).toBeVisible();
  await page.screenshot({ path: 'test-results/office-dispatch.png', fullPage: true });
});
