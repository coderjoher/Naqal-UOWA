import PDFDocument from 'pdfkit';
import { join } from 'node:path';

export interface ReceiptData {
  universityName: string;
  receiptNo: number;
  issuedAt: Date;
  studentName: string;
  studentNumber: string;
  month: string;
  tierName: string;
  pointName: string;
  amount: number;
  collectedBy: string;
  reversal?: boolean;
}

const FONT_DIR = process.env.FONT_DIR ?? join(__dirname, '../../assets/fonts');
const ARABIC = /[؀-ۿ]/;
const LATIN = /[A-Za-z]/;

/** Pure Arabic run (no Latin letters, no digits): needs right-to-left word placement. */
export const isArabicRun = (text: string) => ARABIC.test(text) && !LATIN.test(text) && !/\d/.test(text);

/**
 * pdfkit shapes Arabic letters correctly (fontkit) but lays words out left to right and attaches
 * spaces to the wrong side. Arabic runs are therefore placed word by word from the right edge.
 * Numbers and Latin text always go in their own cells, so they never mix with Arabic runs.
 */
function drawText(doc: PDFKit.PDFDocument, text: string, x: number, y: number, width: number, align: 'left' | 'right' | 'center') {
  if (!isArabicRun(text)) {
    doc.text(text, x, y, { width, align, lineBreak: false });
    return;
  }
  const words = text.trim().split(/\s+/);
  const space = doc.widthOfString(' ');
  const widths = words.map((w) => doc.widthOfString(w));
  const total = widths.reduce((a, b) => a + b, 0) + space * (words.length - 1);
  let cursor = align === 'right' ? x + width : align === 'center' ? x + (width + total) / 2 : x + total;
  words.forEach((w, i) => {
    cursor -= widths[i];
    doc.text(w, cursor, y, { lineBreak: false });
    cursor -= space;
  });
}

const money = (n: number) => `${n.toLocaleString('en-US')} IQD`;

/** A6 receipt: title, receipt number, then label (right) / value (left) rows. */
export function renderReceipt(r: ReceiptData): Promise<Buffer> {
  const doc = new PDFDocument({ size: 'A6', margin: 22, info: { Title: `Receipt ${r.receiptNo}`, Author: r.universityName } });
  doc.registerFont('regular', join(FONT_DIR, 'IBMPlexSansArabic-Regular.ttf'));
  doc.registerFont('bold', join(FONT_DIR, 'IBMPlexSansArabic-SemiBold.ttf'));
  const chunks: Buffer[] = [];
  doc.on('data', (c: Buffer) => chunks.push(c));
  const done = new Promise<Buffer>((resolve) => doc.on('end', () => resolve(Buffer.concat(chunks))));

  const width = doc.page.width - 44;
  const left = 22;
  let y = 22;
  const line = (text: string, font: 'regular' | 'bold', size: number, color: string, align: 'left' | 'right' | 'center', gap: number) => {
    doc.font(font).fontSize(size).fillColor(color);
    drawText(doc, text, left, y, width, align);
    y += doc.currentLineHeight(true) + gap;
  };
  line(r.universityName, 'bold', 12, '#0F172A', 'right', 2);
  line(r.reversal ? 'إيصال إلغاء دفعة' : 'إيصال اشتراك شهري', 'bold', 15, '#2563EB', 'right', 6);
  line(`No. ${r.receiptNo}  ·  ${r.issuedAt.toISOString().slice(0, 10)}`, 'regular', 9, '#56627A', 'left', 8);
  doc.moveTo(left, y).lineTo(left + width, y).strokeColor('#E2E8F0').stroke();
  y += 10;

  const row = (label: string, value: string, strong = false) => {
    doc.font('regular').fontSize(9.5).fillColor('#56627A');
    drawText(doc, label, left + width / 2, y + (strong ? 3 : 1), width / 2, 'right');
    doc.font(strong ? 'bold' : 'regular').fontSize(strong ? 12 : 10).fillColor('#0F172A');
    drawText(doc, value, left, y, width / 2 - 8, 'left');
    y += doc.currentLineHeight(true) + 7;
  };
  row('رقم الإيصال', String(r.receiptNo));
  row('الطالب', r.studentName);
  row('الرقم الجامعي', r.studentNumber);
  row('الشهر', r.month);
  row('الفئة', r.tierName);
  row('نقطة التجمع', r.pointName);
  row('المبلغ', money(r.amount), true);
  row('استلمها', r.collectedBy);

  y += 10;
  line('احتفظ بهذا الإيصال ويُفعّل الاشتراك فور تسجيل الدفع', 'regular', 8, '#56627A', 'center', 0);
  doc.end();
  return done;
}
