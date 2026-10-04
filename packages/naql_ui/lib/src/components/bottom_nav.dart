import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

class NaqlNavItem {
  const NaqlNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Floating pill navigation (reference 1): the active item is a solid primary circle,
/// the rest sit in a white pill. Labels are exposed to screen readers.
class NaqlBottomNav extends StatelessWidget {
  const NaqlBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<NaqlNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: NaqlSpace.s4),
      child: Center(
        heightFactor: 1,
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(NaqlSpace.s2),
          decoration: BoxDecoration(color: NaqlColors.surface, borderRadius: BorderRadius.circular(NaqlRadius.pill), boxShadow: naqlCardShadow),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                Semantics(
                  selected: i == currentIndex,
                  child: NaqlPressable(
                    onPressed: () => onTap(i),
                    semanticLabel: items[i].label,
                    child: AnimatedContainer(
                      duration: NaqlMotion.fast,
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: NaqlSpace.s1),
                      decoration: BoxDecoration(color: i == currentIndex ? NaqlColors.primary : Colors.transparent, shape: BoxShape.circle),
                      child: Icon(items[i].icon, size: 22, color: i == currentIndex ? NaqlColors.onPrimary : NaqlColors.text),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
