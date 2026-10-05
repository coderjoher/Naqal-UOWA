import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/auth.dart';
import '../data/history.dart';
import '../data/subscription.dart';
import '../l10n/gen/app_localizations.dart';
import 'ride_section.dart';
import 'subscription_card.dart';

/// Home leads with the day's answer: is there a ride? (design principle 1).
/// The ride comes first (P4), then the subscription (P3) and the gathering point.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final user = ref.watch(authProvider).value;
    final point = user?.defaultPoint;
    final sub = ref.watch(subscriptionProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s4, NaqlSpace.s5, 120),
        children: [
          NaqlEntrance(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user == null ? t.hello : t.helloName(user.displayName(lang).split(' ').first), style: NaqlText.title),
                ]),
              ),
              NaqlIconButton(icon: LucideIcons.bell, semanticLabel: t.notifications, onPressed: () => context.go('/alerts')),
            ]),
          ),
          const SizedBox(height: NaqlSpace.s6),
          const _Announcements(),
          const NaqlEntrance(index: 1, child: RideSection()),
          const SizedBox(height: NaqlSpace.s4),
          NaqlEntrance(
            index: 2,
            child: sub.when(
              data: (info) => SubscriptionCard(info: info, lang: lang),
              loading: () => const NaqlSkeleton(height: 120, radius: NaqlRadius.lg),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: NaqlSpace.s4),
          if (point != null)
            NaqlEntrance(
              index: 3,
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
        ],
      ),
    );
  }
}

/// TO-11: office announcements on top of Home until the student dismisses them.
class _Announcements extends ConsumerWidget {
  const _Announcements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final list = ref.watch(announcementsProvider).value ?? const [];
    return AnimatedSize(
      duration: NaqlMotion.sheet,
      curve: Curves.easeOutCubic,
      child: Column(children: [
        for (final a in list)
          Padding(
            key: ValueKey('announcement-${a.id}'),
            padding: const EdgeInsets.only(bottom: NaqlSpace.s4),
            child: Container(
              padding: const EdgeInsets.all(NaqlSpace.s4),
              decoration: BoxDecoration(color: NaqlColors.primarySoft, borderRadius: BorderRadius.circular(NaqlRadius.lg)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(LucideIcons.megaphone, color: NaqlColors.primary),
                const SizedBox(width: NaqlSpace.s3),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, style: NaqlText.label.copyWith(color: NaqlColors.primary)),
                    const SizedBox(height: 2),
                    Text(a.body, style: NaqlText.body),
                  ]),
                ),
                NaqlIconButton(
                  icon: LucideIcons.x,
                  semanticLabel: t.dismiss,
                  onPressed: () async {
                    await ref.read(apiProvider).markNotificationsRead([a.id]).catchError((_) {});
                    ref.invalidate(announcementsProvider);
                  },
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
