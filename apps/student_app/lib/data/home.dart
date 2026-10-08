import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';

import 'auth.dart';
import 'taxi.dart';
import 'track.dart';

/// Where the student is, only if location access was already granted (Home never asks; the
/// taxi screen's "use my location" does). Tests override it.
final homeLocatorProvider = Provider<Future<LatLng?> Function()>(
  (ref) => () async {
    try {
      final p = await Geolocator.checkPermission();
      if (p != LocationPermission.always && p != LocationPermission.whileInUse) return null;
      final pos = await Geolocator.getLastKnownPosition();
      return pos == null ? null : LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  },
);

final homeLocationProvider = FutureProvider.autoDispose<LatLng?>((ref) => ref.watch(homeLocatorProvider)());

/// The default gathering point on the map (the profile only carries its id and name).
final pointLocationProvider = FutureProvider.autoDispose<LatLng?>((ref) async {
  final id = ref.watch(authProvider.select((a) => a.value?.defaultPoint?.id));
  if (id == null) return null;
  try {
    return await ref.watch(apiProvider).pointLocation(id);
  } catch (_) {
    return null;
  }
});

/// Home's taxi card: a fare from the gathering point to campus, the pickup time and where the
/// campus is. Only asked for where the office runs taxis.
final homeTaxiQuoteProvider = FutureProvider.autoDispose<TaxiQuote?>((ref) async {
  final enabled = await ref.watch(taxiEnabledProvider.future).catchError((_) => false);
  if (!enabled) return null;
  final from = await ref.watch(pointLocationProvider.future);
  try {
    return await ref.watch(apiProvider).taxiQuote(TaxiDirection.toCampus, from ?? const LatLng(32.616, 44.025));
  } catch (_) {
    return null;
  }
});

/// Unread notifications, for the dot on the bell.
final unreadCountProvider = Provider.autoDispose<int>((ref) => ref.watch(notificationsProvider).value?.where((n) => n.readAt == null).length ?? 0);

/// Baghdad civil date "2026-10-08" for [plus] days from now.
String baghdadDay([int plus = 0]) {
  final d = clock.now().toUtc().add(Duration(hours: 3, days: plus));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Morning greeting until noon (Baghdad time), evening after.
bool baghdadMorning() => clock.now().toUtc().add(const Duration(hours: 3)).hour < 12;
