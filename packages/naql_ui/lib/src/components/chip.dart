import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

/// Selectable pill (wave / date tabs). Selected = solid primary.
class NaqlChip extends StatelessWidget {
  const NaqlChip({super.key, required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: NaqlPressable(
        onPressed: onSelected,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: NaqlMotion.fast,
          height: NaqlTouch.min,
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? NaqlColors.primary : NaqlColors.surface,
            borderRadius: BorderRadius.circular(NaqlRadius.pill),
            border: selected ? null : Border.all(color: NaqlColors.border),
          ),
          child: Text(label, semanticsLabel: '', style: NaqlText.label.copyWith(color: selected ? NaqlColors.onPrimary : NaqlColors.text)),
        ),
      ),
    );
  }
}
