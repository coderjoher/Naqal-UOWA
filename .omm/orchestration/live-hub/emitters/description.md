LiveHub methods and the socket events they emit:
- bus(uni, pos) -> 'bus' to run + ops (LiveService GPS ingest, positions + ETAs).
- runStatus(uni, runId, driverId, {status, seq}) -> 'run' to run + ops + driver (RunsService after each driver action).
- runChanged(uni, runId, driverId) -> 'run:updated' to run + ops + driver (DispatchEngine afterCommit; clients refetch, DR-09).
- toUser(userId, event, payload) -> user room: 'notification' (outbox delivery), 'taxi:offer' (offer card), 'taxi:position' (driver position + ETA to the rider).
- taxiRide(uni, userIds, {rideId, status}) -> 'taxi:ride' to ops + each user room (every taxi state change).
- taxiGone(uni, rideId) -> 'taxi:gone' to taxi:{uni} (ride left requested: accepted, cancelled, expired).
- taxiPresence(uni, driverId, online) -> join/leave taxi:{uni} for that driver's sockets.
- socketCount() for metrics.
