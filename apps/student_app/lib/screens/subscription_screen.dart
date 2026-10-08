import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/subscription.dart';
import '../l10n/gen/app_localizations.dart';
import 'subscription_card.dart';

/// ST-03: the monthly subscription on its own page (from Home's subscription row and the menu),
/// with the payment history one tap away.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final sub = ref.watch(subscriptionProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          NaqlTopBar(title: t.mySubscription, onBack: () => context.canPop() ? context.pop() : context.go('/home'), backLabel: MaterialLocalizations.of(context).backButtonTooltip),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, NaqlSpace.s8), children: [
              sub.when(
                data: (info) => NaqlEntrance(child: SubscriptionCard(info: info, lang: lang)),
                loading: () => const NaqlSkeleton(height: 160, radius: NaqlRadius.lg),
                error: (_, _) => NaqlEmptyState(
                  icon: LucideIcons.wifiOff,
                  title: t.loadFailed,
                  action: NaqlButton(label: t.retry, onPressed: () => ref.invalidate(subscriptionProvider)),
                ),
              ),
              const SizedBox(height: NaqlSpace.s4),
              NaqlEntrance(
                index: 1,
                child: NaqlListRow(
                  title: t.historyPayments,
                  leading: const NaqlIconTile(LucideIcons.receipt, size: 40),
                  onTap: () => context.push('/trips?tab=payments'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
