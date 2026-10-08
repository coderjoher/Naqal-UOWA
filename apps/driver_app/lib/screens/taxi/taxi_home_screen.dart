import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/run_controller.dart';
import '../../data/taxi.dart';
import '../../l10n/gen/app_localizations.dart';

/// Motion: quick ease-out for things arriving, a little faster ease-in for things leaving.
const _enter = Duration(milliseconds: 240);
const _exit = Duration(milliseconds: 180);
const _easeOut = Cubic(0.165, 0.84, 0.44, 1); // ease-out-quart

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// "4.2" — one decimal, Western digits (as on Iraqi price lists).
String _km(double km) => km.toStringAsFixed(1);

/// TX-04: the taxi driver's home. A big online switch, live offers while online, then one ride
/// from pickup to cash. Everything is sized for use in the car (56 dp+ targets, big numbers).
class TaxiHomeScreen extends ConsumerWidget {
  const TaxiHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final s = ref.watch(taxiControllerProvider);
    final reduce = _reduceMotion(context);

    final Widget body;
    if (s.done != null) {
      body = _DoneView(key: ValueKey('done-${s.done!.id}'), ride: s.done!);
    } else if (s.active != null) {
      body = _ActiveRide(key: ValueKey('ride-${s.active!.id}'), ride: s.active!, busy: s.busy);
    } else if (s.online) {
      body = _OfferList(key: const ValueKey('offers'), offers: s.offers, busy: s.busy);
    } else {
      body = Padding(
        key: const ValueKey('offline'),
        padding: const EdgeInsets.only(top: NaqlSpace.s8),
        child: NaqlEmptyState(icon: LucideIcons.moon, title: t.taxiOfflineTitle, message: t.taxiOfflineBody),
      );
    }

    final idle = s.active == null && s.done == null;
    return Column(
      children: [
        NaqlTopBar(title: t.taxiTitle),
        Expanded(
          child: RefreshIndicator(
            color: NaqlColors.primary,
            onRefresh: () => ref.read(taxiControllerProvider.notifier).refreshOffers(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, 120),
              children: [
                AnimatedSize(
                  duration: reduce ? Duration.zero : _enter,
                  curve: _easeOut,
                  alignment: Alignment.topCenter,
                  child: idle
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: NaqlSpace.s4),
                          child: _OnlineSwitch(online: s.online, switching: s.switching),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                _NoticeBanner(notice: s.notice),
                AnimatedSwitcher(
                  duration: reduce ? Duration.zero : _enter,
                  reverseDuration: reduce ? Duration.zero : _exit,
                  switchInCurve: _easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                  child: body,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The online/offline switch: a wide 88 dp pill whose knob slides across and turns green.
class _OnlineSwitch extends ConsumerWidget {
  const _OnlineSwitch({required this.online, required this.switching});
  final bool online;
  final bool switching;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final reduce = _reduceMotion(context);
    final d = reduce ? Duration.zero : _enter;
    final fg = online ? NaqlColors.onPrimary : NaqlColors.text;
    final title = online ? t.taxiOnline : t.taxiOffline;
    final hint = switching ? t.taxiConnecting : (online ? t.taxiOnlineHint : t.taxiOfflineHint);
    return Semantics(
      toggled: online,
      hint: online ? t.taxiGoOffline : t.taxiGoOnline,
      child: NaqlPressable(
        key: const ValueKey('taxi-online'),
        semanticLabel: title,
        pressedScale: 0.98,
        minSize: 88,
        onPressed: switching
            ? null
            : () {
                HapticFeedback.mediumImpact();
                ref.read(taxiControllerProvider.notifier).toggle();
              },
        child: AnimatedContainer(
          duration: d,
          curve: _easeOut,
          height: 88,
          padding: const EdgeInsets.all(NaqlSpace.s2),
          decoration: BoxDecoration(
            color: online ? NaqlColors.success : NaqlColors.surface,
            borderRadius: BorderRadius.circular(NaqlRadius.pill),
            border: Border.all(color: online ? NaqlColors.success : NaqlColors.border, width: 1.5),
            boxShadow: naqlCardShadow,
          ),
          child: Stack(
            children: [
              // The words sit on the side the knob is not on.
              AnimatedPadding(
                duration: d,
                curve: _easeOut,
                padding: EdgeInsetsDirectional.only(start: online ? NaqlSpace.s5 : 88, end: online ? 88 : NaqlSpace.s5),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: NaqlText.title.copyWith(color: fg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        hint,
                        style: NaqlText.label.copyWith(color: online ? NaqlColors.onPrimary : NaqlColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedAlign(
                duration: d,
                curve: _easeOut,
                alignment: online ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                child: AnimatedContainer(
                  duration: d,
                  curve: _easeOut,
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: online ? NaqlColors.surface : NaqlColors.primary, shape: BoxShape.circle),
                  child: AnimatedOpacity(
                    opacity: switching ? 0.4 : 1,
                    duration: d,
                    child: Icon(LucideIcons.power, size: 32, color: online ? NaqlColors.success : NaqlColors.onPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short message under the switch: another driver was faster, no GPS, taxis off…
class _NoticeBanner extends ConsumerWidget {
  const _NoticeBanner({required this.notice});
  final TaxiNotice? notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final reduce = _reduceMotion(context);
    final n = notice;
    Widget child = const SizedBox(width: double.infinity);
    if (n != null) {
      final (text, tone, icon) = switch (n) {
        TaxiNotice.taken => (t.taxiTaken, NaqlTone.warning, LucideIcons.userCheck),
        TaxiNotice.noLocation => (t.taxiNoLocation, NaqlTone.danger, LucideIcons.mapPinOff),
        TaxiNotice.taxisOff => (t.taxisOff, NaqlTone.warning, LucideIcons.circlePause),
        TaxiNotice.studentCancelled => (t.taxiStudentCancelled, NaqlTone.warning, LucideIcons.circleX),
        TaxiNotice.failed => (t.taxiFailed, NaqlTone.danger, LucideIcons.wifiOff),
      };
      child = Padding(
        key: ValueKey(n),
        padding: const EdgeInsets.only(bottom: NaqlSpace.s4),
        child: Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(NaqlSpace.s4, NaqlSpace.s1, NaqlSpace.s1, NaqlSpace.s1),
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(NaqlRadius.md)),
            child: Row(
              children: [
                Icon(icon, color: tone.fg),
                const SizedBox(width: NaqlSpace.s3),
                Expanded(
                  child: Text(
                    text,
                    style: NaqlText.body.copyWith(color: tone.fg, fontWeight: FontWeight.w500),
                  ),
                ),
                NaqlPressable(
                  semanticLabel: t.taxiDismiss,
                  onPressed: () => ref.read(taxiControllerProvider.notifier).dismissNotice(),
                  child: Icon(LucideIcons.x, size: 20, color: tone.fg),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AnimatedSize(
      duration: reduce ? Duration.zero : _enter,
      curve: _easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(duration: reduce ? Duration.zero : NaqlMotion.fast, child: child),
    );
  }
}

/// Live offers. Cards slide in when they arrive and fold away when taken or expired.
class _OfferList extends ConsumerStatefulWidget {
  const _OfferList({super.key, required this.offers, required this.busy});
  final List<TaxiOffer> offers;
  final String? busy;

  @override
  ConsumerState<_OfferList> createState() => _OfferListState();
}

class _OfferListState extends ConsumerState<_OfferList> {
  /// Shown cards, including ones still animating out.
  final _shown = <TaxiOffer>[];
  final _leaving = <String>{};

  /// When each card first appeared: the countdown ring runs from there to `expiresAt`.
  final _firstSeen = <String, DateTime>{};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _merge();
    // The countdown: one tick a second while there are cards.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _shown.isEmpty) return;
      setState(() {});
      ref.read(taxiControllerProvider.notifier).pruneExpired();
    });
  }

  @override
  void didUpdateWidget(covariant _OfferList old) {
    super.didUpdateWidget(old);
    _merge();
  }

  void _merge() {
    final ids = {for (final o in widget.offers) o.id};
    final now = clock.now();
    for (final o in widget.offers) {
      _firstSeen.putIfAbsent(o.id, () => now);
      final i = _shown.indexWhere((x) => x.id == o.id);
      if (i == -1) {
        _shown.add(o);
      } else {
        _shown[i] = o;
      }
      _leaving.remove(o.id);
    }
    for (final o in _shown) {
      if (!ids.contains(o.id)) _leaving.add(o.id);
    }
  }

  void _gone(String id) {
    if (!mounted || !_leaving.contains(id)) return;
    setState(() {
      _shown.removeWhere((o) => o.id == id);
      _leaving.remove(id);
      _firstSeen.remove(id);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final now = clock.now();
    final visible = _shown.where((o) => !_leaving.contains(o.id)).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: _reduceMotion(context) ? Duration.zero : _enter,
          child: visible
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: NaqlSpace.s6),
                  child: NaqlEmptyState(icon: LucideIcons.radar, title: t.taxiWaitingTitle, message: t.taxiWaitingBody),
                ),
        ),
        for (final o in _shown)
          _Slot(
            key: ValueKey('slot-${o.id}'),
            leaving: _leaving.contains(o.id),
            onGone: () => _gone(o.id),
            child: Padding(
              padding: const EdgeInsets.only(bottom: NaqlSpace.s4),
              child: _OfferCard(offer: o, now: now, firstSeen: _firstSeen[o.id] ?? now, busy: widget.busy == o.id, locked: widget.busy != null),
            ),
          ),
      ],
    );
  }
}

/// Grows and fades a card in; folds and fades it out, then reports [onGone].
class _Slot extends StatefulWidget {
  const _Slot({super.key, required this.child, required this.leaving, required this.onGone});
  final Widget child;
  final bool leaving;
  final VoidCallback onGone;

  @override
  State<_Slot> createState() => _SlotState();
}

class _SlotState extends State<_Slot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: _enter, reverseDuration: _exit);
  late final _curve = CurvedAnimation(parent: _c, curve: _easeOut, reverseCurve: Curves.easeIn);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _c.value = widget.leaving ? 0 : 1;
      if (widget.leaving) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onGone());
    } else if (_c.status == AnimationStatus.dismissed && !widget.leaving) {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _Slot old) {
    super.didUpdateWidget(old);
    if (widget.leaving == old.leaving) return;
    if (widget.leaving) {
      if (_reduceMotion(context)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onGone());
      } else {
        _c.reverse().whenComplete(() => widget.onGone());
      }
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _curve,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(_curve),
          child: IgnorePointer(ignoring: widget.leaving, child: widget.child),
        ),
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer, required this.now, required this.firstSeen, required this.busy, required this.locked});
  final TaxiOffer offer;
  final DateTime now;
  final DateTime firstSeen;
  final bool busy;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final toCampus = offer.direction == TaxiDirection.toCampus;
    final left = offer.expiresAt.difference(now);
    final total = offer.expiresAt.difference(firstSeen);
    return NaqlCard(
      key: ValueKey('offer-${offer.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusPill(label: toCampus ? t.taxiToCampus : t.taxiFromCampus, tone: NaqlTone.primary, icon: toCampus ? LucideIcons.school : LucideIcons.house),
              const Spacer(),
              _CountdownRing(left: left, total: total),
            ],
          ),
          const SizedBox(height: NaqlSpace.s3),
          Text(t.taxiFare, style: NaqlText.label.copyWith(color: NaqlColors.textMuted)),
          Text(
            formatIqd(offer.fare, lang),
            style: NaqlText.display.copyWith(fontSize: 38, height: 1.15, fontWeight: FontWeight.w700),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: NaqlSpace.s3),
          Wrap(
            spacing: NaqlSpace.s5,
            runSpacing: NaqlSpace.s2,
            children: [
              _Fact(icon: LucideIcons.route, text: t.taxiTripKm(_km(offer.distanceKm))),
              if (offer.awayKm != null) _Fact(icon: LucideIcons.mapPin, text: t.taxiAwayKm(_km(offer.awayKm!))),
            ],
          ),
          const SizedBox(height: NaqlSpace.s4),
          NaqlButton(
            key: ValueKey('accept-${offer.id}'),
            label: t.taxiAccept,
            icon: LucideIcons.check,
            size: NaqlButtonSize.large,
            expand: true,
            loading: busy,
            onPressed: locked && !busy ? null : () => ref.read(taxiControllerProvider.notifier).accept(offer.id),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: NaqlColors.textMuted),
      const SizedBox(width: NaqlSpace.s1),
      Text(text, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
    ],
  );
}

/// Seconds left to accept, as a ring that empties (amber in the last 15 s).
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.left, required this.total});
  final Duration left;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final secs = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    final frac = total.inMilliseconds <= 0 ? 0.0 : (left.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final color = secs <= 15 ? NaqlColors.warning : NaqlColors.primary;
    return Semantics(
      label: t.taxiSecondsLeft(secs),
      excludeSemantics: true,
      child: SizedBox(
        width: 52,
        height: 52,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: frac),
          // Glides between the once-a-second ticks.
          duration: _reduceMotion(context) ? Duration.zero : const Duration(seconds: 1),
          builder: (_, v, _) => CustomPaint(
            painter: _RingPainter(value: v, color: color),
            child: Center(
              child: Text(
                '$secs',
                style: NaqlText.label.copyWith(fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = NaqlColors.surfaceMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// The accepted ride: who, where, and the one next step as a big button.
class _ActiveRide extends ConsumerWidget {
  const _ActiveRide({super.key, required this.ride, required this.busy});
  final TaxiRide ride;
  final String? busy;

  Future<bool> _confirm(BuildContext context, {required String title, String? body, required String yes, required String no, bool danger = false}) async {
    final ok = await showNaqlSheet<bool>(
      context,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: NaqlText.title),
          if (body != null) ...[const SizedBox(height: NaqlSpace.s2), Text(body, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))],
          const SizedBox(height: NaqlSpace.s5),
          NaqlButton(label: yes, size: NaqlButtonSize.large, variant: danger ? NaqlButtonVariant.danger : NaqlButtonVariant.primary, expand: true, onPressed: () => Navigator.of(c).pop(true)),
          const SizedBox(height: NaqlSpace.s2),
          NaqlButton(label: no, size: NaqlButtonSize.large, variant: NaqlButtonVariant.secondary, expand: true, onPressed: () => Navigator.of(c).pop(false)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _navigate(WidgetRef ref) async {
    final p = ride.target;
    final open = ref.read(urlLauncherProvider);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!await open(googleMapsNavigation(p.lat, p.lng, android: android)) && android) {
      await open(googleMapsNavigation(p.lat, p.lng, android: false));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final ctl = ref.read(taxiControllerProvider.notifier);
    final toCampus = ride.direction == TaxiDirection.toCampus;
    final amount = formatIqd(ride.fare, lang);
    final (step, stage, icon) = switch (ride.status) {
      'arrived' => (2, t.taxiWaitingStudent, LucideIcons.hourglass),
      'on_trip' => (3, toCampus ? t.taxiOnTripCampus : t.taxiOnTripHome, toCampus ? LucideIcons.school : LucideIcons.house),
      _ => (1, toCampus ? t.taxiGoToStudent : t.taxiGoToGate, LucideIcons.navigation),
    };
    final (label, actionIcon) = switch (ride.status) {
      'arrived' => (t.taxiStartTrip, LucideIcons.play),
      'on_trip' => (t.taxiEndTrip(amount), LucideIcons.banknote),
      _ => (t.taxiArrived, LucideIcons.mapPinCheck),
    };
    final phone = ride.studentPhone;
    void call() => ref.read(urlLauncherProvider)(Uri(scheme: 'tel', path: phone));
    final canCancel = ride.status == 'accepted' || ride.status == 'arrived';
    final stepBusy = busy == 'arrive' || busy == 'start' || busy == 'end';

    return NaqlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepBar(step: step),
          const SizedBox(height: NaqlSpace.s4),
          AnimatedSwitcher(
            duration: _reduceMotion(context) ? Duration.zero : NaqlMotion.fast,
            child: Row(
              key: ValueKey(ride.status),
              children: [
                Icon(icon, size: 22, color: NaqlColors.primary),
                const SizedBox(width: NaqlSpace.s2),
                Expanded(
                  child: Text(stage, style: NaqlText.headline.copyWith(color: NaqlColors.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: NaqlSpace.s3),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: NaqlColors.primarySoft, shape: BoxShape.circle),
                child: Text(ride.studentName.isEmpty ? '?' : ride.studentName.characters.first, style: NaqlText.title.copyWith(color: NaqlColors.primary)),
              ),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.studentName, key: const ValueKey('taxi-student'), style: NaqlText.title.copyWith(fontSize: 26, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (ride.label != null && ride.label!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: NaqlSpace.s1),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.mapPin, size: 16, color: NaqlColors.textMuted),
                            const SizedBox(width: NaqlSpace.s1),
                            Expanded(
                              child: Text(ride.label!, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NaqlSpace.s4),
          Row(
            children: [
              Expanded(
                // Read out as "Call <name>"; the visible label stays short.
                child: Semantics(
                  label: t.taxiCallStudent(ride.studentName),
                  button: true,
                  enabled: phone != null,
                  excludeSemantics: true,
                  onTap: phone == null ? null : call,
                  child: NaqlButton(
                    key: const ValueKey('taxi-call'),
                    label: t.taxiCall,
                    icon: LucideIcons.phone,
                    size: NaqlButtonSize.large,
                    variant: NaqlButtonVariant.secondary,
                    expand: true,
                    onPressed: phone == null ? null : call,
                  ),
                ),
              ),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(
                child: NaqlButton(
                  key: const ValueKey('taxi-navigate'),
                  label: t.navigate,
                  icon: LucideIcons.navigation,
                  size: NaqlButtonSize.large,
                  variant: NaqlButtonVariant.secondary,
                  expand: true,
                  onPressed: () => _navigate(ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: NaqlSpace.s4),
          Container(
            padding: const EdgeInsets.all(NaqlSpace.s4),
            decoration: BoxDecoration(color: NaqlColors.surfaceMuted, borderRadius: BorderRadius.circular(NaqlRadius.md)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.taxiFare, style: NaqlText.caption),
                      Text(
                        amount,
                        style: NaqlText.title.copyWith(fontSize: 26, color: NaqlColors.success, fontWeight: FontWeight.w700),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t.taxiDistance, style: NaqlText.caption),
                    Text(t.taxiKm(_km(ride.distanceKm)), style: NaqlText.headline),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: NaqlSpace.s4),
          NaqlButton(
            key: const ValueKey('taxi-step'),
            label: label,
            icon: actionIcon,
            size: NaqlButtonSize.large,
            expand: true,
            loading: stepBusy,
            onPressed: busy != null && !stepBusy
                ? null
                : () async {
                    if (ride.status == 'on_trip') {
                      final ok = await _confirm(context, title: t.taxiEndConfirmTitle(amount), body: t.taxiEndConfirmBody, yes: t.taxiEndConfirmYes, no: t.taxiNotYet);
                      if (!ok) return;
                    }
                    HapticFeedback.mediumImpact();
                    await ctl.step();
                  },
          ),
          if (canCancel) ...[
            const SizedBox(height: NaqlSpace.s2),
            NaqlButton(
              key: const ValueKey('taxi-cancel'),
              label: t.taxiCancelRide,
              variant: NaqlButtonVariant.ghost,
              size: NaqlButtonSize.large,
              expand: true,
              loading: busy == 'cancel',
              onPressed: busy != null
                  ? null
                  : () async {
                      final ok = await _confirm(context, title: t.taxiCancelConfirmTitle, body: t.taxiCancelConfirmBody, yes: t.taxiCancelYes, no: t.taxiKeepRide, danger: true);
                      if (ok) await ctl.cancel();
                    },
            ),
          ],
        ],
      ),
    );
  }
}

/// Three segments: to pickup → waiting → on the trip.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final d = _reduceMotion(context) ? Duration.zero : _enter;
    return Semantics(
      label: t.taxiStep(step),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++) ...[
            if (i > 1) const SizedBox(width: NaqlSpace.s1),
            Expanded(
              child: AnimatedContainer(
                duration: d,
                curve: _easeOut,
                height: 6,
                decoration: BoxDecoration(color: i <= step ? NaqlColors.primary : NaqlColors.border, borderRadius: BorderRadius.circular(NaqlRadius.pill)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A short success moment with the cash amount, then back to the offers.
class _DoneView extends ConsumerWidget {
  const _DoneView({super.key, required this.ride});
  final TaxiRide ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final reduce = _reduceMotion(context);
    return NaqlCard(
      child: Column(
        children: [
          const SizedBox(height: NaqlSpace.s2),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reduce ? 1 : 0.6, end: 1),
            duration: reduce ? Duration.zero : const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: NaqlColors.successSoft, shape: BoxShape.circle),
              child: const Icon(LucideIcons.circleCheck, size: 52, color: NaqlColors.success),
            ),
          ),
          const SizedBox(height: NaqlSpace.s4),
          Semantics(
            liveRegion: true,
            child: Text(t.taxiDoneTitle, style: NaqlText.title, textAlign: TextAlign.center),
          ),
          const SizedBox(height: NaqlSpace.s4),
          Text(t.taxiCashCollected, style: NaqlText.label.copyWith(color: NaqlColors.textMuted)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reduce ? ride.fare.toDouble() : 0, end: ride.fare.toDouble()),
            duration: reduce ? Duration.zero : NaqlMotion.sheet * 2,
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              formatIqd(v.round(), lang),
              key: const ValueKey('taxi-done-cash'),
              style: NaqlText.display.copyWith(fontSize: 42, height: 1.15, fontWeight: FontWeight.w700, color: NaqlColors.success),
              textDirection: TextDirection.ltr,
            ),
          ),
          const SizedBox(height: NaqlSpace.s2),
          Text(
            t.taxiDoneBody,
            style: NaqlText.body.copyWith(color: NaqlColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NaqlSpace.s5),
          NaqlButton(
            label: t.taxiBackToRequests,
            size: NaqlButtonSize.large,
            variant: NaqlButtonVariant.secondary,
            expand: true,
            onPressed: () => ref.read(taxiControllerProvider.notifier).finishDone(),
          ),
        ],
      ),
    );
  }
}
