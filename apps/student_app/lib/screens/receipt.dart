import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/history.dart';
import '../l10n/gen/app_localizations.dart';
import 'feedback_sheets.dart';

/// Top bar of the details pages: round back button, centred title, optional action.
class ReceiptTopBar extends StatelessWidget {
  const ReceiptTopBar({super.key, required this.title, required this.onBack, this.trailing});
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s3, NaqlSpace.s4, NaqlSpace.s1),
      child: Row(children: [
        NaqlIconButton(icon: rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft, onPressed: onBack, semanticLabel: MaterialLocalizations.of(context).backButtonTooltip),
        Expanded(child: Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: NaqlText.headline.copyWith(fontSize: 17)))),
        SizedBox(width: NaqlTouch.min, child: trailing),
      ]),
    );
  }
}

/// One ride, as a receipt: the vehicle (title, plate, a big faded word and an illustration), the
/// driver with "Rate the ride", the route with times, and the payment with its total.
class RideReceipt extends StatelessWidget {
  const RideReceipt({
    super.key,
    required this.kind,
    required this.title,
    this.subtitle,
    this.plate,
    this.plateLabel,
    required this.watermark,
    this.driverName,
    this.driverAction,
    required this.tripTitle,
    required this.stops,
    required this.paymentTitle,
    this.paymentBadge,
    this.lines = const [],
    this.total,
    this.highlight,
    this.footer,
    this.bottom,
  });

  final NaqlVehicleKind kind;
  final String title;
  final String? subtitle;
  final String? plate;
  final String? plateLabel;
  final String watermark;
  final String? driverName;

  /// On the driver row's end: "Rate the ride", or the stars already given.
  final Widget? driverAction;
  final String tripTitle;
  final List<NaqlTimelineStop> stops;
  final String paymentTitle;
  final String? paymentBadge;
  final List<(String, String)> lines;
  final String? total;

  /// Something to do now, above the cards (e.g. "Pay the driver 4,500 IQD").
  final Widget? highlight;
  final String? footer;

  /// Buttons under everything.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: NaqlSpace.s6),
      children: [
        // The vehicle: title and plate over a big faded word and the illustration.
        SizedBox(
          height: 250,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            PositionedDirectional(
              top: 70,
              start: -10,
              child: NaqlWatermark(watermark, size: 120, opacity: 0.05),
            ),
            PositionedDirectional(
              top: NaqlSpace.s4,
              start: NaqlSpace.s4,
              end: NaqlSpace.s4,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: NaqlText.title.copyWith(fontSize: 26, height: 1.2)),
                    if (subtitle != null) Text(subtitle!, style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400)),
                  ]),
                ),
                if (plate != null) NaqlPlateBadge(plate!, large: true, semanticLabel: plateLabel),
              ]),
            ),
            PositionedDirectional(bottom: 10, end: 30, child: NaqlVehicleArt(kind: kind, hero: true, width: 300)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: NaqlSpace.s3, children: [
            ?highlight,
            if (driverName != null)
              NaqlPanel(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(child: NaqlPersonCard(name: driverName!, caption: t.driverCaption, squareAvatar: true, avatarSize: 48, accentAvatar: true)),
                  ?driverAction,
                ]),
              ),
            NaqlPanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(tripTitle, style: NaqlText.label.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: NaqlSpace.s3),
                NaqlTripTimeline(dense: true, stops: stops),
              ]),
            ),
            NaqlPanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(paymentTitle, style: NaqlText.label.copyWith(fontSize: 15, fontWeight: FontWeight.w600))),
                  if (paymentBadge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: NaqlColors.border)),
                      child: Text(paymentBadge!, style: NaqlText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ]),
                for (final (label, value) in lines) NaqlSummaryRow(label: label, value: value),
                if (total != null) NaqlSummaryRow(label: t.rideSummaryTotal, value: total!, total: true),
              ]),
            ),
            ?bottom,
            if (footer != null) Padding(padding: const EdgeInsets.only(top: NaqlSpace.s2), child: Text(footer!, textAlign: TextAlign.center, style: NaqlText.caption)),
          ]),
        ),
      ],
    );
  }
}

/// ST-10: one past bus ride from the trips history, as a receipt; rate it from here (ST-11).
class RideDetailsScreen extends ConsumerWidget {
  const RideDetailsScreen({super.key, required this.rideId, this.initial});
  final String rideId;
  final RideHistoryItem? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    // The history list holds the latest copy (it changes when the ride is rated).
    final ride = ref.watch(rideHistoryProvider).value?.items.where((r) => r.id == rideId).firstOrNull ?? initial;
    void back() => context.canPop() ? context.pop() : context.go('/trips');
    final Widget body;
    if (ride == null) {
      body = Center(child: NaqlEmptyState(icon: LucideIcons.ticket, title: t.receiptMissing));
    } else {
      final morning = ride.waveType == WaveType.morning;
      final point = ride.point(lang);
      final from = morning ? point : t.rideCampus;
      final to = morning ? t.rideCampus : point;
      body = RideReceipt(
        kind: NaqlVehicleKind.bus,
        title: t.serviceBus,
        subtitle: '${formatDayName(ride.date, lang)} · ${morning ? t.rideMorning : t.rideReturn} ${ride.waveTime}',
        plate: ride.plate,
        watermark: t.receiptBusWord,
        driverName: ride.driverName,
        driverAction: ride.rating != null
            ? Semantics(label: t.receiptYouRated(ride.rating!), excludeSemantics: true, child: StarRow(value: ride.rating!, size: 16, key: ValueKey('stars-${ride.id}')))
            : ride.canRate
                ? NaqlButton(key: ValueKey('receipt-rate-${ride.id}'), label: t.rateRide, variant: NaqlButtonVariant.ghost, onPressed: () => showRateSheet(context, ride))
                : null,
        tripTitle: t.receiptTrip(from, to),
        stops: [
          NaqlTimelineStop(title: from, time: morning ? null : ride.waveTime),
          NaqlTimelineStop(title: to, time: morning ? ride.waveTime : null),
        ],
        paymentTitle: ride.fare > 0 ? t.receiptPaidCash : (ride.status == 'done' ? t.receiptCovered : t.receiptNotPaid),
        lines: [if (ride.fare > 0) (t.rideFare, formatIqd(ride.fare, lang))],
        total: formatIqd(ride.fare, lang),
        bottom: NaqlButton(label: t.reportProblem, variant: NaqlButtonVariant.secondary, icon: LucideIcons.messageSquareWarning, expand: true, onPressed: () => showProblemSheet(context, requestId: ride.id)),
        footer: formatDayName(ride.date, lang),
      );
    }
    return Scaffold(
      body: SafeArea(child: Column(children: [ReceiptTopBar(title: t.receiptTitle, onBack: back), Expanded(child: body)])),
    );
  }
}
