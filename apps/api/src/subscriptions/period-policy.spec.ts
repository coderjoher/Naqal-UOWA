import { calendarMonth, covers, daysLeft, monthOf, nextMonth } from './period-policy';

const d = (s: string) => new Date(s);

describe('SubscriptionPeriodPolicy (calendar month)', () => {
  it('[T3-04] computes first and last day, across year end and February (leap and common years)', () => {
    expect(calendarMonth('2026-10')).toMatchObject({ start: d('2026-10-01T00:00:00Z'), end: d('2026-10-31T00:00:00Z') });
    expect(calendarMonth('2026-12')).toMatchObject({ start: d('2026-12-01T00:00:00Z'), end: d('2026-12-31T00:00:00Z') });
    expect(nextMonth('2026-12')).toBe('2027-01');
    expect(calendarMonth('2027-02').end).toEqual(d('2027-02-28T00:00:00Z'));
    expect(calendarMonth('2028-02').end).toEqual(d('2028-02-29T00:00:00Z'));
    expect(() => calendarMonth('2026-13')).toThrow();
  });

  it('[T3-04] uses Baghdad dates: 22:30 UTC on the 31st is already the 1st in Baghdad', () => {
    expect(monthOf(d('2026-10-31T20:59:00Z'))).toBe('2026-10');
    expect(monthOf(d('2026-10-31T21:00:00Z'))).toBe('2026-11');
    const oct = calendarMonth('2026-10');
    expect(covers(oct, d('2026-10-31T20:00:00Z'))).toBe(true);
    expect(covers(oct, d('2026-10-31T22:30:00Z'))).toBe(false);
    expect(daysLeft(oct, d('2026-10-29T08:00:00Z'))).toBe(3);
    expect(daysLeft(oct, d('2026-11-02T08:00:00Z'))).toBe(0);
  });
});
