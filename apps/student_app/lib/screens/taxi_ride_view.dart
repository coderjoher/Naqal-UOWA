import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/taxi.dart';
import '../data/track.dart';
import '../l10n/gen/app_localizations.dart';
import 'live_ride.dart';
import 'receipt.dart';
import 'ride_cards.dart';
import 'taxi_widgets.dart';

/// A booked taxi ride, live: searching → accepted → arrived → on trip → done (or expired /
/// cancelled). One view per phase; the map stays in place across the driving phases.
class TaxiRideView extends ConsumerWidget {
  const TaxiRideView({super.key, required this.rideId, required this.onRetry, required this.onHome, required this.title, required this.backLabel});
  final String rideId;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  /// Screen title and back label: shown in the top bar, or floating over the map while driving.
  final String title;
  final String backLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final ride = ref.watch(taxiRideProvider(rideId));
    Widget framed(Key key, Widget child) => TaxiBarFrame(key: key, title: title, onBack: onHome, child: child);
    final Widget child = ride.when(
      loading: () => framed(
        const ValueKey('loading'),
        const Padding(
          padding: EdgeInsets.all(NaqlSpace.s5),
          child: NaqlSkeleton(height: 320, radius: NaqlRadius.lg),
        ),
      ),
      error: (e, _) => framed(
        const ValueKey('error'),
        Center(
          child: NaqlEmptyState(
            icon: LucideIcons.wifiOff,
            title: t.loadFailed,
            action: NaqlButton(label: t.retry, onPressed: () => ref.invalidate(taxiRideProvider(rideId))),
          ),
        ),
      ),
      data: (r) => switch (r.status) {
        TaxiStatus.requested => framed(const ValueKey('searching'), _Searching(ride: r, onCancel: () => _cancel(context, ref, r))),
        TaxiStatus.accepted ||
        TaxiStatus.arrived ||
        TaxiStatus.onTrip => _Active(key: const ValueKey('active'), ride: r, title: title, backLabel: backLabel, onBack: onHome, onCancel: () => _cancel(context, ref, r)),
        TaxiStatus.done => framed(const ValueKey('done'), _Done(ride: r, onHome: onHome)),
        TaxiStatus.expired || TaxiStatus.cancelled => framed(ValueKey('ended-${r.status.name}'), _Ended(ride: r, onRetry: onRetry, onHome: onHome)),
      },
    );
    return AnimatedSwitcher(
      duration: motion(context, NaqlMotion.sheet),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
          child: c,
        ),
      ),
      child: child,
    );
  }

  /// While a driver is coming, ask first; while still searching, cancel straight away.
  Future<void> _cancel(BuildContext context, WidgetRef ref, TaxiRide r) async {
    final t = AppLocalizations.of(context);
    if (r.status != TaxiStatus.requested) {
      final yes = await showNaqlSheet<bool>(
        context,
        builder: (c) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.taxiCancelTitle, style: NaqlText.title),
            const SizedBox(height: NaqlSpace.s2),
            Text(t.taxiCancelBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
            const SizedBox(height: NaqlSpace.s5),
            NaqlButton(label: t.taxiCancelYes, variant: NaqlButtonVariant.danger, expand: true, onPressed: () => Navigator.of(c).pop(true)),
            const SizedBox(height: NaqlSpace.s2),
            NaqlButton(label: t.taxiKeep, variant: NaqlButtonVariant.secondary, expand: true, onPressed: () => Navigator.of(c).pop(false)),
          ],
        ),
      );
      if (yes != true) return;
    }
    try {
      await ref.read(apiProvider).cancelTaxi(r.id);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, t.loadFailed))));
    }
    ref.invalidate(taxiRideProvider(r.id));
    ref.invalidate(taxiMineProvider);
  }
}

class _Searching extends StatelessWidget {
  const _Searching({required this.ride, required this.onCancel});
  final TaxiRide ride;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s4, NaqlSpace.s5, NaqlSpace.s6),
      children: [
        Center(
          child: TaxiRadar(child: Icon(LucideIcons.carTaxiFront, color: naqlIsDark ? NaqlColors.onInk : NaqlColors.onPrimary, size: 32)),
        ),
        const SizedBox(height: NaqlSpace.s4),
        Semantics(
          liveRegion: true,
          child: Text(t.taxiSearching, style: NaqlText.title, textAlign: TextAlign.center),
        ),
        const SizedBox(height: NaqlSpace.s2),
        Text(
          t.taxiSearchingBody,
          style: NaqlText.body.copyWith(color: NaqlColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: NaqlSpace.s5),
        Center(child: Text(t.taxiTimeLeft, style: NaqlText.caption)),
        Center(
          child: TaxiCountdown(until: ride.expiresAt, style: NaqlText.display, semanticPrefix: t.taxiTimeLeft),
        ),
        const SizedBox(height: NaqlSpace.s5),
        _RideSummary(ride: ride),
        const SizedBox(height: NaqlSpace.s5),
        NaqlButton(label: t.taxiCancel, variant: NaqlButtonVariant.secondary, icon: LucideIcons.x, expand: true, onPressed: onCancel),
      ],
    );
  }
}

/// From → to on a trip timeline, then the distance and the cash fare as summary rows.
class _RideSummary extends ConsumerWidget {
  const _RideSummary({required this.ride});
  final TaxiRide ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    return NaqlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RideTimeline(ride: ride),
          const SizedBox(height: NaqlSpace.s3),
          NaqlSummaryRow(label: t.taxiDistance, value: t.taxiKm(formatKm(ride.distanceKm))),
          NaqlSummaryRow(label: t.taxiCash, value: formatIqd(ride.fare, lang), total: true),
        ],
      ),
    );
  }
}

/// Pickup (ring) → drop-off (gold dot), named the way the student set them.
class _RideTimeline extends StatelessWidget {
  const _RideTimeline({required this.ride});
  final TaxiRide ride;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final toCampus = ride.direction == TaxiDirection.toCampus;
    final spot = ride.label?.isNotEmpty == true ? ride.label! : t.taxiYourSpot;
    return NaqlTripTimeline(
      accentEnd: true,
      stops: [
        NaqlTimelineStop(subtitle: t.taxiPickupPin, title: toCampus ? spot : t.taxiCampus),
        NaqlTimelineStop(subtitle: t.taxiDropoffPin, title: toCampus ? t.taxiCampus : spot),
      ],
    );
  }
}

class _Active extends ConsumerWidget {
  const _Active({super.key, required this.ride, required this.title, required this.backLabel, required this.onBack, required this.onCancel});
  final TaxiRide ride;
  final String title;
  final String backLabel;
  final VoidCallback onBack;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final tiles = ref.watch(mapTilesProvider);
    final (headline, _, _) = taxiStatusLine(t, ride);
    final eta = ride.status == TaxiStatus.arrived ? null : ride.etaMin;
    final driver = ride.driver;
    final dial = ref.read(taxiDialerProvider);
    final step = switch (ride.status) {
      TaxiStatus.accepted => 0,
      TaxiStatus.arrived => 1,
      _ => 2,
    };
    final steps = [t.taxiStepAccepted, t.taxiStepArrived, t.taxiStepOnTrip, t.taxiStepDone];
    final subtitle = switch (ride.status) {
      TaxiStatus.arrived => t.taxiArrivedBody,
      _ when ride.label?.isNotEmpty == true => ride.label!,
      _ => null,
    };
    final toCampus = ride.direction == TaxiDirection.toCampus;
    final spot = ride.label?.isNotEmpty == true ? ride.label! : t.taxiYourSpot;
    final phone = driver?.phone;

    return Stack(
      children: [
        Positioned.fill(
          child: _RideMap(ride: ride, tiles: tiles, attributionBottom: MediaQuery.sizeOf(context).height * 0.6),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LiveTopBar(
            onBack: onBack,
            center: eta == null ? null : NaqlLivePill(key: const ValueKey('taxi-eta'), label: t.taxiMinutes(eta), semanticLabel: t.taxiAway(eta), floating: true),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LiveBottom(
            children: [
              NaqlPanel(
                floating: true,
                radius: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: motion(context, NaqlMotion.fast),
                        layoutBuilder: (cur, prev) => Stack(alignment: AlignmentDirectional.topStart, children: [...prev, ?cur]),
                        child: Column(
                          key: ValueKey(ride.status),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(headline, style: NaqlText.title),
                            if (subtitle != null)
                              Text(
                                subtitle,
                                style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: NaqlSpace.s4),
                    TaxiStepper(steps: steps, current: step, semanticLabel: t.taxiStepOf(step + 1, steps[step])),
                  ],
                ),
              ),
              if (driver != null)
                LiveDriverPanel(
                  name: driver.name,
                  vehicleCaption: t.liveYourTaxi,
                  vehicleTitle: t.liveTaxiName,
                  vehicleSub: t.taxiKm(formatKm(ride.distanceKm)),
                  plate: driver.plate,
                  plateLabel: driver.plate == null ? null : t.taxiPlate(driver.plate!),
                  callKey: const ValueKey('taxi-call'),
                  onCall: phone == null ? null : () => dial(Uri(scheme: 'tel', path: phone)),
                  onMessage: phone == null ? null : () => dial(Uri(scheme: 'sms', path: phone)),
                ),
              LiveRoutePanel(
                stops: [
                  NaqlTimelineStop(title: toCampus ? spot : t.taxiCampus),
                  NaqlTimelineStop(title: toCampus ? t.taxiCampus : spot),
                ],
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: NaqlSpace.s2),
                    NaqlSummaryRow(label: t.taxiCash, value: formatIqd(ride.fare, lang), icon: LucideIcons.banknote),
                    if (ride.status.canCancel) NaqlButton(label: t.taxiCancel, variant: NaqlButtonVariant.secondary, expand: true, onPressed: onCancel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pickup, drop-off and the moving taxi.
class _RideMap extends StatelessWidget {
  const _RideMap({required this.ride, required this.tiles, this.attributionBottom = 0});
  final TaxiRide ride;
  final bool tiles;

  /// Keeps the map credit above a sheet that overlaps the map's bottom edge.
  final double attributionBottom;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pickup = ride.pickup ?? ride.point;
    final dropoff = ride.dropoff;
    final taxi = ride.taxi;
    final pts = [pickup, ?dropoff, ?taxi];
    final toCampus = ride.direction == TaxiDirection.toCampus;
    return Stack(
      children: [
        const Positioned.fill(child: NaqlMapBackdrop()),
        Positioned.fill(
          child: FlutterMap(
            key: const ValueKey('taxi-ride-map'),
            options: MapOptions(
              backgroundColor: const Color(0x00000000),
              initialCameraFit: pts.length > 1 ? CameraFit.coordinates(coordinates: pts, padding: EdgeInsets.fromLTRB(56, 120, 56, 56 + attributionBottom), maxZoom: 16) : null,
              initialCenter: pickup,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              if (tiles)
                NaqlMapTint(
                  child: TileLayer(urlTemplate: mapTilesUrl, userAgentPackageName: 'iq.edu.uowa.naql.student'),
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pickup,
                    width: 44,
                    height: 44,
                    child: TaxiMapPin(
                      key: const ValueKey('taxi-pickup-pin'),
                      icon: toCampus ? LucideIcons.mapPin : LucideIcons.school,
                      label: t.taxiPickupPin,
                      color: NaqlColors.ink,
                      onColor: NaqlColors.onInk,
                    ),
                  ),
                  if (dropoff != null)
                    Marker(
                      point: dropoff,
                      width: 44,
                      height: 44,
                      child: TaxiMapPin(
                        key: const ValueKey('taxi-dropoff-pin'),
                        icon: toCampus ? LucideIcons.school : LucideIcons.house,
                        label: t.taxiDropoffPin,
                        color: NaqlColors.accent,
                        onColor: NaqlColors.onAccent,
                      ),
                    ),
                ],
              ),
              if (taxi != null)
                TweenAnimationBuilder<LatLng>(
                  // The taxi glides to each new position instead of jumping.
                  tween: LatLngTween(begin: taxi, end: taxi),
                  duration: motion(context, const Duration(milliseconds: 900)),
                  curve: Curves.easeOutCubic,
                  builder: (_, p, _) => MarkerLayer(
                    markers: [
                      Marker(
                        point: p,
                        width: 48,
                        height: 48,
                        child: TaxiMapPin(
                          key: const ValueKey('taxi-car-pin'),
                          icon: LucideIcons.carTaxiFront,
                          label: t.taxiCarPin,
                          color: naqlIsDark ? NaqlColors.accent : NaqlColors.primary,
                          onColor: naqlIsDark ? NaqlColors.onAccent : NaqlColors.onPrimary,
                          square: true,
                        ),
                      ),
                    ],
                  ),
                ),
              if (tiles) TaxiAttribution(text: mapAttribution, bottom: attributionBottom),
            ],
          ),
        ),
      ],
    );
  }
}

/// The finished ride as a receipt, with the one thing to do now on top: pay the driver.
class _Done extends ConsumerWidget {
  const _Done({required this.ride, required this.onHome});
  final TaxiRide ride;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final toCampus = ride.direction == TaxiDirection.toCampus;
    final spot = ride.label?.isNotEmpty == true ? ride.label! : t.taxiYourSpot;
    final from = toCampus ? spot : t.taxiCampus;
    final to = toCampus ? t.taxiCampus : spot;
    final ended = ride.endedAt;
    final plate = ride.driver?.plate;
    return RideReceipt(
      kind: NaqlVehicleKind.taxi,
      title: t.liveTaxiName,
      subtitle: ended == null ? null : '${formatDayMonth(ended, lang)} · ${formatClock(ended)}',
      plate: plate,
      plateLabel: plate == null ? null : t.taxiPlate(plate),
      watermark: t.receiptTaxiWord,
      driverName: ride.driver?.name,
      highlight: Container(
        padding: const EdgeInsets.all(NaqlSpace.s4),
        decoration: BoxDecoration(
          color: NaqlColors.accentSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: NaqlColors.accent.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: NaqlColors.successSoft, shape: BoxShape.circle),
              child: Icon(LucideIcons.circleCheckBig, color: NaqlColors.success, size: 26),
            ),
            const SizedBox(width: NaqlSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(liveRegion: true, child: Text(t.taxiDone, style: NaqlText.headline)),
                  Text(
                    t.taxiPayCash(formatIqd(ride.fare, lang)),
                    key: const ValueKey('taxi-pay'),
                    style: NaqlText.label.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      tripTitle: t.receiptTrip(from, to),
      stops: [
        NaqlTimelineStop(title: from),
        NaqlTimelineStop(title: to, time: ended == null ? null : formatClock(ended)),
      ],
      paymentTitle: t.taxiCash,
      lines: [(t.taxiDistance, t.taxiKm(formatKm(ride.distanceKm)))],
      total: formatIqd(ride.fare, lang),
      bottom: NaqlButton(label: t.taxiBackHome, expand: true, onPressed: onHome),
    );
  }
}

class _Ended extends StatelessWidget {
  const _Ended({required this.ride, required this.onRetry, required this.onHome});
  final TaxiRide ride;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final expired = ride.status == TaxiStatus.expired;
    final title = expired ? t.taxiExpired : (ride.cancelledBy == 'student' ? t.taxiCancelledByYou : t.taxiCancelledOther);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NaqlSpace.s6),
        child: NaqlEmptyState(
          icon: expired ? LucideIcons.clock : LucideIcons.circleX,
          title: title,
          message: expired ? t.taxiExpiredBody : t.taxiCancelledBody,
          action: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NaqlButton(label: t.taxiTryAgain, icon: LucideIcons.rotateCcw, expand: true, onPressed: onRetry),
              const SizedBox(height: NaqlSpace.s2),
              NaqlButton(label: t.taxiBackHome, variant: NaqlButtonVariant.ghost, expand: true, onPressed: onHome),
            ],
          ),
        ),
      ),
    );
  }
}
