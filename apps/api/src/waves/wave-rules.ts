export type WaveType = 'morning' | 'return';

export interface WaveLike {
  id?: string;
  type: WaveType;
  minuteOfDay: number;
  weekdays: number;
  active?: boolean;
}

export const ALL_DAYS = 0b1111111;
/** Iraqi university week: Sunday–Thursday. */
export const SUN_TO_THU = 0b0011111;

export function validateWave(w: WaveLike): string[] {
  const errors: string[] = [];
  if (!Number.isInteger(w.minuteOfDay) || w.minuteOfDay < 0 || w.minuteOfDay > 1439) errors.push('Time must be between 00:00 and 23:59');
  if (!Number.isInteger(w.weekdays) || w.weekdays < 1 || w.weekdays > ALL_DAYS) errors.push('Pick at least one weekday');
  return errors;
}

/** Another active wave of the same type at the same time on an overlapping day. */
export function findClash<T extends WaveLike>(candidate: WaveLike, others: T[]): T | undefined {
  return others.find(
    (o) => o.id !== candidate.id && (o.active ?? true) && o.type === candidate.type && o.minuteOfDay === candidate.minuteOfDay && (o.weekdays & candidate.weekdays) !== 0,
  );
}

export const toHHMM = (m: number) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;

export function fromHHMM(s: string): number {
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(s);
  if (!m) throw new Error(`Invalid time ${s}`);
  return Number(m[1]) * 60 + Number(m[2]);
}
