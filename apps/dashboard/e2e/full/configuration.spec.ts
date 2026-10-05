import { expect, test, type Page } from '@playwright/test';

/** Basemap tiles are not needed for the test; answer them with an empty response. */
async function blockTiles(page: Page) {
  await page.route(/tile\.openstreetmap\.org/, (r) => r.fulfill({ status: 204, body: '' }));
}

async function signIn(page: Page) {
  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { level: 1 })).toContainText('أهلاً');
}

const POINTS = ['ساحة العباس', 'باب بغداد', 'حي العامل', 'حي الحسين', 'الحر'];

test('[T1-09] office configures 3 tiers, 5 points on the map and 2 waves end to end in Arabic RTL', async ({ page }) => {
  await blockTiles(page);
  await signIn(page);
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  const nav = page.getByRole('navigation', { name: 'main' });

  // Overview checklist: only driver requirements are done (they have defaults)
  await expect(page.getByText('1/4')).toBeVisible();

  // 1. Tiers: start from the suggested three, adjust one price, save
  await nav.getByRole('link', { name: 'فئات المسافة' }).click();
  await page.getByRole('button', { name: 'استخدم الفئات المقترحة' }).click();
  await page.locator('#tier-sub-0').fill('45000');
  await page.getByRole('button', { name: 'حفظ الفئات' }).click();
  await expect(page.getByRole('status').filter({ hasText: 'تم حفظ الفئات' })).toBeVisible();

  // 2. Points: click the map five times, name each point, save
  await nav.getByRole('link', { name: 'نقاط التجمّع' }).click();
  const map = page.getByRole('application', { name: 'نقاط التجمّع' });
  await expect(map.locator('canvas')).toBeVisible({ timeout: 20_000 });
  const box = (await map.boundingBox())!;
  const offsets = [
    [-120, -90],
    [80, -60],
    [-60, 70],
    [130, 50],
    [-200, 10],
  ];
  for (const [i, name] of POINTS.entries()) {
    await page.mouse.click(box.x + box.width / 2 + offsets[i][0], box.y + box.height / 2 + offsets[i][1]);
    await page.getByLabel('اسم النقطة', { exact: true }).fill(name);
    await page.getByRole('button', { name: 'حفظ', exact: true }).click();
    await expect(page.getByRole('list').getByText(name)).toBeVisible();
  }
  await expect(page.locator('.naql-pin--point')).toHaveCount(5);

  // 3. Waves: one morning arrival, one return departure (Sun–Thu by default)
  await nav.getByRole('link', { name: 'المواعيد' }).click();
  await page.getByRole('button', { name: 'إضافة موعد' }).first().click();
  await page.getByLabel('الوقت').fill('08:00');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('08:00')).toBeVisible();
  await page.getByRole('button', { name: 'إضافة موعد' }).nth(1).click();
  await page.getByLabel('الوقت').fill('14:00');
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByText('14:00')).toBeVisible();

  // Overview checklist reflects the configuration (requirements have defaults → 4/4)
  await nav.getByRole('link', { name: 'نظرة عامة' }).click();
  await expect(page.getByText('4/4')).toBeVisible();
  await page.screenshot({ path: 'test-results/office-overview.png', fullPage: true });

  // Points were stored with automatic tiers and distances
  await nav.getByRole('link', { name: 'نقاط التجمّع' }).click();
  await expect(page.getByText(/كم ·/).first()).toBeVisible();
  await page.screenshot({ path: 'test-results/office-points.png' });
});
