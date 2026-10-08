import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/auth.dart';
import '../data/home.dart';
import '../data/rides.dart';
import '../data/subscription.dart';
import '../data/track.dart';
import '../l10n/gen/app_localizations.dart';

/// ST-04: book a seat on the university bus. Today / tomorrow, the wave times as big tiles
/// (morning waves, then the return waves), where the student boards, what it costs, and one
/// "Confirm booking". A full wave still takes the request: it joins the waitlist (ST-07).
class BusBookingScreen extends ConsumerStatefulWidget {
  const BusBookingScreen({super.key, this.prefer, this.waveId, this.date});

  /// Preselect the first morning (to campus) or return (home) wave.
  final WaveType? prefer;

  /// Preselect this slot (Home's call to action).
  final String? waveId;
  final String? date;

  @override
  ConsumerState<BusBookingScreen> createState() => _BusBookingScreenState();
}

class _BusBookingScreenState extends ConsumerState<BusBookingScreen> {
  bool? _today;
  RideSlot? _slot;
  String? _pointId;
  var _sending = false;
  String? _error;

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  /// First visit with options: pick the day and slot the caller asked for, or the first one.
  void _initFrom(RideOptions o) {
    if (_today != null) return;
    final slots = o.slots;
    RideSlot? pick = slots.where((s) => s.waveId == widget.waveId && s.date == widget.date).firstOrNull;
    pick ??= widget.prefer == null ? null : (slots.where((s) => s.type == widget.prefer && !s.full).firstOrNull ?? slots.where((s) => s.type == widget.prefer).firstOrNull);
    pick ??= slots.where((s) => !s.full).firstOrNull ?? slots.firstOrNull;
    _slot = pick;
    _today = pick?.today ?? true;
    _pointId = o.defaultPointId ?? ref.read(authProvider).value?.defaultPoint?.id;
  }

  Future<void> _send() async {
    final slot = _slot;
    if (slot == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).requestRide(waveId: slot.waveId, date: slot.date, pointId: _pointId);
      ref.invalidate(ridesProvider);
      if (mounted) _back();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, AppLocalizations.of(context).loadFailed));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _choosePoint(List<GatheringPoint> points) async {
    final t = AppLocalizations.of(context);
    final lang = ref.read(localeProvider).languageCode;
    final picked = await showNaqlSheet<String>(
      context,
      builder: (c) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: NaqlSpace.s2, children: [
            Text(t.bookWhere, style: NaqlText.title),
            const SizedBox(height: NaqlSpace.s2),
            for (final p in points.where((p) => p.active))
              NaqlListRow(
                key: ValueKey('point-${p.id}'),
                title: p.displayName(lang),
                subtitle: p.tierName == null ? null : t.subTier(p.tierName!),
                selectable: true,
                selected: _pointId == p.id,
                onTap: () => Navigator.of(c).pop(p.id),
              ),
          ]),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _pointId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final options = ref.watch(rideOptionsProvider);
    final o = options.value;
    if (o != null) _initFrom(o);
    final today = _today ?? true;
    final day = [for (final s in o?.slots ?? const <RideSlot>[]) if (s.today == today) s];
    final morning = day.where((s) => s.type == WaveType.morning).toList();
    final back = day.where((s) => s.type == WaveType.ret).toList();
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Widget tile(RideSlot s, {bool compact = false}) {
      final full = s.full;
      final selected = _slot?.waveId == s.waveId && _slot?.date == s.date;
      final caption = full ? t.bookFull : (s.seatsLeft != null ? t.bookSeatsLeft(s.seatsLeft!) : t.bookOpen);
      return NaqlSlotTile(
        key: ValueKey('slot-${s.waveId}-${s.date}'),
        time: compact ? t.bookReturnSlot(s.time) : s.time,
        caption: compact && !full && !selected ? null : caption,
        compact: compact,
        state: selected ? NaqlSlotState.selected : (full ? NaqlSlotState.full : NaqlSlotState.available),
        semanticLabel: t.rideSlot(s.today ? t.rideToday : t.rideTomorrow, s.type == WaveType.morning ? t.rideMorning : t.rideReturn, s.time),
        onTap: () => setState(() {
          _slot = s;
          _error = null;
        }),
      );
    }

    Widget grid(List<RideSlot> list, {bool compact = false}) => LayoutBuilder(builder: (_, c) {
          final w = (c.maxWidth - 2 * 10) / 3;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final s in list) SizedBox(width: w, child: tile(s, compact: compact))]);
        });

    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s3, NaqlSpace.s4, NaqlSpace.s2),
            child: Row(children: [
              NaqlIconButton(icon: rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft, semanticLabel: MaterialLocalizations.of(context).backButtonTooltip, onPressed: _back),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(child: Semantics(header: true, child: Text(t.serviceBus, style: NaqlText.title.copyWith(fontSize: 20)))),
            ]),
          ),
          Expanded(
            child: options.when(
              loading: () => const Padding(padding: EdgeInsets.all(NaqlSpace.s4), child: NaqlSkeleton(height: 200, radius: NaqlRadius.lg)),
              error: (e, _) => Center(
                child: NaqlEmptyState(
                  icon: LucideIcons.wifiOff,
                  title: apiErrorMessage(e, t.loadFailed),
                  action: NaqlButton(label: t.retry, onPressed: () => ref.invalidate(rideOptionsProvider)),
                ),
              ),
              data: (o) => o.slots.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(NaqlSpace.s6), child: NaqlEmptyState(icon: LucideIcons.calendarX, title: t.rideNoSlots)))
                  : ListView(padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s2, NaqlSpace.s4, NaqlSpace.s6), children: [
                      Row(spacing: NaqlSpace.s2, children: [
                        for (final (v, label) in [(true, t.rideToday), (false, t.rideTomorrow)])
                          Expanded(
                            child: NaqlChip(
                              key: ValueKey('day-${v ? 'today' : 'tomorrow'}'),
                              label: label,
                              selected: today == v,
                              onSelected: () => setState(() {
                                _today = v;
                                final first = o.slots.where((s) => s.today == v).firstOrNull;
                                if (_slot?.today != v) _slot = first;
                              }),
                            ),
                          ),
                      ]),
                      const SizedBox(height: NaqlSpace.s5),
                      if (day.isEmpty)
                        Padding(padding: const EdgeInsets.symmetric(vertical: NaqlSpace.s5), child: Text(t.bookNoDay, style: NaqlText.body.copyWith(color: NaqlColors.textMuted), textAlign: TextAlign.center)),
                      if (morning.isNotEmpty) ...[
                        Text(t.bookPickTime, style: NaqlText.headline.copyWith(fontSize: 16)),
                        const SizedBox(height: 10),
                        grid(morning),
                      ],
                      if (back.isNotEmpty) ...[
                        const SizedBox(height: NaqlSpace.s4),
                        Text(t.bookReturnTitle, style: NaqlText.label.copyWith(color: NaqlColors.textMuted)),
                        const SizedBox(height: NaqlSpace.s2),
                        grid(back, compact: true),
                      ],
                      AnimatedSize(
                        duration: naqlMotion(context),
                        curve: naqlEaseOut,
                        child: _slot?.full ?? false
                            ? Padding(padding: const EdgeInsets.only(top: NaqlSpace.s3), child: Text(t.bookFullHint, style: NaqlText.label.copyWith(color: NaqlColors.warning, fontWeight: FontWeight.w400)))
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: NaqlSpace.s5),
                      Text(t.bookWhere, style: NaqlText.headline.copyWith(fontSize: 16)),
                      const SizedBox(height: 10),
                      _BoardCard(pointId: _pointId, onChange: _choosePoint),
                    ]),
            ),
          ),
          _BottomBar(
            sending: _sending,
            error: _error,
            enabled: _slot != null,
            onConfirm: _send,
          ),
        ]),
      ),
    );
  }
}

/// Where the student boards: a mini map with the gathering point and "Change".
class _BoardCard extends ConsumerWidget {
  const _BoardCard({required this.pointId, required this.onChange});
  final String? pointId;
  final Future<void> Function(List<GatheringPoint>) onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final points = ref.watch(pointsProvider).value ?? const <GatheringPoint>[];
    final user = ref.watch(authProvider).value;
    final p = points.where((x) => x.id == pointId).firstOrNull ?? user?.defaultPoint;
    final isDefault = p?.id == user?.defaultPoint?.id;
    final loc = isDefault ? ref.watch(pointLocationProvider).value : null;
    final tiles = ref.watch(mapTilesProvider);
    final sub = [
      if (p?.tierName != null) t.subTier(p!.tierName!),
      if (p?.distanceKm != null) t.kmAway(p!.distanceKm!.toStringAsFixed(1)),
    ].join(' · ');
    return NaqlPanel(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 110,
          child: Stack(children: [
            const Positioned.fill(child: NaqlMapBackdrop()),
            if (loc != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(backgroundColor: const Color(0x00000000), initialCenter: loc, initialZoom: 15, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                    children: [if (tiles) NaqlMapTint(child: TileLayer(urlTemplate: mapTilesUrl, userAgentPackageName: 'iq.edu.uowa.naql.student'))],
                  ),
                ),
              ),
            Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: NaqlColors.accent.withValues(alpha: 0.22), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Container(width: 12, height: 12, decoration: BoxDecoration(color: NaqlColors.accent, shape: BoxShape.circle)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: NaqlSpace.s2),
          child: Row(children: [
            const NaqlIconTile(LucideIcons.mapPin, accent: true, size: 40),
            const SizedBox(width: NaqlSpace.s3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p?.displayName(lang) ?? t.notSet, style: NaqlText.label.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                if (sub.isNotEmpty) Text(sub, style: NaqlText.caption),
              ]),
            ),
            NaqlButton(key: const ValueKey('change-point'), label: t.change, variant: NaqlButtonVariant.ghost, onPressed: points.isEmpty ? null : () => onChange(points)),
          ]),
        ),
      ]),
    );
  }
}

/// Cost line and the one call to action, pinned to the bottom.
class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.sending, required this.error, required this.enabled, required this.onConfirm});
  final bool sending;
  final String? error;
  final bool enabled;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final covered = ref.watch(subscriptionProvider).value?.isActive ?? false;
    return Container(
      padding: const EdgeInsets.all(NaqlSpace.s4),
      decoration: BoxDecoration(
        color: naqlIsDark ? Color.lerp(NaqlColors.bg, NaqlColors.surface, 0.36) : NaqlColors.surface,
        border: Border(top: BorderSide(color: NaqlColors.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AnimatedSize(
          duration: naqlMotion(context),
          curve: naqlEaseOut,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
                  child: Semantics(liveRegion: true, child: Text(error!, key: const ValueKey('book-error'), style: NaqlText.label.copyWith(color: NaqlColors.danger))),
                ),
        ),
        Row(children: [
          Expanded(child: Text(t.bookCost, style: NaqlText.label.copyWith(color: NaqlColors.textMuted, fontWeight: FontWeight.w400))),
          Text(covered ? t.bookCovered : t.bookPayDriver, style: NaqlText.label.copyWith(fontWeight: FontWeight.w600, color: covered ? NaqlColors.success : NaqlColors.text)),
        ]),
        const SizedBox(height: NaqlSpace.s3),
        NaqlButton(key: const ValueKey('book-confirm'), label: t.bookConfirm, expand: true, loading: sending, onPressed: enabled ? onConfirm : null),
      ]),
    );
  }
}
