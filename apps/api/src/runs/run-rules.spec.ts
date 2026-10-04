import { nextRunState, RunAction, RunState, stopDeparture } from './run-rules';

describe('run rules', () => {
  it('allows the DR-04 sequence and rejects everything else', () => {
    let s: RunState = 'planned';
    const step = (a: RunAction, stopsLeft: number) => (s = nextRunState(s, a, { stopsLeft })!);
    expect(step('start', 2)).toBe('started');
    expect(step('arrive', 2)).toBe('at_stop');
    expect(step('depart', 2)).toBe('started');
    expect(step('arrive', 1)).toBe('at_stop');
    expect(step('depart', 1)).toBe('started');
    expect(step('end', 0)).toBe('done');

    expect(nextRunState('planned', 'arrive', { stopsLeft: 1 })).toBeNull();
    expect(nextRunState('planned', 'end', { stopsLeft: 0 })).toBeNull();
    expect(nextRunState('started', 'start', { stopsLeft: 1 })).toBeNull();
    expect(nextRunState('started', 'end', { stopsLeft: 1 })).toBeNull(); // stops left
    expect(nextRunState('started', 'arrive', { stopsLeft: 0 })).toBeNull();
    expect(nextRunState('at_stop', 'end', { stopsLeft: 0 })).toBeNull(); // leave the stop first
    expect(nextRunState('at_stop', 'arrive', { stopsLeft: 1 })).toBeNull();
    expect(nextRunState('done', 'start', { stopsLeft: 0 })).toBeNull();
    expect(nextRunState('cancelled', 'start', { stopsLeft: 2 })).toBeNull();
  });

  it('[T5-02] no-show timer uses the configured wait and marks missing riders no_show', () => {
    const arrived = new Date('2026-10-05T04:30:00Z');
    const riders = [
      { id: 'a', boarded: true },
      { id: 'b', boarded: false },
    ];
    // 3-minute wait: one second before it ends the bus must still wait.
    const early = stopDeparture(riders, arrived, new Date(arrived.getTime() + 179_000), 3);
    expect(early).toEqual({ canDepart: false, waitLeftS: 1, noShows: [] });
    // Exactly at the configured wait: leave, the missing rider is a no-show.
    expect(stopDeparture(riders, arrived, new Date(arrived.getTime() + 180_000), 3)).toEqual({ canDepart: true, waitLeftS: 0, noShows: ['b'] });
    // A 5-minute university setting is respected.
    expect(stopDeparture(riders, arrived, new Date(arrived.getTime() + 180_000), 5).canDepart).toBe(false);
    // Everyone on board: no need to wait at all.
    expect(stopDeparture([{ id: 'a', boarded: true }], arrived, arrived, 3)).toEqual({ canDepart: true, waitLeftS: 0, noShows: [] });
  });
});
