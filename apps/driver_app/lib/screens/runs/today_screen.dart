import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/runs.dart';
import '../../data/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../home_header.dart';

String waveName(AppLocalizations t, WaveType type, String time) => t.waveLabel(type == WaveType.morning ? t.waveMorning : t.waveReturn, time);

String vehicleName(AppLocalizations t, String? v) => switch (v) {
  'coaster' => t.coaster,
  'minibus' => t.minibus,
  'bus' => t.bus,
  'van' => t.van,
  'taxi' => t.taxi,
  null => t.accountNotSet,
  _ => v,
};

/// DR-03: the bus driver's Home. The next run as a big card in place of the taxi switch
/// (when to leave, first stop, stops, seats and cash), today's figures, and the later runs.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final runs = ref.watch(todayRunsProvider);
    final vehicle = ref.watch(applicationProvider.select((a) => a.value?.vehicleType));
    void open(DriverRun r) => context.push('/run/${r.id}');
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: NaqlColors.primary,
        onRefresh: () async => ref.invalidate(todayRunsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s5, NaqlSpace.s4, 120),
          children: [
            DriverHomeHeader(service: vehicleName(t, vehicle)),
            const SizedBox(height: 14),
            ...runs.when(
              loading: () => [const NaqlSkeleton(height: 132, radius: 28)],
              error: (e, _) => [
                Padding(
                  padding: const EdgeInsets.all(NaqlSpace.s6),
                  child: NaqlEmptyState(
                    icon: LucideIcons.wifiOff,
                    title: t.loadFailed,
                    action: NaqlButton(label: t.retry, size: NaqlButtonSize.large, onPressed: () => ref.invalidate(todayRunsProvider)),
                  ),
                ),
              ],
              data: (list) {
                final kpis = KpiRow(
                  tiles: [
                    NaqlKpiTile(label: t.todayRuns, value: '${list.length}'),
                    NaqlKpiTile(label: t.cashToCollect, value: formatIqd(list.fold(0, (n, r) => n + r.cashToCollect), lang), small: true),
                    NaqlKpiTile(label: t.kpiRiders, value: '${list.fold(0, (n, r) => n + r.booked)}'),
                  ],
                );
                if (list.isEmpty) {
                  return [
                    kpis,
                    const SizedBox(height: 14),
                    NaqlCard(
                      child: NaqlEmptyState(
                        icon: LucideIcons.route,
                        title: t.noRunsToday,
                        message: t.noRunsTodayBody,
                        action: NaqlButton(label: t.setSchedule, icon: LucideIcons.calendarDays, size: NaqlButtonSize.large, onPressed: () => context.go('/schedule')),
                      ),
                    ),
                  ];
                }
                final next = list.where((r) => r.status != 'done').firstOrNull;
                final later = [
                  for (final r in list)
                    if (r != next) r,
                ];
                return [
                  if (next != null)
                    NaqlEntrance(
                      child: NextRunCard(run: next, lang: lang, onTap: () => open(next)),
                    ),
                  const SizedBox(height: 14),
                  NaqlEntrance(index: 1, child: kpis),
                  if (later.isNotEmpty) ...[
                    const SizedBox(height: NaqlSpace.s5),
                    Text(t.laterToday, style: NaqlText.headline.copyWith(fontSize: 17)),
                    const SizedBox(height: NaqlSpace.s3),
                    for (final (i, r) in later.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
                        child: NaqlEntrance(
                          index: i + 2,
                          child: RunCard(run: r, lang: lang, onTap: () => open(r)),
                        ),
                      ),
                  ],
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The run to drive next, as the Home's hero card: gold, big departure time, then the facts.
class NextRunCard extends StatelessWidget {
  const NextRunCard({super.key, required this.run, required this.lang, this.onTap});
  final DriverRun run;
  final String lang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final first = run.stops.firstOrNull;
    final fg = NaqlColors.onAccent;
    final facts = [t.runStops(run.stops.length), t.runSeats(run.booked, run.capacity), if (run.cashToCollect > 0) formatIqd(run.cashToCollect, lang)];
    return NaqlPressable(
      key: const ValueKey('next-run'),
      onPressed: onTap,
      pressedScale: 0.98,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s4, NaqlSpace.s5, NaqlSpace.s4),
        decoration: BoxDecoration(color: NaqlColors.accent, borderRadius: BorderRadius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                  child: Icon(LucideIcons.busFront, size: 28, color: NaqlColors.accent),
                ),
                const SizedBox(width: NaqlSpace.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.nextRunTitle, style: NaqlText.label.copyWith(color: fg.withValues(alpha: 0.8))),
                      Text(
                        waveName(t, run.waveType, run.waveTime),
                        style: NaqlText.title.copyWith(fontSize: 24, height: 1.25, fontWeight: FontWeight.w700, color: fg),
                      ),
                    ],
                  ),
                ),
                Icon(rtl ? LucideIcons.arrowLeft : LucideIcons.arrowRight, color: fg),
              ],
            ),
            const SizedBox(height: NaqlSpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.departAt, style: NaqlText.caption.copyWith(color: fg.withValues(alpha: 0.8))),
                    Text(
                      run.departAt == null ? '—' : formatClock(run.departAt!),
                      style: NaqlText.title.copyWith(fontSize: 30, height: 1.15, fontWeight: FontWeight.w700, color: fg),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
                const SizedBox(width: NaqlSpace.s4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      run.waveType == WaveType.morning ? (first?.point(lang) ?? '') : t.leaveCampus,
                      style: NaqlText.headline.copyWith(color: fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NaqlSpace.s3),
            Wrap(
              spacing: NaqlSpace.s2,
              runSpacing: NaqlSpace.s2,
              children: [
                for (final f in facts)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: fg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(NaqlRadius.pill)),
                    child: Text(
                      f,
                      style: NaqlText.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (run.femaleOnly) StatusPill(label: t.femaleOnly, tone: NaqlTone.femaleOnly, icon: LucideIcons.users),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RunCard extends StatelessWidget {
  const RunCard({super.key, required this.run, required this.lang, this.onTap});

  final DriverRun run;
  final String lang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final first = run.stops.isEmpty ? null : run.stops.first;
    return NaqlCard(
      onTap: onTap,
      padding: const EdgeInsets.all(NaqlSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(waveName(t, run.waveType, run.waveTime), style: NaqlText.label.copyWith(color: NaqlColors.textMuted)),
              ),
              if (run.femaleOnly) StatusPill(label: t.femaleOnly, tone: NaqlTone.femaleOnly, icon: LucideIcons.users),
              if (run.status == 'done') StatusPill(label: t.runDone, tone: NaqlTone.success, icon: LucideIcons.circleCheck),
            ],
          ),
          const SizedBox(height: NaqlSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(run.departAt == null ? '—' : formatClock(run.departAt!), style: NaqlText.title.copyWith(fontSize: 28, height: 1.15), textDirection: TextDirection.ltr),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    run.waveType == WaveType.morning ? (first?.point(lang) ?? '') : t.leaveCampus,
                    style: NaqlText.headline.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NaqlSpace.s3),
          Wrap(
            spacing: NaqlSpace.s4,
            runSpacing: NaqlSpace.s2,
            children: [
              _Fact(icon: LucideIcons.mapPin, text: t.runStops(run.stops.length)),
              _Fact(icon: LucideIcons.users, text: t.runSeats(run.booked, run.capacity)),
              if (run.cashToCollect > 0) _Fact(icon: LucideIcons.banknote, text: formatIqd(run.cashToCollect, lang), strong: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.strong = false});
  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: strong ? NaqlColors.success : NaqlColors.textMuted),
      const SizedBox(width: NaqlSpace.s1),
      Text(text, style: (strong ? NaqlText.label : NaqlText.body).copyWith(color: strong ? NaqlColors.success : NaqlColors.textMuted)),
    ],
  );
}
