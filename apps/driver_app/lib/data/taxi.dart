import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'run_controller.dart';
import 'session.dart';

/// P10 campus taxis, as the taxi driver sees them. Bus drivers never touch any of this.

/// The vehicle type that makes a driver a taxi driver (matches the server's `TAXI`).
const taxiVehicleType = 'taxi';

/// How often an online taxi tells the server where it is (the server counts it offline after 60 s).
const taxiHeartbeat = Duration(seconds: 12);

/// How long the "trip done" moment stays before the offers come back.
const taxiDoneHold = Duration(seconds: 4);

/// How long a short notice ("another driver took it") stays on screen.
const taxiNoticeHold = Duration(seconds: 4);

/// True for an approved driver registered with the taxi vehicle type.
final isTaxiDriverProvider = Provider<bool>((ref) {
  final a = ref.watch(applicationProvider).value;
  return a != null && a.status == DriverStatus.approved && a.vehicleType == taxiVehicleType;
});

enum TaxiDirection {
  toCampus,
  fromCampus;

  static TaxiDirection fromJson(Object? v) => v == 'from_campus' ? fromCampus : toCampus;
}

class TaxiPoint {
  const TaxiPoint(this.lat, this.lng);
  factory TaxiPoint.fromJson(Object? j) {
    final m = j as Map<String, dynamic>;
    return TaxiPoint((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
  }
  final double lat;
  final double lng;
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

/// A request open to nearby taxis. Shows only the area (about 500 m), never the exact point.
class TaxiOffer {
  const TaxiOffer({required this.id, required this.direction, required this.area, required this.distanceKm, required this.fare, required this.expiresAt, this.awayKm});

  factory TaxiOffer.fromJson(Map<String, dynamic> j) => TaxiOffer(
    id: j['id'] as String,
    direction: TaxiDirection.fromJson(j['direction']),
    area: TaxiPoint.fromJson(j['area']),
    distanceKm: (j['distanceKm'] as num).toDouble(),
    fare: (j['fare'] as num).toInt(),
    expiresAt: DateTime.parse(j['expiresAt'] as String).toLocal(),
    awayKm: (j['awayKm'] as num?)?.toDouble(),
  );

  final String id;
  final TaxiDirection direction;
  final TaxiPoint area;
  final double distanceKm;
  final int fare;
  final DateTime expiresAt;
  final double? awayKm;

  bool expired(DateTime now) => !expiresAt.isAfter(now);
}

/// A ride this driver accepted: the exact pickup and drop-off and the student's name and phone.
class TaxiRide {
  const TaxiRide({
    required this.id,
    required this.status,
    required this.direction,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.fare,
    required this.studentName,
    required this.createdAt,
    this.studentPhone,
    this.label,
    this.acceptedAt,
    this.endedAt,
  });

  factory TaxiRide.fromJson(Map<String, dynamic> j) {
    final student = j['student'] as Map<String, dynamic>? ?? const {};
    return TaxiRide(
      id: j['id'] as String,
      status: j['status'] as String,
      direction: TaxiDirection.fromJson(j['direction']),
      pickup: TaxiPoint.fromJson(j['pickup']),
      dropoff: TaxiPoint.fromJson(j['dropoff']),
      label: j['label'] as String?,
      distanceKm: (j['distanceKm'] as num).toDouble(),
      fare: (j['fare'] as num).toInt(),
      acceptedAt: _date(j['acceptedAt']),
      endedAt: _date(j['endedAt']),
      createdAt: _date(j['createdAt']) ?? clock.now(),
      studentName: student['name'] as String? ?? '',
      studentPhone: student['phone'] as String?,
    );
  }

  final String id;

  /// accepted → arrived → on_trip → done (or cancelled / back to requested).
  final String status;
  final TaxiDirection direction;
  final TaxiPoint pickup;
  final TaxiPoint dropoff;
  final String? label;
  final double distanceKm;
  final int fare;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final String studentName;
  final String? studentPhone;

  bool get active => status == 'accepted' || status == 'arrived' || status == 'on_trip';

  /// Where to drive now: the pickup until the student is in the car, then the drop-off.
  TaxiPoint get target => status == 'on_trip' ? dropoff : pickup;
}

/// GET /taxi/driver/rides: recent trips and this month's cash takings.
class TaxiHistory {
  const TaxiHistory({required this.rides, required this.month, required this.trips, required this.cash});

  factory TaxiHistory.fromJson(Map<String, dynamic> j) => TaxiHistory(
    rides: [for (final r in j['rides'] as List? ?? const []) TaxiRide.fromJson(r as Map<String, dynamic>)],
    month: j['month'] as String,
    trips: (j['trips'] as num).toInt(),
    cash: (j['cash'] as num).toInt(),
  );

  final List<TaxiRide> rides;
  final String month;
  final int trips;
  final int cash;
}

/// The taxi endpoints, kept in the app so the shared client stays unchanged.
extension TaxiApi on ApiClient {
  Future<({TaxiRide? active, List<TaxiOffer> offers})> taxiOnline(double lat, double lng) async {
    final j = await post('/taxi/driver/online', {'lat': lat, 'lng': lng}) as Map<String, dynamic>;
    return (
      active: j['active'] == null ? null : TaxiRide.fromJson(j['active'] as Map<String, dynamic>),
      offers: [for (final o in j['offers'] as List? ?? const []) TaxiOffer.fromJson(o as Map<String, dynamic>)],
    );
  }

  Future<void> taxiOffline() async => post('/taxi/driver/offline');

  Future<List<TaxiOffer>> taxiOffers() async => [for (final o in await get('/taxi/driver/offers') as List) TaxiOffer.fromJson(o as Map<String, dynamic>)];

  Future<TaxiRide> taxiAccept(String id) async => TaxiRide.fromJson(await post('/taxi/rides/$id/accept') as Map<String, dynamic>);

  /// `arrive`, `start` or `end` (end records the cash fare).
  Future<TaxiRide> taxiStep(String id, String step) async => TaxiRide.fromJson(await post('/taxi/rides/$id/$step') as Map<String, dynamic>);

  Future<void> taxiCancel(String id) async => post('/taxi/rides/$id/cancel');

  Future<TaxiRide> taxiRide(String id) async => TaxiRide.fromJson(await get('/taxi/driver/rides/$id') as Map<String, dynamic>);

  Future<TaxiHistory> taxiHistory() async => TaxiHistory.fromJson(await get('/taxi/driver/rides') as Map<String, dynamic>);
}

/// This month's taxi trips (earnings screen).
final taxiHistoryProvider = FutureProvider.autoDispose<TaxiHistory>((ref) => ref.watch(apiProvider).taxiHistory());

/// Realtime taxi events on the /live namespace. The shared [LiveFeed] does not carry them, so the
/// taxi screen opens its own connection. Tests use a fake.
abstract class TaxiEvents {
  /// `taxi:offer`: a new request near this taxi.
  Stream<TaxiOffer> get offers;

  /// `taxi:gone`: a request is no longer open (taken, cancelled, expired) — drop its card.
  Stream<String> get gone;

  /// `taxi:ride`: one of this driver's rides changed (e.g. the student cancelled).
  Stream<({String rideId, String status})> get rides;

  void dispose();
}

class SocketTaxiEvents implements TaxiEvents {
  SocketTaxiEvents({required Uri apiBase, required String token}) {
    final prefix = apiBase.path.endsWith('/') ? apiBase.path.substring(0, apiBase.path.length - 1) : apiBase.path;
    _socket = io.io(
      '${apiBase.scheme}://${apiBase.authority}/live',
      io.OptionBuilder().setPath('$prefix/socket.io').setTransports(['websocket']).setAuth({'token': token}).enableReconnection().setReconnectionDelayMax(5000).build(),
    );
    _socket.on('taxi:offer', (d) {
      try {
        _offers.add(TaxiOffer.fromJson((d as Map).cast<String, dynamic>()));
      } catch (_) {
        /* ignore a malformed event */
      }
    });
    _socket.on('taxi:gone', (d) {
      final id = (d as Map?)?['rideId'];
      if (id is String) _gone.add(id);
    });
    _socket.on('taxi:ride', (d) {
      final m = d as Map?;
      if (m?['rideId'] is String && m?['status'] is String) _rides.add((rideId: m!['rideId'] as String, status: m['status'] as String));
    });
  }

  late final io.Socket _socket;
  final _offers = StreamController<TaxiOffer>.broadcast();
  final _gone = StreamController<String>.broadcast();
  final _rides = StreamController<({String rideId, String status})>.broadcast();

  @override
  Stream<TaxiOffer> get offers => _offers.stream;
  @override
  Stream<String> get gone => _gone.stream;
  @override
  Stream<({String rideId, String status})> get rides => _rides.stream;

  @override
  void dispose() {
    _socket.dispose();
    _offers.close();
    _gone.close();
    _rides.close();
  }
}

final taxiEventsProvider = FutureProvider.autoDispose<TaxiEvents?>((ref) async {
  final token = await ref.watch(tokenStoreProvider).read();
  if (token == null) return null;
  final custom = ref.watch(serverUrlProvider);
  final events = SocketTaxiEvents(apiBase: custom == null ? apiBaseUrl() : Uri.parse(custom), token: token);
  ref.onDispose(events.dispose);
  return events;
});

/// Short messages the taxi screen shows; the screen turns them into words.
enum TaxiNotice { taken, noLocation, taxisOff, studentCancelled, failed }

class TaxiState {
  const TaxiState({this.online = false, this.switching = false, this.offers = const [], this.active, this.done, this.busy, this.notice});

  /// The driver chose to be online (heartbeats are being sent).
  final bool online;

  /// Going online or offline is in progress.
  final bool switching;
  final List<TaxiOffer> offers;
  final TaxiRide? active;

  /// The ride just finished: shown briefly with the cash to collect.
  final TaxiRide? done;

  /// The offer id or ride step being sent (its button shows a loader).
  final String? busy;
  final TaxiNotice? notice;

  TaxiState copyWith({bool? online, bool? switching, List<TaxiOffer>? offers, TaxiRide? Function()? active, TaxiRide? Function()? done, String? Function()? busy, TaxiNotice? Function()? notice}) =>
      TaxiState(
        online: online ?? this.online,
        switching: switching ?? this.switching,
        offers: offers ?? this.offers,
        active: active == null ? this.active : active(),
        done: done == null ? this.done : done(),
        busy: busy == null ? this.busy : busy(),
        notice: notice == null ? this.notice : notice(),
      );
}

final taxiControllerProvider = NotifierProvider.autoDispose<TaxiController, TaxiState>(TaxiController.new);

/// TX-04: online/offline, the heartbeat, live offers, and one ride from accept to cash.
class TaxiController extends Notifier<TaxiState> {
  Timer? _heartbeat;
  Timer? _doneTimer;
  Timer? _noticeTimer;
  final _subs = <StreamSubscription<Object?>>[];
  bool _disposed = false;

  /// Mirrors `state.online` (state cannot be read while disposing).
  bool _online = false;

  /// Offers the driver dismissed: they do not come back with the next heartbeat or event.
  final _skipped = <String>{};

  bool _wanted(TaxiOffer o, DateTime now) => !o.expired(now) && !_skipped.contains(o.id);

  /// The driver is not taking this one; it stays open for the other taxis.
  void skip(String offerId) {
    _skipped.add(offerId);
    _drop(offerId);
  }

  ApiClient get _api => ref.read(apiProvider);

  @override
  TaxiState build() {
    final api = ref.read(apiProvider);
    ref.onDispose(() {
      _disposed = true;
      final wasOnline = _online;
      _heartbeat?.cancel();
      _doneTimer?.cancel();
      _noticeTimer?.cancel();
      for (final s in _subs) {
        s.cancel();
      }
      // Leaving the screen (e.g. signing out) takes the taxi offline; the server would also
      // drop it after 60 s without a heartbeat.
      if (wasOnline) unawaited(api.taxiOffline().catchError((_) {}));
    });
    ref.listen(taxiEventsProvider, (_, next) {
      final events = next.value;
      if (events == null) return;
      _subs.add(events.offers.listen(_onOffer));
      _subs.add(events.gone.listen(_drop));
      _subs.add(events.rides.listen((r) => _onRideChange(r.rideId, r.status)));
    }, fireImmediately: true);
    return const TaxiState();
  }

  void _set(TaxiState s) {
    if (_disposed) return;
    _online = s.online;
    state = s;
  }

  void _notify(TaxiNotice n) {
    _set(state.copyWith(notice: () => n));
    _noticeTimer?.cancel();
    _noticeTimer = Timer(taxiNoticeHold, () => _set(state.copyWith(notice: () => null)));
  }

  void dismissNotice() {
    _noticeTimer?.cancel();
    _set(state.copyWith(notice: () => null));
  }

  Future<void> toggle() => state.online ? goOffline() : goOnline();

  Future<void> goOnline() async {
    if (state.online || state.switching) return;
    _set(state.copyWith(switching: true, notice: () => null));
    final ok = await ref.read(locationSourceProvider).ensurePermission();
    if (_disposed) return;
    if (!ok) {
      _set(state.copyWith(switching: false));
      _notify(TaxiNotice.noLocation);
      return;
    }
    final alive = await _beat(first: true);
    if (_disposed) return;
    if (!alive) return;
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(taxiHeartbeat, (_) => _beat());
  }

  Future<void> goOffline() async {
    if (!state.online || state.active != null) return;
    _heartbeat?.cancel();
    _heartbeat = null;
    _set(state.copyWith(online: false, switching: true, offers: const []));
    try {
      await _api.taxiOffline();
    } catch (_) {
      /* the server drops us after 60 s without a heartbeat anyway */
    }
    _set(state.copyWith(switching: false));
  }

  /// One heartbeat. Returns false when the driver could not be (or stay) online.
  Future<bool> _beat({bool first = false}) async {
    final fix = await ref.read(locationSourceProvider).current();
    if (_disposed) return false;
    if (fix == null) {
      if (first) {
        _set(state.copyWith(switching: false));
        _notify(TaxiNotice.noLocation);
      }
      return !first;
    }
    try {
      final res = await _api.taxiOnline(fix.lat, fix.lng);
      if (_disposed) return false;
      final now = clock.now();
      // The ride vanished without a socket event (the student cancelled while we were offline).
      if (state.active != null && res.active == null && state.busy == null) _notify(TaxiNotice.studentCancelled);
      _set(state.copyWith(online: true, switching: false, active: () => res.active, offers: res.active == null ? res.offers.where((o) => _wanted(o, now)).toList() : const []));
      return true;
    } on ApiException catch (e) {
      if (_disposed) return false;
      if (e.statusCode == 422 || e.statusCode == 403) {
        _heartbeat?.cancel();
        _heartbeat = null;
        _set(state.copyWith(online: false, switching: false, offers: const []));
        _notify(TaxiNotice.taxisOff);
        return false;
      }
      if (first) {
        _set(state.copyWith(switching: false));
        _notify(TaxiNotice.failed);
        return false;
      }
      return true;
    } catch (_) {
      // No coverage: keep trying on the next beat; the first one must succeed to go online.
      if (_disposed) return false;
      if (first) {
        _set(state.copyWith(switching: false));
        _notify(TaxiNotice.failed);
        return false;
      }
      return true;
    }
  }

  /// Pull to refresh: the open offers right now.
  Future<void> refreshOffers() async {
    if (!state.online || state.active != null) return;
    try {
      final offers = await _api.taxiOffers();
      final now = clock.now();
      _set(state.copyWith(offers: offers.where((o) => _wanted(o, now)).toList()));
    } catch (_) {
      /* keep what we have */
    }
  }

  void _onOffer(TaxiOffer o) {
    if (!state.online || state.active != null || !_wanted(o, clock.now())) return;
    _set(state.copyWith(offers: [...state.offers.where((x) => x.id != o.id), o]));
  }

  void _drop(String id) {
    if (state.offers.any((o) => o.id == id)) _set(state.copyWith(offers: state.offers.where((o) => o.id != id).toList()));
  }

  /// Removes offers whose time ran out (called by the screen's countdown).
  void pruneExpired() {
    final now = clock.now();
    if (state.offers.any((o) => o.expired(now))) _set(state.copyWith(offers: state.offers.where((o) => !o.expired(now)).toList()));
  }

  Future<void> _onRideChange(String rideId, String status) async {
    final active = state.active;
    if (active == null || active.id != rideId) return;
    if (status == 'cancelled') return _lost();
    await _resync(rideId);
  }

  /// The student cancelled (or the ride is otherwise gone): back to the offers.
  void _lost() {
    _set(state.copyWith(active: () => null));
    _notify(TaxiNotice.studentCancelled);
    unawaited(refreshOffers());
  }

  Future<void> _resync(String rideId) async {
    try {
      final ride = await _api.taxiRide(rideId);
      if (state.active?.id != rideId) return;
      if (ride.active) {
        _set(state.copyWith(active: () => ride));
      } else {
        _lost();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404 && state.active?.id == rideId) _lost();
    } catch (_) {
      /* the next heartbeat brings it */
    }
  }

  /// TX-02: first to accept takes it. 409 means another driver was faster (or it expired).
  Future<void> accept(String offerId) async {
    if (state.busy != null || state.active != null) return;
    _set(state.copyWith(busy: () => offerId));
    try {
      final ride = await _api.taxiAccept(offerId);
      _set(state.copyWith(busy: () => null, active: () => ride, offers: const []));
    } on ApiException catch (e) {
      _set(state.copyWith(busy: () => null, offers: e.statusCode == 409 ? state.offers.where((o) => o.id != offerId).toList() : null));
      _notify(e.statusCode == 409 ? TaxiNotice.taken : TaxiNotice.failed);
    } catch (_) {
      _set(state.copyWith(busy: () => null));
      _notify(TaxiNotice.failed);
    }
  }

  /// The next step of the active ride: arrive → start → end (end records the cash).
  Future<void> step() async {
    final ride = state.active;
    if (ride == null || state.busy != null) return;
    final next = switch (ride.status) {
      'accepted' => 'arrive',
      'arrived' => 'start',
      'on_trip' => 'end',
      _ => null,
    };
    if (next == null) return;
    _set(state.copyWith(busy: () => next));
    try {
      final updated = await _api.taxiStep(ride.id, next);
      if (updated.status == 'done') {
        _set(state.copyWith(busy: () => null, active: () => null, done: () => updated));
        _doneTimer?.cancel();
        _doneTimer = Timer(taxiDoneHold, finishDone);
        unawaited(refreshOffers());
        ref.invalidate(taxiHistoryProvider);
      } else {
        _set(state.copyWith(busy: () => null, active: () => updated));
      }
    } on ApiException catch (e) {
      _set(state.copyWith(busy: () => null));
      _notify(TaxiNotice.failed);
      // The ride moved on elsewhere (e.g. the student cancelled): resync.
      if (e.statusCode == 409 || e.statusCode == 404) unawaited(_resync(ride.id));
    } catch (_) {
      _set(state.copyWith(busy: () => null));
      _notify(TaxiNotice.failed);
    }
  }

  /// Leaves the "trip done" moment and goes back to the offers.
  void finishDone() {
    _doneTimer?.cancel();
    _set(state.copyWith(done: () => null));
  }

  /// The driver gives the ride up; it goes back on offer to the other taxis.
  Future<void> cancel() async {
    final ride = state.active;
    if (ride == null || state.busy != null) return;
    _set(state.copyWith(busy: () => 'cancel'));
    try {
      await _api.taxiCancel(ride.id);
      _set(state.copyWith(busy: () => null, active: () => null));
      unawaited(refreshOffers());
    } catch (_) {
      _set(state.copyWith(busy: () => null));
      _notify(TaxiNotice.failed);
    }
  }
}
