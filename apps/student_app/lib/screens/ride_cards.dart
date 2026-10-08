import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/taxi.dart';
import '../l10n/gen/app_localizations.dart';

String waveLabel(AppLocalizations t, RideInfo r, {bool? today}) => t.rideWave(
      (today ?? true) ? t.rideToday : t.rideTomorrow,
      r.waveType == WaveType.morning ? t.rideMorning : t.rideReturn,
      r.waveTime,
    );

/// Status line for a taxi ride: a word, a tone and an icon (colour is never the only signal).
(String, NaqlTone, IconData) taxiStatusLine(AppLocalizations t, TaxiRide r) => switch (r.status) {
      TaxiStatus.requested => (t.taxiSearching, NaqlTone.primary, LucideIcons.radar),
      TaxiStatus.accepted => (t.taxiAccepted, NaqlTone.primary, LucideIcons.carTaxiFront),
      TaxiStatus.arrived => (t.taxiArrived, NaqlTone.success, LucideIcons.mapPinCheck),
      TaxiStatus.onTrip => (r.direction == TaxiDirection.toCampus ? t.taxiOnTripToCampus : t.taxiOnTripHome, NaqlTone.primary, LucideIcons.navigation),
      TaxiStatus.done => (t.taxiDone, NaqlTone.success, LucideIcons.circleCheck),
      TaxiStatus.expired => (t.taxiExpired, NaqlTone.warning, LucideIcons.clock),
      TaxiStatus.cancelled => (t.taxiCancelledOther, NaqlTone.neutral, LucideIcons.circleX),
    };

/// Caption above a live ride panel ("Today · Morning 08:00") with optional pills on the end.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.caption, this.pills = const []});
  final String caption;
  final List<Widget> pills;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(caption, style: NaqlText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
        for (final p in pills) ...[const SizedBox(width: NaqlSpace.s2), p],
      ]);
}

/// ST-05: the bus is confirmed — the live ride summary on Home: driver and vehicle with the
/// plate (and photo), pickup → destination with times, what to pay, and follow / cancel.
class AssignmentCard extends StatelessWidget {
  const AssignmentCard({super.key, required this.ride, required this.lang, this.photo, this.femaleOnly = false, this.today = true, this.onCancel, this.onTrack});

  final RideInfo ride;
  final String lang;
  final ImageProvider? photo;
  final bool femaleOnly;
  final bool today;
  final VoidCallback? onCancel;

  /// ST-06: shown while the bus is on its way.
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final a = ride.assignment!;
    final pickup = a.pickupAt == null ? '—' : formatClock(a.pickupAt!);
    final morning = ride.waveType == WaveType.morning;
    final point = ride.point(lang);
    return NaqlPanel(
      onTap: onTrack,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PanelHeader(caption: waveLabel(t, ride, today: today), pills: [
          if (femaleOnly) StatusPill(label: t.rideFemaleOnly, tone: NaqlTone.femaleOnly, icon: LucideIcons.users),
          StatusPill(label: t.rideConfirmed, tone: NaqlTone.success, icon: LucideIcons.circleCheck),
        ]),
        const SizedBox(height: NaqlSpace.s3),
        NaqlPersonCard(name: a.driverName, caption: t.driverCaption, squareAvatar: true, avatarSize: 52),
        Padding(padding: const EdgeInsets.symmetric(vertical: NaqlSpace.s3), child: Divider(height: 1, color: NaqlColors.border)),
        Row(children: [
          if (photo != null) ...[_Photo(image: photo!), const SizedBox(width: NaqlSpace.s3)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.trackTitle, style: NaqlText.caption),
              if (a.vehicleType != null) Text(a.vehicleType!, style: NaqlText.headline.copyWith(fontSize: 17)),
              if (a.stopNumber != null && a.stops != null) Text(t.rideStopOf('${a.stopNumber}', '${a.stops}'), style: NaqlText.caption),
            ]),
          ),
          if (a.plate != null) NaqlPlateBadge(a.plate!, large: true),
        ]),
        const SizedBox(height: NaqlSpace.s4),
        // Morning: picked up at the point, at campus by the wave time. Return: leaves campus at the wave time.
        NaqlTripTimeline(dense: true, stops: [
          NaqlTimelineStop(title: morning ? point : t.rideCampus, time: morning ? pickup : ride.waveTime),
          NaqlTimelineStop(title: morning ? t.rideCampus : point, time: morning ? ride.waveTime : pickup),
        ]),
        const SizedBox(height: NaqlSpace.s3),
        _Line(
          icon: ride.fare > 0 ? LucideIcons.banknote : LucideIcons.ticketCheck,
          text: ride.fare > 0 ? t.ridePayDriver(formatIqd(ride.fare, lang)) : t.rideCovered,
          strong: ride.fare > 0,
        ),
        if (onTrack != null) ...[
          const SizedBox(height: NaqlSpace.s3),
          NaqlButton(label: t.trackBus, icon: LucideIcons.mapPinned, expand: true, onPressed: onTrack),
        ],
        if (onCancel != null && onTrack == null) ...[
          const SizedBox(height: NaqlSpace.s1),
          Align(alignment: AlignmentDirectional.centerStart, child: NaqlButton(label: t.rideCancel, variant: NaqlButtonVariant.ghost, onPressed: onCancel)),
        ],
      ]),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.image});
  final ImageProvider image;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 64,
          height: 48,
          color: NaqlColors.primarySoft,
          child: Image(image: image, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(LucideIcons.busFront, color: NaqlColors.primary, size: 22)),
        ),
      );
}

/// ST-07: on the waitlist, with a live countdown to the end of the waiting period.
class WaitlistCard extends StatefulWidget {
  const WaitlistCard({super.key, required this.ride, this.today = true, this.onCancel});

  final RideInfo ride;
  final bool today;
  final VoidCallback? onCancel;

  @override
  State<WaitlistCard> createState() => _WaitlistCardState();
}

class _WaitlistCardState extends State<WaitlistCard> {
  Timer? _timer;
  late Duration _total = _left();

  Duration _left() {
    final until = widget.ride.waitlistedUntil;
    if (until == null) return Duration.zero;
    final d = until.difference(clock.now());
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void didUpdateWidget(WaitlistCard old) {
    super.didUpdateWidget(old);
    if (old.ride.waitlistedUntil != widget.ride.waitlistedUntil) _total = _left();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final left = _left();
    final share = _total.inSeconds == 0 ? 0.0 : left.inSeconds / _total.inSeconds;
    return NaqlPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PanelHeader(caption: waveLabel(t, widget.ride, today: widget.today)),
        const SizedBox(height: NaqlSpace.s3),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: NaqlColors.warningSoft, borderRadius: BorderRadius.circular(NaqlRadius.sm + 4)),
            child: Icon(LucideIcons.hourglass, color: NaqlColors.warning, size: 22),
          ),
          const SizedBox(width: NaqlSpace.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.rideWaitTitle, style: NaqlText.headline),
              const SizedBox(height: 2),
              Text(t.rideWaitBody, style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400)),
            ]),
          ),
        ]),
        const SizedBox(height: NaqlSpace.s4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(t.rideWaitLeft, style: NaqlText.caption)),
          Text(formatCountdown(left), key: const ValueKey('countdown'), style: NaqlText.title.copyWith(fontSize: 28, color: NaqlColors.warning), textDirection: TextDirection.ltr),
        ]),
        const SizedBox(height: NaqlSpace.s2),
        ClipRRect(
          borderRadius: BorderRadius.circular(NaqlRadius.pill),
          child: Container(
            height: 6,
            color: NaqlColors.warningSoft,
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedFractionallySizedBox(
              duration: naqlMotion(context, NaqlMotion.sheet),
              widthFactor: share.clamp(0.0, 1.0),
              child: Container(color: NaqlColors.warning),
            ),
          ),
        ),
        if (widget.onCancel != null) ...[
          const SizedBox(height: NaqlSpace.s2),
          Align(alignment: AlignmentDirectional.centerStart, child: NaqlButton(label: t.rideCancel, variant: NaqlButtonVariant.ghost, onPressed: widget.onCancel)),
        ],
      ]),
    );
  }
}

/// Request received; buses are assigned an hour before the wave.
class PendingRideCard extends StatelessWidget {
  const PendingRideCard({super.key, required this.ride, required this.lang, this.today = true, this.onCancel});

  final RideInfo ride;
  final String lang;
  final bool today;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return NaqlPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PanelHeader(caption: waveLabel(t, ride, today: today), pills: [StatusPill(label: ride.point(lang), tone: NaqlTone.primary, icon: LucideIcons.mapPin)]),
        const SizedBox(height: NaqlSpace.s3),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NaqlIconTile(LucideIcons.clock),
          const SizedBox(width: NaqlSpace.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.ridePendingTitle, style: NaqlText.headline),
              const SizedBox(height: 2),
              Text(t.ridePendingBody, style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400)),
            ]),
          ),
        ]),
        if (onCancel != null) ...[
          const SizedBox(height: NaqlSpace.s2),
          Align(alignment: AlignmentDirectional.centerStart, child: NaqlButton(label: t.rideCancel, variant: NaqlButtonVariant.ghost, onPressed: onCancel)),
        ],
      ]),
    );
  }
}

/// A campus taxi ride that is going: its status, the driver and plate, and "Follow your ride".
class TaxiLiveCard extends StatelessWidget {
  const TaxiLiveCard({super.key, required this.ride, required this.onTap});
  final TaxiRide ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (headline, tone, icon) = taxiStatusLine(t, ride);
    final eta = ride.etaMin;
    final sub = [
      if (ride.driver != null) ride.driver!.name,
      if (eta != null && (ride.status == TaxiStatus.accepted || ride.status == TaxiStatus.onTrip)) t.taxiAway(eta),
    ].join(' · ');
    return NaqlPanel(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(NaqlRadius.md)),
            child: Icon(icon, color: tone.fg, size: 24),
          ),
          const SizedBox(width: NaqlSpace.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.taxiTitle, style: NaqlText.caption),
              Text(headline, style: NaqlText.headline),
              if (sub.isNotEmpty) Text(sub, style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400)),
            ]),
          ),
          if (ride.driver?.plate != null) NaqlPlateBadge(ride.driver!.plate!, semanticLabel: t.taxiPlate(ride.driver!.plate!)),
        ]),
        const SizedBox(height: NaqlSpace.s4),
        NaqlButton(label: t.taxiFollow, icon: LucideIcons.mapPinned, expand: true, onPressed: onTap),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.strong = false});
  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NaqlSpace.s1),
      child: Row(children: [
        Icon(icon, size: 18, color: strong ? NaqlColors.text : NaqlColors.textMuted),
        const SizedBox(width: NaqlSpace.s2),
        Expanded(child: Text(text, style: strong ? NaqlText.label : NaqlText.body.copyWith(color: NaqlColors.textMuted))),
      ]),
    );
  }
}
