import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

/// Location pill that floats over a full-bleed map: a pin, a short place name and an optional
/// caption ("Pickup", "Your location"). Translucent surface, soft shadow, pill shape.
class NaqlLocationPill extends StatelessWidget {
  const NaqlLocationPill({
    super.key,
    required this.label,
    this.caption,
    this.icon = LucideIcons.mapPin,
    this.onTap,
    this.accent = false,
  });

  final String label;
  final String? caption;
  final IconData icon;
  final VoidCallback? onTap;

  /// Gold pin (destination) instead of the primary pin.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final pinBg = accent
        ? NaqlColors.accent
        : (naqlIsDark ? NaqlColors.ink : NaqlColors.primary);
    final pinFg = accent
        ? NaqlColors.onAccent
        : (naqlIsDark ? NaqlColors.onInk : NaqlColors.onPrimary);
    final pill = Container(
      constraints: const BoxConstraints(minHeight: NaqlTouch.min),
      padding: const EdgeInsetsDirectional.only(
        start: NaqlSpace.s1 + 2,
        end: NaqlSpace.s4,
        top: NaqlSpace.s1,
        bottom: NaqlSpace.s1,
      ),
      decoration: BoxDecoration(
        color: NaqlColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(NaqlRadius.pill),
        boxShadow: naqlFloatShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: pinBg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: pinFg),
          ),
          const SizedBox(width: NaqlSpace.s2),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (caption != null)
                  Text(
                    caption!,
                    style: NaqlText.caption.copyWith(fontSize: 11, height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  label,
                  style: NaqlText.label.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final labelled = Semantics(
      label: [caption, label].whereType<String>().join(': '),
      excludeSemantics: true,
      child: pill,
    );
    return onTap == null
        ? labelled
        : NaqlPressable(
            onPressed: onTap,
            semanticLabel: [caption, label].whereType<String>().join(': '),
            child: pill,
          );
  }
}

/// Small round marker for a point on the map (pickup ring, destination dot, vehicle).
class NaqlMapMarker extends StatelessWidget {
  const NaqlMapMarker({
    super.key,
    this.icon,
    this.accent = false,
    this.ring = false,
    this.size = 36,
  });

  /// Icon in the marker. Null draws a plain dot.
  final IconData? icon;

  /// Gold (destination / vehicle highlight) instead of primary.
  final bool accent;

  /// Pickup style: hollow ring.
  final bool ring;
  final double size;

  @override
  Widget build(BuildContext context) {
    final strong = accent
        ? NaqlColors.accent
        : (naqlIsDark ? NaqlColors.ink : NaqlColors.primary);
    final onStrong = accent
        ? NaqlColors.onAccent
        : (naqlIsDark ? NaqlColors.onInk : NaqlColors.onPrimary);
    if (ring) {
      return Container(
        width: size * 0.6,
        height: size * 0.6,
        decoration: BoxDecoration(
          color: NaqlColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: strong, width: 4),
          boxShadow: naqlFloatShadow,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: strong,
        shape: BoxShape.circle,
        border: Border.all(color: NaqlColors.surface, width: 3),
        boxShadow: naqlFloatShadow,
      ),
      child: icon == null
          ? null
          : Icon(icon, size: size * 0.5, color: onStrong),
    );
  }
}

/// Bottom sheet card that sits over a full-bleed map: rounded top (or all corners when
/// [floating]), grab handle, surface colour, soft lift.
class NaqlMapSheet extends StatelessWidget {
  const NaqlMapSheet({
    super.key,
    required this.child,
    this.floating = false,
    this.padding = const EdgeInsets.fromLTRB(
      NaqlSpace.s5,
      NaqlSpace.s3,
      NaqlSpace.s5,
      NaqlSpace.s5,
    ),
  });

  final Widget child;
  final bool floating;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = floating
        ? BorderRadius.circular(NaqlRadius.lg + 4)
        : const BorderRadius.vertical(top: Radius.circular(NaqlRadius.lg + 4));
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: NaqlColors.surface,
        borderRadius: radius,
        border: naqlIsDark
            ? Border.all(color: NaqlColors.border.withValues(alpha: 0.7))
            : null,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 24,
            color: const Color(0xFF000000)
                .withValues(alpha: naqlIsDark ? 0.5 : 0.10),
          ),
        ],
      ),
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: NaqlSpace.s4),
              decoration: BoxDecoration(
                color: NaqlColors.border,
                borderRadius: BorderRadius.circular(NaqlRadius.pill),
              ),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Lays out a full-bleed map with a bottom sheet over it: the sheet takes its natural height (up
/// to [maxSheetFraction] of the screen) and the map fills the rest, running [overlap] pixels
/// under the sheet's rounded top so no background shows at the corners. The map's centre is
/// therefore the centre of the visible map plus half the overlap.
class NaqlMapScaffold extends StatelessWidget {
  const NaqlMapScaffold({
    super.key,
    required this.map,
    required this.sheet,
    this.overlap = 28,
    this.maxSheetFraction = 0.62,
  });

  final Widget map;
  final Widget sheet;
  final double overlap;
  final double maxSheetFraction;

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _MapSheetLayout(
      overlap: overlap,
      maxSheetFraction: maxSheetFraction,
    ),
    children: [
      LayoutId(id: _Slot.map, child: map),
      LayoutId(id: _Slot.sheet, child: sheet),
    ],
  );
}

enum _Slot { map, sheet }

class _MapSheetLayout extends MultiChildLayoutDelegate {
  _MapSheetLayout({required this.overlap, required this.maxSheetFraction});
  final double overlap;
  final double maxSheetFraction;

  @override
  void performLayout(Size size) {
    final sheet = layoutChild(
      _Slot.sheet,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: size.height * maxSheetFraction,
      ),
    );
    positionChild(_Slot.sheet, Offset(0, size.height - sheet.height));
    final mapHeight = (size.height - sheet.height + overlap).clamp(
      0.0,
      size.height,
    );
    layoutChild(_Slot.map, BoxConstraints.tight(Size(size.width, mapHeight)));
    positionChild(_Slot.map, Offset.zero);
  }

  @override
  bool shouldRelayout(_MapSheetLayout old) =>
      old.overlap != overlap || old.maxSheetFraction != maxSheetFraction;
}
