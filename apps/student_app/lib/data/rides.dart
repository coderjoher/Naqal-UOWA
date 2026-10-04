import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';

/// While a request is open or waitlisted the app checks often, so an assignment shows within
/// seconds; otherwise it refreshes slowly (push notifications arrive in P5).
const ridePollWaiting = Duration(seconds: 5);
const ridePollIdle = Duration(seconds: 60);

/// The student's requests for today and tomorrow, refreshed while Home is visible.
final ridesProvider = StreamProvider.autoDispose<List<RideInfo>>((ref) {
  final api = ref.watch(apiProvider);
  final controller = StreamController<List<RideInfo>>();
  Timer? timer;
  var disposed = false;

  Future<void> tick() async {
    timer?.cancel();
    try {
      final rides = await api.myRides();
      if (disposed) return;
      controller.add(rides);
      final waiting = rides.any((r) => r.status == RideStatus.open || r.status == RideStatus.waitlisted);
      timer = Timer(waiting ? ridePollWaiting : ridePollIdle, tick);
    } catch (e, st) {
      if (disposed) return;
      controller.addError(e, st);
      timer = Timer(ridePollWaiting, tick);
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

final rideOptionsProvider = FutureProvider.autoDispose<RideOptions>((ref) => ref.watch(apiProvider).rideOptions());

/// The ride Home should show: the first live one, else nothing.
RideInfo? currentRide(List<RideInfo> rides) {
  for (final r in rides) {
    if (r.isLive) return r;
  }
  return null;
}

/// A request that expired today without a seat, to explain what happened.
RideInfo? lastExpired(List<RideInfo> rides) {
  for (final r in rides) {
    if (r.status == RideStatus.cancelled && r.cancelReason == 'expired') return r;
  }
  return null;
}
