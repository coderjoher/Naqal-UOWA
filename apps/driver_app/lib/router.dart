import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_ui/naql_ui.dart';

import 'l10n/gen/app_localizations.dart';
import 'screens/placeholder_screen.dart';
import 'screens/today_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/today',
    routes: [
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
