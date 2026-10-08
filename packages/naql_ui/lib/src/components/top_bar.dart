import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

enum NaqlIconButtonStyle {
  /// Surface circle with a hairline border (top bars).
  outline,

  /// Translucent surface with a soft shadow, to float over a map.
  floating,

  /// Soft filled circle (call / message actions in cards).
  soft,

  /// Solid primary (light) / ink (dark) circle for the main action in a row.
  solid,
}

/// Circular icon button (back, notifications, call…) as in the reference designs.
class NaqlIconButton extends StatelessWidget {
  const NaqlIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.badge = false,
    this.style = NaqlIconButtonStyle.outline,
    this.size = NaqlTouch.min,
  });

  /// Shortcut for a round control that floats over a map.
  const NaqlIconButton.floating({super.key, required this.icon, required this.onPressed, required this.semanticLabel, this.badge = false, this.size = NaqlTouch.min})
      : style = NaqlIconButtonStyle.floating;

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool badge;
  final NaqlIconButtonStyle style;

  /// Diameter; at least 48 dp (use 56 in the driver app).
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = naqlIsDark;
    final (Color bg, Color fg, BoxBorder? border, List<BoxShadow>? shadow) = switch (style) {
      NaqlIconButtonStyle.outline => (NaqlColors.surface, NaqlColors.text, Border.all(color: NaqlColors.border), null),
      NaqlIconButtonStyle.floating => (NaqlColors.surface.withValues(alpha: 0.94), NaqlColors.text, null, naqlFloatShadow),
      NaqlIconButtonStyle.soft => (dark ? NaqlColors.surfaceMuted : NaqlColors.primarySoft, dark ? NaqlColors.text : NaqlColors.primary, null, null),
      NaqlIconButtonStyle.solid => (dark ? NaqlColors.ink : NaqlColors.primary, dark ? NaqlColors.onInk : NaqlColors.onPrimary, null, null),
    };
    return NaqlPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      minSize: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: border, boxShadow: shadow),
          child: Icon(icon, size: size > NaqlTouch.min ? 22 : 20, color: fg),
        ),
        if (badge)
          PositionedDirectional(
            top: 10,
            end: 12,
            child: Container(width: 9, height: 9, decoration: BoxDecoration(color: NaqlColors.danger, shape: BoxShape.circle, border: Border.all(color: NaqlColors.surface, width: 1.5))),
          ),
      ]),
    );
  }
}

/// Flat top bar: optional back button, centred title + subtitle, optional trailing action.
/// Replaces Material AppBar (no elevation, no scroll tint).
class NaqlTopBar extends StatelessWidget implements PreferredSizeWidget {
  const NaqlTopBar({super.key, required this.title, this.subtitle, this.onBack, this.trailing, this.backLabel = 'Back'});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final String backLabel;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: preferredSize.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5),
          child: Row(children: [
            SizedBox(
              width: NaqlTouch.min,
              child: onBack == null
                  ? null
                  : NaqlIconButton(icon: rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft, onPressed: onBack, semanticLabel: backLabel),
            ),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title, style: NaqlText.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) Text(subtitle!, style: NaqlText.caption),
              ]),
            ),
            SizedBox(width: NaqlTouch.min, child: trailing),
          ]),
        ),
      ),
    );
  }
}
