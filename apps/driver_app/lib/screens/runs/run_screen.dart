import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/run_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import '../drive_layout.dart';
import 'today_screen.dart';

/// DR-03/04: one run, while driving. A map with a blue instruction card on top; the sheet shows
/// progress, the next stop big with a navigate button, who boards there, and every stop in
/// driving order; one big gold action is pinned at the bottom: start → arrive → board → leave
/// → … → finish. Every row and button is at least 56 dp tall so it can be used in the vehicle.
class RunScreen extends ConsumerWidget {
  const RunScreen({super.key, required this.runId});
  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final view = ref.watch(runControllerProvider(runId)).value;
    void back() => context.canPop() ? context.pop() : context.go('/today');
    if (view == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            NaqlTopBar(title: t.todayRuns, onBack: back, backLabel: MaterialLocalizations.of(context).backButtonTooltip),
            const Padding(padding: EdgeInsets.all(NaqlSpace.s5), child: NaqlSkeleton(height: 200, radius: NaqlRadius.lg)),
          ]),
        ),
      );
    }
    return _RunBody(runId: runId, view: view, lang: lang, onBack: back);
  }
}

class _RunBody extends ConsumerStatefulWidget {
  const _RunBody({required this.runId, required this.view, required this.lang, required this.onBack});
  final String runId;
  final RunView view;
  final String lang;
  final VoidCallback onBack;

  @override
  ConsumerState<_RunBody> createState() => _RunBodyState();
}

class _RunBodyState extends ConsumerState<_RunBody> {
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
    final lang = widget.lang;
    final run = v.base;
    final next = v.nextStop;
    final status = v.status;
    final pending = ref.watch(pendingSyncProvider).value ?? 0;
    final error = ref.watch(runControllerProvider(widget.runId).notifier).lastError;
    final here = v.here == null ? null : LatLng(v.here!.lat, v.here!.lng);
    final served = run.stops.where(v.isServed).length;
    final left = v.waitLeft(clock.now());
    final missing = next != null && v.morning ? next.passengers.where((p) => !v.isBoarded(p) && !v.isNoShow(p)).length : 0;
    final tiles = ref.watch(driverMapTilesProvider);

    // The blue card: what to do next, in as few words as possible.
    final (String headline, String body, IconData icon) = switch (status) {
      'planned' when v.morning => (run.departAt == null ? '—' : formatClock(run.departAt!), next == null ? t.startRun : t.headTo(next.point(lang)), LucideIcons.clock),
      'planned' => (run.departAt == null ? run.waveTime : formatClock(run.departAt!), t.leaveCampus, LucideIcons.school),
      'started' when next != null => (
          here == null ? formatClock(next.eta) : _distance(t, here, LatLng(next.lat, next.lng)),
          t.headTo(next.point(lang)),
          LucideIcons.navigation,
        ),
      'started' => (v.morning ? t.endTitleMorning : t.endTitleReturn, waveName(t, run.waveType, run.waveTime), v.morning ? LucideIcons.school : LucideIcons.circleCheck),
      'at_stop' when next != null => (t.atStop, next.point(lang), LucideIcons.mapPinCheck),
      _ => (waveName(t, run.waveType, run.waveTime), t.runDoneBody, LucideIcons.circleCheck),
    };

    final Widget? action = switch (status) {
      'planned' when v.morning => _BigAction(key: const ValueKey('start'), label: t.startRun, icon: LucideIcons.play, onPressed: () => _ctl.start()),
      'planned' => _BigAction(key: const ValueKey('campus'), label: t.leaveCampusNow, icon: LucideIcons.play, onPressed: () => _ctl.start(boarded: [..._campusBoarded])),
      'started' when next != null => _BigAction(key: ValueKey('arrive-${next.seq}'), label: t.imHere, icon: LucideIcons.check, onPressed: () => _ctl.arrive()),
      'started' => _BigAction(key: const ValueKey('end'), label: v.morning ? t.arrivedCampus : t.finishRun, icon: LucideIcons.flag, onPressed: () => _ctl.end()),
      'at_stop' when next != null => _BigAction(
          key: ValueKey('depart-${next.seq}'),
          label: missing > 0 && left == 0 ? t.departMissing(missing) : t.departStop,
          icon: LucideIcons.arrowRightFromLine,
          quiet: missing > 0 && left == 0,
          onPressed: left > 0 ? null : () => _ctl.depart(),
        ),
      _ => null,
    };

    final riders = switch (status) {
      'planned' when !v.morning => [
          for (final p in v.allPassengers)
            _RiderRow(
              passenger: p,
              lang: lang,
              onBoard: _campusBoarded.contains(p.requestId),
              onTap: () => setState(() => _campusBoarded.contains(p.requestId) ? _campusBoarded.remove(p.requestId) : _campusBoarded.add(p.requestId)),
            ),
        ],
      'at_stop' when next != null && v.morning => [
          for (final p in next.passengers)
            _RiderRow(
              passenger: p,
              lang: lang,
              onBoard: v.isBoarded(p),
              paid: v.isPaid(p),
              onTap: v.isBoarded(p) ? null : () => _ctl.board([p.requestId]),
              onCollect: v.isBoarded(p) && p.fare > 0 && !v.isPaid(p) ? () => _ctl.collectFare(p.requestId) : null,
            ),
        ],
      _ when next != null => [for (final p in next.passengers) _RiderRow(passenger: p, lang: lang, onBoard: v.isBoarded(p), noShow: v.isNoShow(p))],
      _ => <Widget>[],
    };

    final (String caption, String title) = switch (status) {
      'planned' when !v.morning => (waveName(t, run.waveType, run.waveTime), t.campus),
      _ when next != null => ('${t.stopOfTotal(next.seq, '${run.stops.length}')} · ${formatClock(next.eta)}', next.point(lang)),
      _ => (t.runProgress('$served', '${run.stops.length}'), v.morning && status != 'done' ? t.campus : waveName(t, run.waveType, run.waveTime)),
    };

    final points = [
      for (final s in run.stops) DrivePoint(LatLng(s.lat, s.lng), label: s.point(lang), number: '${s.seq}', current: s == next && status != 'done', done: v.isServed(s)),
    ];

    return DriveScaffold(
      onBack: widget.onBack,
      map: DriveMap(points: points, here: here, tiles: tiles, hereLabel: t.bus),
      instruction: AnimatedSwitcher(
        duration: naqlMotion(context),
        child: NaqlInstructionCard(key: ValueKey('$status-${next?.seq}'), icon: icon, headline: headline, body: body),
      ),
      action: action == null
          ? null
          : AnimatedSwitcher(
              duration: naqlMotion(context, NaqlMotion.sheet),
              switchInCurve: naqlEaseOut,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a), child: c)),
              child: action,
            ),
      children: [
        AnimatedSize(
          duration: naqlMotion(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (pending > 0)
              Padding(
                key: const ValueKey('pending'),
                padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
                child: Align(alignment: AlignmentDirectional.centerStart, child: StatusPill(label: t.pendingSync(pending), tone: NaqlTone.warning, icon: LucideIcons.cloudOff)),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
                child: Container(
                  padding: const EdgeInsets.all(NaqlSpace.s3),
                  decoration: BoxDecoration(color: NaqlColors.dangerSoft, borderRadius: BorderRadius.circular(NaqlRadius.sm)),
                  child: Text(error, style: NaqlText.body.copyWith(color: NaqlColors.danger)),
                ),
              ),
          ]),
        ),
        NaqlStepBar(total: run.stops.length, done: served, semanticLabel: t.runProgress('$served', '${run.stops.length}')),
        const SizedBox(height: NaqlSpace.s3),
        Row(children: [
          Expanded(child: DriveHeading(caption: caption, title: title, navigate: next == null || status == 'done' ? null : _NavButton(stop: next))),
        ]),
        if (run.femaleOnly) ...[
          const SizedBox(height: NaqlSpace.s2),
          Align(alignment: AlignmentDirectional.centerStart, child: StatusPill(label: t.femaleOnly, tone: NaqlTone.femaleOnly, icon: LucideIcons.users)),
        ],
        const SizedBox(height: NaqlSpace.s3),
        if (status == 'done')
          NaqlPanel(
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: NaqlColors.successSoft, borderRadius: BorderRadius.circular(NaqlRadius.md)), child: Icon(LucideIcons.circleCheck, color: NaqlColors.success)),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(child: Text(t.runDone, style: NaqlText.title.copyWith(fontSize: 22))),
            ]),
          )
        else ...[
          if (status == 'planned' && !v.morning) Padding(padding: const EdgeInsets.only(bottom: NaqlSpace.s2), child: Text(t.boardAtCampus, style: NaqlText.headline)),
          if (status == 'at_stop' && v.morning && next != null && next.passengers.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: NaqlSpace.s2), child: Text(t.boardHint, style: NaqlText.label.copyWith(color: NaqlColors.textMuted))),
          if (riders.isNotEmpty)
            NaqlPanel(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(children: [
                for (final (i, r) in riders.indexed) ...[if (i > 0) Divider(height: 1, color: NaqlColors.border), r],
              ]),
            )
          else if (next != null)
            Text(t.noRidersHere, style: NaqlText.label.copyWith(color: NaqlColors.textMuted)),
          if (left > 0) ...[
            const SizedBox(height: NaqlSpace.s3),
            Row(children: [
              Icon(LucideIcons.hourglass, size: 18, color: NaqlColors.warning),
              const SizedBox(width: NaqlSpace.s2),
              Text(t.waitLeft(formatCountdown(Duration(seconds: left))), key: const ValueKey('wait'), style: NaqlText.label.copyWith(color: NaqlColors.warning)),
            ]),
          ],
        ],
        const SizedBox(height: NaqlSpace.s6),
        Text(t.stopsTitle, style: NaqlText.headline),
        const SizedBox(height: NaqlSpace.s3),
        if (!v.morning) _CampusRow(label: t.leaveCampus, time: run.waveTime, first: true, last: run.stops.isEmpty, done: status != 'planned'),
        for (final (i, s) in run.stops.indexed)
          StopTile(stop: s, view: v, lang: lang, first: i == 0 && v.morning, last: i == run.stops.length - 1 && !v.morning),
        if (v.morning) _CampusRow(label: t.arriveBy(run.waveTime), time: run.waveTime, first: run.stops.isEmpty, last: true, done: status == 'done'),
      ],
    );
  }

  static String _distance(AppLocalizations t, LatLng from, LatLng to) {
    final (value, metres) = driveDistance(from, to);
    return metres ? t.distanceM(value) : t.distanceKmShort(value);
  }
}

/// The big gold action pinned at the bottom of the sheet (64 dp).
class _BigAction extends StatelessWidget {
  const _BigAction({super.key, required this.label, required this.icon, required this.onPressed, this.quiet = false});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Leaving with someone missing: a calmer button, the driver should think twice.
  final bool quiet;

  @override
  Widget build(BuildContext context) => NaqlButton(
        label: label,
        icon: icon,
        size: NaqlButtonSize.huge,
        expand: true,
        variant: quiet ? NaqlButtonVariant.secondary : NaqlButtonVariant.accent,
        onPressed: onPressed,
      );
}

/// A rider at the stop: initial, name, and a tag (subscriber / cash amount); tap to mark on
/// board, then take the cash for pay-per-ride riders. 56 dp tall.
class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.passenger, required this.lang, required this.onBoard, this.onTap, this.onCollect, this.paid = false, this.noShow = false});
  final RunPassenger passenger;
  final String lang;
  final bool onBoard;
  final VoidCallback? onTap;
  final VoidCallback? onCollect;
  final bool paid;
  final bool noShow;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = passenger;
    final amount = formatIqd(p.fare, lang).split(' ').first;
    final Widget tag = onBoard && p.fare > 0
        ? (paid
            ? NaqlTag(t.paidLabel, tone: NaqlTone.success, icon: LucideIcons.banknote)
            : NaqlButton(key: ValueKey('fare-${p.requestId}'), label: t.collectFare(formatIqd(p.fare, lang)), variant: NaqlButtonVariant.secondary, onPressed: onCollect))
        : onBoard
            ? NaqlTag(t.onBoard, tone: NaqlTone.success, icon: LucideIcons.check)
            : noShow
                ? NaqlTag(t.noShowLabel)
                : (p.subscriber && p.fare == 0 ? NaqlTag(t.subscriber, tone: NaqlTone.success) : NaqlTag(t.riderCash(amount), tone: NaqlTone.accent));
    return NaqlPressable(
      onPressed: onTap,
      semanticLabel: p.name,
      pressedScale: 0.98,
      child: AnimatedContainer(
        key: ValueKey('rider-${p.requestId}'),
        duration: naqlMotion(context),
        curve: naqlEaseOut,
        constraints: const BoxConstraints(minHeight: NaqlTouch.driver + 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: NaqlSpace.s2),
        color: onBoard ? NaqlColors.successSoft.withValues(alpha: 0.6) : null,
        child: Row(children: [
          AnimatedSwitcher(
            duration: naqlMotion(context),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Container(
              key: ValueKey(onBoard),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: onBoard ? NaqlColors.success : NaqlColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
              child: onBoard
                  ? Icon(LucideIcons.check, size: 20, color: naqlIsDark ? NaqlColors.bg : NaqlColors.onPrimary)
                  : Text(p.name.trim().isEmpty ? '' : p.name.trim().characters.first, style: NaqlText.label.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: NaqlSpace.s3),
          Expanded(child: Text(p.name, style: NaqlText.body.copyWith(fontWeight: FontWeight.w500))),
          const SizedBox(width: NaqlSpace.s2),
          tag,
        ]),
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
    return NavigateButton(
      key: const ValueKey('navigate'),
      label: t.openNavigation,
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
              duration: naqlMotion(context, NaqlMotion.sheet),
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
                          duration: naqlMotion(context, NaqlMotion.fast),
                          child: Icon(LucideIcons.chevronDown, size: 20, color: NaqlColors.textMuted),
                        ),
                      ]),
                    ),
                  ),
                  AnimatedSize(
                    duration: naqlMotion(context, NaqlMotion.sheet),
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
          duration: naqlMotion(context, NaqlMotion.sheet),
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
