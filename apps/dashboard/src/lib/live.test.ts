import { describe, expect, it } from 'vitest';
import { applyRunStatus } from './live';

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
