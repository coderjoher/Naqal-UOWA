/** Civil dates and times in Asia/Baghdad (UTC+3, no DST). Dates are 'YYYY-MM-DD'. */
const OFFSET_MS = 3 * 3600_000;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function baghdadDate(at: Date, plusDays = 0): string {
  const d = new Date(at.getTime() + OFFSET_MS + plusDays * 86400_000);
  return d.toISOString().slice(0, 10);
}

export function isDate(s: string): boolean {
  return DATE_RE.test(s) && !Number.isNaN(Date.parse(`${s}T00:00:00Z`)) && new Date(`${s}T00:00:00Z`).toISOString().startsWith(s);
}

/** The value Prisma stores in a `@db.Date` column. */
export const dbDate = (date: string) => new Date(`${date}T00:00:00Z`);
export const fromDbDate = (d: Date) => d.toISOString().slice(0, 10);

/** Baghdad midnight of `date`, as an instant. */
export const midnight = (date: string) => Date.parse(`${date}T00:00:00Z`) - OFFSET_MS;

/** Seconds after Baghdad midnight of `date` (negative before it, > 86400 on later days). */
export const secondsInto = (date: string, at: Date) => Math.floor((at.getTime() - midnight(date)) / 1000);

export const instantAt = (date: string, seconds: number) => new Date(midnight(date) + seconds * 1000);

/** 0 = Sunday … 6 = Saturday, matching the wave weekday bit mask. */
export const weekday = (date: string) => new Date(`${date}T00:00:00Z`).getUTCDay();

export const runsOn = (weekdays: number, date: string) => (weekdays & (1 << weekday(date))) !== 0;
