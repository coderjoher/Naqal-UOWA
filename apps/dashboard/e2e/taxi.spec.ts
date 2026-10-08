import { expect, test } from '@playwright/test';

/** P10: the office's campus taxi page, with the API mocked at the network layer. */
test('[T10-12] office sees online taxis and today\'s rides, previews the tariff and saves it', async ({ page }) => {
  let settings = { taxiEnabled: true, taxiBaseFare: 2000, taxiPerKm: 500, taxiMinFare: 3000, taxiOfferSeconds: 180 };
  let saved: Record<string, number> | null = null;
  await page.route('**/api/**', (route) => {
    const url = route.request().url();
    if (url.endsWith('/universities/current')) return route.fulfill({ json: { id: 'uni', name: 'Warith', nameAr: 'جامعة وارث الأنبياء', campusLat: 32.58, campusLng: 44.06, coverage: [] } });
    return route.fulfill({ json: [] });
  });
  await page.route('**/api/auth/login', (route) => route.fulfill({ json: { accessToken: 't', user: { id: 'u1', name: 'مكتب النقل', role: 'office', universityId: 'uni' } } }));
  await page.route('**/api/taxi/settings', async (route) => {
    if (route.request().method() === 'PATCH') {
      saved = route.request().postDataJSON();
      settings = { ...settings, ...saved };
    }
    await route.fulfill({ json: settings });
  });
  const at = new Date().toISOString();
  await page.route('**/api/taxi/overview', (route) =>
    route.fulfill({
      json: {
        date: at.slice(0, 10),
        kpis: { requested: 3, done: 1, active: 1, unserved: 1, cash: 4500, avgAcceptSec: 42, online: 2 },
        online: [
          { driverId: 'd1', name: 'علي كريم', plate: '45670 كربلاء أجرة', lat: 32.6, lng: 44.05, at, busy: true },
          { driverId: 'd2', name: 'حسن جبار', plate: '45671 كربلاء أجرة', lat: 32.59, lng: 44.07, at, busy: false },
        ],
        rides: [
          { id: 'r1', status: 'on_trip', direction: 'to_campus', label: 'قرب جامع باب بغداد', distanceKm: 4.4, fare: 4250, createdAt: at, acceptedAt: at, endedAt: null, cancelledBy: null, student: 'زينب كاظم', driver: 'علي كريم', plate: '45670 كربلاء أجرة' },
          { id: 'r2', status: 'expired', direction: 'from_campus', label: null, distanceKm: 7.1, fare: 5750, createdAt: at, acceptedAt: null, endedAt: null, cancelledBy: null, student: 'علي حسن', driver: null, plate: null },
        ],
      },
    }),
  );

  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
  await page.getByRole('navigation', { name: 'main' }).getByRole('link', { name: 'التكسي الجامعي' }).click();

  await expect(page.getByRole('heading', { name: 'التكسي الجامعي' })).toBeVisible();
  await expect(page.getByRole('switch', { name: /الخدمة مفعّلة/ })).toHaveAttribute('aria-checked', 'true');
  await expect(page.locator('button[aria-pressed]', { hasText: 'حسن جبار' })).toContainText('متاح');
  await expect(page.getByRole('cell', { name: 'زينب كاظم' })).toBeVisible();
  await expect(page.getByText('في الرحلة')).toBeVisible();
  await expect(page.getByText('لم يُقبل').first()).toBeVisible();

  // 10 km at 2000 + 500/km = 7,000; at 750/km = 9,500.
  const preview = page.getByText('ما سيدفعه الطالب').locator('..');
  await expect(preview).toContainText('7,000');
  await page.getByLabel('لكل كيلومتر').fill('750');
  await expect(preview).toContainText('9,500');
  await page.getByRole('button', { name: 'احفظ التسعيرة' }).click();
  await expect(page.getByText('حُفظت التسعيرة')).toBeVisible();
  expect(saved).toMatchObject({ taxiPerKm: 750, taxiBaseFare: 2000 });
});
