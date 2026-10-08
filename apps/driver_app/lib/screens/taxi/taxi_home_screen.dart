import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/run_controller.dart';
import '../../data/taxi.dart';
import '../../l10n/gen/app_localizations.dart';
import '../drive_layout.dart';
import '../home_header.dart';

/// Motion: quick ease-out for things arriving, a little faster ease-in for things leaving.
const _enter = Duration(milliseconds: 240);
const _exit = Duration(milliseconds: 180);
const _easeOut = naqlEaseOut;

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// "4.2" — one decimal, Western digits (as on Iraqi price lists).
String _km(double km) => km.toStringAsFixed(1);

/// TX-04: the taxi driver's Home. Greeting and plate, a huge online switch, today's figures,
/// and live offers while online. An accepted ride takes the whole screen (map, instruction,
/// one big gold step), then a short "done" moment with the cash. 56 dp+ targets throughout.
class TaxiHomeScreen extends ConsumerWidget {
  const TaxiHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(taxiControllerProvider);
    final reduce = _reduceMotion(context);
    final Widget body;
    if (s.done != null) {
      body = _DoneView(key: ValueKey('done-${s.done!.id}'), ride: s.done!);
    } else if (s.active != null) {
      body = _TaxiDrive(key: ValueKey('ride-${s.active!.id}'), ride: s.active!, busy: s.busy);
    } else {
      body = _Idle(key: const ValueKey('idle'), state: s);
    }
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : _enter,
      reverseDuration: reduce ? Duration.zero : _exit,
      switchInCurve: _easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: body,
    );
  }
}

/// No ride: the switch, the figures and the offers.
class _Idle extends ConsumerWidget {
  const _Idle({super.key, required this.state});
  final TaxiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final s = state;
    final on = s.online;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: NaqlColors.primary,
        onRefresh: () async {
          ref.invalidate(taxiHistoryProvider);
          await ref.read(taxiControllerProvider.notifier).refreshOffers();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s5, NaqlSpace.s4, 120),
          children: [
            DriverHomeHeader(service: t.taxiTitle),
            const SizedBox(height: 14),
            NaqlToggleCard(
              key: const ValueKey('taxi-online'),
              on: on,
              title: on ? t.taxiOnline : t.taxiOffline,
              subtitle: s.switching ? t.taxiConnecting : (on ? t.taxiOnlineSub : t.taxiOfflineHint),
              cta: t.taxiGoOnline,
              watermark: t.watermarkOn,
              busy: s.switching,
              semanticHint: on ? t.taxiGoOffline : t.taxiGoOnline,
              onTap: s.switching
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      ref.read(taxiControllerProvider.notifier).toggle();
                    },
            ),
            const SizedBox(height: 14),
            const _TaxiKpis(),
            const SizedBox(height: NaqlSpace.s4),
            _NoticeBanner(notice: s.notice),
            AnimatedSwitcher(
              duration: _reduceMotion(context) ? Duration.zero : _enter,
              switchInCurve: _easeOut,
              child: on
                  ? _OfferList(key: const ValueKey('offers'), offers: s.offers, busy: s.busy)
                  : Padding(
                      key: const ValueKey('offline'),
                      padding: const EdgeInsets.only(top: NaqlSpace.s4),
                      child: NaqlEmptyState(icon: LucideIcons.moon, title: t.taxiOfflineTitle, message: t.taxiOfflineBody),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's taxi trips and cash, and this month's trips, from the driver's own history.
class _TaxiKpis extends ConsumerWidget {
  const _TaxiKpis();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final h = ref.watch(taxiHistoryProvider).value;
    final now = clock.now().toUtc().add(const Duration(hours: 3));
    bool today(DateTime? d) {
      if (d == null) return false;
      final b = d.toUtc().add(const Duration(hours: 3));
      return b.year == now.year && b.month == now.month && b.day == now.day;
    }

    final done = h?.rides.where((r) => r.status == 'done' && today(r.endedAt)).toList();
    return KpiRow(
      tiles: [
        NaqlKpiTile(label: t.kpiTaxiToday, value: done == null ? '—' : '${done.length}'),
        NaqlKpiTile(label: t.kpiCash, value: done == null ? '—' : formatIqd(done.fold(0, (n, r) => n + r.fare), lang).split(' ').first, small: true),
        NaqlKpiTile(label: t.kpiMonth, value: h == null ? '—' : '${h.trips}'),
      ],
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
              ? Padding(
                  padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
                  child: Row(
                    children: [Expanded(child: Text(t.taxiNewRequest, style: NaqlText.headline.copyWith(fontSize: 17)))],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: NaqlSpace.s5),
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
    final secs = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    final frac = total.inMilliseconds <= 0 ? 0.0 : left.inMilliseconds / total.inMilliseconds;
    final fare = formatIqd(offer.fare, lang);
    final dir = toCampus ? t.taxiToCampus : t.taxiFromCampus;
    return Container(
      key: ValueKey('offer-${offer.id}'),
      padding: const EdgeInsets.all(NaqlSpace.s4),
      decoration: BoxDecoration(
        color: NaqlColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: naqlSelectColor, width: 1.5),
        boxShadow: naqlCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NaqlCountdownRing(seconds: secs, fraction: frac, semanticLabel: t.taxiSecondsLeft(secs)),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(toCampus ? LucideIcons.school : LucideIcons.house, size: 15, color: NaqlColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          dir,
                          style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400),
                        ),
                        Text(' · ', style: NaqlText.label.copyWith(color: NaqlColors.textMuted)),
                        Text(
                          t.taxiTripKm(_km(offer.distanceKm)),
                          style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                    if (offer.awayKm != null) Text(t.taxiAwayKm(_km(offer.awayKm!)), style: NaqlText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: NaqlSpace.s2),
              Text(
                fare,
                style: NaqlText.title.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
          const SizedBox(height: NaqlSpace.s3),
          Row(
            children: [
              Expanded(
                child: NaqlButton(
                  key: ValueKey('accept-${offer.id}'),
                  label: t.taxiAccept,
                  // The whole offer is read out on the button, with the time left.
                  semanticLabel: '${t.taxiSecondsLeft(secs)}، $dir، ${t.taxiTripKm(_km(offer.distanceKm))}، $fare، ${t.taxiAccept}',
                  size: NaqlButtonSize.huge,
                  expand: true,
                  loading: busy,
                  onPressed: locked && !busy ? null : () => ref.read(taxiControllerProvider.notifier).accept(offer.id),
                ),
              ),
              const SizedBox(width: 10),
              NaqlIconButton(
                key: ValueKey('skip-${offer.id}'),
                icon: LucideIcons.x,
                semanticLabel: t.taxiSkipOffer,
                size: 64,
                onPressed: locked ? null : () => ref.read(taxiControllerProvider.notifier).skip(offer.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The accepted ride, full screen while driving: where to go (blue card), the map, the step
/// bar, the student, call and navigate, the fare, and the one next step as a big gold button.
class _TaxiDrive extends ConsumerWidget {
  const _TaxiDrive({super.key, required this.ride, required this.busy});
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
      _ => (t.taxiArrived, LucideIcons.check),
    };
    final phone = ride.studentPhone;
    void call() => ref.read(urlLauncherProvider)(Uri(scheme: 'tel', path: phone));
    final canCancel = ride.status == 'accepted' || ride.status == 'arrived';
    final stepBusy = busy == 'arrive' || busy == 'start' || busy == 'end';
    final spot = ride.label?.isNotEmpty == true ? ride.label! : t.pickupPlace;
    final pickup = DrivePoint(LatLng(ride.pickup.lat, ride.pickup.lng), label: t.pickupPlace, current: ride.status != 'on_trip');
    final dropoff = DrivePoint(LatLng(ride.dropoff.lat, ride.dropoff.lng), label: t.dropoffPlace, current: ride.status == 'on_trip', done: false);

    return DriveScaffold(
      map: DriveMap(points: [pickup, dropoff], tiles: ref.watch(driverMapTilesProvider), hereLabel: t.taxi),
      instruction: AnimatedSwitcher(
        duration: _reduceMotion(context) ? Duration.zero : NaqlMotion.fast,
        child: NaqlInstructionCard(key: ValueKey(ride.status), icon: icon, headline: stage, body: ride.status == 'on_trip' ? (toCampus ? t.campus : spot) : spot),
      ),
      action: NaqlButton(
        key: const ValueKey('taxi-step'),
        label: label,
        icon: actionIcon,
        size: NaqlButtonSize.huge,
        variant: NaqlButtonVariant.accent,
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
      children: [
        NaqlStepBar(total: 3, done: step, semanticLabel: t.taxiStep(step)),
        const SizedBox(height: NaqlSpace.s3),
        DriveHeading(
          caption: '${t.taxiStep(step)} · ${t.taxiKm(_km(ride.distanceKm))}',
          title: ride.studentName,
          navigate: NavigateButton(key: const ValueKey('taxi-navigate'), label: t.navigate, onPressed: () => _navigate(ref)),
        ),
        const SizedBox(height: NaqlSpace.s3),
        NaqlPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NaqlTripTimeline(
                dense: true,
                stops: [
                  NaqlTimelineStop(title: toCampus ? spot : t.campus),
                  NaqlTimelineStop(title: toCampus ? t.campus : spot),
                ],
              ),
              const SizedBox(height: NaqlSpace.s2),
              NaqlSummaryRow(label: t.taxiFare, value: amount, icon: LucideIcons.banknote),
            ],
          ),
        ),
        const SizedBox(height: NaqlSpace.s3),
        // Read out as "Call <name>"; the visible label stays short.
        Semantics(
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
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NaqlSpace.s4),
          child: NaqlCard(
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
                    decoration: BoxDecoration(color: NaqlColors.successSoft, shape: BoxShape.circle),
                    child: Icon(LucideIcons.circleCheck, size: 52, color: NaqlColors.success),
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
          ),
        ),
      ),
    );
  }
}
