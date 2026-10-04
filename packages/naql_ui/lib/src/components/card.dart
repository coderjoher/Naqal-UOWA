import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

/// White rounded surface on the tinted background. Nested cards are flat with a border.
class NaqlCard extends StatelessWidget {
  const NaqlCard({super.key, required this.child, this.onTap, this.nested = false, this.padding = const EdgeInsets.all(NaqlSpace.s5)});

  final Widget child;
  final VoidCallback? onTap;
  final bool nested;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: nested ? NaqlColors.surfaceMuted : NaqlColors.surface,
        borderRadius: BorderRadius.circular(nested ? NaqlRadius.md : NaqlRadius.lg),
        boxShadow: nested ? null : naqlCardShadow,
      ),
      child: child,
    );
    return onTap == null ? box : NaqlPressable(onPressed: onTap, pressedScale: 0.99, child: box);
  }
}
