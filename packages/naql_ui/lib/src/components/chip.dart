import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

/// Selectable pill (wave / date tabs, quick destinations such as "Home" or "Campus").
/// Selected = solid primary (light) or the ink pill (dark). An optional leading [icon] makes it a
/// quick-destination chip; [floating] gives it a translucent surface and shadow over a map.
class NaqlChip extends StatelessWidget {
  const NaqlChip({super.key, required this.label, required this.selected, required this.onSelected, this.icon, this.floating = false});

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final IconData? icon;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final dark = naqlIsDark;
    final selBg = dark ? NaqlColors.ink : NaqlColors.primary;
    final selFg = dark ? NaqlColors.onInk : NaqlColors.onPrimary;
    final idleBg = floating ? NaqlColors.surface.withValues(alpha: 0.94) : (dark ? NaqlColors.surfaceMuted : NaqlColors.surface);
    final fg = selected ? selFg : NaqlColors.text;
    return Semantics(
      selected: selected,
      child: NaqlPressable(
        onPressed: onSelected,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: naqlMotion(context),
          curve: Curves.easeOutCubic,
          height: NaqlTouch.min,
          padding: EdgeInsetsDirectional.only(start: icon == null ? NaqlSpace.s5 : NaqlSpace.s4, end: NaqlSpace.s5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selBg : idleBg,
            borderRadius: BorderRadius.circular(NaqlRadius.pill),
            border: selected || (dark && !floating) ? null : Border.all(color: NaqlColors.border),
            boxShadow: floating ? naqlFloatShadow : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: selected ? selFg : NaqlColors.textMuted), const SizedBox(width: NaqlSpace.s2)],
            Text(label, semanticsLabel: '', style: NaqlText.label.copyWith(color: fg, fontWeight: icon == null ? null : FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
