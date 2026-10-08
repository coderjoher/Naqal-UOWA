import { BadRequestException, ConflictException, ForbiddenException, Inject, Injectable, Logger, NotFoundException, UnprocessableEntityException } from '@nestjs/common';
import type { Prisma, TaxiDirection, TaxiRide, TaxiRideStatus } from '@prisma/client';
import type Redis from 'ioredis';
import { baghdadDate } from '../dispatch/clock';
import { TAXI } from '../drivers/driver-rules';
import { haversineKm, insidePolygon, isPolygon, LatLng } from '../geo/geo';
import { LiveHub } from '../live/live.hub';
import { NotificationsService } from '../notifications/notifications.service';
import type { NotificationDraft } from '../notifications/rules';
import { PaymentsService } from '../payments/payments.service';
import { PrismaService, Tx } from '../prisma/prisma.service';
import { REDIS } from '../redis/redis.module';
import { RoutingService } from '../routing/routing.service';
import { runAsSystem, runAsTenant } from '../tenancy/tenant-context';
import { ACTIVE_TAXI, coarse, driversToOffer, etaMinutes, fareFor, nextTaxiState, ONLINE_STALE_MS, OnlineTaxi, OFFER_RADIUS_KM, TaxiAction } from './taxi-rules';

export interface TaxiRequestInput {
  direction: TaxiDirection;
  lat: number;
  lng: number;
  label?: string;
  clientId: string;
}

export interface TaxiSettingsInput {
  taxiEnabled?: boolean;
  taxiBaseFare?: number;
  taxiPerKm?: number;
  taxiMinFare?: number;
  taxiOfferSeconds?: number;
}

const DRIVER_BUSY: TaxiRideStatus[] = ['accepted', 'arrived', 'on_trip'];
const onlineKey = (universityId: string) => `taxi:online:${universityId}`;

type RideWithPeople = TaxiRide & {
  student: { id: string; name: string; nameAr: string | null; phone: string | null };
  driver: { id: string; name: string; nameAr: string | null; phone: string | null; loginPhone: string | null; driver: { plate: string | null; seats: number | null; vehicleType: string | null } | null } | null;
};

const PEOPLE = {
  student: { select: { id: true, name: true, nameAr: true, phone: true } },
  driver: { select: { id: true, name: true, nameAr: true, phone: true, loginPhone: true, driver: { select: { plate: true, seats: true, vehicleType: true } } } },
} satisfies Prisma.TaxiRideInclude;

/**
 * P10 campus taxis. A student asks for a taxi between their location and campus; the nearest
 * online taxi drivers get an offer that shows only the area; the first to accept takes it; the
 * driver collects the distance fare in cash, recorded like a bus cash fare (settled monthly).
 */
@Injectable()
export class TaxiService {
  private readonly log = new Logger(TaxiService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly routing: RoutingService,
    private readonly payments: PaymentsService,
    private readonly notifications: NotificationsService,
    private readonly hub: LiveHub,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  /** Overridden in tests. */
  now() {
    return new Date();
  }

  // ── shared ───────────────────────────────────────────────────────────────────

  private async university(universityId: string) {
    return this.prisma.db.university.findUniqueOrThrow({
      where: { id: universityId },
      select: { id: true, campusLat: true, campusLng: true, coverage: true, taxiEnabled: true, taxiBaseFare: true, taxiPerKm: true, taxiMinFare: true, taxiOfferSeconds: true },
    });
  }

  private tariff(u: { taxiBaseFare: number; taxiPerKm: number; taxiMinFare: number }) {
    return { baseFare: u.taxiBaseFare, perKm: u.taxiPerKm, minFare: u.taxiMinFare };
  }

  /** Online taxis of a university (fresh heartbeats only). */
  async online(universityId: string): Promise<OnlineTaxi[]> {
    const all = await this.redis.hgetall(onlineKey(universityId));
    const now = this.now().getTime();
    const out: OnlineTaxi[] = [];
    for (const [driverId, v] of Object.entries(all)) {
      try {
        const p = JSON.parse(v) as { lat: number; lng: number; at: number };
        if (now - p.at <= ONLINE_STALE_MS) out.push({ driverId, lat: p.lat, lng: p.lng, at: p.at });
      } catch {
        /* ignore a corrupt entry */
      }
    }
    return out;
  }

  private async position(universityId: string, driverId: string) {
    const v = await this.redis.hget(onlineKey(universityId), driverId);
    if (!v) return null;
    try {
      const p = JSON.parse(v) as { lat: number; lng: number; at: number };
      return { lat: p.lat, lng: p.lng, at: new Date(p.at).toISOString() };
    } catch {
      return null;
    }
  }

  private async busyDrivers(): Promise<Set<string>> {
    const rows = await this.prisma.db.taxiRide.findMany({ where: { status: { in: DRIVER_BUSY }, driverId: { not: null } }, select: { driverId: true } });
    return new Set(rows.map((r) => r.driverId!));
  }

  private studentPoint(r: Pick<TaxiRide, 'lat' | 'lng'>): LatLng {
    return { lat: r.lat, lng: r.lng };
  }

  /** Moves a ride from one status to the next only if it is still where we saw it (no lost updates). */
  private async transition(tx: Tx, ride: TaxiRide, action: TaxiAction, data: Prisma.TaxiRideUncheckedUpdateManyInput = {}) {
    const to = nextTaxiState(ride.status, action);
    if (!to) throw new ConflictException(`This ride is ${ride.status.replace('_', ' ')}`);
    const res = await tx.taxiRide.updateMany({ where: { id: ride.id, status: ride.status, driverId: ride.driverId }, data: { ...data, status: to } });
    if (res.count === 0) throw new ConflictException('The ride changed; refresh and try again');
    return to;
  }

  // ── student ──────────────────────────────────────────────────────────────────

  /** TX-03: the fare is known before booking, with how many taxis are around. */
  async quote(universityId: string, direction: TaxiDirection, point: LatLng) {
    const u = await this.university(universityId);
    if (!u.taxiEnabled) throw new UnprocessableEntityException('Campus taxis are not available at this university');
    if (isPolygon(u.coverage) && !insidePolygon(point, u.coverage)) throw new UnprocessableEntityException('This place is outside the service area');
    const route = await this.routing.toCampus(point, { lat: u.campusLat, lng: u.campusLng });
    const distanceKm = Math.round(route.distanceKm * 10) / 10;
    const near = driversToOffer(await this.online(universityId), point, this.now().getTime(), await this.busyDrivers());
    return {
      direction,
      distanceKm,
      durationMin: route.durationMin === null ? null : Math.max(1, Math.round(route.durationMin)),
      fare: fareFor(distanceKm, this.tariff(u)),
      tariff: this.tariff(u),
      taxisNearby: near.length,
      pickupMin: near.length ? etaMinutes(near[0], point) : null,
      campus: { lat: u.campusLat, lng: u.campusLng },
    };
  }

  /** TX-01 / TX-02: book; one active ride per student; a retried request returns the same ride. */
  async request(universityId: string, studentId: string, input: TaxiRequestInput) {
    const db = this.prisma.db;
    const same = await db.taxiRide.findUnique({ where: { clientId: input.clientId } });
    if (same) {
      if (same.studentId !== studentId) throw new ConflictException('Duplicate request key');
      return this.forStudent(studentId, same.id);
    }
    const active = await db.taxiRide.findFirst({ where: { studentId, status: { in: ACTIVE_TAXI } }, select: { id: true } });
    if (active) throw new ConflictException('You already have a taxi ride in progress');
    const q = await this.quote(universityId, input.direction, input);
    const u = await this.university(universityId);
    let ride: TaxiRide;
    try {
      ride = await db.taxiRide.create({
        data: {
          universityId,
          studentId,
          direction: input.direction,
          lat: input.lat,
          lng: input.lng,
          label: input.label?.trim() || null,
          distanceKm: q.distanceKm,
          fare: q.fare,
          clientId: input.clientId,
          expiresAt: new Date(this.now().getTime() + u.taxiOfferSeconds * 1000),
        },
      });
    } catch (e) {
      if ((e as { code?: string }).code === 'P2002') {
        const r = await db.taxiRide.findUnique({ where: { clientId: input.clientId } });
        if (r && r.studentId === studentId) return this.forStudent(studentId, r.id);
      }
      throw e;
    }
    await this.offer(universityId, ride);
    this.hub.taxiRide(universityId, [studentId], { rideId: ride.id, status: ride.status });
    return this.forStudent(studentId, ride.id);
  }

  /** Sends the offer to the nearest free taxis: a card in the app and a push. */
  private async offer(universityId: string, ride: TaxiRide) {
    const drivers = driversToOffer(await this.online(universityId), this.studentPoint(ride), this.now().getTime(), await this.busyDrivers());
    if (!drivers.length) return 0;
    const round = ride.expiresAt.getTime();
    const drafts: NotificationDraft[] = drivers.map((d) => ({
      userId: d.driverId,
      kind: 'taxi.offer',
      dedupeKey: `taxi-offer:${ride.id}:${d.driverId}:${round}`,
      data: { rideId: ride.id, direction: ride.direction, fare: ride.fare },
    }));
    await this.notifications.addNow(universityId, drafts);
    for (const d of drivers) this.hub.toUser(d.driverId, 'taxi:offer', this.offerCard(ride, d));
    return drivers.length;
  }

  /** What a driver sees before accepting: the area, not the exact point (TX-02 / NF-12). */
  private offerCard(ride: TaxiRide, from: LatLng | null) {
    const area = coarse(this.studentPoint(ride));
    return {
      id: ride.id,
      direction: ride.direction,
      area,
      distanceKm: ride.distanceKm,
      fare: ride.fare,
      expiresAt: ride.expiresAt.toISOString(),
      awayKm: from ? Math.round(haversineKm(from, area) * 10) / 10 : null,
    };
  }

  async cancelByStudent(universityId: string, studentId: string, rideId: string) {
    const ride = await this.prisma.db.taxiRide.findFirst({ where: { id: rideId, studentId } });
    if (!ride) throw new NotFoundException();
    await this.prisma.db.$transaction(async (tx) => {
      await this.transition(tx as Tx, ride, 'cancel_student', { cancelledAt: this.now(), cancelledBy: 'student' });
      if (ride.driverId) {
        await NotificationsService.add(tx as Tx, universityId, [{ userId: ride.driverId, kind: 'taxi.cancelled', dedupeKey: `taxi-cancel:${ride.id}`, data: { rideId: ride.id } }]);
      }
    });
    await this.notifications.deliverPending(universityId);
    this.hub.taxiGone(universityId, ride.id);
    this.hub.taxiRide(universityId, [studentId, ...(ride.driverId ? [ride.driverId] : [])], { rideId: ride.id, status: 'cancelled' });
    return this.forStudent(studentId, ride.id);
  }

  /** The student's view: the driver and car once accepted, the taxi's position and ETA. */
  async forStudent(studentId: string, rideId: string) {
    const ride = (await this.prisma.db.taxiRide.findFirst({ where: { id: rideId, studentId }, include: PEOPLE })) as RideWithPeople | null;
    if (!ride) throw new NotFoundException();
    return this.studentView(ride);
  }

  private async studentView(ride: RideWithPeople) {
    const showDriver = ride.driver && ride.status !== 'requested';
    const live = showDriver && ACTIVE_TAXI.includes(ride.status) ? await this.position(ride.universityId, ride.driver!.id) : null;
    const campus = await this.prisma.db.university.findUniqueOrThrow({ where: { id: ride.universityId }, select: { campusLat: true, campusLng: true } });
    // Before pickup the taxi heads to the student's point (or the campus gate for trips home).
    const pickup = ride.direction === 'to_campus' ? this.studentPoint(ride) : { lat: campus.campusLat, lng: campus.campusLng };
    const dropoff = ride.direction === 'to_campus' ? { lat: campus.campusLat, lng: campus.campusLng } : this.studentPoint(ride);
    const target = ride.status === 'on_trip' ? dropoff : pickup;
    return {
      id: ride.id,
      status: ride.status,
      direction: ride.direction,
      lat: ride.lat,
      lng: ride.lng,
      label: ride.label,
      distanceKm: ride.distanceKm,
      fare: ride.fare,
      expiresAt: ride.expiresAt.toISOString(),
      createdAt: ride.createdAt.toISOString(),
      acceptedAt: ride.acceptedAt?.toISOString() ?? null,
      arrivedAt: ride.arrivedAt?.toISOString() ?? null,
      startedAt: ride.startedAt?.toISOString() ?? null,
      endedAt: ride.endedAt?.toISOString() ?? null,
      cancelledBy: ride.cancelledBy,
      pickup,
      dropoff,
      driver: showDriver
        ? {
            id: ride.driver!.id,
            name: ride.driver!.nameAr || ride.driver!.name,
            phone: ACTIVE_TAXI.includes(ride.status) ? ride.driver!.loginPhone ?? ride.driver!.phone : null,
            plate: ride.driver!.driver?.plate ?? null,
            seats: ride.driver!.driver?.seats ?? null,
          }
        : null,
      taxi: live,
      etaMin: live && (ride.status === 'accepted' || ride.status === 'on_trip') ? etaMinutes(live, target) : null,
    };
  }

  /** The active ride (if any) and the last rides. */
  async mine(studentId: string) {
    const rows = (await this.prisma.db.taxiRide.findMany({ where: { studentId }, orderBy: { createdAt: 'desc' }, take: 20, include: PEOPLE })) as RideWithPeople[];
    const views = await Promise.all(rows.map((r) => this.studentView(r)));
    return { active: views.find((v) => ACTIVE_TAXI.includes(v.status)) ?? null, history: views.filter((v) => !ACTIVE_TAXI.includes(v.status)) };
  }

  // ── driver ───────────────────────────────────────────────────────────────────

  /** Only approved drivers registered with the taxi vehicle type drive taxis. */
  private async assertTaxiDriver(universityId: string, driverId: string, opts: { evenIfOff?: boolean } = {}) {
    const [p, u] = await Promise.all([
      this.prisma.db.driverProfile.findUnique({ where: { userId: driverId }, select: { status: true, vehicleType: true } }),
      this.university(universityId),
    ]);
    if (!p || p.vehicleType !== TAXI) throw new ForbiddenException('Only taxi drivers can do this');
    if (p.status !== 'approved') throw new ForbiddenException('Your registration is not approved');
    if (!u.taxiEnabled && !opts.evenIfOff) throw new UnprocessableEntityException('Campus taxis are switched off');
    return u;
  }

  /** TX-04: heartbeat while online; forwards the taxi's position to its rider. Returns open offers. */
  async heartbeat(universityId: string, driverId: string, point: LatLng) {
    // A trip already under way still reports its position if the office switches taxis off.
    const active = await this.prisma.db.taxiRide.findFirst({ where: { driverId, status: { in: DRIVER_BUSY } } });
    await this.assertTaxiDriver(universityId, driverId, { evenIfOff: !!active });
    const at = this.now().getTime();
    await this.redis.hset(onlineKey(universityId), driverId, JSON.stringify({ lat: point.lat, lng: point.lng, at }));
    this.hub.taxiPresence(universityId, driverId, true);
    if (active) {
      const u = await this.university(universityId);
      const campus = { lat: u.campusLat, lng: u.campusLng };
      // Heading to the pickup (the student, or the campus gate for trips home), then to the drop-off.
      const toStudent = (active.direction === 'to_campus') === (active.status !== 'on_trip');
      const etaMin = active.status === 'arrived' ? null : etaMinutes(point, toStudent ? this.studentPoint(active) : campus);
      this.hub.toUser(active.studentId, 'taxi:position', { rideId: active.id, lat: point.lat, lng: point.lng, at: new Date(at).toISOString(), etaMin });
      return { online: true, active: await this.forDriver(driverId, active.id), offers: [] };
    }
    return { online: true, active: null, offers: await this.offersFor(universityId, driverId, point) };
  }

  async goOffline(universityId: string, driverId: string) {
    await this.redis.hdel(onlineKey(universityId), driverId);
    this.hub.taxiPresence(universityId, driverId, false);
    return { online: false };
  }

  /** Open requests near the driver, area only. */
  async offersFor(universityId: string, driverId: string, from?: LatLng) {
    const me = from ?? (await this.position(universityId, driverId));
    if (!me) return [];
    const open = await this.prisma.db.taxiRide.findMany({ where: { status: 'requested', expiresAt: { gt: this.now() } }, orderBy: { createdAt: 'asc' }, take: 50 });
    return open.filter((r) => haversineKm(me, this.studentPoint(r)) <= OFFER_RADIUS_KM).map((r) => this.offerCard(r, me));
  }

  /** TX-02: first to accept takes it — a conditional update, so two drivers can never both win. */
  async accept(universityId: string, driverId: string, rideId: string) {
    await this.assertTaxiDriver(universityId, driverId);
    const db = this.prisma.db;
    const busy = await db.taxiRide.findFirst({ where: { driverId, status: { in: DRIVER_BUSY } }, select: { id: true } });
    if (busy) throw new ConflictException('Finish your current ride first');
    const now = this.now();
    const driverName = await db.user.findUniqueOrThrow({ where: { id: driverId }, select: { name: true, nameAr: true } });
    const ride = await db.$transaction(async (tx) => {
      const won = await tx.taxiRide.updateMany({ where: { id: rideId, status: 'requested', expiresAt: { gt: now } }, data: { status: 'accepted', driverId, acceptedAt: now } });
      if (won.count === 0) throw new ConflictException('Another driver took this ride, or it is no longer open');
      const r = await tx.taxiRide.findUniqueOrThrow({ where: { id: rideId } });
      await NotificationsService.add(tx as Tx, universityId, [
        { userId: r.studentId, kind: 'taxi.accepted', dedupeKey: `taxi-accepted:${r.id}:${driverId}`, data: { rideId: r.id, driverName: driverName.nameAr || driverName.name } },
      ]);
      return r;
    });
    await this.notifications.deliverPending(universityId);
    this.hub.taxiGone(universityId, ride.id);
    this.hub.taxiRide(universityId, [ride.studentId, driverId], { rideId: ride.id, status: ride.status });
    return this.forDriver(driverId, ride.id);
  }

  private async driverRide(driverId: string, rideId: string) {
    const ride = await this.prisma.db.taxiRide.findFirst({ where: { id: rideId, driverId } });
    if (!ride) throw new NotFoundException();
    return ride;
  }

  async arrive(universityId: string, driverId: string, rideId: string) {
    const ride = await this.driverRide(driverId, rideId);
    await this.prisma.db.$transaction(async (tx) => {
      await this.transition(tx as Tx, ride, 'arrive', { arrivedAt: this.now() });
      await NotificationsService.add(tx as Tx, universityId, [{ userId: ride.studentId, kind: 'taxi.arrived', dedupeKey: `taxi-arrived:${ride.id}`, data: { rideId: ride.id } }]);
    });
    await this.notifications.deliverPending(universityId);
    return this.changed(universityId, driverId, ride, 'arrived');
  }

  async start(universityId: string, driverId: string, rideId: string) {
    const ride = await this.driverRide(driverId, rideId);
    await this.prisma.db.$transaction((tx) => this.transition(tx as Tx, ride, 'start', { startedAt: this.now(), arrivedAt: ride.arrivedAt ?? this.now() }));
    return this.changed(universityId, driverId, ride, 'on_trip');
  }

  /** TX-05: ending the trip records the cash fare the driver collected (immutable, receipted). */
  async end(universityId: string, driverId: string, rideId: string) {
    const ride = await this.driverRide(driverId, rideId);
    if (ride.status === 'done') return this.forDriver(driverId, ride.id);
    await this.prisma.db.$transaction(async (tx) => {
      await this.transition(tx as Tx, ride, 'end', { endedAt: this.now() });
      await this.payments.record(tx as Tx, {
        universityId,
        type: 'cash_fare',
        method: 'cash_driver',
        amount: ride.fare,
        studentId: ride.studentId,
        collectedById: driverId,
        reference: ride.id,
        taxiRideId: ride.id,
        idempotencyKey: `taxi:${ride.id}`,
        note: 'Campus taxi',
      });
    });
    return this.changed(universityId, driverId, ride, 'done');
  }

  /** A driver who gives up puts the ride back on offer for the others (with a fresh offer window). */
  async cancelByDriver(universityId: string, driverId: string, rideId: string) {
    const ride = await this.driverRide(driverId, rideId);
    const u = await this.university(universityId);
    const expiresAt = new Date(this.now().getTime() + u.taxiOfferSeconds * 1000);
    await this.prisma.db.$transaction((tx) => this.transition(tx as Tx, ride, 'cancel_driver', { driverId: null, acceptedAt: null, arrivedAt: null, expiresAt }));
    this.hub.taxiRide(universityId, [ride.studentId, driverId], { rideId: ride.id, status: 'requested' });
    const again = await this.prisma.db.taxiRide.findUniqueOrThrow({ where: { id: ride.id } });
    await this.offer(universityId, again);
    return { ok: true };
  }

  private async changed(universityId: string, driverId: string, ride: TaxiRide, status: TaxiRideStatus) {
    this.hub.taxiRide(universityId, [ride.studentId, driverId], { rideId: ride.id, status });
    return this.forDriver(driverId, ride.id);
  }

  /** The driver's view after accepting: the exact point, the rider's name and phone. */
  async forDriver(driverId: string, rideId: string) {
    const ride = (await this.prisma.db.taxiRide.findFirst({ where: { id: rideId, driverId }, include: PEOPLE })) as RideWithPeople | null;
    if (!ride) throw new NotFoundException();
    const campus = await this.prisma.db.university.findUniqueOrThrow({ where: { id: ride.universityId }, select: { campusLat: true, campusLng: true } });
    return this.driverView(ride, { lat: campus.campusLat, lng: campus.campusLng });
  }

  private driverView(ride: RideWithPeople, c: LatLng) {
    const p = this.studentPoint(ride);
    const active = ACTIVE_TAXI.includes(ride.status);
    return {
      id: ride.id,
      status: ride.status,
      direction: ride.direction,
      pickup: ride.direction === 'to_campus' ? p : c,
      dropoff: ride.direction === 'to_campus' ? c : p,
      label: ride.label,
      distanceKm: ride.distanceKm,
      fare: ride.fare,
      acceptedAt: ride.acceptedAt?.toISOString() ?? null,
      endedAt: ride.endedAt?.toISOString() ?? null,
      createdAt: ride.createdAt.toISOString(),
      student: { name: ride.student.nameAr || ride.student.name, phone: active ? ride.student.phone : null },
    };
  }

  /** The driver's taxi trips and this month's cash takings. */
  async driverHistory(driverId: string) {
    const rows = (await this.prisma.db.taxiRide.findMany({ where: { driverId }, orderBy: { createdAt: 'desc' }, take: 50, include: PEOPLE })) as RideWithPeople[];
    const campus = rows.length ? await this.prisma.db.university.findUniqueOrThrow({ where: { id: rows[0].universityId }, select: { campusLat: true, campusLng: true } }) : null;
    const rides = campus ? rows.map((r) => this.driverView(r, { lat: campus.campusLat, lng: campus.campusLng })) : [];
    const month = baghdadDate(this.now()).slice(0, 7);
    const thisMonth = rides.filter((r) => r.status === 'done' && r.endedAt && baghdadDate(new Date(r.endedAt)).startsWith(month));
    return { rides, month, trips: thisMonth.length, cash: thisMonth.reduce((s, r) => s + r.fare, 0) };
  }

  // ── office ───────────────────────────────────────────────────────────────────

  async settings(universityId: string) {
    const u = await this.university(universityId);
    return { taxiEnabled: u.taxiEnabled, taxiBaseFare: u.taxiBaseFare, taxiPerKm: u.taxiPerKm, taxiMinFare: u.taxiMinFare, taxiOfferSeconds: u.taxiOfferSeconds };
  }

  async updateSettings(universityId: string, input: TaxiSettingsInput) {
    if (input.taxiBaseFare !== undefined && input.taxiMinFare !== undefined && input.taxiMinFare < input.taxiBaseFare) {
      throw new BadRequestException('The minimum fare cannot be below the base fare');
    }
    await this.prisma.db.university.update({ where: { id: universityId }, data: input });
    return this.settings(universityId);
  }

  /** TX-06: the day's rides, who is online, and the headline numbers. */
  async overview(universityId: string, date = baghdadDate(this.now())) {
    const from = new Date(`${date}T00:00:00+03:00`);
    const to = new Date(from.getTime() + 24 * 3600_000);
    const db = this.prisma.db;
    const rides = (await db.taxiRide.findMany({ where: { createdAt: { gte: from, lt: to } }, orderBy: { createdAt: 'desc' }, include: PEOPLE })) as RideWithPeople[];
    const online = await this.online(universityId);
    const busy = await this.busyDrivers();
    const people = await db.user.findMany({ where: { id: { in: online.map((o) => o.driverId) } }, select: { id: true, name: true, nameAr: true, driver: { select: { plate: true } } } });
    const accepted = rides.filter((r) => r.acceptedAt);
    const waits = accepted.map((r) => (r.acceptedAt!.getTime() - r.createdAt.getTime()) / 1000);
    const done = rides.filter((r) => r.status === 'done');
    return {
      date,
      kpis: {
        requested: rides.length,
        done: done.length,
        active: rides.filter((r) => ACTIVE_TAXI.includes(r.status)).length,
        unserved: rides.filter((r) => r.status === 'expired').length,
        cash: done.reduce((s, r) => s + r.fare, 0),
        avgAcceptSec: waits.length ? Math.round(waits.reduce((a, b) => a + b, 0) / waits.length) : null,
        online: online.length,
      },
      online: online.map((o) => {
        const p = people.find((x) => x.id === o.driverId);
        return { driverId: o.driverId, name: p?.nameAr || p?.name || '', plate: p?.driver?.plate ?? null, lat: o.lat, lng: o.lng, at: new Date(o.at).toISOString(), busy: busy.has(o.driverId) };
      }),
      rides: rides.map((r) => ({
        id: r.id,
        status: r.status,
        direction: r.direction,
        label: r.label,
        distanceKm: r.distanceKm,
        fare: r.fare,
        createdAt: r.createdAt.toISOString(),
        acceptedAt: r.acceptedAt?.toISOString() ?? null,
        endedAt: r.endedAt?.toISOString() ?? null,
        cancelledBy: r.cancelledBy,
        student: r.student.nameAr || r.student.name,
        driver: r.driver ? r.driver.nameAr || r.driver.name : null,
        plate: r.driver?.driver?.plate ?? null,
      })),
    };
  }

  // ── sweep ────────────────────────────────────────────────────────────────────

  /** Requests nobody accepted in time expire; the student hears straight away. */
  async expireDue() {
    const now = this.now();
    const due = await runAsSystem(() => this.prisma.db.taxiRide.findMany({ where: { status: 'requested', expiresAt: { lte: now } }, select: { id: true, universityId: true } }));
    let expired = 0;
    for (const d of due) {
      const done = await runAsTenant(d.universityId, () =>
        this.prisma.db.$transaction(async (tx) => {
          const res = await tx.taxiRide.updateMany({ where: { id: d.id, status: 'requested', expiresAt: { lte: now } }, data: { status: 'expired' } });
          if (res.count === 0) return null;
          const r = await tx.taxiRide.findUniqueOrThrow({ where: { id: d.id } });
          await NotificationsService.add(tx as Tx, d.universityId, [{ userId: r.studentId, kind: 'taxi.expired', dedupeKey: `taxi-expired:${r.id}`, data: { rideId: r.id } }]);
          return r;
        }),
      );
      if (!done) continue;
      expired++;
      await this.notifications.deliverPending(d.universityId);
      this.hub.taxiGone(d.universityId, d.id);
      this.hub.taxiRide(d.universityId, [done.studentId], { rideId: d.id, status: 'expired' });
    }
    if (expired) this.log.log(`Expired ${expired} unanswered taxi request(s)`);
    return { expired };
  }
}
