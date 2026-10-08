import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/run_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import 'today_screen.dart';

/// DR-03/04: one run — what to do now on top, the stops in driving order below. Every row and
/// button is at least 56 dp tall so it can be used in the vehicle.
class RunScreen extends ConsumerWidget {
  const RunScreen({super.key, required this.runId});
  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final view = ref.watch(runControllerProvider(runId)).value;
    final pending = ref.watch(pendingSyncProvider).value ?? 0;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          NaqlTopBar(
            title: view == null ? t.todayRuns : waveName(t, view.base.waveType, view.base.waveTime),
            onBack: () => context.go('/today'),
            backLabel: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          AnimatedSwitcher(
            duration: NaqlMotion.fast,
            child: pending > 0
                ? Padding(
                    key: const ValueKey('pending'),
                    padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, 0, NaqlSpace.s5, NaqlSpace.s2),
                    child: StatusPill(label: t.pendingSync(pending), tone: NaqlTone.warning, icon: LucideIcons.cloudOff),
                  )
                : const SizedBox.shrink(key: ValueKey('synced')),
          ),
          Expanded(
            child: view == null
                ? const Padding(padding: EdgeInsets.all(NaqlSpace.s5), child: NaqlSkeleton(height: 200, radius: NaqlRadius.lg))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, NaqlSpace.s8),
                    children: [
                      NaqlEntrance(child: _Summary(view: view, lang: lang)),
                      const SizedBox(height: NaqlSpace.s4),
                      NaqlEntrance(index: 1, child: ActionPanel(runId: runId, view: view, lang: lang)),
                      const SizedBox(height: NaqlSpace.s5),
                      Text(t.stopsTitle, style: NaqlText.headline),
                      const SizedBox(height: NaqlSpace.s3),
                      if (!view.morning) _CampusRow(label: t.leaveCampus, time: view.base.waveTime, first: true, last: view.base.stops.isEmpty, done: view.status != 'planned'),
                      for (final (i, s) in view.base.stops.indexed)
                        NaqlEntrance(
                          index: i + 2,
                          child: StopTile(
                            stop: s,
                            view: view,
                            lang: lang,
                            first: i == 0 && view.morning,
                            last: i == view.base.stops.length - 1 && !view.morning,
                          ),
                        ),
                      if (view.morning) _CampusRow(label: t.arriveBy(view.base.waveTime), time: view.base.waveTime, first: view.base.stops.isEmpty, last: true, done: view.status == 'done'),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.view, required this.lang});
  final RunView view;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final run = view.base;
    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: NaqlText.caption),
            const SizedBox(height: NaqlSpace.s1),
            Text(value, style: NaqlText.title.copyWith(fontSize: 20, color: color), textDirection: TextDirection.ltr),
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

/// The one thing to do now, as a big button: start → arrive → board → leave → … → finish.
class ActionPanel extends ConsumerStatefulWidget {
  const ActionPanel({super.key, required this.runId, required this.view, required this.lang});
  final String runId;
  final RunView view;
  final String lang;

  @override
  ConsumerState<ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends ConsumerState<ActionPanel> {
  Timer? _tick;
  final _campusBoarded = <String>{};

  @override
  void initState() {
    super.initState();
    // Re-evaluates the no-show wait every second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.view.status == 'at_stop') setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  RunController get _ctl => ref.read(runControllerProvider(widget.runId).notifier);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final v = widget.view;
    final next = v.nextStop;
    final error = ref.watch(runControllerProvider(widget.runId).notifier).lastError;

    final Widget body = switch (v.status) {
      'planned' when v.morning => _Big(
          key: const ValueKey('start'),
          title: next == null ? t.startRun : t.nextStop,
          subtitle: next?.point(widget.lang),
          trailing: next == null ? null : _NavButton(stop: next),
          action: NaqlButton(label: t.startRun, icon: LucideIcons.play, size: NaqlButtonSize.large, expand: true, onPressed: () => _ctl.start()),
        ),
      'planned' => _Big(
          key: const ValueKey('campus'),
          title: t.boardAtCampus,
          rows: [
            for (final p in v.allPassengers)
              _RiderRow(
                passenger: p,
                state: _campusBoarded.contains(p.requestId) ? _Rider.onBoard : _Rider.waiting,
                lang: widget.lang,
                onTap: () => setState(() => _campusBoarded.contains(p.requestId) ? _campusBoarded.remove(p.requestId) : _campusBoarded.add(p.requestId)),
              ),
          ],
          action: NaqlButton(label: t.leaveCampusNow, icon: LucideIcons.play, size: NaqlButtonSize.large, expand: true, onPressed: () => _ctl.start(boarded: [..._campusBoarded])),
        ),
      'started' when next != null => _Big(
          key: ValueKey('drive-${next.seq}'),
          title: v.morning ? t.nextStop : t.dropOff,
          subtitle: '${next.seq}. ${next.point(widget.lang)}',
          trailing: _NavButton(stop: next),
          action: NaqlButton(label: t.imHere, icon: LucideIcons.mapPinCheck, size: NaqlButtonSize.large, expand: true, onPressed: () => _ctl.arrive()),
        ),
      'started' => _Big(
          key: const ValueKey('end'),
          title: v.morning ? t.endTitleMorning : t.endTitleReturn,
          icon: v.morning ? LucideIcons.school : LucideIcons.circleCheck,
          action: NaqlButton(label: v.morning ? t.arrivedCampus : t.finishRun, icon: LucideIcons.flag, size: NaqlButtonSize.large, expand: true, onPressed: () => _ctl.end()),
        ),
      'at_stop' when next != null => _atStop(context, v, next),
      'done' => _Big(key: const ValueKey('done'), title: t.runDone, subtitle: t.runDoneBody, icon: LucideIcons.circleCheck, tone: NaqlTone.success),
      _ => const SizedBox.shrink(),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
          child: Container(
            padding: const EdgeInsets.all(NaqlSpace.s3),
            decoration: BoxDecoration(color: NaqlColors.dangerSoft, borderRadius: BorderRadius.circular(NaqlRadius.sm)),
            child: Text(error, style: NaqlText.body.copyWith(color: NaqlColors.danger)),
          ),
        ),
      AnimatedSwitcher(
        duration: NaqlMotion.sheet,
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a), child: c)),
        child: body,
      ),
    ]);
  }

  Widget _atStop(BuildContext context, RunView v, RunStopInfo stop) {
    final t = AppLocalizations.of(context);
    final left = v.waitLeft(clock.now());
    final missing = v.morning ? stop.passengers.where((p) => !v.isBoarded(p) && !v.isNoShow(p)).length : 0;
    return _Big(
      key: ValueKey('stop-${stop.seq}'),
      title: '${t.atStop} · ${stop.seq}. ${stop.point(widget.lang)}',
      subtitle: v.morning && stop.passengers.isNotEmpty ? t.boardHint : null,
      rows: [
        if (v.morning)
          for (final p in stop.passengers)
            _RiderRow(
              passenger: p,
              state: v.isBoarded(p) ? _Rider.onBoard : _Rider.waiting,
              lang: widget.lang,
              paid: v.isPaid(p),
              onTap: v.isBoarded(p) ? null : () => _ctl.board([p.requestId]),
              onCollect: v.isBoarded(p) && p.fare > 0 && !v.isPaid(p) ? () => _ctl.collectFare(p.requestId) : null,
            ),
        if (left > 0) ...[
          const SizedBox(height: NaqlSpace.s2),
          Row(children: [
            Icon(LucideIcons.hourglass, size: 18, color: NaqlColors.warning),
            const SizedBox(width: NaqlSpace.s2),
            Text(t.waitLeft(formatCountdown(Duration(seconds: left))), key: const ValueKey('wait'), style: NaqlText.label.copyWith(color: NaqlColors.warning)),
          ]),
        ],
      ],
      action: NaqlButton(
        label: missing > 0 && left == 0 ? t.departMissing(missing) : t.departStop,
        icon: LucideIcons.arrowRightFromLine,
        size: NaqlButtonSize.large,
        expand: true,
        variant: missing > 0 && left == 0 ? NaqlButtonVariant.secondary : NaqlButtonVariant.primary,
        onPressed: left > 0 ? null : () => _ctl.depart(),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({super.key, required this.title, this.subtitle, this.trailing, this.rows = const [], this.action, this.icon, this.tone = NaqlTone.primary});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> rows;
  final Widget? action;
  final IconData? icon;
  final NaqlTone tone;

  @override
  Widget build(BuildContext context) {
    return NaqlCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (icon != null) ...[
            Container(width: 48, height: 48, decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(NaqlRadius.md)), child: Icon(icon, color: tone.fg)),
            const SizedBox(width: NaqlSpace.s3),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: NaqlText.title.copyWith(fontSize: 22)),
              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))],
            ]),
          ),
          ?trailing,
        ]),
        if (rows.isNotEmpty) ...[const SizedBox(height: NaqlSpace.s3), ...rows],
        if (action != null) ...[const SizedBox(height: NaqlSpace.s4), action!],
      ]),
    );
  }
}

enum _Rider { waiting, onBoard }

/// 56 dp rider row: tap to mark on board; cash button for pay-per-ride riders.
class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.passenger, required this.state, required this.lang, this.onTap, this.onCollect, this.paid = false});
  final RunPassenger passenger;
  final _Rider state;
  final String lang;
  final VoidCallback? onTap;
  final VoidCallback? onCollect;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final on = state == _Rider.onBoard;
    return Padding(
      padding: const EdgeInsets.only(top: NaqlSpace.s2),
      child: NaqlPressable(
        onPressed: onTap,
        semanticLabel: passenger.name,
        child: AnimatedContainer(
          key: ValueKey('rider-${passenger.requestId}'),
          duration: naqlMotion(context),
          constraints: const BoxConstraints(minHeight: NaqlTouch.driver),
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s3),
          decoration: BoxDecoration(
            color: on ? NaqlColors.successSoft : NaqlColors.surfaceMuted,
            borderRadius: BorderRadius.circular(NaqlRadius.md),
          ),
          child: Row(children: [
            AnimatedSwitcher(
              duration: NaqlMotion.fast,
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(on ? LucideIcons.circleCheck : LucideIcons.circle, key: ValueKey(on), color: on ? NaqlColors.success : NaqlColors.border, size: 26),
            ),
            const SizedBox(width: NaqlSpace.s3),
            Expanded(child: Text(passenger.name, style: NaqlText.label)),
            if (passenger.fare > 0 && on)
              paid
                  ? StatusPill(label: t.paidLabel, tone: NaqlTone.success, icon: LucideIcons.banknote)
                  : TextButton(
                      key: ValueKey('fare-${passenger.requestId}'),
                      onPressed: onCollect,
                      style: TextButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: NaqlColors.success, textStyle: NaqlText.label.copyWith(fontWeight: FontWeight.w600)),
                      child: Text(t.collectFare(formatIqd(passenger.fare, lang))),
                    )
            else if (!on)
              Text(t.waiting, style: NaqlText.caption),
          ]),
        ),
      ),
    );
  }
}

/// DR-06: hand-off to Google Maps or Waze with the stop's coordinates.
class _NavButton extends ConsumerWidget {
  const _NavButton({required this.stop});
  final RunStopInfo stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return NaqlButton(
      key: const ValueKey('navigate'),
      label: t.navigate,
      icon: LucideIcons.navigation,
      variant: NaqlButtonVariant.secondary,
      onPressed: () => showNaqlSheet<void>(
        context,
        builder: (c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.navigate, style: NaqlText.title),
          const SizedBox(height: NaqlSpace.s4),
          NaqlButton(
            label: t.navGoogle,
            icon: LucideIcons.map,
            size: NaqlButtonSize.large,
            expand: true,
            onPressed: () async {
              Navigator.of(c).pop();
              final open = ref.read(urlLauncherProvider);
              final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
              if (!await open(googleMapsNavigation(stop.lat, stop.lng, android: android)) && android) {
                await open(googleMapsNavigation(stop.lat, stop.lng, android: false));
              }
            },
          ),
          const SizedBox(height: NaqlSpace.s2),
          NaqlButton(
            label: t.navWaze,
            icon: LucideIcons.navigation2,
            size: NaqlButtonSize.large,
            variant: NaqlButtonVariant.secondary,
            expand: true,
            onPressed: () {
              Navigator.of(c).pop();
              ref.read(urlLauncherProvider)(wazeNavigation(stop.lat, stop.lng));
            },
          ),
        ]),
      ),
    );
  }
}

/// A stop on the timeline: number, place, time, riders. Tapping shows who boards here.
class StopTile extends StatefulWidget {
  const StopTile({super.key, required this.stop, required this.view, required this.lang, this.first = false, this.last = false});

  final RunStopInfo stop;
  final RunView view;
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
    final v = widget.view;
    final served = v.isServed(s);
    final here = v.status == 'at_stop' && v.nextStop?.seq == s.seq;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Rail(label: '${s.seq}', first: widget.first, last: widget.last, done: served, current: here),
        const SizedBox(width: NaqlSpace.s3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
            child: AnimatedOpacity(
              duration: NaqlMotion.sheet,
              opacity: served ? 0.6 : 1,
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
                          child: Icon(LucideIcons.chevronDown, size: 20, color: NaqlColors.textMuted),
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
                            Divider(height: 1, color: NaqlColors.border),
                            for (final p in s.passengers)
                              ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: NaqlTouch.driver),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4),
                                  child: Row(children: [
                                    Expanded(child: Text(p.name, style: NaqlText.body)),
                                    if (v.isNoShow(p))
                                      StatusPill(label: t.noShowLabel, tone: NaqlTone.neutral)
                                    else if (v.isBoarded(p))
                                      StatusPill(label: t.onBoard, tone: NaqlTone.success)
                                    else if (p.subscriber && p.fare == 0)
                                      StatusPill(label: t.subscriber, tone: NaqlTone.primary)
                                    else
                                      StatusPill(label: t.payCash(formatIqd(p.fare, widget.lang)), tone: NaqlTone.success, icon: LucideIcons.banknote),
                                  ]),
                                ),
                              ),
                          ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CampusRow extends StatelessWidget {
  const _CampusRow({required this.label, required this.time, this.first = false, this.last = false, this.done = false});
  final String label;
  final String time;
  final bool first;
  final bool last;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Rail(icon: LucideIcons.school, first: first, last: last, done: done),
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

/// Vertical line with a numbered dot; the current stop pulses, served stops turn green.
class _Rail extends StatelessWidget {
  const _Rail({this.label, this.icon, this.first = false, this.last = false, this.done = false, this.current = false});
  final String? label;
  final IconData? icon;
  final bool first;
  final bool last;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = done ? NaqlColors.success : NaqlColors.primary;
    final filled = icon != null || current;
    return SizedBox(
      width: 36,
      child: Column(children: [
        Container(width: 2, height: 14, color: first ? Colors.transparent : NaqlColors.border),
        AnimatedContainer(
          duration: NaqlMotion.sheet,
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: filled ? color : NaqlColors.surface, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
          child: icon != null
              ? Icon(icon, size: 18, color: NaqlColors.onPrimary)
              : done
                  ? Icon(LucideIcons.check, size: 18, color: NaqlColors.success)
                  : Text(label ?? '', style: NaqlText.label.copyWith(color: filled ? NaqlColors.onPrimary : color)),
        ),
        Expanded(child: Container(width: 2, color: last ? Colors.transparent : NaqlColors.border)),
      ]),
    );
  }
}
