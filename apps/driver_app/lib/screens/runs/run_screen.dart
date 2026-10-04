import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/runs.dart';
import '../../l10n/gen/app_localizations.dart';
import 'today_screen.dart';

/// DR-03: one run — stops in driving order, riders and cash per stop. Rows are at least 56 dp
/// tall so they can be used in the vehicle.
class RunScreen extends ConsumerWidget {
  const RunScreen({super.key, required this.runId});
  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final run = ref.watch(todayRunsProvider).value?.where((r) => r.id == runId).firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          NaqlTopBar(
            title: run == null ? t.todayRuns : waveName(t, run.waveType, run.waveTime),
            onBack: () => context.go('/today'),
            backLabel: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          Expanded(
            child: run == null
                ? const Padding(padding: EdgeInsets.all(NaqlSpace.s5), child: NaqlSkeleton(height: 200, radius: NaqlRadius.lg))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, NaqlSpace.s8),
                    children: [
                      NaqlEntrance(child: _Summary(run: run, lang: lang)),
                      const SizedBox(height: NaqlSpace.s5),
                      Text(t.stopsTitle, style: NaqlText.headline),
                      const SizedBox(height: NaqlSpace.s3),
                      if (run.waveType == WaveType.ret)
                        _CampusRow(label: t.leaveCampus, time: run.waveTime, first: true, last: run.stops.isEmpty),
                      for (final (i, s) in run.stops.indexed)
                        NaqlEntrance(
                          index: i + 1,
                          child: StopTile(stop: s, lang: lang, first: i == 0 && run.waveType == WaveType.morning, last: i == run.stops.length - 1 && run.waveType == WaveType.ret),
                        ),
                      if (run.waveType == WaveType.morning) _CampusRow(label: t.arriveBy(run.waveTime), time: run.waveTime, first: run.stops.isEmpty, last: true),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.run, required this.lang});
  final DriverRun run;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: NaqlText.caption),
            const SizedBox(height: NaqlSpace.s1),
            Text(value, style: NaqlText.headline.copyWith(color: color), textDirection: TextDirection.ltr),
          ]),
        );
    return NaqlCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (run.femaleOnly) ...[
          Align(alignment: AlignmentDirectional.centerStart, child: StatusPill(label: t.femaleOnly, tone: NaqlTone.femaleOnly, icon: LucideIcons.users)),
          const SizedBox(height: NaqlSpace.s3),
        ],
        Row(children: [
          cell(t.departAt, run.departAt == null ? '—' : formatClock(run.departAt!)),
          cell(t.seatsLabel, '${run.booked}/${run.capacity}'),
          cell(t.cashToCollect, formatIqd(run.cashToCollect, lang), color: run.cashToCollect > 0 ? NaqlColors.success : null),
        ]),
      ]),
    );
  }
}

/// A stop on the timeline: number, place, time, riders. Tapping shows who boards here.
class StopTile extends StatefulWidget {
  const StopTile({super.key, required this.stop, required this.lang, this.first = false, this.last = false});

  final RunStopInfo stop;
  final String lang;
  final bool first;
  final bool last;

  @override
  State<StopTile> createState() => _StopTileState();
}

class _StopTileState extends State<StopTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = widget.stop;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Rail(label: '${s.seq}', first: widget.first, last: widget.last, done: s.served),
        const SizedBox(width: NaqlSpace.s3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
            child: NaqlCard(
              padding: EdgeInsets.zero,
              onTap: () => setState(() => _open = !_open),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ConstrainedBox(
                  key: ValueKey('stop-${s.seq}'),
                  constraints: const BoxConstraints(minHeight: NaqlTouch.driver),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: NaqlSpace.s3),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(s.point(widget.lang), style: NaqlText.headline),
                          const SizedBox(height: 2),
                          Text(t.riders(s.passengers.length), style: NaqlText.caption),
                        ]),
                      ),
                      Text(formatClock(s.eta), style: NaqlText.title.copyWith(fontSize: 22), textDirection: TextDirection.ltr),
                      const SizedBox(width: NaqlSpace.s2),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: NaqlMotion.fast,
                        child: const Icon(LucideIcons.chevronDown, size: 20, color: NaqlColors.textMuted),
                      ),
                    ]),
                  ),
                ),
                AnimatedSize(
                  duration: NaqlMotion.sheet,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_open
                      ? const SizedBox(width: double.infinity)
                      : Column(children: [
                          const Divider(height: 1, color: NaqlColors.border),
                          for (final p in s.passengers)
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: NaqlTouch.driver),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4),
                                child: Row(children: [
                                  Expanded(child: Text(p.name, style: NaqlText.body)),
                                  p.subscriber && p.fare == 0
                                      ? StatusPill(label: t.subscriber, tone: NaqlTone.primary)
                                      : StatusPill(label: t.payCash(formatIqd(p.fare, widget.lang)), tone: NaqlTone.success, icon: LucideIcons.banknote),
                                ]),
                              ),
                            ),
                        ]),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CampusRow extends StatelessWidget {
  const _CampusRow({required this.label, required this.time, this.first = false, this.last = false});
  final String label;
  final String time;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Rail(icon: LucideIcons.school, first: first, last: last),
        const SizedBox(width: NaqlSpace.s3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
            child: Container(
              constraints: const BoxConstraints(minHeight: NaqlTouch.driver),
              padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: NaqlSpace.s3),
              decoration: BoxDecoration(color: NaqlColors.primarySoft, borderRadius: BorderRadius.circular(NaqlRadius.md)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(t.campus, style: NaqlText.headline.copyWith(color: NaqlColors.primary)),
                    Text(label, style: NaqlText.caption),
                  ]),
                ),
                Text(time, style: NaqlText.title.copyWith(fontSize: 22, color: NaqlColors.primary), textDirection: TextDirection.ltr),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Vertical line with a numbered dot; the line stops at the ends of the route.
class _Rail extends StatelessWidget {
  const _Rail({this.label, this.icon, this.first = false, this.last = false, this.done = false});
  final String? label;
  final IconData? icon;
  final bool first;
  final bool last;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done ? NaqlColors.success : NaqlColors.primary;
    return SizedBox(
      width: 36,
      child: Column(children: [
        Container(width: 2, height: 14, color: first ? Colors.transparent : NaqlColors.border),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: icon != null ? color : NaqlColors.surface, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
          child: icon != null
              ? Icon(icon, size: 18, color: NaqlColors.onPrimary)
              : Text(label ?? '', style: NaqlText.label.copyWith(color: color)),
        ),
        Expanded(child: Container(width: 2, color: last ? Colors.transparent : NaqlColors.border)),
      ]),
    );
  }
}
