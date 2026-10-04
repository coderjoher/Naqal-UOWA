import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/runs.dart';
import '../../l10n/gen/app_localizations.dart';

String waveName(AppLocalizations t, WaveType type, String time) => t.waveLabel(type == WaveType.morning ? t.waveMorning : t.waveReturn, time);

/// DR-03: today's runs, biggest first: when to leave, how many stops and riders.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final runs = ref.watch(todayRunsProvider);
    return Column(children: [
      NaqlTopBar(title: t.todayRuns),
      Expanded(
        child: runs.when(
          loading: () => const Padding(padding: EdgeInsets.all(NaqlSpace.s5), child: NaqlSkeleton(height: 160, radius: NaqlRadius.lg)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(NaqlSpace.s6),
              child: NaqlEmptyState(
                icon: LucideIcons.wifiOff,
                title: t.loadFailed,
                action: NaqlButton(label: t.retry, size: NaqlButtonSize.large, onPressed: () => ref.invalidate(todayRunsProvider)),
              ),
            ),
          ),
          data: (list) => list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(NaqlSpace.s6),
                    child: NaqlEmptyState(
                      icon: LucideIcons.route,
                      title: t.noRunsToday,
                      message: t.noRunsTodayBody,
                      action: NaqlButton(label: t.setSchedule, icon: LucideIcons.calendarDays, size: NaqlButtonSize.large, onPressed: () => context.go('/schedule')),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: NaqlColors.primary,
                  onRefresh: () async => ref.invalidate(todayRunsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, 120),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: NaqlSpace.s4),
                    itemBuilder: (_, i) => NaqlEntrance(index: i, child: RunCard(run: list[i], lang: lang, onTap: () => context.go('/today/run/${list[i].id}'))),
                  ),
                ),
        ),
      ),
    ]);
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(waveName(t, run.waveType, run.waveTime), style: NaqlText.label.copyWith(color: NaqlColors.textMuted))),
          if (run.femaleOnly) StatusPill(label: t.femaleOnly, tone: NaqlTone.femaleOnly, icon: LucideIcons.users),
        ]),
        const SizedBox(height: NaqlSpace.s3),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.departAt, style: NaqlText.caption),
            Text(run.departAt == null ? '—' : formatClock(run.departAt!), style: NaqlText.title.copyWith(fontSize: 32), textDirection: TextDirection.ltr),
          ]),
          const SizedBox(width: NaqlSpace.s4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: NaqlSpace.s1),
              child: Text(
                run.waveType == WaveType.morning ? (first?.point(lang) ?? '') : t.leaveCampus,
                style: NaqlText.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Icon(Directionality.of(context) == TextDirection.rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight, color: NaqlColors.textMuted),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: NaqlSpace.s4), child: Divider(height: 1, color: NaqlColors.border)),
        Row(children: [
          _Fact(icon: LucideIcons.mapPin, text: t.runStops(run.stops.length)),
          const SizedBox(width: NaqlSpace.s4),
          _Fact(icon: LucideIcons.users, text: t.runSeats(run.booked, run.capacity)),
          const Spacer(),
          if (run.cashToCollect > 0) _Fact(icon: LucideIcons.banknote, text: formatIqd(run.cashToCollect, lang), strong: true),
        ]),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.strong = false});
  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: strong ? NaqlColors.success : NaqlColors.textMuted),
        const SizedBox(width: NaqlSpace.s1),
        Text(text, style: (strong ? NaqlText.label : NaqlText.body).copyWith(color: strong ? NaqlColors.success : NaqlColors.textMuted)),
      ]);
}
