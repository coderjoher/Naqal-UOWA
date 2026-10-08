# P10 — Campus taxis

Status: in-progress
Depends on: P9

## Goal

Students can call a taxi between home and campus at any time, not only at bus waves. Nearby taxi
drivers registered in the same driver app get the request; the first to accept takes it; the
student pays the distance fare in cash and it is settled like a bus cash fare. Everything built
before keeps working unchanged.

## Scope

- TX-01 Book, one active ride, cancel
- TX-02 Offer to the nearest online taxis (area only), first to accept wins
- TX-03 Distance fare shown before booking
- TX-04 Taxi drivers: registration, approval, online/offline, kept out of bus dispatch
- TX-05 Trip steps, cash fare recorded once, counted in settlement
- TX-06 Office page: switch, tariff, online taxis, today's rides
- TX-07 Driver, plate, live position and ETA; expiry of unanswered requests

## Built

- **API** (`apps/api/src/taxi/`) — `taxi_rides` table (tenant-scoped), `TaxiService`, `TaxiController`
  and a BullMQ sweep (every 20 s) that expires unanswered requests. Online taxis report a heartbeat
  every ~10–15 s into Redis; a driver counts as offline after 60 s of silence. Accepting is one
  conditional update (`status = requested AND not expired`), so two drivers can never both win.
  Offers carry the area rounded to ~500 m; the exact point, the student's name and phone go only to
  the driver who accepted (NF-12). Ending the trip records a `cash_fare` / `cash_driver` payment
  linked to the ride (idempotency key `taxi:<ride>`); settlement adds it to the driver's cash for
  the month the trip ended, so the commission rule (c × cash) applies unchanged.
- **Tariff** — per university: base fare, per km, minimum, accept window; road distance from OSRM
  (straight line × 1.3 when OSRM is down); rounded up to 250 IQD.
- **Driver rules** — vehicle type `taxi` is accepted (3–7 seats instead of the bus minimum) only
  when the university runs taxis; taxi drivers are excluded from wave availability and dispatch.
- **Realtime** — socket events `taxi:offer`, `taxi:gone`, `taxi:ride`, `taxi:position`; push
  notifications `taxi.offer`, `taxi.accepted`, `taxi.arrived`, `taxi.cancelled`, `taxi.expired`.
- **Dashboard** — *Campus taxis* page: on/off switch, KPIs, online taxis on the map, today's rides,
  tariff with a live fare preview.
- **Student app** — taxi card on Home (when enabled), pick the point on the map or by GPS, quote,
  searching, accepted with driver/plate/call/live map/ETA, arrived, on trip, pay in cash.
- **Driver app** — taxi mode for taxi drivers: online toggle with heartbeat, offer cards with a
  countdown, accept, arrived → start → end and collect cash, navigation, taxi trips in earnings.
- **Demo** — taxis switched on; taxi drivers `07800000011` … `07800000013`.

## Tests

| Test ID | Layer | Covers | What must pass |
|---------|-------|--------|----------------|
| T10-01 | unit | TX-03 | Fare = max(min, base + ⌈km × per km⌉), rounded up to 250 IQD |
| T10-02 | unit | TX-02 | Offers show a ~500 m area; only fresh, free taxis within the radius get them, nearest first |
| T10-03 | unit | TX-04 | A taxi registers with 3–7 seats only when the university runs taxis; buses keep the bus minimum |
| T10-04 | unit | TX-01, TX-05 | Ride state machine: only allowed steps; a driver who gives up puts the ride back on offer |
| T10-05 | e2e | TX-01, TX-02, TX-03 | Quote before booking; offers reach nearby online taxis only, without the exact point; one active ride; retry-safe |
| T10-06 | e2e | TX-02, TX-07 | Two drivers accept at once: exactly one wins; the student sees the driver, plate, position and ETA |
| T10-07 | e2e | TX-07, TX-02 | Driver cancel re-offers the ride; unanswered requests expire once and the student is notified |
| T10-08 | e2e | TX-05 | Ending records exactly one cash fare; the settlement counts it as the driver's cash |
| T10-09 | e2e | TX-04, TX-06 | Taxi drivers cannot set bus availability; the office sets the tariff and switches the service off |
| T10-10 | widget | TX-01, TX-07 | Student app: taxi card only when enabled; quote → searching → accepted shows driver and plate |
| T10-11 | widget | TX-04, TX-05 | Driver app: taxi drivers get taxi mode; going online shows offers; accept shows the ride; bus drivers unchanged |
| T10-12 | playwright | TX-06 | Office page shows online taxis and rides, previews the tariff and saves it |

## Exit gate

- [ ] All P10 tests green in CI
- [ ] A taxi trip run end to end on the demo stack with two phones (student and taxi driver)
