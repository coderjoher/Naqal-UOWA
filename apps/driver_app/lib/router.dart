import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import 'data/session.dart';
import 'l10n/gen/app_localizations.dart';
import 'screens/application_screen.dart';
import 'screens/onboarding/code_screen.dart';
import 'screens/onboarding/phone_screen.dart';
import 'screens/onboarding/university_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/status_screen.dart';
import 'screens/today_screen.dart';

const _onboarding = {'/welcome', '/university', '/phone', '/code'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(applicationProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/today',
    refreshListenable: refresh,
    redirect: (context, state) {
      final app = ref.read(applicationProvider);
      final loc = state.matchedLocation;
      if (app.isLoading && !app.hasValue) return loc == '/splash' ? null : '/splash';
      final a = app.value;
      if (a == null) return _onboarding.contains(loc) ? null : '/welcome';
      // Where each application status lives.
      final home = switch (a.status) {
        DriverStatus.draft => '/apply',
        DriverStatus.rejected => loc == '/apply' ? '/apply' : '/status',
        DriverStatus.pending || DriverStatus.suspended => '/status',
        DriverStatus.approved => null,
      };
      if (home != null) return loc == home ? null : home;
      if (_onboarding.contains(loc) || loc == '/splash' || loc == '/apply' || loc == '/status') return '/today';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: Icon(LucideIcons.busFront, size: 48, color: NaqlColors.primary)))),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/university', builder: (_, _) => const UniversityScreen()),
      GoRoute(path: '/phone', builder: (_, _) => const PhoneScreen()),
      GoRoute(path: '/code', builder: (_, _) => const CodeScreen()),
      GoRoute(path: '/apply', builder: (_, _) => const ApplicationScreen()),
      GoRoute(path: '/status', builder: (_, _) => const StatusScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/today', builder: (_, _) => const TodayScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/earnings', builder: (c, _) => PlaceholderScreen(title: AppLocalizations.of(c).tabEarnings))]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (c, _) => PlaceholderScreen(title: AppLocalizations.of(c).tabProfile))]),
        ],
      ),
    ],
  );
});

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: NaqlBottomNav(
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          NaqlNavItem(icon: LucideIcons.route, label: t.tabToday),
          NaqlNavItem(icon: LucideIcons.wallet, label: t.tabEarnings),
          NaqlNavItem(icon: LucideIcons.circleUser, label: t.tabProfile),
        ],
      ),
    );
  }
}

