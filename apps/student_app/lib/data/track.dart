import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';

/// Map tiles from the network. Tests turn them off.
final mapTilesProvider = Provider<bool>((ref) => true);

class TrackState {
  const TrackState({required this.info, this.bus, this.connected = false});
  final TrackInfo info;
  final BusPosition? bus;
  final bool connected;

  TrackState copyWith({TrackInfo? info, BusPosition? bus, bool? connected}) => TrackState(info: info ?? this.info, bus: bus ?? this.bus, connected: connected ?? this.connected);
}

/// ST-06: the student's bus, live. Starts from the API (last known position, NF-10) and then
/// follows the run's socket room; without a live connection it re-reads the API every 15 s.
final trackProvider = StreamProvider.autoDispose.family<TrackState, String>((ref, requestId) {
  final api = ref.watch(apiProvider);
  final out = StreamController<TrackState>();
  TrackState? state;
  final subs = <StreamSubscription<Object?>>[];
  Timer? poll;
  var disposed = false;

  void emit(TrackState s) {
    state = s;
    if (!disposed) out.add(s);
  }

  Future<void> reload() async {
    try {
      final info = await api.track(requestId);
      final bus = info.bus;
      final keep = state?.bus;
      emit(TrackState(info: info, bus: keep != null && (bus == null || keep.at.isAfter(bus.at)) ? keep : bus, connected: state?.connected ?? false));
    } catch (e, st) {
      if (state == null && !disposed) out.addError(e, st);
    }
  }

  Future<void> start() async {
    await reload();
    poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!(state?.connected ?? false)) reload();
    });
    final feed = await ref.read(liveFeedProvider.future).catchError((_) => null);
    final runId = state?.info.runId;
    if (feed == null || runId == null || disposed) return;
    subs.add(feed.connected.listen((c) {
      if (state != null) emit(state!.copyWith(connected: c));
    }));
    subs.add(feed.buses.where((b) => b.runId == runId).listen((b) {
      if (state != null) emit(TrackState(info: state!.info, bus: b, connected: true));
    }));
    subs.add(feed.runChanges.where((id) => id == runId).listen((_) => reload()));
    final last = await feed.join(runId);
    if (last != null && state != null && (state!.bus == null || last.at.isAfter(state!.bus!.at))) emit(state!.copyWith(bus: last));
  }

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

/// ST-09: in-app notifications, refreshed when a live one arrives.
final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) async* {
  final api = ref.watch(apiProvider);
  yield await api.notifications();
  final feed = await ref.watch(liveFeedProvider.future).catchError((_) => null);
  if (feed == null) return;
  await for (final _ in feed.notifications) {
    yield await api.notifications();
  }
});
