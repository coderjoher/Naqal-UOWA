import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';

/// How often to re-check while the student is waiting for the office to record a payment
/// (T3-08: the card turns active within 5 s), and when it is already active.
const waitingPoll = Duration(seconds: 4);
const activePoll = Duration(minutes: 5);

/// The student's subscription, refreshed periodically while the home screen is visible.
final subscriptionProvider = StreamProvider.autoDispose<SubscriptionInfo>((ref) {
  final api = ref.watch(apiProvider);
  final controller = StreamController<SubscriptionInfo>();
  Timer? timer;
  var disposed = false;

  Future<void> tick() async {
    try {
      final info = await api.subscription();
      if (disposed) return;
      controller.add(info);
      timer = Timer(info.isActive ? activePoll : waitingPoll, tick);
    } catch (e, st) {
      if (disposed) return;
      controller.addError(e, st);
      timer = Timer(waitingPoll, tick);
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
