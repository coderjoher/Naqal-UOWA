import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/history.dart';
import '../l10n/gen/app_localizations.dart';
import 'feedback_sheets.dart';

/// ST-10: past rides and payments, loaded page by page as the list scrolls.
class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key, this.initialTab = 0});

  /// 0 = rides, 1 = payments.
  final int initialTab;

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  late var _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NaqlTopBar(title: t.tabTrips, onBack: () => context.canPop() ? context.pop() : context.go('/home'), backLabel: MaterialLocalizations.of(context).backButtonTooltip),
            Padding(
              padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, NaqlSpace.s3),
              child: Row(
                children: [
                  Expanded(
                    child: NaqlChip(key: const ValueKey('tab-rides'), label: t.historyRides, selected: _tab == 0, onSelected: () => setState(() => _tab = 0)),
                  ),
                  const SizedBox(width: NaqlSpace.s2),
                  Expanded(
                    child: NaqlChip(key: const ValueKey('tab-payments'), label: t.historyPayments, selected: _tab == 1, onSelected: () => setState(() => _tab = 1)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: naqlMotion(context),
                child: _tab == 0 ? const _RideList(key: ValueKey('rides')) : const _PaymentList(key: ValueKey('payments')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A paged list: first-load skeleton, error with retry, empty state, and a footer that loads the
/// next page (or offers a retry) when the end comes into view.
class _Paged<T> extends ConsumerWidget {
  const _Paged({required this.state, required this.onRetry, required this.onMore, required this.onRefresh, required this.empty, required this.item});

  final AsyncValue<PagedList<T>> state;
  final VoidCallback onRetry;
  final VoidCallback onMore;
  final Future<void> Function() onRefresh;
  final Widget empty;
  final Widget Function(T item, int index) item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return state.when(
      skipLoadingOnRefresh: true,
      loading: () => ListView(
        padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5),
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: NaqlSpace.s3),
              child: NaqlSkeleton(height: 84, radius: NaqlRadius.md),
            ),
        ],
      ),
      error: (e, _) => Center(
        child: NaqlEmptyState(
          key: const ValueKey('history-error'),
          icon: LucideIcons.wifiOff,
          title: t.loadFailed,
          action: NaqlButton(label: t.retry, onPressed: onRetry),
        ),
      ),
      data: (list) => list.items.isEmpty
          ? Center(
              child: Padding(padding: const EdgeInsets.all(NaqlSpace.s6), child: empty),
            )
          : RefreshIndicator(
              color: NaqlColors.primary,
              onRefresh: onRefresh,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.extentAfter < 300) onMore();
                  return false;
                },
                child: ListView.separated(
                  key: const ValueKey('history-list'),
                  padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, 0, NaqlSpace.s5, NaqlSpace.s8),
                  itemCount: list.items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: NaqlSpace.s3),
                  itemBuilder: (_, i) {
                    if (i < list.items.length) return item(list.items[i], i);
                    if (list.moreError) {
                      return Center(
                        child: NaqlButton(key: const ValueKey('more-retry'), label: t.retry, variant: NaqlButtonVariant.secondary, onPressed: onMore),
                      );
                    }
                    if (list.hasMore) {
                      // Visible end of the list: ask for the next page.
                      WidgetsBinding.instance.addPostFrameCallback((_) => onMore());
                      return Padding(
                        key: ValueKey('more-loading'),
                        padding: EdgeInsets.all(NaqlSpace.s4),
                        child: Center(
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: NaqlColors.primary)),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(NaqlSpace.s4),
                      child: Center(child: Text(t.historyEnd, style: NaqlText.caption)),
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class _RideList extends ConsumerWidget {
  const _RideList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    return _Paged<RideHistoryItem>(
      state: ref.watch(rideHistoryProvider),
      onRetry: () => ref.invalidate(rideHistoryProvider),
      onMore: () => ref.read(rideHistoryProvider.notifier).loadMore(),
      onRefresh: () => ref.refresh(rideHistoryProvider.future),
      empty: NaqlEmptyState(icon: LucideIcons.ticket, title: t.historyNoRides, message: t.historyNoRidesBody),
      item: (r, i) => NaqlEntrance(
        index: i % 8,
        child: _RideRow(ride: r, lang: lang),
      ),
    );
  }
}

class _RideRow extends ConsumerWidget {
  const _RideRow({required this.ride, required this.lang});
  final RideHistoryItem ride;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final (label, tone) = switch (ride.status) {
      'done' => (t.historyDone, NaqlTone.success),
      'no_show' => (t.historyNoShow, NaqlTone.warning),
      'cancelled' => (ride.cancelReason == 'expired' ? t.historyExpired : t.historyCancelled, NaqlTone.neutral),
      _ => (t.historyMissed, NaqlTone.neutral),
    };
    final morning = ride.waveType == WaveType.morning;
    final point = ride.point(lang);
    return NaqlCard(
      key: ValueKey('ride-${ride.id}'),
      onTap: () => context.push('/trips/ride/${ride.id}', extra: ride),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NaqlIconTile(morning ? LucideIcons.sunrise : LucideIcons.sunset, accent: !morning, size: 40),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDayName(ride.date, lang), style: NaqlText.label.copyWith(fontWeight: FontWeight.w600)),
                    Text('${morning ? t.rideMorning : t.rideReturn} ${ride.waveTime}', style: NaqlText.caption),
                  ],
                ),
              ),
              StatusPill(label: label, tone: tone),
            ],
          ),
          const SizedBox(height: NaqlSpace.s3),
          // Morning: from the gathering point to campus by the wave time. Return: leaves campus then.
          NaqlTripTimeline(
            accentEnd: true,
            dense: true,
            stops: [
              NaqlTimelineStop(title: morning ? point : t.rideCampus, time: morning ? null : ride.waveTime),
              NaqlTimelineStop(title: morning ? t.rideCampus : point, time: morning ? ride.waveTime : null),
            ],
          ),
          if (ride.driverName != null || ride.fare > 0) ...[
            const SizedBox(height: NaqlSpace.s3),
            Row(
              children: [
                if (ride.driverName != null) ...[
                  Icon(LucideIcons.user, size: 16, color: NaqlColors.textMuted),
                  const SizedBox(width: NaqlSpace.s1),
                  Expanded(child: Text(ride.driverName!, style: NaqlText.caption)),
                ] else
                  const Spacer(),
                if (ride.fare > 0)
                  Text(
                    formatIqd(ride.fare, lang),
                    style: NaqlText.label.copyWith(fontWeight: FontWeight.w600),
                    textDirection: TextDirection.ltr,
                  ),
              ],
            ),
          ],
          if (ride.rating != null || ride.canRate || ride.status == 'done') ...[
            const SizedBox(height: NaqlSpace.s3),
            Row(
              children: [
                if (ride.rating != null)
                  Expanded(
                    child: StarRow(value: ride.rating!, size: 18, key: ValueKey('stars-${ride.id}')),
                  )
                else if (ride.canRate)
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: NaqlButton(
                        key: ValueKey('rate-${ride.id}'),
                        label: t.rateRide,
                        icon: LucideIcons.star,
                        variant: NaqlButtonVariant.secondary,
                        onPressed: () => showRateSheet(context, ride),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                NaqlButton(
                  label: t.reportProblem,
                  variant: NaqlButtonVariant.ghost,
                  onPressed: () => showProblemSheet(context, requestId: ride.id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentList extends ConsumerWidget {
  const _PaymentList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    return _Paged<PaymentItem>(
      state: ref.watch(paymentHistoryProvider),
      onRetry: () => ref.invalidate(paymentHistoryProvider),
      onMore: () => ref.read(paymentHistoryProvider.notifier).loadMore(),
      onRefresh: () => ref.refresh(paymentHistoryProvider.future),
      empty: NaqlEmptyState(icon: LucideIcons.receipt, title: t.historyNoPayments, message: t.historyNoPaymentsBody),
      item: (p, i) {
        final title = switch (p.type) {
          'subscription' => p.month == null ? t.paySubscription : t.paySubscriptionMonth(formatMonth(p.month!, lang)),
          'tier_difference' => t.payTierDifference,
          _ => t.payCashFare,
        };
        return NaqlEntrance(
          index: i % 8,
          child: NaqlCard(
            key: ValueKey('payment-${p.receiptNo}'),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: p.reversal ? NaqlColors.dangerSoft : NaqlColors.successSoft, borderRadius: BorderRadius.circular(NaqlRadius.sm + 2)),
                  child: Icon(p.reversal ? LucideIcons.undo2 : LucideIcons.receipt, size: 20, color: p.reversal ? NaqlColors.danger : NaqlColors.success),
                ),
                const SizedBox(width: NaqlSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.reversal ? t.payReversal(title) : title, style: NaqlText.label),
                      Text('${t.payReceipt(p.receiptNo)} · ${formatDayMonth(p.createdAt, lang)}', style: NaqlText.caption),
                    ],
                  ),
                ),
                Text(
                  formatIqd(p.amount, lang),
                  style: NaqlText.headline.copyWith(color: p.reversal ? NaqlColors.danger : NaqlColors.text),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
