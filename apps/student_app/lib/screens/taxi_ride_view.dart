import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/taxi.dart';
import '../data/track.dart';
import '../l10n/gen/app_localizations.dart';
import 'taxi_card.dart';
import 'taxi_widgets.dart';

/// A booked taxi ride, live: searching → accepted → arrived → on trip → done (or expired /
/// cancelled). One view per phase; the map stays in place across the driving phases.
class TaxiRideView extends ConsumerWidget {
  const TaxiRideView({super.key, required this.rideId, required this.onRetry, required this.onHome});
  final String rideId;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final ride = ref.watch(taxiRideProvider(rideId));
    final Widget child = ride.when(
      loading: () => const Padding(
        key: ValueKey('loading'),
        padding: EdgeInsets.all(NaqlSpace.s5),
        child: NaqlSkeleton(height: 320, radius: NaqlRadius.lg),
      ),
      error: (e, _) => Center(
        key: const ValueKey('error'),
        child: NaqlEmptyState(
          icon: LucideIcons.wifiOff,
          title: t.loadFailed,
          action: NaqlButton(label: t.retry, onPressed: () => ref.invalidate(taxiRideProvider(rideId))),
        ),
      ),
      data: (r) => switch (r.status) {
        TaxiStatus.requested => _Searching(key: const ValueKey('searching'), ride: r, onCancel: () => _cancel(context, ref, r)),
        TaxiStatus.accepted || TaxiStatus.arrived || TaxiStatus.onTrip => _Active(key: const ValueKey('active'), ride: r, onCancel: () => _cancel(context, ref, r)),
        TaxiStatus.done => _Done(key: const ValueKey('done'), ride: r, onHome: onHome),
        TaxiStatus.expired || TaxiStatus.cancelled => _Ended(key: ValueKey('ended-${r.status.name}'), ride: r, onRetry: onRetry, onHome: onHome),
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
  const _Searching({super.key, required this.ride, required this.onCancel});
  final TaxiRide ride;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s4, NaqlSpace.s5, NaqlSpace.s6),
      children: [
        const Center(
          child: TaxiRadar(child: Icon(LucideIcons.carTaxiFront, color: NaqlColors.onPrimary, size: 32)),
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

/// From → to, the distance and the cash fare, in a quiet nested card.
class _RideSummary extends ConsumerWidget {
  const _RideSummary({required this.ride});
  final TaxiRide ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final toCampus = ride.direction == TaxiDirection.toCampus;
    final spot = ride.label?.isNotEmpty == true ? ride.label! : t.taxiYourSpot;
    return NaqlCard(
      nested: true,
      padding: const EdgeInsets.all(NaqlSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Leg(icon: LucideIcons.mapPin, text: toCampus ? spot : t.taxiCampus),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 9),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(width: 2, height: 14, color: NaqlColors.border),
            ),
          ),
          _Leg(icon: toCampus ? LucideIcons.school : LucideIcons.house, text: toCampus ? t.taxiCampus : spot),
          const Divider(height: NaqlSpace.s6, color: NaqlColors.border),
          Row(
            children: [
              Expanded(
                child: Text(t.taxiKm(formatKm(ride.distanceKm)), style: NaqlText.label.copyWith(color: NaqlColors.textMuted)),
              ),
              Text(formatIqd(ride.fare, lang), style: NaqlText.headline),
            ],
          ),
        ],
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: NaqlColors.primary),
      const SizedBox(width: NaqlSpace.s3),
      Expanded(
        child: Text(text, style: NaqlText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

class _Active extends ConsumerWidget {
  const _Active({super.key, required this.ride, required this.onCancel});
  final TaxiRide ride;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final tiles = ref.watch(mapTilesProvider);
    final (headline, tone, icon) = taxiStatusLine(t, ride);
    final eta = ride.status == TaxiStatus.arrived ? null : ride.etaMin;
    final driver = ride.driver;
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

    return LayoutBuilder(
      builder: (context, box) => Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NaqlRadius.lg),
                child: _RideMap(ride: ride, tiles: tiles),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.62),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s4, NaqlSpace.s5, NaqlSpace.s5),
              child: NaqlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
                          child: Icon(icon, color: tone.fg),
                        ),
                        const SizedBox(width: NaqlSpace.s3),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: AnimatedSwitcher(
                              duration: motion(context, NaqlMotion.fast),
                              layoutBuilder: (cur, prev) => Stack(alignment: AlignmentDirectional.centerStart, children: [...prev, ?cur]),
                              child: Column(
                                key: ValueKey(ride.status),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(headline, style: NaqlText.headline),
                                  if (subtitle != null)
                                    Text(
                                      subtitle,
                                      style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (eta != null) ...[
                          const SizedBox(width: NaqlSpace.s2),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                t.taxiMinutes(eta),
                                key: const ValueKey('taxi-eta'),
                                style: NaqlText.title.copyWith(color: NaqlColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: NaqlSpace.s5),
                    TaxiStepper(steps: steps, current: step, semanticLabel: t.taxiStepOf(step + 1, steps[step])),
                    if (driver != null) ...[
                      const Divider(height: NaqlSpace.s8, color: NaqlColors.border),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: NaqlColors.primarySoft, shape: BoxShape.circle),
                            child: ExcludeSemantics(
                              child: Text(driver.name.isEmpty ? '?' : driver.name.characters.first, style: NaqlText.headline.copyWith(color: NaqlColors.primary)),
                            ),
                          ),
                          const SizedBox(width: NaqlSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driver.name, style: NaqlText.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (driver.plate != null) ...[const SizedBox(height: 2), _Plate(plate: driver.plate!, semantic: t.taxiPlate(driver.plate!))],
                              ],
                            ),
                          ),
                          if (driver.phone != null)
                            NaqlIconButton(
                              key: const ValueKey('taxi-call'),
                              icon: LucideIcons.phone,
                              semanticLabel: t.taxiCall,
                              onPressed: () => ref.read(taxiDialerProvider)(Uri(scheme: 'tel', path: driver.phone)),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: NaqlSpace.s4),
                    Row(
                      children: [
                        const Icon(LucideIcons.banknote, size: 20, color: NaqlColors.textMuted),
                        const SizedBox(width: NaqlSpace.s2),
                        Expanded(
                          child: Text(
                            t.taxiCash,
                            style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400),
                          ),
                        ),
                        Text(formatIqd(ride.fare, lang), style: NaqlText.label.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (ride.status.canCancel) ...[
                      const SizedBox(height: NaqlSpace.s3),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: NaqlButton(label: t.taxiCancel, variant: NaqlButtonVariant.ghost, onPressed: onCancel),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plate as it looks on the car: a bordered box with Western digits.
class _Plate extends StatelessWidget {
  const _Plate({required this.plate, required this.semantic});
  final String plate;
  final String semantic;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s2, vertical: 2),
    decoration: BoxDecoration(
      color: NaqlColors.surface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: NaqlColors.text, width: 1.2),
    ),
    child: Text(
      plate,
      style: NaqlText.label.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5),
      semanticsLabel: semantic,
    ),
  );
}

/// Pickup, drop-off and the moving taxi.
class _RideMap extends StatelessWidget {
  const _RideMap({required this.ride, required this.tiles});
  final TaxiRide ride;
  final bool tiles;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pickup = ride.pickup ?? ride.point;
    final dropoff = ride.dropoff;
    final taxi = ride.taxi;
    final pts = [pickup, ?dropoff, ?taxi];
    final toCampus = ride.direction == TaxiDirection.toCampus;
    return ColoredBox(
      color: NaqlColors.surfaceMuted,
      child: FlutterMap(
        key: const ValueKey('taxi-ride-map'),
        options: MapOptions(
          initialCameraFit: pts.length > 1 ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(56), maxZoom: 16) : null,
          initialCenter: pickup,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
        children: [
          if (tiles) TileLayer(urlTemplate: mapTilesUrl, userAgentPackageName: 'iq.edu.uowa.naql.student'),
          MarkerLayer(
            markers: [
              Marker(
                point: pickup,
                width: 44,
                height: 44,
                child: TaxiMapPin(key: const ValueKey('taxi-pickup-pin'), icon: toCampus ? LucideIcons.mapPin : LucideIcons.school, label: t.taxiPickupPin, color: NaqlColors.ink),
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
                    color: NaqlColors.success,
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
                    child: TaxiMapPin(key: const ValueKey('taxi-car-pin'), icon: LucideIcons.carTaxiFront, label: t.taxiCarPin, color: NaqlColors.primary, square: true),
                  ),
                ],
              ),
            ),
          if (tiles) const SimpleAttributionWidget(source: Text(mapAttribution)),
        ],
      ),
    );
  }
}

class _Done extends ConsumerWidget {
  const _Done({super.key, required this.ride, required this.onHome});
  final TaxiRide ride;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final toCampus = ride.direction == TaxiDirection.toCampus;
    final spot = ride.label?.isNotEmpty == true ? ride.label! : t.taxiYourSpot;
    final arrow = Directionality.of(context) == TextDirection.rtl ? '←' : '→';
    return ListView(
      padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s6, NaqlSpace.s5, NaqlSpace.s6),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: NaqlColors.successSoft, shape: BoxShape.circle),
            child: const Icon(LucideIcons.circleCheckBig, color: NaqlColors.success, size: 34),
          ),
        ),
        const SizedBox(height: NaqlSpace.s4),
        Text(t.taxiDone, style: NaqlText.title, textAlign: TextAlign.center),
        const SizedBox(height: NaqlSpace.s5),
        Container(
          padding: const EdgeInsets.all(NaqlSpace.s4),
          decoration: BoxDecoration(color: NaqlColors.primarySoft, borderRadius: BorderRadius.circular(NaqlRadius.md)),
          child: Row(
            children: [
              const Icon(LucideIcons.banknote, color: NaqlColors.primary),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(
                child: Text(
                  t.taxiPayCash(formatIqd(ride.fare, lang)),
                  key: const ValueKey('taxi-pay'),
                  style: NaqlText.headline.copyWith(color: NaqlColors.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: NaqlSpace.s4),
        NaqlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.taxiSummary, style: NaqlText.headline),
              const SizedBox(height: NaqlSpace.s2),
              NaqlInfoRow(label: t.taxiRoute, value: toCampus ? '$spot $arrow ${t.taxiCampus}' : '${t.taxiCampus} $arrow $spot'),
              NaqlInfoRow(label: t.taxiDistance, value: t.taxiKm(formatKm(ride.distanceKm))),
              if (ride.driver != null) NaqlInfoRow(label: t.taxiDriver, value: ride.driver!.name),
              if (ride.driver?.plate != null) NaqlInfoRow(label: t.taxiPlateLabel, value: ride.driver!.plate!),
            ],
          ),
        ),
        const SizedBox(height: NaqlSpace.s6),
        NaqlButton(label: t.taxiBackHome, expand: true, onPressed: onHome),
      ],
    );
  }
}

class _Ended extends StatelessWidget {
  const _Ended({super.key, required this.ride, required this.onRetry, required this.onHome});
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
