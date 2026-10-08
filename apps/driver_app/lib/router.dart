import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import 'data/session.dart';
import 'data/taxi.dart';
import 'l10n/gen/app_localizations.dart';
import 'screens/account_screen.dart';
import 'screens/application_screen.dart';
import 'screens/earnings_screen.dart';
import 'screens/onboarding/code_screen.dart';
import 'screens/onboarding/phone_screen.dart';
import 'screens/onboarding/university_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/status_screen.dart';
import 'screens/runs/run_screen.dart';
import 'screens/runs/today_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/taxi/taxi_home_screen.dart';

const _onboarding = {'/welcome', '/university', '/phone', '/code'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(applicationProvider, (_, _) => refresh.value++);
  ref.listen(isTaxiDriverProvider, (_, _) => refresh.value++);
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
      // P10: taxi drivers have no bus waves (the server refuses them) and no bus runs.
      if (ref.read(isTaxiDriverProvider) && (loc == '/schedule' || loc.startsWith('/today/run/'))) return '/today';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => Scaffold(body: Center(child: Icon(LucideIcons.busFront, size: 48, color: NaqlColors.primary)))),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/university', builder: (_, _) => const UniversityScreen()),
      GoRoute(path: '/phone', builder: (_, _) => const PhoneScreen()),
      GoRoute(path: '/code', builder: (_, _) => const CodeScreen()),
      GoRoute(path: '/apply', builder: (_, _) => const ApplicationScreen()),
      GoRoute(path: '/status', builder: (_, _) => const StatusScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/today',
              builder: (_, _) => const _TodayTab(),
              routes: [GoRoute(path: 'run/:id', builder: (_, s) => RunScreen(runId: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/earnings', builder: (_, _) => const EarningsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const AccountScreen())]),
        ],
      ),
    ],
  );
});

/// First tab: the taxi home for taxi drivers, today's bus runs for everyone else.
class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(isTaxiDriverProvider) ? const TaxiHomeScreen() : const TodayScreen();
}

/// Shell branches, in order: today, schedule, earnings, profile.
const _scheduleBranch = 1;

class _Shell extends ConsumerWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final taxi = ref.watch(isTaxiDriverProvider);
    // Taxi drivers work on demand, so the Schedule tab is left out; the other tabs keep their branches.
    final tabs = [
      (branch: 0, item: taxi ? NaqlNavItem(icon: LucideIcons.carTaxiFront, label: t.taxi) : NaqlNavItem(icon: LucideIcons.route, label: t.tabToday)),
      if (!taxi) (branch: _scheduleBranch, item: NaqlNavItem(icon: LucideIcons.calendarDays, label: t.tabSchedule)),
      (branch: 2, item: NaqlNavItem(icon: LucideIcons.wallet, label: t.tabEarnings)),
      (branch: 3, item: NaqlNavItem(icon: LucideIcons.circleUser, label: t.tabProfile)),
    ];
    final current = tabs.indexWhere((x) => x.branch == shell.currentIndex);
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: NaqlBottomNav(
        currentIndex: current < 0 ? 0 : current,
        onTap: (i) => shell.goBranch(tabs[i].branch, initialLocation: tabs[i].branch == shell.currentIndex),
        items: [for (final x in tabs) x.item],
      ),
    );
  }
}
