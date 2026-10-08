import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/taxi.dart';
import '../l10n/gen/app_localizations.dart';

/// Status line for a ride: a word, a tone and an icon (colour is never the only signal).
(String, NaqlTone, IconData) taxiStatusLine(AppLocalizations t, TaxiRide r) => switch (r.status) {
  TaxiStatus.requested => (t.taxiSearching, NaqlTone.primary, LucideIcons.radar),
  TaxiStatus.accepted => (t.taxiAccepted, NaqlTone.primary, LucideIcons.carTaxiFront),
  TaxiStatus.arrived => (t.taxiArrived, NaqlTone.success, LucideIcons.mapPinCheck),
  TaxiStatus.onTrip => (r.direction == TaxiDirection.toCampus ? t.taxiOnTripToCampus : t.taxiOnTripHome, NaqlTone.primary, LucideIcons.navigation),
  TaxiStatus.done => (t.taxiDone, NaqlTone.success, LucideIcons.circleCheck),
  TaxiStatus.expired => (t.taxiExpired, NaqlTone.warning, LucideIcons.clock),
  TaxiStatus.cancelled => (t.taxiCancelledOther, NaqlTone.neutral, LucideIcons.circleX),
};

/// Home's campus taxi entry (P10). Hidden unless the office runs taxis; while a ride is going
/// it turns into the ride's live status and opens the tracking screen.
class TaxiHomeCard extends ConsumerWidget {
  const TaxiHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(taxiEnabledProvider).value ?? false;
    final Widget child = enabled ? const _Card() : const SizedBox.shrink(key: ValueKey('taxi-off'));
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : NaqlMotion.sheet,
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.topStart,
      child: child,
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final active = ref.watch(taxiMineProvider).value?.active;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Padding(
      key: const ValueKey('taxi-card'),
      padding: const EdgeInsets.only(bottom: NaqlSpace.s4),
      child: AnimatedSwitcher(
        duration: reduce ? Duration.zero : NaqlMotion.sheet,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: active == null
            ? _Entry(key: const ValueKey('taxi-entry'), title: t.taxiCardTitle, body: t.taxiCardBody, onTap: () => context.go('/taxi'))
            : _Live(key: ValueKey('taxi-live-${active.id}-${active.status.name}'), ride: active, onTap: () => context.go('/taxi?ride=${active.id}')),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({super.key, required this.title, required this.body, required this.onTap});
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      child: NaqlCard(
        onTap: onTap,
        child: Row(
          children: [
            const NaqlIconTile(LucideIcons.carTaxiFront, accent: true, size: 52),
            const SizedBox(width: NaqlSpace.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: NaqlText.headline),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NaqlSpace.s2),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: naqlIsDark ? NaqlColors.ink : NaqlColors.primary, shape: BoxShape.circle),
              child: Icon(rtl ? LucideIcons.arrowLeft : LucideIcons.arrowRight, color: naqlIsDark ? NaqlColors.onInk : NaqlColors.onPrimary, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _Live extends StatelessWidget {
  const _Live({super.key, required this.ride, required this.onTap});
  final TaxiRide ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (headline, tone, icon) = taxiStatusLine(t, ride);
    final eta = ride.etaMin;
    final sub = [
      if (ride.driver != null) ride.driver!.name,
      if (ride.driver?.plate != null) ride.driver!.plate!,
      if (eta != null && (ride.status == TaxiStatus.accepted || ride.status == TaxiStatus.onTrip)) t.taxiAway(eta),
    ].join(' · ');
    return NaqlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(NaqlRadius.md)),
                child: Icon(icon, color: tone.fg, size: 24),
              ),
              const SizedBox(width: NaqlSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.taxiTitle, style: NaqlText.caption),
                    Text(headline, style: NaqlText.headline),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NaqlSpace.s4),
          NaqlButton(label: t.taxiFollow, icon: LucideIcons.mapPinned, variant: NaqlButtonVariant.secondary, expand: true, onPressed: onTap),
        ],
      ),
    );
  }
}
