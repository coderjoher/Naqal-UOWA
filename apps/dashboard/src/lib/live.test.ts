import { describe, expect, it } from 'vitest';
import { agoParts, applyRunStatus } from './live';

describe('applyRunStatus (TO-07)', () => {
  const run = { runId: 'r', status: 'started', stops: [{ seq: 1, arrived: false, served: false }, { seq: 2, arrived: false, served: false }] };

  it('marks the stop the bus arrived at, then served when it leaves', () => {
    const at = applyRunStatus(run, { runId: 'r', status: 'at_stop', seq: 1 });
    expect(at.status).toBe('at_stop');
    expect(at.stops[0]).toEqual({ seq: 1, arrived: true, served: false });
    const left = applyRunStatus(at, { runId: 'r', status: 'started', seq: 1 });
    expect(left.stops[0]).toEqual({ seq: 1, arrived: true, served: true });
    expect(left.stops[1]).toEqual({ seq: 2, arrived: false, served: false });
  });

  it('a status without a stop only changes the status', () => {
    expect(applyRunStatus(run, { runId: 'r', status: 'done' })).toEqual({ ...run, status: 'done' });
  });
});

describe('agoParts (T9-02)', () => {
  it('[T9-02] uses the largest whole unit', () => {
    expect(agoParts(0)).toEqual({ key: 'live.updatedAgo', n: 0 });
    expect(agoParts(59)).toEqual({ key: 'live.updatedAgo', n: 59 });
    expect(agoParts(60)).toEqual({ key: 'live.updatedAgoMin', n: 1 });
    expect(agoParts(3599)).toEqual({ key: 'live.updatedAgoMin', n: 59 });
    expect(agoParts(7200)).toEqual({ key: 'live.updatedAgoHour', n: 2 });
    expect(agoParts(2543081)).toEqual({ key: 'live.updatedAgoDay', n: 29 });
    expect(agoParts(-5)).toEqual({ key: 'live.updatedAgo', n: 0 });
  });
});
