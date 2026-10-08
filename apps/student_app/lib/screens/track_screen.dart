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
import '../data/taxi.dart';
import '../data/track.dart';
import '../l10n/gen/app_localizations.dart';
import 'live_ride.dart';
import 'taxi_widgets.dart';

/// Older than this, a position is shown as "last known" (NF-10).
const staleAfter = Duration(seconds: 30);

/// ST-06: the bus live. Full-bleed map with the bus and the student's stop, the arrival time
/// floating on top, and the driver, vehicle (with plate) and route floating at the bottom.
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
    final ride = ref.watch(ridesProvider).value?.where((r) => r.id == widget.requestId).firstOrNull;
    void back() => context.canPop() ? context.pop() : context.go('/home');
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
        data: (s) => _Body(state: s, lang: lang, tiles: ref.watch(mapTilesProvider), ride: ride, onBack: back),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.lang, required this.tiles, required this.onBack, this.ride});
  final TrackState state;
  final String lang;
  final bool tiles;
  final VoidCallback onBack;
  final RideInfo? ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final info = state.info;
    final bus = state.bus;
    final stop = info.stopLat == null ? null : LatLng(info.stopLat!, info.stopLng!);
    final now = clock.now();
    final age = bus == null ? null : now.difference(bus.at);
    final stale = bus != null && (!state.connected || age! > staleAfter);
    final eta = bus == null || info.stopSeq == null ? null : bus.etas[info.stopSeq];
    final a = ride?.assignment;
    final busAt = bus == null ? null : LatLng(bus.lat, bus.lng);
    final dial = ref.read(taxiDialerProvider);

    final String headline = switch (info) {
      _ when info.boarded => t.onBus,
      _ when !info.moving => t.notStarted,
      _ when eta != null && eta < 60 => t.etaNow,
      _ when eta != null => t.etaMinutes((eta / 60).ceil()),
      _ => t.notStarted,
    };
    final live = info.moving && !stale && !info.boarded;

    final stopName = info.stopName == null ? null : (lang == 'ar' && info.stopNameAr != null ? info.stopNameAr : info.stopName);
    final pickup = eta != null && info.moving ? formatClock(now.add(Duration(seconds: eta))) : (a?.pickupAt == null ? null : formatClock(a!.pickupAt!));
    final morning = ride?.waveType != WaveType.ret;
    final mine = NaqlTimelineStop(title: stopName == null ? t.yourStop : '${t.yourStop}: $stopName', time: pickup);
    final campus = NaqlTimelineStop(title: t.rideCampus, time: ride?.waveTime);

    final map = ColoredBox(
      color: NaqlColors.bg,
      child: Stack(children: [
        const Positioned.fill(child: NaqlMapBackdrop()),
        if (stop != null || busAt != null)
          Positioned.fill(
            child: FlutterMap(
              key: const ValueKey('track-map'),
              options: MapOptions(
                backgroundColor: const Color(0x00000000),
                initialCameraFit: busAt != null && stop != null
                    ? CameraFit.bounds(bounds: LatLngBounds(busAt, stop), padding: EdgeInsets.fromLTRB(64, 130, 64, MediaQuery.sizeOf(context).height * 0.5), maxZoom: 16)
                    : null,
                initialCenter: stop ?? busAt!,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                if (tiles) NaqlMapTint(child: TileLayer(urlTemplate: mapTilesUrl, userAgentPackageName: 'iq.edu.uowa.naql.student')),
                if (busAt != null && stop != null)
                  PolylineLayer(polylines: [Polyline(points: [busAt, stop], strokeWidth: 3, color: NaqlColors.danger)]),
                MarkerLayer(markers: [
                  if (stop != null)
                    Marker(point: stop, width: 44, height: 44, child: TaxiMapPin(key: const ValueKey('stop-pin'), icon: LucideIcons.mapPin, label: t.yourStop, color: NaqlColors.danger, onColor: NaqlColors.surface)),
                ]),
                if (busAt != null) _AnimatedBus(to: busAt, label: t.busLabel, stale: stale),
                if (tiles) const TaxiAttribution(text: mapAttribution, bottom: 8),
              ],
            ),
          ),
      ]),
    );

    return Stack(children: [
      Positioned.fill(child: map),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: LiveTopBar(
          onBack: onBack,
          center: AnimatedSwitcher(
            duration: naqlMotion(context),
            child: live
                ? NaqlLivePill(key: const ValueKey('live'), label: headline, floating: true)
                : LiveStatusPill(key: const ValueKey('still'), label: headline),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: LiveBottom(children: [
          if (age != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill(
                key: const ValueKey('freshness'),
                label: stale ? '${t.lastKnown} · ${t.updatedAgo(_ago(t, age))}' : t.updatedAgo(_ago(t, age)),
                tone: stale ? NaqlTone.warning : NaqlTone.success,
                icon: stale ? LucideIcons.wifiOff : LucideIcons.radio,
              ),
            ),
          if (a != null)
            LiveDriverPanel(
              name: a.driverName,
              vehicleCaption: t.trackTitle,
              vehicleTitle: a.vehicleType,
              vehicleSub: a.stopNumber != null && a.stops != null ? t.rideStopOf('${a.stopNumber}', '${a.stops}') : null,
              plate: a.plate,
              onCall: a.driverPhone == null ? null : () => dial(Uri(scheme: 'tel', path: a.driverPhone)),
              onMessage: a.driverPhone == null ? null : () => dial(Uri(scheme: 'sms', path: a.driverPhone)),
              callKey: const ValueKey('bus-call'),
            )
          else
            Text(t.trackTitle, style: NaqlText.headline),
          LiveRoutePanel(stops: morning ? [mine, campus] : [NaqlTimelineStop(title: t.rideCampus, time: ride?.waveTime), mine]),
        ]),
      ),
    ]);
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
      tween: LatLngTween(begin: to, end: to),
      duration: naqlMotion(context, const Duration(milliseconds: 900)),
      curve: Curves.easeOutCubic,
      builder: (_, p, _) => MarkerLayer(markers: [
        Marker(
          point: p,
          width: 48,
          height: 48,
          child: TaxiMapPin(
            key: const ValueKey('bus-pin'),
            icon: LucideIcons.busFront,
            label: label,
            color: stale ? NaqlColors.textMuted : (naqlIsDark ? NaqlColors.ink : NaqlColors.primary),
            onColor: stale ? NaqlColors.surface : (naqlIsDark ? NaqlColors.onInk : NaqlColors.onPrimary),
            square: true,
          ),
        ),
      ]),
    );
  }
}
