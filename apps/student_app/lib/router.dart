import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import 'data/auth.dart';
import 'data/taxi.dart';
import 'screens/bus_booking_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/track_screen.dart';
import 'screens/onboarding/activate_screen.dart';
import 'screens/onboarding/choose_point_screen.dart';
import 'screens/onboarding/sign_in_screen.dart';
import 'screens/onboarding/university_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/receipt.dart';
import 'screens/subscription_screen.dart';
import 'screens/taxi_screen.dart';
import 'screens/trips_screen.dart';

const _onboarding = {'/welcome', '/university', '/sign-in', '/activate'};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever auth or the chosen university changes.
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(universitySlugProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) return loc == '/splash' ? null : '/splash';
      final user = auth.value;
      if (user == null) {
        if (_onboarding.contains(loc)) {
          // Sign-in screens need a university first.
          if ((loc == '/sign-in' || loc == '/activate') && ref.read(universitySlugProvider) == null) return '/university';
          return null;
        }
        return '/welcome';
      }
      if (user.defaultPoint == null) return loc == '/choose-point' ? null : '/choose-point';
      // Onboarding is finished once a point is chosen (changing it later uses /profile/point).
      if (_onboarding.contains(loc) || loc == '/splash' || loc == '/choose-point') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/university', builder: (_, _) => const UniversityScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/activate', builder: (_, _) => const ActivateScreen()),
      GoRoute(path: '/choose-point', builder: (_, _) => const ChoosePointScreen()),
      // Home is the hub (map-first, no tab bar): everything else opens on top of it and
      // goes back to it.
      GoRoute(
        path: '/home',
        builder: (_, _) => const HomeScreen(),
        routes: [GoRoute(path: 'track/:id', builder: (_, s) => TrackScreen(requestId: s.pathParameters['id']!))],
      ),
      GoRoute(
        path: '/bus',
        builder: (_, s) => BusBookingScreen(
          prefer: switch (s.uri.queryParameters['dir']) { 'morning' => WaveType.morning, 'return' => WaveType.ret, _ => null },
          waveId: s.uri.queryParameters['wave'],
          date: s.uri.queryParameters['date'],
        ),
      ),
      GoRoute(
        path: '/taxi',
        builder: (_, s) => TaxiScreen(
          rideId: s.uri.queryParameters['ride'],
          direction: switch (s.uri.queryParameters['dir']) { 'to' => TaxiDirection.toCampus, 'from' => TaxiDirection.fromCampus, _ => null },
        ),
      ),
      GoRoute(
        path: '/trips',
        builder: (_, s) => TripsScreen(initialTab: s.uri.queryParameters['tab'] == 'payments' ? 1 : 0),
        routes: [GoRoute(path: 'ride/:id', builder: (_, s) => RideDetailsScreen(rideId: s.pathParameters['id']!, initial: s.extra is RideHistoryItem ? s.extra! as RideHistoryItem : null))],
      ),
      GoRoute(path: '/alerts', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/subscription', builder: (_, _) => const SubscriptionScreen()),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const ProfileScreen(),
        routes: [GoRoute(path: 'point', builder: (_, _) => const ChoosePointScreen(changing: true))],
      ),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Icon(LucideIcons.busFront, size: 48, color: NaqlColors.primary)));
}
