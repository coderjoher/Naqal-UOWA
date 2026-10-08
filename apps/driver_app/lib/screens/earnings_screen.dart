import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/earnings.dart';
import '../data/taxi.dart';
import '../l10n/gen/app_localizations.dart';
import 'runs/today_screen.dart';

/// DR-08: what the driver has earned this month (same formula as the office's settlement),
/// the runs behind it, and past approved settlements.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final earnings = ref.watch(earningsProvider);
    final taxi = ref.watch(isTaxiDriverProvider);
    return Column(children: [
      NaqlTopBar(title: t.tabEarnings),
      Expanded(
        child: earnings.when(
          loading: () => const Padding(padding: EdgeInsets.all(NaqlSpace.s5), child: NaqlSkeleton(height: 200, radius: NaqlRadius.lg)),
          error: (e, _) => Center(
            child: NaqlEmptyState(
              icon: LucideIcons.wifiOff,
              title: t.loadFailed,
              action: NaqlButton(label: t.retry, size: NaqlButtonSize.large, onPressed: () => ref.invalidate(earningsProvider)),
            ),
          ),
          data: (e) => RefreshIndicator(
            onRefresh: () {
              if (taxi) ref.invalidate(taxiHistoryProvider);
              return ref.refresh(earningsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, 120),
              children: [
                NaqlEntrance(index: 0, child: _Summary(e: e, lang: lang)),
                if (e.flagged > 0) ...[
                  const SizedBox(height: NaqlSpace.s3),
                  NaqlEntrance(
                    index: 1,
                    child: Container(
                      padding: const EdgeInsets.all(NaqlSpace.s4),
                      decoration: BoxDecoration(color: NaqlColors.warningSoft, borderRadius: BorderRadius.circular(NaqlRadius.md)),
                      child: Row(children: [
                        Icon(LucideIcons.triangleAlert, color: NaqlColors.warning),
                        const SizedBox(width: NaqlSpace.s3),
                        Expanded(child: Text(t.earningsFlagged('${e.flagged}'), key: const ValueKey('flagged'), style: NaqlText.body.copyWith(color: NaqlColors.warning))),
                      ]),
                    ),
                  ),
                ],
                if (taxi) ...[
                  const SizedBox(height: NaqlSpace.s6),
                  NaqlEntrance(index: 2, child: _TaxiMonth(lang: lang)),
                ],
                const SizedBox(height: NaqlSpace.s6),
                Text(t.earningsRunsTitle, style: NaqlText.headline),
                const SizedBox(height: NaqlSpace.s3),
                if (e.list.isEmpty)
                  NaqlCard(child: Text(t.earningsNoRuns, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)))
                else
                  NaqlCard(
                    padding: const EdgeInsets.symmetric(vertical: NaqlSpace.s2),
                    child: Column(children: [
                      for (final r in e.list) _RunRow(run: r, lang: lang),
                    ]),
                  ),
                if (e.past.isNotEmpty) ...[
                  const SizedBox(height: NaqlSpace.s6),
                  Text(t.earningsPast, style: NaqlText.headline),
                  const SizedBox(height: NaqlSpace.s3),
                  for (final p in e.past) ...[
                    NaqlCard(
                      key: ValueKey('past-${p.month}'),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: NaqlColors.successSoft, borderRadius: BorderRadius.circular(NaqlRadius.sm + 2)),
                          child: Icon(LucideIcons.badgeCheck, color: NaqlColors.success, size: 20),
                        ),
                        const SizedBox(width: NaqlSpace.s3),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(formatMonth(p.month, lang), style: NaqlText.label),
                            Text(t.earningsPastRuns('${p.runs}'), style: NaqlText.caption),
                          ]),
                        ),
                        Text(formatIqd(p.payout, lang), style: NaqlText.headline, textDirection: TextDirection.ltr),
                      ]),
                    ),
                    const SizedBox(height: NaqlSpace.s2),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.e, required this.lang});
  final DriverEarnings e;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, tone) = switch (e.source) {
      EarningsSource.approved => (t.earningsApproved, NaqlTone.success),
      EarningsSource.draft => (t.earningsDraft, NaqlTone.warning),
      EarningsSource.estimate => (t.earningsEstimate, NaqlTone.primary),
    };
    return NaqlCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(t.earningsTitle(formatMonth(e.month, lang)), style: NaqlText.headline)),
          StatusPill(label: label, tone: tone),
        ]),
        const SizedBox(height: NaqlSpace.s4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: e.estimate.toDouble()),
          duration: naqlMotion(context, NaqlMotion.sheet),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => Text(
            formatIqd(v.round(), lang),
            key: const ValueKey('estimate'),
            style: NaqlText.hero.copyWith(fontSize: 40, height: 1.15, color: e.estimate < 0 ? NaqlColors.danger : NaqlColors.text),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
          ),
        ),
        if (e.estimate < 0) Text(t.earningsOwe, style: NaqlText.caption.copyWith(color: NaqlColors.danger)),
        const SizedBox(height: NaqlSpace.s3),
        Divider(height: 1, color: NaqlColors.border),
        const SizedBox(height: NaqlSpace.s2),
        _Figure(icon: LucideIcons.route, label: t.earningsRuns, value: '${e.runs}', valueKey: 'runs'),
        _Figure(icon: LucideIcons.banknote, label: t.earningsCash, value: formatIqd(e.cash, lang)),
        _Figure(icon: LucideIcons.percent, label: t.earningsCashCommission, value: e.cashCommission == 0 ? formatIqd(0, lang) : '−${formatIqd(e.cashCommission, lang)}'),
        const SizedBox(height: NaqlSpace.s3),
        Text(t.earningsHint, style: NaqlText.caption),
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.icon, required this.label, required this.value, this.valueKey});
  final IconData icon;
  final String label;
  final String value;
  final String? valueKey;

  @override
  Widget build(BuildContext context) {
    // Same look as NaqlSummaryRow, with a key on the value for tests.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NaqlSpace.s2),
      child: Row(children: [
        Icon(icon, size: 18, color: NaqlColors.textMuted),
        const SizedBox(width: NaqlSpace.s2),
        Expanded(child: Text(label, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))),
        Text(value, key: valueKey == null ? null : ValueKey<String>(valueKey!), style: NaqlText.body.copyWith(fontWeight: FontWeight.w600), textDirection: TextDirection.ltr),
      ]),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run, required this.lang});
  final EarningRun run;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, tone, icon) = run.counted
        ? (t.earningsCounted, NaqlTone.success, LucideIcons.circleCheck)
        : run.flagged
            ? (t.earningsNotCounted, NaqlTone.warning, LucideIcons.circleAlert)
            : (t.earningsPending, NaqlTone.neutral, LucideIcons.clock);
    return Padding(
      key: ValueKey('earning-run-${run.id}'),
      padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: NaqlSpace.s2),
      child: Row(children: [
        Icon(run.waveType == WaveType.morning ? LucideIcons.sunrise : LucideIcons.sunset, color: NaqlColors.textMuted),
        const SizedBox(width: NaqlSpace.s3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(formatDayName(run.date, lang), style: NaqlText.label),
            Text(waveName(t, run.waveType, run.time), style: NaqlText.caption),
          ]),
        ),
        StatusPill(label: label, tone: tone, icon: icon),
      ]),
    );
  }
}

/// P10: this month's taxi trips and cash, and the last few trips (taxi drivers only).
class _TaxiMonth extends ConsumerWidget {
  const _TaxiMonth({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final history = ref.watch(taxiHistoryProvider);
    return history.when(
      loading: () => const NaqlSkeleton(height: 96, radius: NaqlRadius.lg),
      error: (_, _) => NaqlCard(
        child: Row(children: [
          Expanded(child: Text(t.loadFailed, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))),
          NaqlButton(label: t.retry, variant: NaqlButtonVariant.ghost, onPressed: () => ref.invalidate(taxiHistoryProvider)),
        ]),
      ),
      data: (h) {
        final recent = h.rides.take(5).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          NaqlCard(
            key: const ValueKey('taxi-month'),
            child: Row(children: [
              const NaqlIconTile(LucideIcons.carTaxiFront, accent: true, size: 48),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.taxiMonthTitle, style: NaqlText.label.copyWith(color: NaqlColors.textMuted)),
                  Text(t.taxiMonthSummary(h.trips, formatIqd(h.cash, lang)), key: const ValueKey('taxi-month-summary'), style: NaqlText.headline),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: NaqlSpace.s6),
          Text(t.taxiRecent, style: NaqlText.headline),
          const SizedBox(height: NaqlSpace.s3),
          if (recent.isEmpty)
            NaqlCard(child: Text(t.taxiNoTrips, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)))
          else
            NaqlCard(
              padding: const EdgeInsets.symmetric(vertical: NaqlSpace.s2),
              child: Column(children: [for (final r in recent) _TaxiRow(ride: r, lang: lang)]),
            ),
        ]);
      },
    );
  }
}

class _TaxiRow extends StatelessWidget {
  const _TaxiRow({required this.ride, required this.lang});
  final TaxiRide ride;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final toCampus = ride.direction == TaxiDirection.toCampus;
    final done = ride.status == 'done';
    return Padding(
      key: ValueKey('taxi-ride-${ride.id}'),
      padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: NaqlSpace.s2),
      child: Row(children: [
        Icon(toCampus ? LucideIcons.school : LucideIcons.house, color: NaqlColors.textMuted),
        const SizedBox(width: NaqlSpace.s3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(toCampus ? t.taxiToCampus : t.taxiFromCampus, style: NaqlText.label),
            Text('${formatDayMonth(ride.endedAt ?? ride.createdAt, lang)} · ${ride.studentName}', style: NaqlText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (done)
          Text(formatIqd(ride.fare, lang), style: NaqlText.label.copyWith(color: NaqlColors.success), textDirection: TextDirection.ltr)
        else
          StatusPill(
            label: ride.active ? t.taxiStatusActive : t.taxiStatusCancelled,
            tone: ride.active ? NaqlTone.primary : NaqlTone.neutral,
          ),
      ]),
    );
  }
}
