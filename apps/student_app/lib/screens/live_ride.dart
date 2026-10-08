import 'package:flutter/material.dart';
import 'package:naql_ui/naql_ui.dart';

import '../l10n/gen/app_localizations.dart';

// Building blocks of the live ride screens (bus and taxi): a full-bleed map, a floating top row
// with the live ETA, and cards floating at the bottom (driver and vehicle, then the route).

/// Back button on the start, the live ETA pill in the middle, room for an action on the end.
class LiveTopBar extends StatelessWidget {
  const LiveTopBar({super.key, required this.onBack, this.center, this.trailing});
  final VoidCallback onBack;
  final Widget? center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s3, NaqlSpace.s4, 0),
        child: Row(children: [
          NaqlIconButton.floating(icon: rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft, onPressed: onBack, semanticLabel: MaterialLocalizations.of(context).backButtonTooltip),
          Expanded(child: Center(child: center)),
          SizedBox(width: NaqlTouch.min, child: trailing),
        ]),
      ),
    );
  }
}

/// A calm status pill for the top bar when nothing is moving (no pulsing dot).
class LiveStatusPill extends StatelessWidget {
  const LiveStatusPill({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4),
          decoration: naqlFloatingDecoration(alpha: 0.95),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: NaqlColors.textMuted, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: NaqlText.label.copyWith(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
}

/// Driver (with message / call where a phone exists) and, under a hairline, the vehicle with its
/// Iraqi plate.
class LiveDriverPanel extends StatelessWidget {
  const LiveDriverPanel({
    super.key,
    required this.name,
    this.rating,
    this.onCall,
    this.onMessage,
    this.callKey,
    required this.vehicleCaption,
    this.vehicleTitle,
    this.vehicleSub,
    this.plate,
    this.plateLabel,
    this.photo,
  });

  final String name;
  final String? rating;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final Key? callKey;
  final String vehicleCaption;
  final String? vehicleTitle;
  final String? vehicleSub;
  final String? plate;
  final String? plateLabel;
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return NaqlPanel(
      floating: true,
      radius: 26,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NaqlPersonCard(
          name: name,
          caption: t.driverCaption,
          rating: rating,
          squareAvatar: true,
          avatarSize: 64,
          actions: [
            if (onMessage != null) NaqlPersonAction(key: const ValueKey('live-message'), icon: LucideIcons.messageCircle, label: t.liveMessage, onPressed: onMessage),
            if (onCall != null) NaqlPersonAction(key: callKey, icon: LucideIcons.phone, label: t.liveCallDriver, positive: true, onPressed: onCall),
          ],
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: NaqlColors.border)),
        Row(children: [
          if (photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 64, height: 48, child: Image(image: photo!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())),
            ),
            const SizedBox(width: NaqlSpace.s3),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(vehicleCaption, style: NaqlText.caption),
              if (vehicleTitle != null) Text(vehicleTitle!, style: NaqlText.headline.copyWith(fontSize: 17)),
              if (vehicleSub != null) Text(vehicleSub!, style: NaqlText.caption),
            ]),
          ),
          if (plate != null) NaqlPlateBadge(plate!, large: true, semanticLabel: plateLabel),
        ]),
      ]),
    );
  }
}

/// Pickup → destination with times.
class LiveRoutePanel extends StatelessWidget {
  const LiveRoutePanel({super.key, required this.stops, this.footer});
  final List<NaqlTimelineStop> stops;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => NaqlPanel(
        floating: true,
        padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          NaqlTripTimeline(dense: true, stops: stops),
          ?footer,
        ]),
      );
}

/// The floating cards at the bottom of a live screen, scrollable when they do not fit.
class LiveBottom extends StatelessWidget {
  const LiveBottom({super.key, required this.children, this.maxFraction = 0.76});
  final List<Widget> children;
  final double maxFraction;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * maxFraction),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: NaqlSpace.s4),
          child: SingleChildScrollView(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s3),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: children),
          ),
        ),
      );
}
