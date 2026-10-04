import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../l10n/gen/app_localizations.dart';

String waveLabel(AppLocalizations t, RideInfo r, {bool? today}) => t.rideWave(
      (today ?? true) ? t.rideToday : t.rideTomorrow,
      r.waveType == WaveType.morning ? t.rideMorning : t.rideReturn,
      r.waveTime,
    );

/// ST-05: the bus is confirmed — pickup time and place first, then bus, driver, plate and photo.
class AssignmentCard extends StatelessWidget {
  const AssignmentCard({super.key, required this.ride, required this.lang, this.photo, this.femaleOnly = false, this.today = true, this.onCancel});

  final RideInfo ride;
  final String lang;
  final ImageProvider? photo;
  final bool femaleOnly;
  final bool today;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final a = ride.assignment!;
    final pickup = a.pickupAt == null ? '—' : formatClock(a.pickupAt!);
    final morning = ride.waveType == WaveType.morning;
    final point = ride.point(lang);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: NaqlSpace.s1, bottom: NaqlSpace.s2),
        child: Text(waveLabel(t, ride, today: today), style: NaqlText.caption),
      ),
      TripCard(
        // Morning: picked up at the point, at campus by the wave time. Return: leaves campus at the wave time.
        departTime: morning ? pickup : ride.waveTime,
        from: morning ? point : t.rideCampus,
        arriveTime: morning ? ride.waveTime : pickup,
        to: morning ? t.rideCampus : point,
        status: t.rideConfirmed,
        statusTone: NaqlTone.success,
        driverName: a.driverName,
        busLabel: a.vehicleType,
        plate: a.plate,
        photo: photo,
        femaleOnly: femaleOnly,
        femaleOnlyLabel: t.rideFemaleOnly,
        footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (a.stopNumber != null && a.stops != null)
            _Line(icon: LucideIcons.mapPin, text: t.rideStopOf('${a.stopNumber}', '${a.stops}')),
          _Line(
            icon: ride.fare > 0 ? LucideIcons.banknote : LucideIcons.ticketCheck,
            text: ride.fare > 0 ? t.ridePayDriver(formatIqd(ride.fare, lang)) : t.rideCovered,
            strong: ride.fare > 0,
          ),
          if (onCancel != null) ...[
            const SizedBox(height: NaqlSpace.s2),
            Align(alignment: AlignmentDirectional.centerStart, child: NaqlButton(label: t.rideCancel, variant: NaqlButtonVariant.ghost, onPressed: onCancel)),
          ],
        ]),
      ),
    ]);
  }
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: NaqlSpace.s1, bottom: NaqlSpace.s2),
        child: Text(waveLabel(t, widget.ride, today: widget.today), style: NaqlText.caption),
      ),
      NaqlCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: NaqlColors.warningSoft, shape: BoxShape.circle),
              child: const Icon(LucideIcons.hourglass, color: NaqlColors.warning, size: 22),
            ),
            const SizedBox(width: NaqlSpace.s3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.rideWaitTitle, style: NaqlText.headline),
                const SizedBox(height: NaqlSpace.s1),
                Text(t.rideWaitBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
              ]),
            ),
          ]),
          const SizedBox(height: NaqlSpace.s5),
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
                duration: NaqlMotion.sheet,
                widthFactor: share.clamp(0.0, 1.0),
                child: Container(color: NaqlColors.warning),
              ),
            ),
          ),
          if (widget.onCancel != null) ...[
            const SizedBox(height: NaqlSpace.s3),
            Align(alignment: AlignmentDirectional.centerStart, child: NaqlButton(label: t.rideCancel, variant: NaqlButtonVariant.ghost, onPressed: widget.onCancel)),
          ],
        ]),
      ),
    ]);
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: NaqlSpace.s1, bottom: NaqlSpace.s2),
        child: Text(waveLabel(t, ride, today: today), style: NaqlText.caption),
      ),
      NaqlCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: NaqlColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(LucideIcons.clock, color: NaqlColors.primary, size: 22),
            ),
            const SizedBox(width: NaqlSpace.s3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t.ridePendingTitle, style: NaqlText.headline)),
                  StatusPill(label: ride.point(lang), tone: NaqlTone.primary, icon: LucideIcons.mapPin),
                ]),
                const SizedBox(height: NaqlSpace.s1),
                Text(t.ridePendingBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
              ]),
            ),
          ]),
          if (onCancel != null) ...[
            const SizedBox(height: NaqlSpace.s3),
            Align(alignment: AlignmentDirectional.centerStart, child: NaqlButton(label: t.rideCancel, variant: NaqlButtonVariant.ghost, onPressed: onCancel)),
          ],
        ]),
      ),
    ]);
  }
}

/// No live request: invite the student to ask for a seat.
class RequestRideCard extends StatelessWidget {
  const RequestRideCard({super.key, required this.onRequest, this.expiredNote});

  final VoidCallback onRequest;
  final String? expiredNote;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return NaqlCard(
      padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5, vertical: NaqlSpace.s6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (expiredNote != null) ...[
          Container(
            padding: const EdgeInsets.all(NaqlSpace.s3),
            decoration: BoxDecoration(color: NaqlColors.warningSoft, borderRadius: BorderRadius.circular(NaqlRadius.sm)),
            child: Row(children: [
              const Icon(LucideIcons.info, color: NaqlColors.warning, size: 18),
              const SizedBox(width: NaqlSpace.s2),
              Expanded(child: Text(expiredNote!, style: NaqlText.body.copyWith(color: NaqlColors.warning))),
            ]),
          ),
          const SizedBox(height: NaqlSpace.s5),
        ],
        NaqlEmptyState(
          icon: LucideIcons.busFront,
          title: t.noRideToday,
          message: t.noRideTodayBody,
          action: NaqlButton(label: t.rideRequest, icon: LucideIcons.plus, onPressed: onRequest),
        ),
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
