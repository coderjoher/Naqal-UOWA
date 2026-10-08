import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/rides.dart';
import '../data/track.dart';
import '../l10n/gen/app_localizations.dart';
import 'taxi_widgets.dart';

/// Older than this, a position is shown as "last known" (NF-10).
const staleAfter = Duration(seconds: 30);

/// ST-06: the bus on a map with the time to the student's stop.
class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final track = ref.watch(trackProvider(widget.requestId));
    // The assignment (driver, bus, plate) comes with the student's ride.
    final assignment = ref.watch(ridesProvider).value?.where((r) => r.id == widget.requestId).firstOrNull?.assignment;
    void back() => context.go('/home');
    return Scaffold(
      body: track.when(
        loading: () => TaxiBarFrame(
          title: t.trackTitle,
          onBack: back,
          child: const Padding(padding: EdgeInsets.all(NaqlSpace.s5), child: NaqlSkeleton(height: 320, radius: NaqlRadius.lg)),
        ),
        error: (e, _) => TaxiBarFrame(
          title: t.trackTitle,
          onBack: back,
          child: Center(child: NaqlEmptyState(icon: LucideIcons.wifiOff, title: t.loadFailed)),
        ),
        data: (s) => _Body(state: s, lang: lang, tiles: ref.watch(mapTilesProvider), assignment: assignment, onBack: back),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.lang, required this.tiles, required this.onBack, this.assignment});
  final TrackState state;
  final String lang;
  final bool tiles;
  final VoidCallback onBack;
  final RideAssignment? assignment;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final info = state.info;
    final bus = state.bus;
    final stop = info.stopLat == null ? null : LatLng(info.stopLat!, info.stopLng!);
    final now = clock.now();
    final age = bus == null ? null : now.difference(bus.at);
    final stale = bus != null && (!state.connected || age! > staleAfter);
    final eta = bus == null || info.stopSeq == null ? null : bus.etas[info.stopSeq];
    final a = assignment;
    const overlap = 28.0;

    final (String headline, NaqlTone tone) = switch (info) {
      _ when info.boarded => (t.onBus, NaqlTone.success),
      _ when !info.moving => (t.notStarted, NaqlTone.neutral),
      _ when eta != null && eta < 60 => (t.etaNow, NaqlTone.success),
      _ when eta != null => (t.etaMinutes((eta / 60).ceil()), NaqlTone.primary),
      _ => (t.notStarted, NaqlTone.neutral),
    };

    final map = Stack(children: [
      Positioned.fill(
        child: ColoredBox(
          color: NaqlColors.surfaceMuted,
          child: stop == null && bus == null
              ? const SizedBox.expand()
              : FlutterMap(
                  key: const ValueKey('track-map'),
                  options: MapOptions(
                    backgroundColor: NaqlColors.surfaceMuted,
                    initialCameraFit: bus != null && stop != null
                        ? CameraFit.bounds(bounds: LatLngBounds(LatLng(bus.lat, bus.lng), stop), padding: const EdgeInsets.fromLTRB(56, 120, 56, 56 + overlap), maxZoom: 16)
                        : null,
                    initialCenter: stop ?? LatLng(bus!.lat, bus.lng),
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    if (tiles) NaqlMapTint(child: TileLayer(urlTemplate: mapTilesUrl, userAgentPackageName: 'iq.edu.uowa.naql.student')),
                    MarkerLayer(markers: [
                      if (stop != null)
                        Marker(point: stop, width: 44, height: 44, child: _Pin(key: const ValueKey('stop-pin'), icon: LucideIcons.mapPin, label: t.yourStop, color: NaqlColors.ink, onColor: NaqlColors.onInk)),
                    ]),
                    if (bus != null) _AnimatedBus(to: LatLng(bus.lat, bus.lng), label: t.busLabel, stale: stale),
                    if (tiles) const TaxiAttribution(text: mapAttribution, bottom: overlap),
                  ],
                ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: TaxiMapTop(
          title: t.trackTitle,
          onBack: onBack,
          backLabel: MaterialLocalizations.of(context).backButtonTooltip,
          below: eta != null && !info.boarded && info.moving && !stale ? NaqlLivePill(label: t.taxiMinutes((eta / 60).ceil()), semanticLabel: headline, floating: true) : null,
        ),
      ),
    ]);

    final sheet = NaqlMapSheet(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AnimatedSwitcher(
                    duration: naqlMotion(context),
                    child: Text(headline, key: ValueKey(headline), style: NaqlText.title.copyWith(fontSize: 24)),
                  ),
                  if (info.stopName != null)
                    Text('${t.yourStop}: ${lang == 'ar' && info.stopNameAr != null ? info.stopNameAr : info.stopName}', style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
                ]),
              ),
              const SizedBox(width: NaqlSpace.s3),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(NaqlRadius.md)),
                child: Icon(LucideIcons.busFront, color: tone.fg),
              ),
            ]),
            if (age != null) ...[
              const SizedBox(height: NaqlSpace.s3),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusPill(
                  key: const ValueKey('freshness'),
                  label: stale ? '${t.lastKnown} · ${t.updatedAgo(_ago(t, age))}' : t.updatedAgo(_ago(t, age)),
                  tone: stale ? NaqlTone.warning : NaqlTone.success,
                  icon: stale ? LucideIcons.wifiOff : LucideIcons.radio,
                ),
              ),
            ],
            if (a != null) ...[
              const SizedBox(height: NaqlSpace.s4),
              // Person card (the driver) and vehicle card (type and plate).
              NaqlCard(nested: true, padding: const EdgeInsets.all(NaqlSpace.s3), child: NaqlPersonCard(name: a.driverName, caption: t.driverCaption)),
              if (a.vehicleType != null || a.plate != null) ...[
                const SizedBox(height: NaqlSpace.s2),
                NaqlCard(
                  nested: true,
                  padding: const EdgeInsets.all(NaqlSpace.s3),
                  child: Row(children: [
                    const NaqlIconTile(LucideIcons.busFront, size: 52),
                    const SizedBox(width: NaqlSpace.s3),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.vehicleCaption, style: NaqlText.caption),
                        if (a.vehicleType != null) Text(a.vehicleType!, style: NaqlText.headline.copyWith(fontSize: 17)),
                      ]),
                    ),
                    if (a.plate != null) NaqlPlateBadge(a.plate!),
                  ]),
                ),
              ],
            ],
            // Room for the floating tab bar (this screen lives inside the Home tab).
            const SizedBox(height: 88),
          ]),
        ),
      ),
    );
    return NaqlMapScaffold(map: map, sheet: sheet, overlap: overlap, maxSheetFraction: 0.55);
  }

  static String _ago(AppLocalizations t, Duration d) => d.inSeconds < 60 ? t.agoSeconds(d.inSeconds < 0 ? 0 : d.inSeconds) : t.agoMinutes(d.inMinutes);
}

/// The bus glides to each new position instead of jumping.
class _AnimatedBus extends StatelessWidget {
  const _AnimatedBus({required this.to, required this.label, required this.stale});
  final LatLng to;
  final String label;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<LatLng>(
      tween: _LatLngTween(end: to),
      duration: naqlMotion(context, const Duration(milliseconds: 900)),
      curve: Curves.easeOutCubic,
      builder: (_, p, _) => MarkerLayer(markers: [
        Marker(point: p, width: 48, height: 48, child: _Pin(
            key: const ValueKey('bus-pin'),
            icon: LucideIcons.busFront,
            label: label,
            color: stale ? NaqlColors.textMuted : NaqlColors.accent,
            onColor: stale ? NaqlColors.surface : NaqlColors.onAccent,
            square: true,
          )),
      ]),
    );
  }
}

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng end}) : super(begin: end, end: end);
  @override
  LatLng lerp(double t) => LatLng(begin!.latitude + (end!.latitude - begin!.latitude) * t, begin!.longitude + (end!.longitude - begin!.longitude) * t);
}

class _Pin extends StatelessWidget {
  const _Pin({super.key, required this.icon, required this.label, required this.color, this.onColor, this.square = false});
  final IconData icon;
  final String label;
  final Color color;
  final Color? onColor;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(14) : null,
          border: Border.all(color: NaqlColors.surface, width: 3),
          boxShadow: naqlFloatShadow,
        ),
        child: Icon(icon, color: onColor ?? NaqlColors.onPrimary, size: 22),
      ),
    );
  }
}
