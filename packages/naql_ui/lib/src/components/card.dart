import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

/// Rounded (24) surface card. Light mode: white on the tinted background with one soft shadow.
/// Dark mode: charcoal with a hairline border and no shadow. Nested cards are flat.
class NaqlCard extends StatelessWidget {
  const NaqlCard({super.key, required this.child, this.onTap, this.nested = false, this.padding = const EdgeInsets.all(NaqlSpace.s5), this.color});

  final Widget child;
  final VoidCallback? onTap;
  final bool nested;
  final EdgeInsetsGeometry padding;

  /// Optional fill (e.g. a soft tone for a highlight card). Defaults to the surface colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = naqlIsDark;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (nested ? NaqlColors.surfaceMuted : NaqlColors.surface),
        borderRadius: BorderRadius.circular(nested ? NaqlRadius.md : NaqlRadius.lg),
        border: dark && !nested ? Border.all(color: NaqlColors.border.withValues(alpha: 0.7)) : null,
        boxShadow: nested ? null : naqlCardShadow,
      ),
      child: child,
    );
    return onTap == null ? box : NaqlPressable(onPressed: onTap, pressedScale: 0.99, child: box);
  }
}

/// Selectable option card (ride option, direction, wave). The selected card gets a soft tint and
/// a strong border, like the highlighted "Business" option in the reference. Use [accent] for
/// the gold variant. [badge] is a small pill on the trailing side (e.g. a price).
class NaqlOptionCard extends StatelessWidget {
  const NaqlOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.badge,
    this.accent = false,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  /// Short text in a pill on the trailing side, e.g. "3,000 IQD".
  final String? badge;

  /// Gold instead of primary tint when selected.
  final bool accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final strong = accent ? NaqlColors.accent : NaqlColors.primary;
    final soft = accent ? NaqlColors.accentSoft : NaqlColors.primarySoft;
    final iconFg = accent ? (naqlIsDark ? NaqlColors.accent : NaqlColors.onAccent) : NaqlColors.primary;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: NaqlPressable(
        onPressed: onTap,
        semanticLabel: [title, subtitle, badge].whereType<String>().join(', '),
        pressedScale: 0.98,
        child: AnimatedContainer(
          duration: naqlMotion(context),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: NaqlSpace.s3),
          decoration: BoxDecoration(
            color: selected ? soft : NaqlColors.surface,
            borderRadius: BorderRadius.circular(NaqlRadius.md + 4),
            border: Border.all(color: selected ? strong : NaqlColors.border, width: selected ? 1.5 : 1),
          ),
          child: ExcludeSemantics(child: Row(children: [
            if (icon != null) ...[
              AnimatedContainer(
                duration: naqlMotion(context),
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: selected ? NaqlColors.surface : NaqlColors.surfaceMuted, shape: BoxShape.circle),
                child: Icon(icon, size: 22, color: selected ? iconFg : NaqlColors.text),
              ),
              const SizedBox(width: NaqlSpace.s3),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: NaqlText.headline.copyWith(fontSize: 16), semanticsLabel: ''),
                if (subtitle != null) Text(subtitle!, style: NaqlText.caption, semanticsLabel: ''),
              ]),
            ),
            if (badge != null) ...[const SizedBox(width: NaqlSpace.s2), NaqlBadge(badge!, highlighted: selected, accent: accent)],
            if (trailing != null) ...[const SizedBox(width: NaqlSpace.s2), trailing!],
          ])),
        ),
      ),
    );
  }
}

/// Small pill with short text (price, count). Highlighted = solid primary (or gold with [accent]).
class NaqlBadge extends StatelessWidget {
  const NaqlBadge(this.text, {super.key, this.highlighted = false, this.accent = false, this.icon});
  final String text;
  final bool highlighted;
  final bool accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = !highlighted
        ? (NaqlColors.surfaceMuted, NaqlColors.text)
        : accent
            ? (NaqlColors.accent, NaqlColors.onAccent)
            : (naqlIsDark ? NaqlColors.ink : NaqlColors.primary, naqlIsDark ? NaqlColors.onInk : NaqlColors.onPrimary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s3, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NaqlRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: NaqlSpace.s1)],
        Text(text, style: NaqlText.label.copyWith(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Section header above a group of cards: a quiet, confident title with an optional action.
class NaqlSectionHeader extends StatelessWidget {
  const NaqlSectionHeader(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: NaqlText.headline))),
          ?action,
        ]),
      );
}

/// A rounded square with an icon on a soft tone, used as a leading visual in cards.
class NaqlIconTile extends StatelessWidget {
  const NaqlIconTile(this.icon, {super.key, this.accent = false, this.size = 44});
  final IconData icon;
  final bool accent;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: accent ? NaqlColors.accentSoft : NaqlColors.primarySoft, borderRadius: BorderRadius.circular(NaqlRadius.sm + 4)),
        child: Icon(icon, size: size * 0.48, color: accent ? (naqlIsDark ? NaqlColors.accent : NaqlColors.onAccent) : NaqlColors.primary),
      );
}
