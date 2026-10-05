import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';
import { join } from 'node:path';
import { drawText, FONT_DIR } from '../payments/receipt-pdf';

export interface ExportLine {
  driver: string;
  plate: string;
  runs: number;
  cash: number;
  cashCommission: number;
  payout: number;
}

export interface ExportData {
  universityName: string;
  month: string;
  status: 'draft' | 'approved';
  approvedAt: Date | null;
  commissionPct: number;
  tiers: { name: string; pool: number; runs: number; commission: number }[];
  lines: ExportLine[];
  totals: { pool: number; payout: number; commission: number; cash: number; unallocated: number; residual: number };
}

const fmt = (n: number) => n.toLocaleString('en-US');

/** TO-09: Arabic A4 settlement sheet: summary, pools per tier, one row per driver, totals. */
export function settlementPdf(d: ExportData): Promise<Buffer> {
  const doc = new PDFDocument({ size: 'A4', margin: 36, info: { Title: `Settlement ${d.month}`, Author: d.universityName } });
  doc.registerFont('regular', join(FONT_DIR, 'IBMPlexSansArabic-Regular.ttf'));
  doc.registerFont('bold', join(FONT_DIR, 'IBMPlexSansArabic-SemiBold.ttf'));
  const chunks: Buffer[] = [];
  doc.on('data', (c: Buffer) => chunks.push(c));
  const done = new Promise<Buffer>((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));

  const left = 36;
  const width = doc.page.width - 72;
  let y = 36;
  const text = (t: string, x: number, w: number, align: 'left' | 'right' | 'center', font: 'regular' | 'bold' = 'regular', size = 9.5, color = '#0F172A') => {
    doc.font(font).fontSize(size).fillColor(color);
    drawText(doc, t, x, y, w, align);
  };

  text(d.universityName, left, width, 'right', 'bold', 13);
  y += 20;
  text('تسوية مستحقات السائقين', left, width, 'right', 'bold', 17, '#2563EB');
  text(`${d.month}  ·  ${d.status === 'approved' ? `APPROVED ${d.approvedAt?.toISOString().slice(0, 10) ?? ''}` : 'DRAFT'}`, left, width, 'left', 'regular', 10, '#56627A');
  y += 30;

  // Summary
  const summary: [string, string][] = [
    ['مجموع الاشتراكات', fmt(d.totals.pool)],
    ['نسبة العمولة', `${d.commissionPct}%`],
    ['العمولة', fmt(d.totals.commission)],
    ['الأجرة النقدية لدى السائقين', fmt(d.totals.cash)],
    ['مجموع المستحقات', fmt(d.totals.payout)],
    ['غير موزع', fmt(d.totals.unallocated)],
    ['فرق التقريب', fmt(d.totals.residual)],
  ];
  for (const [label, value] of summary) {
    text(label, left + width / 2, width / 2, 'right', 'regular', 10, '#56627A');
    text(value, left, width / 2 - 8, 'left', 'bold', 10);
    y += 16;
  }
  y += 8;

  // Pools per tier
  const tierCols = [
    { label: 'الفئة', w: 0.4 },
    { label: 'الاشتراكات', w: 0.25 },
    { label: 'الرحلات', w: 0.15 },
    { label: 'العمولة', w: 0.2 },
  ];
  const row = (cells: string[], cols: { w: number }[], font: 'regular' | 'bold') => {
    let x = left + width;
    cells.forEach((c, i) => {
      const w = cols[i].w * width;
      x -= w;
      text(c, x + 4, w - 8, i === 0 ? 'right' : 'left', font, 9);
    });
    y += 15;
    doc.moveTo(left, y - 2).lineTo(left + width, y - 2).strokeColor('#E2E8F0').lineWidth(0.5).stroke();
  };
  row(tierCols.map((c) => c.label), tierCols, 'bold');
  for (const t of d.tiers) row([t.name, fmt(t.pool), String(t.runs), fmt(t.commission)], tierCols, 'regular');
  y += 14;

  // Drivers
  const cols = [
    { label: 'السائق', w: 0.3 },
    { label: 'اللوحة', w: 0.14 },
    { label: 'الرحلات', w: 0.1 },
    { label: 'نقد مستلم', w: 0.15 },
    { label: 'عمولة النقد', w: 0.14 },
    { label: 'المستحق', w: 0.17 },
  ];
  row(cols.map((c) => c.label), cols, 'bold');
  for (const l of d.lines) {
    if (y > doc.page.height - 60) {
      doc.addPage();
      y = 36;
      row(cols.map((c) => c.label), cols, 'bold');
    }
    row([l.driver, l.plate, String(l.runs), fmt(l.cash), fmt(l.cashCommission), fmt(l.payout)], cols, 'regular');
  }
  row(['المجموع', '', String(d.lines.reduce((k, l) => k + l.runs, 0)), fmt(d.totals.cash), fmt(d.lines.reduce((k, l) => k + l.cashCommission, 0)), fmt(d.totals.payout)], cols, 'bold');
  y += 20;
  text('المبالغ بالدينار العراقي. المستحق السالب يعني أن على السائق دفع الفرق للمكتب.', left, width, 'right', 'regular', 8, '#56627A');
  doc.end();
  return done;
}

/** TO-09: the same numbers as a spreadsheet (Drivers and Tiers sheets, right-to-left). */
export async function settlementXlsx(d: ExportData): Promise<Buffer> {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'Naql';
  wb.created = new Date(0);
  const drivers = wb.addWorksheet('Drivers', { views: [{ rightToLeft: true }] });
  drivers.columns = [
    { header: 'السائق', key: 'driver', width: 28 },
    { header: 'اللوحة', key: 'plate', width: 14 },
    { header: 'الرحلات', key: 'runs', width: 10 },
    { header: 'نقد مستلم', key: 'cash', width: 14 },
    { header: 'عمولة النقد', key: 'cashCommission', width: 14 },
    { header: 'المستحق', key: 'payout', width: 16 },
  ];
  for (const l of d.lines) drivers.addRow(l);
  drivers.addRow({ driver: 'المجموع', runs: d.lines.reduce((k, l) => k + l.runs, 0), cash: d.totals.cash, cashCommission: d.lines.reduce((k, l) => k + l.cashCommission, 0), payout: d.totals.payout });
  drivers.getRow(1).font = { bold: true };
  drivers.getRow(drivers.rowCount).font = { bold: true };
  for (const k of ['cash', 'cashCommission', 'payout']) drivers.getColumn(k).numFmt = '#,##0';

  const tiers = wb.addWorksheet('Tiers', { views: [{ rightToLeft: true }] });
  tiers.columns = [
    { header: 'الفئة', key: 'name', width: 20 },
    { header: 'الاشتراكات', key: 'pool', width: 16 },
    { header: 'الرحلات', key: 'runs', width: 10 },
    { header: 'العمولة', key: 'commission', width: 14 },
  ];
  for (const t of d.tiers) tiers.addRow(t);
  tiers.getRow(1).font = { bold: true };

  const summary = wb.addWorksheet('Summary', { views: [{ rightToLeft: true }] });
  summary.columns = [{ key: 'k', width: 28 }, { key: 'v', width: 18 }];
  summary.addRows([
    { k: d.universityName, v: d.month },
    { k: 'الحالة', v: d.status },
    { k: 'نسبة العمولة %', v: d.commissionPct },
    { k: 'مجموع الاشتراكات', v: d.totals.pool },
    { k: 'العمولة', v: d.totals.commission },
    { k: 'الأجرة النقدية', v: d.totals.cash },
    { k: 'مجموع المستحقات', v: d.totals.payout },
    { k: 'غير موزع', v: d.totals.unallocated },
    { k: 'فرق التقريب', v: d.totals.residual },
  ]);
  return Buffer.from(await wb.xlsx.writeBuffer());
}
