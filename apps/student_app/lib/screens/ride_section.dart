import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/auth.dart';
import '../data/rides.dart';
import '../l10n/gen/app_localizations.dart';
import 'request_sheet.dart';
import 'ride_cards.dart';

/// Home's ride answer: assigned bus, waitlist countdown, pending request, or the request button.
class RideSection extends ConsumerWidget {
  const RideSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    final rides = ref.watch(ridesProvider);
    final user = ref.watch(authProvider).value;
    return rides.when(
      loading: () => const NaqlSkeleton(height: 180, radius: NaqlRadius.lg),
      error: (_, _) => RequestRideCard(onRequest: () => showRequestSheet(context)),
      data: (list) {
        final ride = currentRide(list);
        final today = ride == null || ride.date == _today();
        final cancel = ride == null ? null : () => _cancel(context, ref, ride);
        final Widget child = switch (ride?.status) {
          RideStatus.assigned when ride!.assignment != null => AssignmentCard(
              ride: ride,
              lang: lang,
              today: today,
              femaleOnly: user?.gender == Gender.female,
              photo: ride.assignment!.vehiclePhotoUrl == null ? null : NetworkImage(ref.read(apiProvider).resolve(ride.assignment!.vehiclePhotoUrl!).toString()),
              onCancel: cancel,
            ),
          RideStatus.waitlisted => WaitlistCard(ride: ride!, today: today, onCancel: cancel),
          RideStatus.open || RideStatus.assigned => PendingRideCard(ride: ride!, lang: lang, today: today, onCancel: cancel),
          _ => RequestRideCard(
              onRequest: () => showRequestSheet(context),
              expiredNote: switch (lastExpired(list)) { final e? => AppLocalizations.of(context).rideExpired(e.waveTime), null => null },
            ),
        };
        return AnimatedSwitcher(
          duration: NaqlMotion.sheet,
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, alignment: AlignmentDirectional.topStart, child: c)),
          child: KeyedSubtree(key: ValueKey('${ride?.id}-${ride?.status}'), child: child),
        );
      },
    );
  }

  static String _today() {
    final d = clock.now().toUtc().add(const Duration(hours: 3));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, RideInfo ride) async {
    final t = AppLocalizations.of(context);
    final yes = await showNaqlSheet<bool>(
      context,
      builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(t.rideCancelTitle, style: NaqlText.title),
        const SizedBox(height: NaqlSpace.s2),
        Text(t.rideCancelBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
        const SizedBox(height: NaqlSpace.s5),
        NaqlButton(label: t.rideCancelYes, variant: NaqlButtonVariant.danger, expand: true, onPressed: () => Navigator.of(c).pop(true)),
        const SizedBox(height: NaqlSpace.s2),
        NaqlButton(label: t.rideKeep, variant: NaqlButtonVariant.secondary, expand: true, onPressed: () => Navigator.of(c).pop(false)),
      ]),
    );
    if (yes != true) return;
    try {
      await ref.read(apiProvider).cancelRide(ride.id);
    } catch (e) {
      if (context.mounted) {
        await showNaqlSheet<void>(context, builder: (_) => Text(apiErrorMessage(e, t.loadFailed), style: NaqlText.body));
      }
    }
    ref.invalidate(ridesProvider);
  }
}
