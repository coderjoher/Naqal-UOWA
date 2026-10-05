import { computeReport, reportCsv, ReportInput } from './metrics';

const T = (h: number, m = 0) => Date.UTC(2026, 9, 5, h - 3, m); // Baghdad clock on 5 Oct 2026

/** A small month worked out by hand. */
const fixture: ReportInput = {
  tiers: [
    { id: 'A', name: 'A' },
    { id: 'B', name: 'B' },
  ],
  requests: [
    // Tier A: 6 requests, 1 cancelled by the student (not counted), 4 served (one no-show), 1 expired.
    { tierId: 'A', status: 'done', cancelReason: null, fare: 0 },
    { tierId: 'A', status: 'done', cancelReason: null, fare: 1500 },
    { tierId: 'A', status: 'done', cancelReason: null, fare: 0 },
    { tierId: 'A', status: 'no_show', cancelReason: null, fare: 0 },
    { tierId: 'A', status: 'cancelled', cancelReason: 'expired', fare: 0 },
    { tierId: 'A', status: 'cancelled', cancelReason: 'student', fare: 0 },
    // Tier B: 4 requests, 2 served, 1 expired, 1 cancelled by the office (counted as not served).
    { tierId: 'B', status: 'done', cancelReason: null, fare: 0 },
    { tierId: 'B', status: 'done', cancelReason: null, fare: 2500 },
    { tierId: 'B', status: 'cancelled', cancelReason: 'expired', fare: 2500 },
    { tierId: 'B', status: 'cancelled', cancelReason: 'office', fare: 0 },
  ],
  runs: [
    // Morning 08:00: reached campus 07:52 (on time), 08:04 (late). Return 14:00: left 14:03 (on time), 14:09 (late).
    { tierId: 'A', waveType: 'morning', waveAt: T(8), status: 'done', startedAt: T(7, 10), endedAt: T(7, 52) },
    { tierId: 'A', waveType: 'morning', waveAt: T(8), status: 'done', startedAt: T(7, 20), endedAt: T(8, 4) },
    { tierId: 'B', waveType: 'return', waveAt: T(14), status: 'done', startedAt: T(14, 3), endedAt: T(14, 40) },
    { tierId: 'B', waveType: 'return', waveAt: T(14), status: 'done', startedAt: T(14, 9), endedAt: T(14, 50) },
    // Not finished: not in the on-time denominator.
    { tierId: 'B', waveType: 'morning', waveAt: T(8), status: 'started', startedAt: T(7, 30), endedAt: null },
  ],
  subscriptions: [
    { studentId: 's1', tierId: 'A', price: 40000 },
    { studentId: 's2', tierId: 'A', price: 40000 },
    { studentId: 's3', tierId: 'B', price: 60000 },
  ],
  previousSubscribers: [
    { studentId: 's1', tierId: 'A' },
    { studentId: 's4', tierId: 'A' },
    { studentId: 's3', tierId: 'B' },
    { studentId: 's5', tierId: 'B' },
  ],
  cashFares: [
    { tierId: 'A', amount: 1500 },
    { tierId: 'B', amount: 2500 },
    { tierId: 'B', amount: 500 },
  ],
};

describe('reports (TO-10)', () => {
  it('[T7-04] fulfilment, on-time, waitlist-expiry and renewal match hand-computed fixtures', () => {
    const r = computeReport(fixture);
    // Requested: 10 − 1 (student cancelled) = 9; served: 4 + 2 = 6.
    expect(r.fulfilment).toEqual({ value: 66.7, num: 6, den: 9 });
    // Finished runs: 4; on time: 07:52 morning and 14:03 return.
    expect(r.onTime).toEqual({ value: 50, num: 2, den: 4 });
    // Expired: 2 of 9.
    expect(r.waitlistExpiry).toEqual({ value: 22.2, num: 2, den: 9 });
    // Renewal: s1 and s3 of s1, s4, s3, s5.
    expect(r.renewal).toEqual({ value: 50, num: 2, den: 4 });
    expect(r.subscribers).toBe(3);
    expect(r.tiers).toEqual([
      { tierId: 'A', name: 'A', subscribers: 2, subscriptions: 80000, cash: 1500, revenue: 81500 },
      { tierId: 'B', name: 'B', subscribers: 1, subscriptions: 60000, cash: 3000, revenue: 63000 },
    ]);
    expect(r.revenue).toBe(144500);
  });

  it('filters by tier', () => {
    const a = computeReport(fixture, 'A');
    expect(a.fulfilment).toEqual({ value: 80, num: 4, den: 5 });
    expect(a.onTime).toEqual({ value: 50, num: 1, den: 2 });
    expect(a.waitlistExpiry).toEqual({ value: 20, num: 1, den: 5 });
    expect(a.renewal).toEqual({ value: 50, num: 1, den: 2 });
    expect(a.tiers.map((t) => t.tierId)).toEqual(['A']);
    expect(a.revenue).toBe(81500);
  });

  it('an empty month has no rates rather than 0 %', () => {
    const r = computeReport({ tiers: [], requests: [], runs: [], subscriptions: [], previousSubscribers: [], cashFares: [] });
    expect(r.fulfilment.value).toBeNull();
    expect(r.onTime.value).toBeNull();
    expect(r.renewal.value).toBeNull();
  });

  it('exports CSV that Excel opens (BOM, CRLF, quoted cells)', () => {
    const csv = reportCsv('2026-10', computeReport({ ...fixture, tiers: [{ id: 'A', name: 'A, near' }, { id: 'B', name: 'B' }] }));
    expect(csv.startsWith('﻿month,2026-10\r\n')).toBe(true);
    expect(csv).toContain('fulfilment_pct,66.7\r\n');
    expect(csv).toContain('"A, near",2,80000,1500,81500\r\n');
  });
});
