import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';
import 'status_pill.dart';

/// Fill of a selected card in dark mode: a whisper of gold over the background.
Color get _darkSelectedFill => Color.alphaBlend(NaqlColors.accent.withValues(alpha: 0.09), NaqlColors.bg);

/// List separator for screen-reader labels: the Arabic comma in right-to-left text.
String _sep(BuildContext context) => Directionality.of(context) == TextDirection.rtl ? '، ' : ', ';

/// The strong selection colour: gold in dark mode, university blue in light mode.
Color get naqlSelectColor => naqlIsDark ? NaqlColors.accent : NaqlColors.primary;

/// Inner card on a bottom sheet or a page: charcoal with a hairline in dark mode, the tinted
/// background in light mode (the sheet itself is white). Radius 22 as in the mockups.
class NaqlPanel extends StatelessWidget {
  const NaqlPanel({super.key, required this.child, this.padding = const EdgeInsets.all(NaqlSpace.s4), this.onTap, this.clip = false, this.floating = false, this.radius = 22});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Clip children to the rounded shape (a mini map at the top edge).
  final bool clip;

  /// Floats over a map: white with a soft shadow in light mode.
  final bool floating;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: naqlIsDark || floating ? NaqlColors.surface : NaqlColors.bg,
        borderRadius: BorderRadius.circular(radius),
        border: naqlIsDark ? Border.all(color: NaqlColors.border) : null,
        boxShadow: floating && !naqlIsDark ? naqlFloatShadow : null,
      ),
      child: child,
    );
    return onTap == null ? box : NaqlPressable(onPressed: onTap, pressedScale: 0.99, child: box);
  }
}

enum NaqlBadgeStyle {
  /// Solid gold (dark) / blue (light): "Included".
  strong,

  /// Soft green: an ETA such as "4 min".
  success,

  /// Quiet grey.
  neutral,
}

/// One big service choice on Home ("University bus", "Taxi"): title, a small badge, one line,
/// a faded watermark word and a vehicle illustration. Two of these sit side by side.
class NaqlServiceCard extends StatelessWidget {
  const NaqlServiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    required this.art,
    this.subtitle,
    this.badge,
    this.badgeStyle = NaqlBadgeStyle.strong,
    this.watermark,
    this.height = 168,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final NaqlBadgeStyle badgeStyle;
  final String? watermark;
  final Widget art;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = naqlIsDark;
    final d = naqlMotion(context, NaqlMotion.fast);
    final (Color badgeBg, Color badgeFg) = switch (badgeStyle) {
      NaqlBadgeStyle.strong => dark ? (NaqlColors.accent, NaqlColors.onAccent) : (NaqlColors.primary, NaqlColors.onPrimary),
      NaqlBadgeStyle.success => (NaqlColors.successSoft, NaqlColors.success),
      NaqlBadgeStyle.neutral => (NaqlColors.surfaceMuted, NaqlColors.textMuted),
    };
    final bg = selected ? (dark ? _darkSelectedFill : NaqlColors.primarySoft) : NaqlColors.surface;
    final border = selected ? naqlSelectColor : NaqlColors.border;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: NaqlPressable(
        onPressed: onTap,
        pressedScale: 0.98,
        semanticLabel: [title, badge, subtitle].whereType<String>().join(_sep(context)),
        child: AnimatedContainer(
          duration: d,
          curve: naqlEaseOut,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: selected ? (dark ? 1.5 : 2) : 1),
          ),
          child: ExcludeSemantics(
            child: Stack(children: [
              if (watermark != null)
                PositionedDirectional(
                  end: -6,
                  bottom: 6,
                  child: Text(
                      watermark!,
                      maxLines: 1,
                      softWrap: false,
                      style: NaqlText.display.copyWith(
                        fontSize: 52,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: (selected ? naqlSelectColor : NaqlColors.text).withValues(alpha: selected ? 0.09 : 0.05),
                      ),
                  ),
                ),
              PositionedDirectional(
                start: 14,
                bottom: 16,
                child: AnimatedScale(
                  duration: naqlMotion(context, NaqlMotion.sheet),
                  curve: naqlEaseOut,
                  scale: selected ? 1 : 0.94,
                  alignment: AlignmentDirectional.bottomStart.resolve(Directionality.of(context)),
                  child: art,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(title, style: NaqlText.headline.copyWith(fontSize: 17), maxLines: 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(NaqlRadius.pill)),
                        child: Text(badge!, style: NaqlText.caption.copyWith(fontSize: 11, height: 1.3, fontWeight: FontWeight.w600, color: badgeFg)),
                      ),
                  ]),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: NaqlText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

enum NaqlSlotState { available, selected, full }

/// A time-slot tile in the booking grid: the time big, a status line under it
/// ("6 seats left", "Full"). [compact] is the shorter tile used for return waves.
class NaqlSlotTile extends StatelessWidget {
  const NaqlSlotTile({super.key, required this.time, required this.state, required this.onTap, this.caption, this.compact = false, this.semanticLabel});

  final String time;
  final String? caption;
  final NaqlSlotState state;
  final VoidCallback? onTap;
  final bool compact;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = naqlIsDark;
    final selected = state == NaqlSlotState.selected;
    final full = state == NaqlSlotState.full;
    final bg = selected ? (dark ? _darkSelectedFill : NaqlColors.primarySoft) : NaqlColors.surface;
    final timeColor = full ? NaqlColors.textMuted.withValues(alpha: 0.7) : NaqlColors.text;
    final capColor = selected ? naqlSelectColor : (full ? NaqlColors.textMuted : NaqlColors.success);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: NaqlPressable(
        onPressed: onTap,
        pressedScale: 0.96,
        semanticLabel: semanticLabel ?? [time, caption].whereType<String>().join(_sep(context)),
        child: AnimatedContainer(
          duration: naqlMotion(context),
          curve: naqlEaseOut,
          height: compact ? 64 : 88,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
            border: Border.all(color: selected ? naqlSelectColor : NaqlColors.border, width: selected ? (dark ? 1.5 : 2) : 1),
          ),
          child: ExcludeSemantics(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                time,
                textDirection: TextDirection.ltr,
                style: NaqlText.title.copyWith(fontSize: compact ? 16 : (selected ? 22 : 20), height: 1.2, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: timeColor),
              ),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(caption!, style: NaqlText.caption.copyWith(fontSize: 11, color: capColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Small coloured tag: "Subscriber", "1,500 cash". Text and colour together (never colour only).
class NaqlTag extends StatelessWidget {
  const NaqlTag(this.label, {super.key, this.tone = NaqlTone.neutral, this.icon});
  final String label;
  final NaqlTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(NaqlRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: tone.fg), const SizedBox(width: 4)],
          Text(label, style: NaqlText.caption.copyWith(fontWeight: FontWeight.w600, color: tone.fg)),
        ]),
      );
}
