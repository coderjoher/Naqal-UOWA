import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

// The driving screens (bus run, taxi ride), after the "driver during a run" design: a map on
// top with a blue instruction card, and a sheet with progress, the big place name, the riders
// and one big gold action pinned at the bottom. Every target is at least 56 dp.

/// Map tiles from the network. Tests turn them off.
final driverMapTilesProvider = Provider<bool>((ref) => true);

/// One point on the driving map.
class DrivePoint {
  const DrivePoint(this.at, {required this.label, this.current = false, this.number, this.done = false});
  final LatLng at;
  final String label;

  /// The place to drive to now (gold).
  final bool current;

  /// Stop number shown in the marker.
  final String? number;
  final bool done;
}

class DriveScaffold extends StatelessWidget {
  const DriveScaffold({
    super.key,
    required this.map,
    required this.instruction,
    this.onBack,
    required this.children,
    this.action,
    this.mapFraction = 0.40,
  });

  final Widget map;
  final Widget instruction;
  /// Null while a taxi ride is going: the ride is the whole screen until it ends.
  final VoidCallback? onBack;
  final List<Widget> children;

  /// The one big action, pinned under the sheet's content.
  final Widget? action;
  final double mapFraction;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dark = naqlIsDark;
    final top = h * mapFraction;
    return Scaffold(
      body: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, height: top + 32, child: map),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(NaqlSpace.s3, NaqlSpace.s3, NaqlSpace.s3, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (onBack != null) ...[
                  NaqlIconButton.floating(
                    icon: rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
                    onPressed: onBack,
                    semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
                    size: NaqlTouch.driver,
                  ),
                  const SizedBox(width: NaqlSpace.s2),
                ],
                Expanded(child: instruction),
              ]),
            ),
          ),
        ),
        Positioned(
          top: top,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: dark ? NaqlColors.bg : NaqlColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: dark ? Border(top: BorderSide(color: NaqlColors.border)) : null,
              boxShadow: [BoxShadow(offset: const Offset(0, -8), blurRadius: 30, color: const Color(0xFF000000).withValues(alpha: dark ? 0.5 : 0.08))],
            ),
            child: Column(children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: NaqlSpace.s3, bottom: NaqlSpace.s2),
                decoration: BoxDecoration(color: NaqlColors.border, borderRadius: BorderRadius.circular(NaqlRadius.pill)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s1, NaqlSpace.s4, NaqlSpace.s4),
                  children: children,
                ),
              ),
              if (action != null)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: NaqlSpace.s4),
                  child: Padding(padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s2, NaqlSpace.s4, 0), child: action),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// The map behind a driving screen: the route through the points, the next one in gold, and the
/// vehicle where the last GPS fix put it.
class DriveMap extends StatelessWidget {
  const DriveMap({super.key, required this.points, this.here, required this.tiles, required this.hereLabel});
  final List<DrivePoint> points;
  final LatLng? here;
  final bool tiles;
  final String hereLabel;

  @override
  Widget build(BuildContext context) {
    final all = [for (final p in points) p.at, ?here];
    final distinct = all.map((p) => '${p.latitude},${p.longitude}').toSet().length;
    final route = [?here, for (final p in points.where((p) => !p.done)) p.at];
    return Stack(children: [
      const Positioned.fill(child: NaqlMapBackdrop()),
      if (all.isNotEmpty)
        Positioned.fill(
          child: FlutterMap(
            options: MapOptions(
              backgroundColor: const Color(0x00000000),
              initialCameraFit: distinct > 1 ? CameraFit.coordinates(coordinates: all, padding: const EdgeInsets.fromLTRB(56, 150, 56, 72), maxZoom: 16) : null,
              initialCenter: all.first,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              if (tiles) NaqlMapTint(child: TileLayer(urlTemplate: mapTilesUrl, userAgentPackageName: 'iq.edu.uowa.naql.driver')),
              if (route.length > 1) PolylineLayer(polylines: [Polyline(points: route, strokeWidth: 5, color: NaqlColors.primary)]),
              MarkerLayer(markers: [
                for (final p in points)
                  Marker(
                    point: p.at,
                    width: p.current ? 32 : 26,
                    height: p.current ? 32 : 26,
                    child: Semantics(
                      label: p.label,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.current ? NaqlColors.accent : (p.done ? NaqlColors.success : NaqlColors.surface),
                          shape: BoxShape.circle,
                          border: Border.all(color: p.current ? NaqlColors.bg : NaqlColors.primary, width: p.current ? 4 : 2),
                        ),
                        child: p.number == null || p.current ? null : Text(p.number!, style: NaqlText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: NaqlColors.text)),
                      ),
                    ),
                  ),
                if (here != null)
                  Marker(
                    point: here!,
                    width: 40,
                    height: 40,
                    child: Semantics(
                      label: hereLabel,
                      child: Container(
                        decoration: BoxDecoration(color: NaqlColors.primary.withValues(alpha: 0.25), shape: BoxShape.circle),
                        child: Icon(LucideIcons.navigation2, size: 22, color: NaqlColors.ink),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
        ),
    ]);
  }
}

/// Small caption over the big place name, with a round 56 dp navigate button on the end.
class DriveHeading extends StatelessWidget {
  const DriveHeading({super.key, required this.caption, required this.title, this.navigate});
  final String caption;
  final String title;
  final Widget? navigate;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(caption, style: NaqlText.caption.copyWith(fontSize: 13)),
            Text(title, style: NaqlText.title.copyWith(fontSize: 26, height: 1.3, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (navigate != null) ...[const SizedBox(width: NaqlSpace.s3), navigate!],
      ]);
}

/// The round blue "open navigation" button.
class NavigateButton extends StatelessWidget {
  const NavigateButton({super.key, required this.onPressed, required this.label});
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => NaqlPressable(
        onPressed: onPressed,
        semanticLabel: label,
        minSize: NaqlTouch.driver,
        child: Container(
          width: NaqlTouch.driver,
          height: NaqlTouch.driver,
          decoration: BoxDecoration(color: NaqlColors.primarySoft, shape: BoxShape.circle),
          child: Icon(LucideIcons.navigation, size: 24, color: NaqlColors.primary),
        ),
      );
}

/// Distance as the driver reads it: "200 m" under a kilometre, "1.4 km" above.
(String value, bool metres) driveDistance(LatLng from, LatLng to) {
  final m = const Distance().as(LengthUnit.Meter, from, to);
  if (m < 1000) return ('${(m / 10).round() * 10}', true);
  return ((m / 1000).toStringAsFixed(1), false);
}
