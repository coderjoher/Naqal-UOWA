Room names from rooms in live/live.hub.ts:
- run:{runId} - riders of that run, its driver, office (joined via 'join').
- ops:{universityId} - office staff of the university (auto on connect).
- user:{userId} - every socket of a user (auto on connect); notification and taxi delivery target.
- driver:{driverId} - driver sockets (auto on connect); run status/updates.
- taxi:{universityId} - online taxi drivers (P10); joined/left server-side by taxiPresence from heartbeat/goOffline via socketsJoin/socketsLeave on the driver's user room.
