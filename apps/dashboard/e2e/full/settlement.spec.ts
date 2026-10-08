import { expect, test } from '@playwright/test';
import { execFileSync } from 'node:child_process';
import ExcelJS from 'exceljs';

const MONTH = '2026-08';
const E2E_DB = process.env.E2E_DATABASE_URL ?? 'postgresql://naql:naql@localhost:5432/naql_e2e';

test('[T6-05] office reviews, approves and downloads PDF and XLSX; totals in the files match the screen', async ({ page }) => {
  execFileSync('npx', ['ts-node', 'scripts/seed-month.ts', 'warith', MONTH], { cwd: '../api', env: { ...process.env, DATABASE_URL: E2E_DB }, stdio: 'pipe' });

  await page.goto('/login');
  await page.getByLabel('البريد الإلكتروني').fill('office@uowa.edu.iq');
  await page.getByLabel('كلمة المرور').fill('password123');
  await page.getByRole('button', { name: 'دخول' }).click();
  await page.getByRole('link', { name: 'التسوية الشهرية' }).click();
  await page.getByLabel('الشهر', { exact: true }).fill(MONTH);

  await page.getByRole('button', { name: 'احسب التسوية' }).click();
  await expect(page.getByTestId('settlement-status')).toContainText('مسودة');
  await expect(page.getByTestId('line-payout')).toHaveCount(3);

  // Two runs need review (a teleporting track and an unfinished run); keep the GPS decision.
  await expect(page.getByTestId('review-run')).toHaveCount(2);
  await expect(page.getByTestId('review-run').first()).toContainText(/قفزة في الموقع|لم تكتمل/);

  const screenPayout = Number(await page.getByTestId('total-payout').getAttribute('data-value'));
  const linePayouts = await page.getByTestId('line-payout').evaluateAll((els) => els.map((e) => Number(e.getAttribute('data-value'))));
  expect(linePayouts.reduce((a, b) => a + b, 0)).toBe(screenPayout);

  await page.getByRole('button', { name: 'اعتمد' }).click();
  await page.getByRole('button', { name: 'نعم، اعتمد' }).click();
  await expect(page.getByTestId('settlement-status')).toContainText('معتمدة');
  await expect(page.getByRole('button', { name: 'أعد الحساب' })).toHaveCount(0);

  const [pdf] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'PDF' }).click()]);
  expect(pdf.suggestedFilename()).toBe(`settlement-${MONTH}.pdf`);
  const pdfPath = await pdf.path();
  const text = execFileSync('pdftotext', ['-layout', pdfPath, '-']).toString();
  expect(text).toContain(screenPayout.toLocaleString('en-US'));
  for (const p of linePayouts) expect(text).toContain(p.toLocaleString('en-US'));

  const [xlsx] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: 'Excel' }).click()]);
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(await xlsx.path());
  const sheet = wb.getWorksheet('Drivers')!;
  expect(Number(sheet.getRow(sheet.rowCount).getCell(6).value)).toBe(screenPayout);
  const rows: number[] = [];
  sheet.eachRow((row, i) => {
    if (i > 1 && i < sheet.rowCount) rows.push(Number(row.getCell(6).value));
  });
  expect(rows.sort()).toEqual([...linePayouts].sort());

  // The approval is in the audit log.
  await page.getByRole('navigation', { name: 'main' }).getByRole('button', { name: 'الإعدادات' }).click();
  await page.getByRole('link', { name: 'سجل التغييرات' }).click();
  await expect(page.getByText('settlement.approve')).toBeVisible();
});
