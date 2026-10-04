import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_ui/naql_ui.dart';

import '../l10n/gen/app_localizations.dart';

/// Home leads with the day's answer: is there a ride? (design principle 1).
/// P3 adds the subscription card, P4 the request flow and trip card.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s4, NaqlSpace.s5, 120),
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.hello, style: NaqlText.title),
                const SizedBox(height: NaqlSpace.s2),
                StatusPill(label: t.noSubscription, icon: LucideIcons.creditCard),
              ]),
            ),
            NaqlIconButton(icon: LucideIcons.bell, semanticLabel: t.notifications, onPressed: () => context.go('/alerts')),
          ]),
          const SizedBox(height: NaqlSpace.s6),
          NaqlCard(
            padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5, vertical: NaqlSpace.s8),
            child: NaqlEmptyState(icon: LucideIcons.busFront, title: t.noRideToday, message: t.noRideTodayBody),
          ),
        ],
      ),
    );
  }
}
