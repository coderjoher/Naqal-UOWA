import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/auth.dart';
import '../l10n/gen/app_localizations.dart';

/// Home leads with the day's answer: is there a ride? (design principle 1).
/// P3 adds the subscription card, P4 the request flow and trip card.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final user = ref.watch(authProvider).value;
    final point = user?.defaultPoint;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s4, NaqlSpace.s5, 120),
        children: [
          NaqlEntrance(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user == null ? t.hello : t.helloName(user.displayName(lang).split(' ').first), style: NaqlText.title),
                  const SizedBox(height: NaqlSpace.s2),
                  StatusPill(label: t.noSubscription, icon: LucideIcons.creditCard),
                ]),
              ),
              NaqlIconButton(icon: LucideIcons.bell, semanticLabel: t.notifications, onPressed: () => context.go('/alerts')),
            ]),
          ),
          const SizedBox(height: NaqlSpace.s6),
          if (point != null)
            NaqlEntrance(
              index: 1,
              child: NaqlCard(
                onTap: () => context.go('/profile/point'),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: NaqlColors.primarySoft, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.mapPin, color: NaqlColors.primary, size: 22),
                  ),
                  const SizedBox(width: NaqlSpace.s3),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.yourPoint, style: NaqlText.caption),
                      Text(point.displayName(lang), style: NaqlText.headline),
                    ]),
                  ),
                  Text(t.change, style: NaqlText.label.copyWith(color: NaqlColors.primary)),
                ]),
              ),
            ),
          const SizedBox(height: NaqlSpace.s4),
          NaqlEntrance(
            index: 2,
            child: NaqlCard(
              padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5, vertical: NaqlSpace.s8),
              child: NaqlEmptyState(icon: LucideIcons.busFront, title: t.noRideToday, message: t.noRideTodayBody),
            ),
          ),
        ],
      ),
    );
  }
}
