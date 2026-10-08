import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

/// Tappable row inside a card: optional leading icon/badge, title, subtitle, trailing check or chevron.
class NaqlListRow extends StatelessWidget {
  const NaqlListRow({super.key, required this.title, this.subtitle, this.leading, this.selected = false, this.selectable = false, this.onTap, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;

  /// Part of a "choose one" list: shows an empty circle instead of a chevron when not selected.
  final bool selectable;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      selected: selected,
      child: NaqlPressable(
        onPressed: onTap,
        semanticLabel: title,
        pressedScale: 0.98,
        child: AnimatedContainer(
          duration: NaqlMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: NaqlSpace.s3),
          decoration: BoxDecoration(
            color: selected ? NaqlColors.primarySoft : NaqlColors.surface,
            borderRadius: BorderRadius.circular(NaqlRadius.md),
            border: Border.all(color: selected ? NaqlColors.primary : NaqlColors.border),
          ),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: NaqlSpace.s3)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: NaqlText.label.copyWith(fontWeight: FontWeight.w600), semanticsLabel: ''),
                if (subtitle != null) Text(subtitle!, style: NaqlText.caption),
              ]),
            ),
            trailing ??
                (selected
                    ? Icon(LucideIcons.circleCheck, color: NaqlColors.primary, size: 22)
                    : selectable
                        ? Icon(LucideIcons.circle, color: NaqlColors.border, size: 22)
                        : Icon(rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight, color: NaqlColors.textMuted, size: 20)),
          ]),
        ),
      ),
    );
  }
}

/// Read-only label/value pair. `locked` shows that the value comes from the university record.
class NaqlInfoRow extends StatelessWidget {
  const NaqlInfoRow({super.key, required this.label, required this.value, this.locked = false, this.lockedHint});

  final String label;
  final String value;
  final bool locked;
  final String? lockedHint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value${locked && lockedHint != null ? '. $lockedHint' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NaqlSpace.s2),
        child: Row(children: [
          Expanded(child: Text(label, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))),
          Text(value, style: NaqlText.body.copyWith(fontWeight: FontWeight.w600)),
          if (locked) ...[const SizedBox(width: NaqlSpace.s2), Icon(LucideIcons.lock, size: 16, color: NaqlColors.textMuted)],
        ]),
      ),
    );
  }
}

/// Small round badge with a short text (e.g. tier letter).
class NaqlLetterBadge extends StatelessWidget {
  const NaqlLetterBadge(this.text, {super.key, this.active = true});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? NaqlColors.primary : NaqlColors.surfaceMuted, shape: BoxShape.circle),
        child: Text(text, style: NaqlText.label.copyWith(color: active ? NaqlColors.onPrimary : NaqlColors.textMuted, fontWeight: FontWeight.w600)),
      );
}
