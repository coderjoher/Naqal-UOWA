import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'pressable.dart';

enum NaqlButtonVariant {
  /// The one strong call to action: university blue in light mode, a near-white ink pill in dark mode.
  primary,

  /// Soft outline pill.
  secondary,

  /// Text only.
  ghost,
  danger,

  /// Gold highlight for special moments (go online, rate the ride). Use sparingly.
  accent,
}

enum NaqlButtonSize {
  /// Inline buttons (48 dp).
  regular(NaqlTouch.min),

  /// Driver app: larger target for use in the vehicle.
  large(NaqlTouch.driver);

  const NaqlButtonSize(this.height);
  final double height;
}

/// Pill button. Use exactly one [NaqlButtonVariant.primary] per screen.
///
/// A primary button with [expand] is the screen's full-width CTA: it is always at least 56 dp
/// tall with a larger label, like the reference's "Continue".
class NaqlButton extends StatelessWidget {
  const NaqlButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NaqlButtonVariant.primary,
    this.size = NaqlButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final NaqlButtonVariant variant;
  final NaqlButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;

  (Color bg, Color fg, Color? border) get _colors => switch (variant) {
        NaqlButtonVariant.primary => naqlIsDark ? (NaqlColors.ink, NaqlColors.onInk, null) : (NaqlColors.primary, NaqlColors.onPrimary, null),
        NaqlButtonVariant.secondary => (naqlIsDark ? NaqlColors.surfaceMuted : NaqlColors.surface, NaqlColors.text, NaqlColors.border),
        NaqlButtonVariant.ghost => (Colors.transparent, NaqlColors.primary, null),
        NaqlButtonVariant.danger => (NaqlColors.danger, NaqlColors.onPrimary, null),
        NaqlButtonVariant.accent => (NaqlColors.accent, NaqlColors.onAccent, null),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors;
    final enabled = onPressed != null && !loading;
    final cta = expand && variant != NaqlButtonVariant.ghost;
    final height = cta && size.height < NaqlTouch.driver ? NaqlTouch.driver : size.height;
    final style = (size == NaqlButtonSize.large || cta ? NaqlText.headline.copyWith(fontSize: 17) : NaqlText.label).copyWith(color: fg, fontWeight: FontWeight.w600);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: NaqlPressable(
        onPressed: enabled ? onPressed : null,
        semanticLabel: label,
        minSize: height,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(NaqlRadius.pill),
            border: border == null ? null : Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                _Dots(color: fg)
              else ...[
                if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: NaqlSpace.s2)],
                Flexible(child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis, semanticsLabel: '')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading indicator: three pulsing dots (no Material spinner).
class _Dots extends StatefulWidget {
  const _Dots({required this.color});
  final Color color;

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
            final o = 0.35 + 0.65 * (1 - (2 * t - 1).abs());
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: widget.color.withValues(alpha: o), shape: BoxShape.circle),
            );
          }),
        ),
      ),
    );
  }
}
