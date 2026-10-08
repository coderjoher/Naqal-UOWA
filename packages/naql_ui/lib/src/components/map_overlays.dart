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
      NaqlSpace.s4,
      NaqlSpace.s3,
      NaqlSpace.s4,
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
        : const BorderRadius.vertical(top: Radius.circular(32));
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Dark: the sheet is the page itself (near-black) with a hairline on top, so the
        // charcoal panels inside it stand out. Light: a white sheet with a soft lift.
        color: naqlIsDark ? NaqlColors.bg : NaqlColors.surface,
        borderRadius: radius,
        border: naqlIsDark
            ? (floating ? Border.all(color: NaqlColors.border) : Border(top: BorderSide(color: NaqlColors.border)))
            : null,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -8),
            blurRadius: 30,
            color: const Color(0xFF000000)
                .withValues(alpha: naqlIsDark ? 0.5 : 0.08),
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
              margin: const EdgeInsets.only(bottom: NaqlSpace.s3 + 2),
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


/// Decoration for anything that floats over a map: translucent charcoal with a hairline in dark
/// mode, white with a soft shadow in light mode.
BoxDecoration naqlFloatingDecoration({double radius = NaqlRadius.pill, double alpha = 0.92}) => BoxDecoration(
      color: naqlIsDark ? NaqlColors.surface.withValues(alpha: alpha) : NaqlColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: naqlIsDark ? Border.all(color: NaqlColors.border) : null,
      boxShadow: naqlIsDark ? null : naqlFloatShadow,
    );

/// Wide pill over a map with an icon and a short place ("Hay Al-Hussein, Karbala").
class NaqlPlacePill extends StatelessWidget {
  const NaqlPlacePill({super.key, required this.label, this.icon = LucideIcons.navigation, this.onTap, this.semanticLabel});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      height: NaqlTouch.min,
      padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4),
      decoration: naqlFloatingDecoration(),
      child: Row(children: [
        Icon(icon, size: 16, color: naqlIsDark ? NaqlColors.accent : NaqlColors.primary),
        const SizedBox(width: NaqlSpace.s2),
        Expanded(child: Text(label, style: NaqlText.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
    return NaqlPressable(onPressed: onTap, pressedScale: 0.98, semanticLabel: semanticLabel ?? label, child: ExcludeSemantics(child: pill));
  }
}

/// Round avatar button that opens the account / menu: the person's initial on blue (light) or
/// charcoal (dark), with a ring so it reads over any map.
class NaqlAvatarButton extends StatelessWidget {
  const NaqlAvatarButton({super.key, required this.name, required this.onPressed, required this.semanticLabel, this.size = NaqlTouch.min});
  final String name;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final n = name.trim();
    final dark = naqlIsDark;
    return NaqlPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      minSize: size,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? NaqlColors.surfaceMuted : NaqlColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: dark ? NaqlColors.border : NaqlColors.surface, width: 2),
          boxShadow: dark ? null : naqlFloatShadow,
        ),
        child: ExcludeSemantics(
          child: Text(n.isEmpty ? '' : n.characters.first, style: NaqlText.headline.copyWith(height: 1, color: dark ? NaqlColors.text : NaqlColors.onPrimary)),
        ),
      ),
    );
  }
}

/// Stylised street blocks drawn under the map tiles: what the map looks like before tiles load,
/// offline, and in tests and previews. Tiles cover it once they arrive.
class NaqlMapBackdrop extends StatelessWidget {
  const NaqlMapBackdrop({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: CustomPaint(painter: _BackdropPainter(NaqlColors.current), child: const SizedBox.expand()));
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.p);
  final NaqlPalette p;

  // One 390 × 520 tile of blocks, as in the mockups; repeated to fill any size.
  static const _blocks = [
    Rect.fromLTWH(18, 24, 96, 70), Rect.fromLTWH(130, 24, 120, 70), Rect.fromLTWH(266, 24, 106, 70),
    Rect.fromLTWH(18, 112, 70, 110), Rect.fromLTWH(104, 112, 146, 50), Rect.fromLTWH(266, 112, 106, 110),
    Rect.fromLTWH(104, 178, 146, 44), Rect.fromLTWH(18, 240, 160, 90), Rect.fromLTWH(196, 240, 176, 90),
    Rect.fromLTWH(18, 348, 110, 120), Rect.fromLTWH(146, 348, 226, 56), Rect.fromLTWH(146, 420, 226, 80),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final dark = identical(p, NaqlPalette.dark);
    final ground = dark ? Color.lerp(p.bg, p.surface, 0.36)! : Color.lerp(p.surfaceMuted, p.border, 0.3)!;
    final block = dark ? Color.lerp(p.bg, p.surface, 0.9)! : Color.lerp(p.bg, p.surface, 0.55)!;
    final park = dark ? Color.lerp(block, p.success, 0.06)! : Color.lerp(block, p.success, 0.14)!;
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final paint = Paint()..color = block;
    for (var oy = 0.0; oy < size.height; oy += 520) {
      for (var ox = 0.0; ox < size.width; ox += 390) {
        for (final (i, r) in _blocks.indexed) {
          canvas.drawRRect(RRect.fromRectAndRadius(r.shift(Offset(ox, oy)), const Radius.circular(6)), i == 8 ? (Paint()..color = park) : paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => !identical(old.p, p);
}
