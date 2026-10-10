RideRequest.status (enum RideStatus): one student's request for one wave on one date (ST-04). Created as open by RidesService.request (dispatch/rides.service.ts); all later transitions happen inside DispatchEngine (dispatch/dispatch.engine.ts) or RunsService.applyOne (runs/runs.service.ts):
- open -> assigned / waitlisted: DispatchEngine.plan (wave.plan job) or recheckIn (waitlist.recheck job) via save().
- waitlisted -> assigned: recheck or office extraRun; assigned -> waitlisted: 'bumped' event when a subscriber displaces a pay-per-ride rider (SM-03).
- waitlisted -> cancelled (cancelReason=expired): waitlist.expire delayed job at waitlistedUntil (min(now + university.waitlistMinutes, wave time)).
- open/waitlisted/assigned -> cancelled: DispatchEngine.cancel (student), refused once boarded or the bus passed the stop.
- assigned -> no_show: run depart (morning) or start (return) after noShowWaitMinutes for riders not boarded (SM-04, no penalty).
- assigned -> done: run end.
Each transition emits a deduplicated notification (ride.assigned / waitlisted / bumped / expired).
