import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/auth.dart';
import '../data/rides.dart';
import '../l10n/gen/app_localizations.dart';

/// ST-04: choose a wave (today or tomorrow) and a gathering point. Returns the new request.
Future<RideInfo?> showRequestSheet(BuildContext context) => showNaqlSheet<RideInfo>(context, builder: (_) => const RequestSheet());

class RequestSheet extends ConsumerStatefulWidget {
  const RequestSheet({super.key});

  @override
  ConsumerState<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<RequestSheet> {
  RideSlot? _slot;
  String? _pointId;
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    final slot = _slot;
    if (slot == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final ride = await ref.read(apiProvider).requestRide(waveId: slot.waveId, date: slot.date, pointId: _pointId);
      ref.invalidate(ridesProvider);
      if (mounted) Navigator.of(context).pop(ride);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, AppLocalizations.of(context).loadFailed));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final options = ref.watch(rideOptionsProvider);
    final points = ref.watch(pointsProvider);
    final user = ref.watch(authProvider).value;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(t.rideRequestTitle, style: NaqlText.title),
          const SizedBox(height: NaqlSpace.s1),
          Text(t.rideRequestBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
          const SizedBox(height: NaqlSpace.s5),
          Text(t.rideWhen, style: NaqlText.label),
          const SizedBox(height: NaqlSpace.s2),
          options.when(
            loading: () => const NaqlSkeleton(height: 48, radius: NaqlRadius.pill),
            error: (e, _) => Text(apiErrorMessage(e, t.loadFailed), style: NaqlText.body.copyWith(color: NaqlColors.danger)),
            data: (o) {
              if (o.slots.isEmpty) return Text(t.rideNoSlots, style: NaqlText.body.copyWith(color: NaqlColors.textMuted));
              _slot ??= o.slots.first;
              _pointId ??= o.defaultPointId ?? user?.defaultPoint?.id;
              return Wrap(spacing: NaqlSpace.s2, runSpacing: NaqlSpace.s2, children: [
                for (final s in o.slots)
                  NaqlChip(
                    key: ValueKey('slot-${s.waveId}-${s.date}'),
                    label: t.rideSlot(s.today ? t.rideToday : t.rideTomorrow, s.type == WaveType.morning ? t.rideMorning : t.rideReturn, s.time),
                    selected: _slot?.waveId == s.waveId && _slot?.date == s.date,
                    onSelected: () => setState(() => _slot = s),
                  ),
              ]);
            },
          ),
          const SizedBox(height: NaqlSpace.s5),
          Text(t.rideWhere, style: NaqlText.label),
          const SizedBox(height: NaqlSpace.s2),
          points.when(
            loading: () => const NaqlSkeleton(height: 120, radius: NaqlRadius.md),
            error: (e, _) => Text(apiErrorMessage(e, t.loadFailed), style: NaqlText.body.copyWith(color: NaqlColors.danger)),
            data: (list) => Column(children: [
              for (final p in list.where((p) => p.active))
                NaqlListRow(
                  title: p.displayName(lang),
                  subtitle: p.tierName == null ? null : t.subTier(p.tierName!),
                  selectable: true,
                  selected: (_pointId ?? user?.defaultPoint?.id) == p.id,
                  onTap: () => setState(() => _pointId = p.id),
                ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: NaqlSpace.s3),
            Text(_error!, style: NaqlText.body.copyWith(color: NaqlColors.danger)),
          ],
          const SizedBox(height: NaqlSpace.s5),
          NaqlButton(label: t.rideSend, icon: LucideIcons.send, expand: true, loading: _sending, onPressed: _slot == null ? null : _send),
        ]),
      ),
    );
  }
}
