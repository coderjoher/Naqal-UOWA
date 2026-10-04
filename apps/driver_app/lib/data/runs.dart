import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';

/// Today's runs, refreshed every 30 s while visible (insertions and cancellations change them).
const runsPoll = Duration(seconds: 30);

final todayRunsProvider = StreamProvider.autoDispose<List<DriverRun>>((ref) {
  final api = ref.watch(apiProvider);
  final controller = StreamController<List<DriverRun>>();
  Timer? timer;
  var disposed = false;

  Future<void> tick() async {
    try {
      final runs = await api.driverRuns();
      if (!disposed) controller.add(runs);
    } catch (e, st) {
      if (!disposed) controller.addError(e, st);
    }
    if (!disposed) timer = Timer(runsPoll, tick);
  }

  tick();
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// DR-02: the next seven days with the waves the driver offered. Toggles save immediately.
final availabilityProvider = AsyncNotifierProvider.autoDispose<AvailabilityNotifier, List<AvailabilityDay>>(AvailabilityNotifier.new);

class AvailabilityNotifier extends AsyncNotifier<List<AvailabilityDay>> {
  @override
  Future<List<AvailabilityDay>> build() => ref.read(apiProvider).availability();

  /// Optimistic toggle; on failure the previous state comes back and the error is rethrown.
  Future<void> toggle(String date, String waveId) async {
    final days = state.value;
    if (days == null) return;
    final day = days.firstWhere((d) => d.date == date);
    final wave = day.waves.firstWhere((w) => w.waveId == waveId);
    if (wave.locked) return;
    final next = [
      for (final w in day.waves)
        if (w.waveId == waveId ? !w.available : w.available) w.waveId,
    ];
    state = AsyncData([
      for (final d in days)
        d.date == date
            ? AvailabilityDay(date: date, waves: [
                for (final w in d.waves) AvailabilityWave(waveId: w.waveId, type: w.type, time: w.time, available: next.contains(w.waveId), locked: w.locked),
              ])
            : d,
    ]);
    try {
      final saved = await ref.read(apiProvider).setAvailability(date, next);
      state = AsyncData([for (final d in state.value!) d.date == date ? saved : d]);
    } catch (_) {
      state = AsyncData(days);
      rethrow;
    }
  }
}
