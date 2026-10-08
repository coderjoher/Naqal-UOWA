import { expect, test } from '@playwright/test';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const MONTH = '2026-08';
const E2E_DB = process.env.E2E_DATABASE_URL ?? 'postgresql://naql:naql@localhost:5432/naql_e2e';

test('[T7-05] reports page filters by month and tier and exports CSV', async ({ page }) => {
  execFileSync('npx', ['ts-node', 'scripts/seed-month.ts', 'warith', MONTH], { cwd: '../api', env: { ...process.env, DATABASE_URL: E2E_DB }, stdio: 'pipe' });

  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
  await page.getByRole('link', { name: 'التقارير' }).click();
  await page.getByLabel('الشهر', { exact: true }).fill(MONTH);

  // The fixture month: 28 subscribers, every finished run on time, one run never finished.
  await expect(page.getByTestId('m-subscribers')).toHaveAttribute('data-value', '28');
  await expect(page.getByTestId('m-ontime')).toHaveAttribute('data-value', '100');
  const revenueAll = Number(await page.getByTestId('m-revenue').getAttribute('data-value'));
  expect(revenueAll).toBeGreaterThan(0);
  const fulfilment = await page.getByTestId('m-fulfilment').getAttribute('data-value');

  // One tier: fewer subscribers and less revenue; the table shows only that tier.
  const tier = page.getByTestId('report-tier');
  const first = await tier.locator('option').nth(1).getAttribute('value');
  await tier.selectOption(first!);
  await expect(page.getByTestId('m-subscribers')).not.toHaveAttribute('data-value', '28');
  const revenueTier = Number(await page.getByTestId('m-revenue').getAttribute('data-value'));
  expect(revenueTier).toBeGreaterThan(0);
  expect(revenueTier).toBeLessThan(revenueAll);
  await expect(page.getByRole('table').getByRole('row')).toHaveCount(2);

  // CSV: the same numbers as the screen for the selected tier.
  const [csv] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'CSV' }).click()]);
  expect(csv.suggestedFilename()).toBe(`report-${MONTH}.csv`);
  const text = readFileSync(await csv.path(), 'utf8');
  expect(text.charCodeAt(0)).toBe(0xfeff);
  expect(text).toContain(`month,${MONTH}`);
  expect(text).toContain(`revenue_iqd,${revenueTier}`);
  const subs = await page.getByTestId('m-subscribers').getAttribute('data-value');
  expect(text).toContain(`subscribers,${subs}`);

  // Back to all tiers: the first numbers return.
  await tier.selectOption('');
  await expect(page.getByTestId('m-fulfilment')).toHaveAttribute('data-value', fulfilment ?? '');
  await expect(page.getByTestId('m-revenue')).toHaveAttribute('data-value', String(revenueAll));
});
