import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';

// P10 campus taxis, student side. The shared packages do not know about taxis yet, so the
// models, calls and socket events live in the app (see TaxiApi / SocketTaxiLive).

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
LatLng? _latLng(Object? v) => v is Map ? LatLng((v['lat'] as num).toDouble(), (v['lng'] as num).toDouble()) : null;

enum TaxiDirection {
  toCampus('to_campus'),
  fromCampus('from_campus');

  const TaxiDirection(this.json);
  final String json;

  static TaxiDirection fromJson(Object? v) => v == 'from_campus' ? fromCampus : toCampus;
}

enum TaxiStatus {
  requested,
  accepted,
  arrived,
  onTrip,
  done,
  cancelled,
  expired;

  static TaxiStatus fromJson(Object? v) => switch (v) {
    'accepted' => accepted,
    'arrived' => arrived,
    'on_trip' => onTrip,
    'done' => done,
    'cancelled' => cancelled,
    'expired' => expired,
    _ => requested,
  };

  /// Still going: the student can follow it (and cancel until the trip starts).
  bool get isActive => this == requested || this == accepted || this == arrived || this == onTrip;
  bool get canCancel => this == requested || this == accepted || this == arrived;
}

/// GET /taxi/quote: the fare is known before booking.
class TaxiQuote {
  const TaxiQuote({required this.direction, required this.distanceKm, this.durationMin, required this.fare, required this.taxisNearby, this.pickupMin, this.campus});

  factory TaxiQuote.fromJson(Map<String, dynamic> j) => TaxiQuote(
    direction: TaxiDirection.fromJson(j['direction']),
    distanceKm: (j['distanceKm'] as num).toDouble(),
    durationMin: (j['durationMin'] as num?)?.toInt(),
    fare: (j['fare'] as num).toInt(),
    taxisNearby: (j['taxisNearby'] as num?)?.toInt() ?? 0,
    pickupMin: (j['pickupMin'] as num?)?.toInt(),
    campus: _latLng(j['campus']),
  );

  final TaxiDirection direction;
  final double distanceKm;
  final int? durationMin;
  final int fare;
  final int taxisNearby;
  final int? pickupMin;
  final LatLng? campus;
}

class TaxiDriver {
  const TaxiDriver({required this.name, this.phone, this.plate, this.seats});

  factory TaxiDriver.fromJson(Map<String, dynamic> j) =>
      TaxiDriver(name: j['name'] as String? ?? '', phone: j['phone'] as String?, plate: j['plate'] as String?, seats: (j['seats'] as num?)?.toInt());

  final String name;
  final String? phone;
  final String? plate;
  final int? seats;
}

/// Where the taxi is (socket 'taxi:position' or the API's last known position).
class TaxiPosition {
  const TaxiPosition({required this.rideId, required this.point, required this.at, this.etaMin});

  factory TaxiPosition.fromJson(Map<String, dynamic> j) => TaxiPosition(
    rideId: j['rideId'] as String? ?? '',
    point: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
    at: _date(j['at']) ?? DateTime.now(),
    etaMin: (j['etaMin'] as num?)?.toInt(),
  );

  final String rideId;
  final LatLng point;
  final DateTime at;
  final int? etaMin;
}

/// StudentRide from the API.
class TaxiRide {
  const TaxiRide({
    required this.id,
    required this.status,
    required this.direction,
    required this.point,
    this.label,
    required this.distanceKm,
    required this.fare,
    required this.expiresAt,
    this.createdAt,
    this.endedAt,
    this.cancelledBy,
    this.pickup,
    this.dropoff,
    this.driver,
    this.taxi,
    this.taxiAt,
    this.etaMin,
  });

  factory TaxiRide.fromJson(Map<String, dynamic> j) {
    final taxi = j['taxi'] as Map<String, dynamic>?;
    return TaxiRide(
      id: j['id'] as String,
      status: TaxiStatus.fromJson(j['status']),
      direction: TaxiDirection.fromJson(j['direction']),
      point: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
      label: j['label'] as String?,
      distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
      fare: (j['fare'] as num?)?.toInt() ?? 0,
      expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
      createdAt: _date(j['createdAt']),
      endedAt: _date(j['endedAt']),
      cancelledBy: j['cancelledBy'] as String?,
      pickup: _latLng(j['pickup']),
      dropoff: _latLng(j['dropoff']),
      driver: j['driver'] == null ? null : TaxiDriver.fromJson(j['driver'] as Map<String, dynamic>),
      taxi: _latLng(taxi),
      taxiAt: _date(taxi?['at']),
      etaMin: (j['etaMin'] as num?)?.toInt(),
    );
  }

  final String id;
  final TaxiStatus status;
  final TaxiDirection direction;

  /// The student's point (pickup to campus, drop-off on the way home).
  final LatLng point;
  final String? label;
  final double distanceKm;
  final int fare;
  final DateTime expiresAt;
  final DateTime? createdAt;
  final DateTime? endedAt;
  final String? cancelledBy;
  final LatLng? pickup;
  final LatLng? dropoff;
  final TaxiDriver? driver;
  final LatLng? taxi;
  final DateTime? taxiAt;
  final int? etaMin;

  /// A live position, kept only if it is newer than what the ride already has.
  TaxiRide withPosition(TaxiPosition p) {
    if (taxiAt != null && p.at.isBefore(taxiAt!)) return this;
    return TaxiRide(
      id: id,
      status: status,
      direction: direction,
      point: point,
      label: label,
      distanceKm: distanceKm,
      fare: fare,
      expiresAt: expiresAt,
      createdAt: createdAt,
      endedAt: endedAt,
      cancelledBy: cancelledBy,
      pickup: pickup,
      dropoff: dropoff,
      driver: driver,
      taxi: p.point,
      taxiAt: p.at,
      etaMin: p.etaMin,
    );
  }
}

class TaxiMine {
  const TaxiMine({this.active, this.history = const []});

  factory TaxiMine.fromJson(Map<String, dynamic> j) => TaxiMine(
    active: j['active'] == null ? null : TaxiRide.fromJson(j['active'] as Map<String, dynamic>),
    history: [for (final r in j['history'] as List? ?? const []) TaxiRide.fromJson(r as Map<String, dynamic>)],
  );

  final TaxiRide? active;
  final List<TaxiRide> history;
}

/// The taxi endpoints (P10), on top of the shared client.
extension TaxiApi on ApiClient {
  /// GET /students/me now carries `taxiEnabled`; the shared profile model does not keep it.
  Future<bool> taxiEnabled() async => ((await get('/students/me') as Map<String, dynamic>)['taxiEnabled'] as bool?) ?? false;

  Future<TaxiQuote> taxiQuote(TaxiDirection direction, LatLng p) async =>
      TaxiQuote.fromJson(await get('/taxi/quote?direction=${direction.json}&lat=${p.latitude}&lng=${p.longitude}') as Map<String, dynamic>);

  Future<TaxiRide> requestTaxi({required TaxiDirection direction, required LatLng point, String? label, required String clientId}) async => TaxiRide.fromJson(
    await post('/taxi/rides', {'direction': direction.json, 'lat': point.latitude, 'lng': point.longitude, 'label': ?label, 'clientId': clientId}) as Map<String, dynamic>,
  );

  Future<TaxiMine> myTaxiRides() async => TaxiMine.fromJson(await get('/taxi/rides/me') as Map<String, dynamic>);

  Future<TaxiRide> taxiRide(String id) async => TaxiRide.fromJson(await get('/taxi/rides/$id') as Map<String, dynamic>);

  Future<TaxiRide> cancelTaxi(String id) async => TaxiRide.fromJson(await post('/taxi/rides/$id/cancel') as Map<String, dynamic>);

  /// The default gathering point's coordinates (the profile only has its id and name).
  Future<LatLng?> pointLocation(String pointId) async {
    for (final p in await get('/gathering-points') as List) {
      final m = p as Map<String, dynamic>;
      if (m['id'] == pointId && m['lat'] is num && m['lng'] is num) return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
    }
    return null;
  }
}

/// Retry-safe request key: one per booking attempt, reused if the same attempt is sent again.
String newTaxiClientId([Random? random]) {
  final r = random ?? Random.secure();
  return 'tx-${List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

/// Taxi events from the /live socket. Tests use a fake.
abstract class TaxiLive {
  /// 'taxi:ride': a ride changed (refetch it). Emits the ride id.
  Stream<String> get rides;

  /// 'taxi:position': where the accepted taxi is now.
  Stream<TaxiPosition> get positions;
  void dispose();
}

class SocketTaxiLive implements TaxiLive {
  SocketTaxiLive({required Uri apiBase, required String token}) {
    // Same address rules as the shared bus feed (path prefix behind nginx).
    final prefix = apiBase.path.endsWith('/') ? apiBase.path.substring(0, apiBase.path.length - 1) : apiBase.path;
    _socket = io.io(
      '${apiBase.scheme}://${apiBase.authority}/live',
      io.OptionBuilder()
          .setPath('$prefix/socket.io')
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelayMax(5000)
          .enableForceNew()
          .build(),
    );
    _socket.on('taxi:ride', (d) {
      final id = (d as Map?)?['rideId'];
      if (id is String) _rides.add(id);
    });
    _socket.on('taxi:position', (d) {
      if (d is Map) _positions.add(TaxiPosition.fromJson(d.cast<String, dynamic>()));
    });
    _socket.on('notification', (d) {
      // taxi.accepted / arrived / expired / cancelled: refetch as well, in case 'taxi:ride' was missed.
      final m = d is Map ? d : null;
      final kind = m?['kind'];
      final data = m?['data'];
      final id = m?['rideId'] ?? (data is Map ? data['rideId'] : null);
      if (kind is String && kind.startsWith('taxi.') && id is String) _rides.add(id);
    });
  }

  late final io.Socket _socket;
  final _rides = StreamController<String>.broadcast();
  final _positions = StreamController<TaxiPosition>.broadcast();

  @override
  Stream<String> get rides => _rides.stream;
  @override
  Stream<TaxiPosition> get positions => _positions.stream;

  @override
  void dispose() {
    _socket.dispose();
    _rides.close();
    _positions.close();
  }
}

/// Opened only while a taxi screen needs it (the bus feed stays as it is).
final taxiLiveProvider = FutureProvider.autoDispose<TaxiLive?>((ref) async {
  final token = await ref.watch(tokenStoreProvider).read();
  if (token == null) return null;
  final custom = ref.watch(serverUrlProvider);
  final live = SocketTaxiLive(apiBase: custom == null ? apiBaseUrl() : Uri.parse(custom), token: token);
  ref.onDispose(live.dispose);
  return live;
});

/// Home shows the taxi entry only where the office has switched taxis on.
final taxiEnabledProvider = FutureProvider.autoDispose<bool>((ref) => ref.watch(apiProvider).taxiEnabled());

const taxiPollActive = Duration(seconds: 5);
const taxiPollIdle = Duration(seconds: 60);

/// The student's active taxi ride (for the Home card) and recent ones.
final taxiMineProvider = StreamProvider.autoDispose<TaxiMine>((ref) {
  final api = ref.watch(apiProvider);
  final controller = StreamController<TaxiMine>();
  Timer? timer;
  var disposed = false;

  Future<void> tick() async {
    timer?.cancel();
    try {
      final mine = await api.myTaxiRides();
      if (disposed) return;
      controller.add(mine);
      timer = Timer(mine.active != null ? taxiPollActive : taxiPollIdle, tick);
    } catch (e, st) {
      if (disposed) return;
      controller.addError(e, st);
      timer = Timer(taxiPollActive, tick);
    }
  }

  tick();
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// One ride, live: refetched on 'taxi:ride', moved on 'taxi:position', and re-read every 5 s
/// while it is active in case the socket is down.
final taxiRideProvider = StreamProvider.autoDispose.family<TaxiRide, String>((ref, id) {
  final api = ref.watch(apiProvider);
  final out = StreamController<TaxiRide>();
  final subs = <StreamSubscription<Object?>>[];
  TaxiRide? ride;
  Timer? poll;
  var disposed = false;

  void emit(TaxiRide r) {
    ride = r;
    if (!disposed) out.add(r);
  }

  Future<void> reload() async {
    try {
      final fresh = await api.taxiRide(id);
      if (disposed) return;
      final keep = ride;
      // Keep a newer socket position than the one the API last saw.
      final merged = keep?.taxi != null && keep!.taxiAt != null && fresh.status.isActive && (fresh.taxiAt == null || keep.taxiAt!.isAfter(fresh.taxiAt!))
          ? fresh.withPosition(TaxiPosition(rideId: id, point: keep.taxi!, at: keep.taxiAt!, etaMin: keep.etaMin))
          : fresh;
      emit(merged);
      if (!merged.status.isActive) poll?.cancel();
    } catch (e, st) {
      if (ride == null && !disposed) out.addError(e, st);
    }
  }

  Future<void> start() async {
    await reload();
    if (disposed || !(ride?.status.isActive ?? true)) return;
    poll = Timer.periodic(taxiPollActive, (_) => reload());
    final live = await ref.read(taxiLiveProvider.future).catchError((_) => null);
    if (live == null || disposed) return;
    subs.add(live.rides.where((r) => r == id).listen((_) => reload()));
    subs.add(
      live.positions.where((p) => p.rideId == id).listen((p) {
        final r = ride;
        if (r != null && r.status.isActive) emit(r.withPosition(p));
      }),
    );
  }

  // Keep the socket open while this ride is followed (listen, so it never rebuilds this).
  ref.listen(taxiLiveProvider, (_, _) {});
  start();
  ref.onDispose(() {
    disposed = true;
    poll?.cancel();
    for (final s in subs) {
      s.cancel();
    }
    out.close();
  });
  return out.stream;
});

/// "Use my location". Null when location is off or not allowed. Tests override it.
final taxiLocatorProvider = Provider<Future<LatLng?> Function()>(
  (ref) => () async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  },
);

/// Opens the phone dialer. Tests override it.
final taxiDialerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
