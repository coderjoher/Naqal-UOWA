import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'person_card.dart';
import 'pressable.dart';

/// The driver's big online switch as a card: gold with a dark power disc when on, a quiet card
/// with a call to action when off. The whole card is the switch (132 dp tall).
class NaqlToggleCard extends StatelessWidget {
  const NaqlToggleCard({
    super.key,
    required this.on,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.cta,
    this.watermark,
    this.busy = false,
    this.semanticHint,
  });

  final bool on;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Shown as a pill when off ("Go online").
  final String? cta;
  final String? watermark;

  /// Switching is in progress: the disc dims.
  final bool busy;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    final d = naqlMotion(context, NaqlMotion.sheet);
    final fg = on ? NaqlColors.onAccent : NaqlColors.text;
    return Semantics(
      toggled: on,
      hint: semanticHint,
      child: NaqlPressable(
        onPressed: onTap,
        pressedScale: 0.98,
        minSize: 132,
        semanticLabel: title,
        child: AnimatedContainer(
          duration: d,
          curve: naqlEaseOut,
          constraints: const BoxConstraints(minHeight: 132),
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5, vertical: NaqlSpace.s4),
          decoration: BoxDecoration(
            color: on ? NaqlColors.accent : NaqlColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: on || !naqlIsDark ? null : Border.all(color: NaqlColors.border),
            boxShadow: on ? [BoxShadow(color: NaqlColors.accent.withValues(alpha: naqlIsDark ? 0.18 : 0.35), blurRadius: 24, offset: const Offset(0, 8))] : naqlCardShadow,
          ),
          child: ExcludeSemantics(
            child: Stack(clipBehavior: Clip.none, children: [
              if (watermark != null)
                PositionedDirectional(
                  end: -28,
                  bottom: -52,
                  child: AnimatedOpacity(
                    duration: d,
                    opacity: on ? 1 : 0,
                    child: Text(watermark!, style: NaqlText.display.copyWith(fontSize: 120, height: 1, fontWeight: FontWeight.w700, color: NaqlColors.onAccent.withValues(alpha: 0.1))),
                  ),
                ),
              Row(children: [
                AnimatedContainer(
                  duration: d,
                  curve: naqlEaseOut,
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: on ? NaqlColors.onAccent : NaqlColors.surfaceMuted, shape: BoxShape.circle),
                  child: AnimatedOpacity(
                    duration: d,
                    opacity: busy ? 0.4 : 1,
                    child: Icon(LucideIcons.power, size: 32, color: on ? NaqlColors.accent : NaqlColors.textMuted),
                  ),
                ),
                const SizedBox(width: NaqlSpace.s4),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, style: NaqlText.title.copyWith(fontSize: 26, height: 1.25, fontWeight: FontWeight.w700, color: fg)),
                    Text(subtitle, style: NaqlText.label.copyWith(color: on ? NaqlColors.onAccent.withValues(alpha: 0.85) : NaqlColors.textMuted)),
                    if (!on && cta != null) ...[
                      const SizedBox(height: NaqlSpace.s3),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: naqlIsDark ? NaqlColors.ink : NaqlColors.primary, borderRadius: BorderRadius.circular(NaqlRadius.pill)),
                        child: Text(cta!, style: NaqlText.label.copyWith(fontWeight: FontWeight.w600, color: naqlIsDark ? NaqlColors.onInk : NaqlColors.onPrimary)),
                      ),
                    ],
                  ]),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A small figure tile: label on top, the number big. Optional gold star after the value.
class NaqlKpiTile extends StatelessWidget {
  const NaqlKpiTile({super.key, required this.label, required this.value, this.star = false, this.valueKey, this.small = false});
  final String label;
  final String value;
  final bool star;
  final Key? valueKey;

  /// Smaller number for long values (money).
  final bool small;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: NaqlColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: naqlIsDark ? Border.all(color: NaqlColors.border) : null,
            boxShadow: naqlCardShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: NaqlText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(
              height: 34,
              child: Row(children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(value, key: valueKey, textDirection: TextDirection.ltr, style: NaqlText.title.copyWith(fontSize: small ? 20 : 26, height: 1.2, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (star) ...[const SizedBox(width: 4), CustomPaint(size: const Size.square(16), painter: NaqlStarPainter(NaqlColors.accent))],
              ]),
            ),
          ]),
        ),
      );
}

/// Seconds left as a ring that empties, the number in the middle (amber near the end).
class NaqlCountdownRing extends StatelessWidget {
  const NaqlCountdownRing({super.key, required this.seconds, required this.fraction, this.size = 56, this.semanticLabel, this.warnBelow = 15});
  final int seconds;
  final double fraction;
  final double size;
  final String? semanticLabel;
  final int warnBelow;

  @override
  Widget build(BuildContext context) {
    final color = seconds <= warnBelow ? NaqlColors.warning : NaqlColors.accent;
    return Semantics(
      container: true,
      label: semanticLabel ?? '$seconds',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction.clamp(0.0, 1.0)),
          // Glides between once-a-second ticks.
          duration: naqlMotion(context, const Duration(seconds: 1)),
          builder: (_, v, _) => CustomPaint(
            painter: _RingPainter(value: v, color: color, track: NaqlColors.border),
            child: Center(child: Text('$seconds', style: NaqlText.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700))),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color, required this.track});
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final r = (Offset.zero & size).deflate(stroke / 2 + 2);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}

/// Turn-by-turn style card at the top of the driving screen: university blue in both modes,
/// a big line (distance or time) and the instruction under it.
class NaqlInstructionCard extends StatelessWidget {
  const NaqlInstructionCard({super.key, required this.headline, required this.body, this.icon = LucideIcons.navigation, this.trailing});
  final String headline;
  final String body;
  final IconData icon;
  final Widget? trailing;

  static const _blue = Color(0xFF0F3D8C);
  static const _white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        liveRegion: true,
        label: '$headline. $body',
        excludeSemantics: trailing == null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: 14),
          decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(NaqlRadius.lg), boxShadow: naqlFloatShadow),
          child: Row(children: [
            Icon(icon, size: 36, color: _white),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(headline, style: NaqlText.title.copyWith(fontSize: 28, height: 1.15, fontWeight: FontWeight.w700, color: _white), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(body, style: NaqlText.label.copyWith(color: _white), maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            ?trailing,
          ]),
        ),
      );
}

/// Segmented progress (stops served, ride steps): gold for done, hairline for the rest.
class NaqlStepBar extends StatelessWidget {
  const NaqlStepBar({super.key, required this.total, required this.done, this.semanticLabel});
  final int total;
  final int done;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final d = naqlMotion(context, NaqlMotion.sheet);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: d,
              curve: naqlEaseOut,
              height: 6,
              decoration: BoxDecoration(color: i < done ? NaqlColors.accent : NaqlColors.border, borderRadius: BorderRadius.circular(NaqlRadius.pill)),
            ),
          ),
        ],
      ]),
    );
  }
}

class NaqlTabItem {
  const NaqlTabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Floating rounded tab bar with icons and labels (driver app). The active tab is gold in dark
/// mode and university blue in light mode. Every tab is at least 56 dp.
class NaqlTabBar extends StatelessWidget {
  const NaqlTabBar({super.key, required this.items, required this.currentIndex, required this.onTap});
  final List<NaqlTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final active = naqlIsDark ? NaqlColors.accent : NaqlColors.primary;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(NaqlSpace.s4, 0, NaqlSpace.s4, NaqlSpace.s4),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: NaqlColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: naqlIsDark ? Border.all(color: NaqlColors.border) : null,
          boxShadow: naqlFloatShadow,
        ),
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                selected: i == currentIndex,
                child: NaqlPressable(
                  onPressed: () => onTap(i),
                  semanticLabel: items[i].label,
                  minSize: NaqlTouch.driver,
                  child: SizedBox(
                    height: 72,
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: i == currentIndex ? active : NaqlColors.textMuted),
                      duration: naqlMotion(context),
                      curve: naqlEaseOut,
                      builder: (_, c, _) => ExcludeSemantics(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(items[i].icon, size: 24, color: c),
                        const SizedBox(height: 2),
                        Text(items[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: NaqlText.caption.copyWith(fontSize: 11, color: c, fontWeight: i == currentIndex ? FontWeight.w600 : FontWeight.w400)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
