/**
 * Q4 (open question): a subscription covers a **calendar month**. All period logic lives here so
 * switching to "30 days from activation" is a one-class change.
 * Dates are civil dates in Asia/Baghdad (UTC+3, no DST), represented as UTC midnight.
 */
export interface Period {
  month: string; // YYYY-MM
  start: Date; // first day 00:00
  end: Date; // last day 00:00 (inclusive)
}

export const BAGHDAD_OFFSET_MS = 3 * 3600_000;

export function monthOf(d: Date): string {
  const local = new Date(d.getTime() + BAGHDAD_OFFSET_MS);
  return `${local.getUTCFullYear()}-${String(local.getUTCMonth() + 1).padStart(2, '0')}`;
}

export function parseMonth(month: string): { year: number; m: number } {
  const match = /^(\d{4})-(0[1-9]|1[0-2])$/.exec(month);
  if (!match) throw new Error(`Invalid month ${month}`);
  return { year: Number(match[1]), m: Number(match[2]) };
}

export function calendarMonth(month: string): Period {
  const { year, m } = parseMonth(month);
  return { month, start: new Date(Date.UTC(year, m - 1, 1)), end: new Date(Date.UTC(year, m, 0)) };
}

export function nextMonth(month: string): string {
  const { year, m } = parseMonth(month);
  return m === 12 ? `${year + 1}-01` : `${year}-${String(m + 1).padStart(2, '0')}`;
}

/** Whether a subscription period covers the Baghdad civil date of `at`. */
export function covers(p: { start: Date; end: Date }, at: Date): boolean {
  const local = new Date(at.getTime() + BAGHDAD_OFFSET_MS);
  const day = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());
  return day >= p.start.getTime() && day <= p.end.getTime();
}

/** Days left including today; 0 when expired. */
export function daysLeft(p: { end: Date }, at: Date): number {
  const local = new Date(at.getTime() + BAGHDAD_OFFSET_MS);
  const today = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());
  return Math.max(0, Math.round((p.end.getTime() - today) / 86400_000) + 1);
}
