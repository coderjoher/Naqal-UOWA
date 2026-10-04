import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

/// Circular white icon button (back, notifications…) as in the reference designs.
class NaqlIconButton extends StatelessWidget {
  const NaqlIconButton({super.key, required this.icon, required this.onPressed, required this.semanticLabel, this.badge = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return NaqlPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: NaqlTouch.min,
          height: NaqlTouch.min,
          decoration: BoxDecoration(color: NaqlColors.surface, shape: BoxShape.circle, border: Border.all(color: NaqlColors.border)),
          child: Icon(icon, size: 20, color: NaqlColors.text),
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
