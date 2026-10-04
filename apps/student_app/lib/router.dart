import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_ui/naql_ui.dart';

import 'l10n/gen/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/placeholder_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/trips', builder: (c, _) => PlaceholderScreen(title: AppLocalizations.of(c).tabTrips))]),
          StatefulShellBranch(routes: [GoRoute(path: '/alerts', builder: (c, _) => PlaceholderScreen(title: AppLocalizations.of(c).tabAlerts))]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (c, _) => PlaceholderScreen(title: AppLocalizations.of(c).tabProfile))]),
        ],
      ),
    ],
  );
});

/// Content scrolls under the floating pill navigation (no Material NavigationBar).
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
          NaqlNavItem(icon: LucideIcons.house, label: t.tabHome),
          NaqlNavItem(icon: LucideIcons.ticket, label: t.tabTrips),
          NaqlNavItem(icon: LucideIcons.bell, label: t.tabAlerts),
          NaqlNavItem(icon: LucideIcons.circleUser, label: t.tabProfile),
        ],
      ),
    );
  }
}
