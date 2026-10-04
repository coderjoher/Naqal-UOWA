import { expect, test, type Page } from '@playwright/test';

/** The API is mocked at the network layer; the real API is covered by apps/api e2e tests. */
async function mockApi(page: Page, role: 'office' | 'super_admin') {
  // Catch-all first (later routes take precedence): every other endpoint answers with empty data.
  await page.route('**/api/**', (route) => {
    const url = route.request().url();
    if (url.endsWith('/driver-requirements')) return route.fulfill({ json: { documents: [], vehicleTypes: [], minSeats: 10, maxVehicleAgeYears: 15 } });
    if (url.endsWith('/universities/current')) return route.fulfill({ json: { id: 'uni', name: 'Warith', nameAr: 'جامعة وارث الأنبياء', campusLat: 32.58, campusLng: 44.06, coverage: [] } });
    return route.fulfill({ json: [] });
  });
  await page.route('**/api/auth/login', async (route) => {
    const { email, password } = route.request().postDataJSON();
    if (password !== 'password123') return route.fulfill({ status: 401, json: { message: 'Unauthorized' } });
    await route.fulfill({
      json: { accessToken: 'test-token', user: { id: 'u1', name: email.startsWith('office') ? 'مكتب النقل' : 'مدير المنصة', role, universityId: role === 'office' ? 'uni' : null } },
    });
  });
  await page.route('**/api/users', (route) =>
    route.fulfill({
      json: [
        { id: '1', name: 'علي حسن', email: 'ali@uowa.edu.iq', role: 'student', status: 'active' },
        { id: '2', name: 'زينب كاظم', email: 'zainab@uowa.edu.iq', role: 'driver', status: 'suspended' },
      ],
    }),
  );
  await page.route('**/api/universities', (route) =>
    route.fulfill({ json: [{ id: 'w', name: 'Warith Al-Anbiyaa University', nameAr: 'جامعة وارث الأنبياء', slug: 'warith', commissionPct: '10', waitlistMinutes: 30 }] }),
  );
}

async function signIn(page: Page, email: string) {
  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill(email);
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
}

test('[T0-10] unauthenticated users are redirected to login from any dashboard route', async ({ page }) => {
  for (const path of ['/', '/users', '/universities']) {
    await page.goto(path);
    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByRole('heading', { name: 'تسجيل الدخول' })).toBeVisible();
  }
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
});

test('[T0-10] office user never sees super-admin menus and cannot open them', async ({ page }) => {
  await mockApi(page, 'office');
  await signIn(page, 'office@uowa.edu.iq');
  const nav = page.getByRole('navigation', { name: 'main' });
  await expect(nav.getByRole('link', { name: 'المستخدمون' })).toBeVisible();
  await expect(nav.getByRole('link', { name: 'الجامعات' })).toHaveCount(0);

  await page.goto('/universities');
  await expect(page).toHaveURL(/\/$/);

  await nav.getByRole('link', { name: 'المستخدمون' }).click();
  await expect(page.getByRole('cell', { name: 'علي حسن' })).toBeVisible();
  await expect(page.getByText('موقوف')).toBeVisible();
  await page.screenshot({ path: 'test-results/office-users.png', fullPage: true });
});

test('[T0-10] super admin sees universities, not office menus', async ({ page }) => {
  await mockApi(page, 'super_admin');
  await signIn(page, 'admin@naql.app');
  const nav = page.getByRole('navigation', { name: 'main' });
  await nav.getByRole('link', { name: 'الجامعات' }).click();
  await expect(page.getByRole('cell', { name: 'جامعة وارث الأنبياء' })).toBeVisible();
  await expect(nav.getByRole('link', { name: 'المستخدمون' })).toHaveCount(0);
  await page.goto('/users');
  await expect(page).toHaveURL(/\/$/);
});

test('[T0-10] wrong password shows an error and stays on login', async ({ page }) => {
  await mockApi(page, 'office');
  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('wrong-password');
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('alert')).toContainText('غير صحيحة');
  await expect(page).toHaveURL(/\/login$/);
  await page.screenshot({ path: 'test-results/login-error.png' });
});
