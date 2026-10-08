import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

/// Selectable pill (wave / date tabs, quick destinations such as "Home" or "Campus").
/// Selected = solid primary (light) or the ink pill (dark). An optional leading [icon] makes it a
/// quick-destination chip; [floating] gives it a translucent surface and shadow over a map.
class NaqlChip extends StatelessWidget {
  const NaqlChip({super.key, required this.label, required this.selected, required this.onSelected, this.icon, this.floating = false, this.iconColor});

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final IconData? icon;
  final bool floating;

  /// Icon colour when not selected (e.g. gold for the campus).
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final dark = naqlIsDark;
    final selBg = dark ? NaqlColors.ink : NaqlColors.primary;
    final selFg = dark ? NaqlColors.onInk : NaqlColors.onPrimary;
    final idleBg = floating ? (dark ? NaqlColors.surface.withValues(alpha: 0.92) : NaqlColors.surface) : (dark ? NaqlColors.surfaceMuted : NaqlColors.surface);
    final fg = selected ? selFg : NaqlColors.text;
    return Semantics(
      selected: selected,
      child: NaqlPressable(
        onPressed: onSelected,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: naqlMotion(context),
          curve: Curves.easeOutCubic,
          // Over a map the chip is drawn 40 dp tall; the tap target stays 48 dp (NaqlPressable).
          height: floating ? 40 : NaqlTouch.min,
          padding: EdgeInsetsDirectional.only(start: icon == null ? NaqlSpace.s5 : (floating ? 14 : NaqlSpace.s4), end: floating ? 14 : NaqlSpace.s5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selBg : idleBg,
            borderRadius: BorderRadius.circular(NaqlRadius.pill),
            border: selected || (dark && !floating) || (floating && !dark) ? null : Border.all(color: NaqlColors.border),
            boxShadow: floating && !dark ? naqlFloatShadow : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: floating ? 15 : 18, color: selected ? selFg : (iconColor ?? NaqlColors.textMuted)), SizedBox(width: floating ? 6 : NaqlSpace.s2)],
            Text(label, semanticsLabel: '', style: (floating ? NaqlText.label.copyWith(fontSize: 13) : NaqlText.label).copyWith(color: fg, fontWeight: icon == null || floating ? FontWeight.w500 : FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
