import { messageFor, NotificationDraft, notificationsFor, RideEvent } from './rules';

/** The store keeps each dedupe key once (unique index), like the notifications table. */
function outbox() {
  const kept = new Map<string, NotificationDraft>();
  return { add: (ns: NotificationDraft[]) => ns.forEach((n) => !kept.has(n.dedupeKey) && kept.set(n.dedupeKey, n)), all: () => [...kept.values()] };
}

describe('[T5-08] notification rules', () => {
  const riders = [
    { requestId: 'r1', studentId: 's1', seq: 1 },
    { requestId: 'r2', studentId: 's2', seq: 2 },
  ];

  it('fire exactly once per event: assigned, approaching, arrived, cancelled', () => {
    const box = outbox();
    const events: RideEvent[] = [
      { type: 'assigned', requestId: 'r1', studentId: 's1', runId: 'run1' },
      { type: 'assigned', requestId: 'r1', studentId: 's1', runId: 'run1' }, // re-check, same bus
      // GPS pings every 5 s: ETA falls from 9 to 4 to 3 minutes for stop 1, stop 2 stays far.
      { type: 'eta', runId: 'run1', etas: [{ seq: 1, seconds: 540 }, { seq: 2, seconds: 900 }], riders },
      { type: 'eta', runId: 'run1', etas: [{ seq: 1, seconds: 240 }, { seq: 2, seconds: 600 }], riders },
      { type: 'eta', runId: 'run1', etas: [{ seq: 1, seconds: 180 }, { seq: 2, seconds: 540 }], riders },
      { type: 'arrived', runId: 'run1', seq: 1, riders },
      { type: 'arrived', runId: 'run1', seq: 1, riders }, // offline retry of the same action
      { type: 'cancelled', requestId: 'r2', studentId: 's2', reason: 'student' },
      { type: 'cancelled', requestId: 'r2', studentId: 's2', reason: 'student' },
    ];
    for (const e of events) box.add(notificationsFor(e));
    expect(box.all().map((n) => `${n.userId}:${n.kind}`)).toEqual(['s1:ride.assigned', 's1:ride.approaching', 's1:ride.arrived', 's2:ride.cancelled']);
    expect(box.all().find((n) => n.kind === 'ride.approaching')!.data.minutes).toBe(4);
  });

  it('a move to another bus notifies again; only riders of the stop hear "arrived"', () => {
    const box = outbox();
    box.add(notificationsFor({ type: 'assigned', requestId: 'r1', studentId: 's1', runId: 'run1' }));
    box.add(notificationsFor({ type: 'assigned', requestId: 'r1', studentId: 's1', runId: 'run2' }));
    box.add(notificationsFor({ type: 'arrived', runId: 'run2', seq: 2, riders }));
    expect(box.all().map((n) => n.dedupeKey)).toEqual(['assigned:r1:run1', 'assigned:r1:run2', 'arrived:r2']);
  });

  it('messages exist in Arabic and English for every kind', () => {
    for (const kind of ['ride.assigned', 'ride.waitlisted', 'ride.bumped', 'ride.approaching', 'ride.arrived', 'ride.expired', 'ride.cancelled'] as const) {
      expect(messageFor({ kind, data: { minutes: 4 } }, 'ar').title).toMatch(/[؀-ۿ]/);
      expect(messageFor({ kind, data: {} }, 'en').body.length).toBeGreaterThan(5);
    }
    expect(messageFor({ kind: 'ride.approaching', data: { minutes: 4 } }, 'en').body).toContain('4 minutes');
  });
});
