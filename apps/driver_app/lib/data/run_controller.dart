import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'runs.dart';

/// GPS interval while a run is under way (DR-05).
const gpsInterval = Duration(seconds: 5);

/// How often the outbox is pushed to the server.
const syncInterval = Duration(seconds: 5);

class GpsFix {
  const GpsFix({required this.lat, required this.lng, required this.at, this.speed, this.heading});
  final double lat;
  final double lng;
  final DateTime at;
  final double? speed;
  final double? heading;
}

/// Device location. Real phones use [GeolocatorSource]; tests feed fixes directly.
abstract class LocationSource {
  Future<bool> ensurePermission();
  Stream<GpsFix> positions();
}

class GeolocatorSource implements LocationSource {
  @override
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  @override
  Stream<GpsFix> positions() => Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          intervalDuration: gpsInterval,
          distanceFilter: 0,
          // Keeps GPS alive with the screen off; shown as an ongoing notification.
          foregroundNotificationConfig: const ForegroundNotificationConfig(notificationTitle: 'نقل وارث', notificationText: 'الرحلة جارية — تتم مشاركة موقع الحافلة', enableWakeLock: true),
        ),
      ).map((p) => GpsFix(lat: p.latitude, lng: p.longitude, at: p.timestamp, speed: p.speed, heading: p.heading));
}

final locationSourceProvider = Provider<LocationSource>((ref) => GeolocatorSource());

/// Opens a URL in another app (maps). Tests record the calls.
final urlLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

/// NF-09: one outbox for the app, kept in preferences so it survives restarts.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  final prefs = ref.watch(prefsProvider);
  final q = SyncQueue(
    store: JsonOutboxStore(read: () async => prefs.get('naql.outbox'), write: (s) => prefs.set('naql.outbox', s)),
    api: ref.watch(apiProvider),
  );
  final timer = Timer.periodic(syncInterval, (_) => q.flush());
  ref.onDispose(() {
    timer.cancel();
    q.dispose();
  });
  return q;
});

/// Items still waiting to reach the server.
final pendingSyncProvider = StreamProvider<int>((ref) async* {
  final q = ref.watch(syncQueueProvider);
  await q.init();
  yield q.length;
  yield* q.pending;
});

/// Local changes not yet confirmed by the server, shown immediately (optimistic UI).
class RunLocal {
  const RunLocal({this.status, this.arrived = const {}, this.served = const {}, this.boarded = const {}, this.noShow = const {}, this.paid = const {}});

  final String? status;
  final Map<int, DateTime> arrived;
  final Set<int> served;
  final Set<String> boarded;
  final Set<String> noShow;
  final Set<String> paid;

  RunLocal copyWith({String? status, Map<int, DateTime>? arrived, Set<int>? served, Set<String>? boarded, Set<String>? noShow, Set<String>? paid}) => RunLocal(
        status: status ?? this.status,
        arrived: arrived ?? this.arrived,
        served: served ?? this.served,
        boarded: boarded ?? this.boarded,
        noShow: noShow ?? this.noShow,
        paid: paid ?? this.paid,
      );
}

/// The run as the driver sees it: server state plus not-yet-sent actions.
class RunView {
  const RunView(this.base, [this.local = const RunLocal()]);
  final DriverRun base;
  final RunLocal local;

  String get status => local.status ?? base.status;
  bool get morning => base.waveType == WaveType.morning;
  bool isServed(RunStopInfo s) => s.served || local.served.contains(s.seq);
  DateTime? arrivedAt(RunStopInfo s) => local.arrived[s.seq] ?? s.arrivedAt;
  bool isBoarded(RunPassenger p) => p.boarded || local.boarded.contains(p.requestId);
  bool isNoShow(RunPassenger p) => p.status == 'no_show' || local.noShow.contains(p.requestId);
  bool isPaid(RunPassenger p) => p.paid || local.paid.contains(p.requestId);
  RunStopInfo? get nextStop => base.stops.where((s) => !isServed(s)).firstOrNull;
  List<RunPassenger> get allPassengers => [for (final s in base.stops) ...s.passengers];

  /// SM-04: seconds the bus must still wait at the current stop (0 = may leave).
  int waitLeft(DateTime now) {
    final stop = nextStop;
    // Only pickups wait (morning); on return runs the stops are drop-offs.
    if (!morning || status != 'at_stop' || stop == null) return 0;
    final missing = stop.passengers.where((p) => !isBoarded(p) && !isNoShow(p));
    if (missing.isEmpty) return 0;
    final since = arrivedAt(stop) ?? now;
    final left = since.add(Duration(minutes: base.waitMinutes)).difference(now).inSeconds;
    return left < 0 ? 0 : left;
  }
}

final runControllerProvider = AsyncNotifierProvider.autoDispose.family<RunController, RunView, String>(RunController.new);

/// DR-04/05/07: drives one run. Every action goes to the outbox first, is shown at once, and is
/// synced in order; GPS is recorded every 5 s while the run is under way.
class RunController extends AsyncNotifier<RunView> {
  RunController(this.runId);
  final String runId;

  StreamSubscription<GpsFix>? _gps;
  DateTime? _lastFix;
  final _subs = <StreamSubscription<Object?>>[];

  /// Last message from the server refusing an action (shown to the driver).
  String? lastError;

  SyncQueue get _queue => ref.read(syncQueueProvider);

  @override
  Future<RunView> build() async {
    ref.onDispose(() {
      _gps?.cancel();
      for (final s in _subs) {
        s.cancel();
      }
    });
    final q = _queue;
    await q.init();
    _subs.add(q.runUpdates.listen((json) {
      if (json['id'] == runId && !_hasPending) _replace(DriverRun.fromJson(json));
    }));
    _subs.add(q.rejected.listen((r) {
      if (r.item.runId != runId) return;
      lastError = r.message;
      _refresh(force: true);
    }));
    ref.listen(liveFeedProvider, (_, next) {
      final feed = next.value;
      if (feed == null) return;
      feed.join(runId);
      _subs.add(feed.runChanges.where((id) => id == runId).listen((_) => _refresh()));
    });

    final cached = ref.read(todayRunsProvider).value?.where((r) => r.id == runId).firstOrNull;
    final base = cached ?? await ref.read(apiProvider).runDetail(runId);
    final view = RunView(base);
    _syncGps(view);
    return view;
  }

  bool get _hasPending => _queue.items.any((i) => i.runId == runId && i.kind == 'action');

  void _replace(DriverRun base) {
    final v = RunView(base);
    state = AsyncData(v);
    _syncGps(v);
  }

  /// DR-09: new riders or stops — reload unless local actions are still on their way.
  Future<void> _refresh({bool force = false}) async {
    if (_hasPending && !force) return;
    try {
      _replace(await ref.read(apiProvider).runDetail(runId));
    } catch (_) {
      /* offline: keep what we have */
    }
  }

  Future<void> _act(String type, RunLocal Function(RunView v) apply, {int? seq, List<String>? requestIds}) async {
    final v = state.value;
    if (v == null) return;
    lastError = null;
    await _queue.add(OutboxItem(kind: 'action', runId: runId, payload: {
      'type': type,
      'at': clock.now().toUtc().toIso8601String(),
      'seq': ?seq,
      'requestIds': ?requestIds,
    }));
    final next = RunView(v.base, apply(v));
    state = AsyncData(next);
    _syncGps(next);
    unawaited(_queue.flush());
  }

  Future<void> start({List<String> boarded = const []}) => _act(
        'start',
        (v) => v.local.copyWith(status: 'started', boarded: {...v.local.boarded, ...boarded}, noShow: v.morning ? null : {...v.local.noShow, ...v.allPassengers.where((p) => !v.isBoarded(p) && !boarded.contains(p.requestId)).map((p) => p.requestId)}),
        requestIds: boarded.isEmpty ? null : boarded,
      );

  Future<void> arrive() {
    final stop = state.value?.nextStop;
    if (stop == null) return Future.value();
    return _act('arrive', (v) => v.local.copyWith(status: 'at_stop', arrived: {...v.local.arrived, stop.seq: clock.now()}), seq: stop.seq);
  }

  Future<void> board(List<String> ids) => _act('board', (v) => v.local.copyWith(boarded: {...v.local.boarded, ...ids}), requestIds: ids);

  Future<void> depart() {
    final v = state.value;
    final stop = v?.nextStop;
    if (v == null || stop == null) return Future.value();
    final missing = v.morning ? stop.passengers.where((p) => !v.isBoarded(p)).map((p) => p.requestId) : const <String>[];
    return _act('depart', (v) => v.local.copyWith(status: 'started', served: {...v.local.served, stop.seq}, noShow: {...v.local.noShow, ...missing}));
  }

  Future<void> end() => _act('end', (v) => v.local.copyWith(status: 'done'));

  /// DR-07: cash taken from a pay-per-ride rider (idempotent on the server).
  Future<void> collectFare(String requestId) async {
    final v = state.value;
    if (v == null) return;
    await _queue.add(OutboxItem(kind: 'fare', runId: runId, payload: {'requestId': requestId}));
    state = AsyncData(RunView(v.base, v.local.copyWith(paid: {...v.local.paid, requestId})));
    unawaited(_queue.flush());
  }

  void _syncGps(RunView v) {
    final underway = v.status == 'started' || v.status == 'at_stop';
    if (underway && _gps == null) {
      final source = ref.read(locationSourceProvider);
      source.ensurePermission().then((ok) {
        if (!ok || _gps != null) return;
        _gps = source.positions().listen(_onFix);
      });
    } else if (!underway && _gps != null) {
      _gps!.cancel();
      _gps = null;
    }
  }

  void _onFix(GpsFix f) {
    // At most one point per interval, even if the device reports faster.
    if (_lastFix != null && f.at.difference(_lastFix!) < gpsInterval - const Duration(milliseconds: 200)) return;
    _lastFix = f.at;
    _queue.add(OutboxItem(kind: 'gps', runId: runId, payload: {'lat': f.lat, 'lng': f.lng, 'at': f.at.toUtc().toIso8601String(), 'speed': ?f.speed, 'heading': ?f.heading}));
  }
}

/// DR-06: turn-by-turn in Google Maps (Android intent, web fallback) or Waze.
Uri googleMapsNavigation(double lat, double lng, {bool android = true}) =>
    android ? Uri.parse('google.navigation:q=$lat,$lng&mode=d') : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
Uri wazeNavigation(double lat, double lng) => Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
