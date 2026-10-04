import { cancelRequest, insertRequest, planWave, recheckWaitlist } from './dispatch';
import { arrival, load, passengers, violation } from './schedule';
import { CAMPUS, Run } from './types';
import { KARBALA, ctxFor, rider, riders } from './test-city';

const drivers = (...seats: number[]) => seats.map((s, i) => ({ id: `d${i + 1}`, seats: s }));
const ids = (run: Run) => passengers(run).map((p) => p.id).sort();

describe('dispatch domain', () => {
  describe('planWave', () => {
    it('never mixes genders and keeps every run on time', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600);
      const req = [...riders(5, 'abbas_sq'), ...riders(4, 'abbas_sq', { gender: 'female' }), ...riders(3, 'hay_hussein')];
      const { runs, waitlisted } = planWave(req, drivers(14, 14, 14), ctx);
      expect(waitlisted).toEqual([]);
      expect(runs).toHaveLength(2);
      for (const r of runs) {
        expect(violation(r, ctx)).toBeNull();
        expect(new Set(passengers(r).map((p) => p.gender)).size).toBe(1);
        expect(arrival(r, ctx)).toBeLessThanOrEqual(8 * 3600 - ctx.cfg.bufferS);
      }
    });

    it('waitlists what does not fit, subscribers first', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600);
      const payPerRide = riders(2, 'abbas_sq', { subscriber: false, createdAt: 0 });
      const subs = riders(3, 'abbas_sq', { createdAt: 100 });
      const { runs, waitlisted } = planWave([...payPerRide, ...subs], drivers(4), ctx);
      expect(load(runs[0])).toBe(4);
      expect(waitlisted).toHaveLength(1);
      expect(waitlisted[0].subscriber).toBe(false);
    });

    it('orders morning stops from far to near and return stops from near to far', () => {
      const req = [...riders(2, 'bab_baghdad'), ...riders(2, 'al_hurr'), ...riders(2, 'abbas_sq')];
      const morning = planWave(req, drivers(10), ctxFor(KARBALA, 'morning', 8, 6 * 3600)).runs[0];
      expect(morning.stops.map((s) => s.pointId)).toEqual(['al_hurr', 'abbas_sq', 'bab_baghdad']);
      const ret = planWave(req, drivers(10), ctxFor(KARBALA, 'return', 14, 12 * 3600)).runs[0];
      expect(ret.stops.map((s) => s.pointId)).toEqual(['bab_baghdad', 'abbas_sq', 'al_hurr']);
      expect(ret.stops[0].time).toBe(14 * 3600 + ctxFor(KARBALA).travel(CAMPUS, 'bab_baghdad'));
    });

    it('splits a point with more riders than seats across buses', () => {
      const { runs, waitlisted } = planWave(riders(20, 'abbas_sq'), drivers(12, 12), ctxFor(KARBALA, 'morning', 8, 6 * 3600));
      expect(waitlisted).toEqual([]);
      expect(runs.map(load).sort()).toEqual([12, 8]);
    });
  });

  describe('[T4-03] cheapest insertion', () => {
    it('picks the smallest detour among runs with a free seat that have not passed the point', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600);
      const { runs } = planWave([...riders(2, 'al_hurr', { tierId: 'C', tierRank: 2 }), ...riders(2, 'hindiya_rd')], drivers(10, 10), ctx);
      expect(runs).toHaveLength(2);
      const viaHurr = runs.find((r) => r.stops[0].pointId === 'al_hurr')!;
      // hay_hussein lies on the way from al_hurr; the hindiya_rd bus would need a long detour.
      const r = insertRequest(runs, rider('hay_hussein', { tierId: 'C', tierRank: 2 }), ctx);
      expect(r.placed).toBe(true);
      expect(r.runId).toBe(viaHurr.id);

      // A full run is never chosen, even when it is the cheapest.
      const full = runs.map((x) => (x.id === viaHurr.id ? { ...x, capacity: load(x) } : x));
      expect(insertRequest(full, rider('hay_hussein', { tierId: 'C', tierRank: 2 }), ctx).runId).not.toBe(viaHurr.id);
    });

    it('does not insert before a stop the bus has already served', () => {
      const plan = planWave([...riders(2, 'al_hurr'), ...riders(2, 'bab_baghdad')], drivers(10), ctxFor(KARBALA, 'morning', 8, 6 * 3600));
      const run = plan.runs[0];
      // The bus has served al_hurr and is on its way; al_hurr cannot take new riders any more.
      const ctx = ctxFor(KARBALA, 'morning', 8, run.stops[0].time + 1);
      const r = insertRequest(plan.runs, rider('al_hurr'), ctx);
      expect(r.placed).toBe(false);
      // A later stop can still be joined.
      expect(insertRequest(plan.runs, rider('bab_baghdad'), ctx).placed).toBe(true);
    });

    it('joining an existing stop costs nothing and keeps times', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600);
      const { runs } = planWave(riders(2, 'abbas_sq'), drivers(10), ctx);
      const r = insertRequest(runs, rider('abbas_sq'), ctx);
      expect(r.runs[0].stops).toHaveLength(1);
      expect(r.runs[0].stops[0].time).toBe(runs[0].stops[0].time);
    });

    it('return runs only take riders before they leave campus', () => {
      const plan = planWave(riders(2, 'abbas_sq'), drivers(10), ctxFor(KARBALA, 'return', 14, 13 * 3600));
      expect(insertRequest(plan.runs, rider('bab_baghdad'), ctxFor(KARBALA, 'return', 14, 13 * 3600)).placed).toBe(true);
      expect(insertRequest(plan.runs, rider('bab_baghdad'), ctxFor(KARBALA, 'return', 14, 14 * 3600)).placed).toBe(false);
    });
  });

  describe('[T4-04] subscriber priority', () => {
    const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600);

    it('gives the last seat to the subscriber when both compete in planning', () => {
      const payer = rider('abbas_sq', { subscriber: false, createdAt: 1 });
      const sub = rider('abbas_sq', { subscriber: true, createdAt: 2 });
      const { runs, waitlisted } = planWave([...riders(3, 'abbas_sq', { createdAt: 0 }), payer, sub], drivers(4), ctx);
      expect(ids(runs[0])).toContain(sub.id);
      expect(waitlisted.map((p) => p.id)).toEqual([payer.id]);
    });

    it('bumps a pay-per-ride rider, never a subscriber, when a subscriber arrives to a full bus', () => {
      const payerEarly = rider('abbas_sq', { subscriber: false, createdAt: 1 });
      const payerLate = rider('abbas_sq', { subscriber: false, createdAt: 5 });
      const { runs } = planWave([...riders(2, 'abbas_sq', { createdAt: 0 }), payerEarly, payerLate], drivers(4), ctx);
      expect(load(runs[0])).toBe(4);

      const sub = rider('abbas_sq', { subscriber: true, createdAt: 9 });
      const r = insertRequest(runs, sub, ctx);
      expect(r.placed).toBe(true);
      expect(r.bumped?.id).toBe(payerLate.id); // lowest priority leaves first
      expect(ids(r.runs[0])).toContain(sub.id);

      // A pay-per-ride request never bumps anyone.
      expect(insertRequest(r.runs, rider('abbas_sq', { subscriber: false }), ctx).placed).toBe(false);
      // With only subscribers on board, a subscriber cannot bump.
      const allSubs = planWave(riders(4, 'abbas_sq'), drivers(4), ctx).runs;
      expect(insertRequest(allSubs, rider('abbas_sq'), ctx).placed).toBe(false);
    });

    it('never bumps a rider who has boarded', () => {
      const payer = rider('abbas_sq', { subscriber: false, boarded: true });
      const { runs } = planWave([payer, ...riders(3, 'abbas_sq')], drivers(4), ctx);
      expect(insertRequest(runs, rider('abbas_sq'), ctx).placed).toBe(false);
    });

    it('seats subscribers from the waitlist before earlier pay-per-ride riders', () => {
      const { runs } = planWave(riders(3, 'abbas_sq'), drivers(4), ctx);
      const payer = { passenger: rider('abbas_sq', { subscriber: false, createdAt: 1 }), expiresAt: 7 * 3600 };
      const sub = { passenger: rider('abbas_sq', { subscriber: true, createdAt: 50 }), expiresAt: 7 * 3600 };
      const r = recheckWaitlist(runs, [payer, sub], ctx, 1800);
      expect(r.events).toEqual([{ type: 'assigned', requestId: sub.passenger.id, runId: runs[0].id }]);
      expect(r.waitlist.map((w) => w.passenger.id)).toEqual([payer.passenger.id]);
    });
  });

  describe('[T4-05] waitlist', () => {
    it('assigns a waitlisted request after a cancellation and expires exactly at the configured time', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600);
      const seated = riders(4, 'abbas_sq');
      const plan = planWave([...seated, rider('abbas_sq', { createdAt: 99 })], drivers(4), ctx);
      expect(plan.waitlisted).toHaveLength(1);
      const entry = { passenger: plan.waitlisted[0], expiresAt: ctx.now + 30 * 60 };

      // Nothing frees up: still waiting one second before expiry…
      const still = recheckWaitlist(plan.runs, [entry], { ...ctx, now: entry.expiresAt - 1 }, 1800);
      expect(still.events).toEqual([]);
      expect(still.waitlist).toHaveLength(1);
      // …and expired exactly at the configured time, with an event for the notification.
      const gone = recheckWaitlist(plan.runs, [entry], { ...ctx, now: entry.expiresAt }, 1800);
      expect(gone.events).toEqual([{ type: 'expired', requestId: entry.passenger.id }]);
      expect(gone.waitlist).toEqual([]);

      // A cancellation frees the seat and the re-check fills it.
      const { runs, freed } = cancelRequest(plan.runs, seated[0].id, ctx);
      expect(freed).toBe(true);
      const after = recheckWaitlist(runs, [entry], { ...ctx, now: ctx.now + 60 }, 1800);
      expect(after.events).toEqual([{ type: 'assigned', requestId: entry.passenger.id, runId: runs[0].id }]);
      expect(load(after.runs[0])).toBe(4);
    });

    it('drops the stop when its last rider cancels and re-times the run', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600);
      const far = rider('al_hurr');
      const plan = planWave([far, ...riders(2, 'bab_baghdad')], drivers(10), ctx);
      expect(plan.runs[0].stops).toHaveLength(2);
      const { runs } = cancelRequest(plan.runs, far.id, ctx);
      expect(runs[0].stops.map((s) => s.pointId)).toEqual(['bab_baghdad']);
      expect(runs[0].stops[0].time).toBeGreaterThan(plan.runs[0].stops[1].time - 1); // no earlier than before
      expect(cancelRequest(runs, 'nope', ctx).freed).toBe(false);
    });

    it('refuses to remove a rider whose stop was already served', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600);
      const far = rider('al_hurr');
      const plan = planWave([far, ...riders(2, 'bab_baghdad')], drivers(10), ctx);
      const later = { ...ctx, now: plan.runs[0].stops[0].time + 1 };
      expect(cancelRequest(plan.runs, far.id, later).freed).toBe(false);
    });
  });

  describe('[T4-06] tiers', () => {
    const a = (n: number, at: string) => riders(n, at, { tierId: 'A', tierRank: 0 });
    const c = (n: number, at: string) => riders(n, at, { tierId: 'C', tierRank: 2 });
    const req = () => [...c(3, 'hay_hussein'), ...a(3, 'abbas_sq')];

    it('tags each run with the tier of its farthest stop', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600, { mixTierThresholdS: 0 });
      const { runs } = planWave(req(), drivers(10, 10), ctx);
      expect(runs).toHaveLength(1); // mixing allowed: one bus picks up both
      expect(runs[0].tierId).toBe('C');
      expect(runs[0].stops.map((s) => s.pointId)).toEqual(['hay_hussein', 'abbas_sq']);
    });

    it('keeps runs single-tier when the saving is within the threshold', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600, { mixTierThresholdS: 4 * 3600 });
      const { runs } = planWave(req(), drivers(10, 10), ctx);
      expect(runs).toHaveLength(2);
      expect(runs.map((r) => r.tierId).sort()).toEqual(['A', 'C']);
      for (const r of runs) expect(new Set(passengers(r).map((p) => p.tierId)).size).toBe(1);
    });

    it('mixes tiers when buses run out rather than leaving riders behind', () => {
      const ctx = ctxFor(KARBALA, 'morning', 8, 6 * 3600, { mixTierThresholdS: 4 * 3600 });
      const { runs, waitlisted } = planWave(req(), drivers(10), ctx);
      expect(waitlisted).toEqual([]);
      expect(runs).toHaveLength(1);
      expect(runs[0].tierId).toBe('C');
    });
  });
});
