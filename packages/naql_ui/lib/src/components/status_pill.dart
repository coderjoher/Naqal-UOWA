import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

enum NaqlTone {
  neutral,
  primary,
  accent,
  success,
  warning,
  danger,
  femaleOnly;

  /// Foreground (text, dot, icon). Follows the active palette.
  Color get fg => switch (this) {
        neutral => NaqlColors.textMuted,
        primary => NaqlColors.primary,
        // Gold text on a pale gold pill is too faint: the accent tone uses the dark on-accent ink.
        accent => naqlIsDark ? NaqlColors.accent : NaqlColors.onAccent,
        success => NaqlColors.success,
        warning => NaqlColors.warning,
        danger => NaqlColors.danger,
        femaleOnly => NaqlColors.femaleOnly,
      };

  /// Soft background.
  Color get bg => switch (this) {
        neutral => NaqlColors.surfaceMuted,
        primary => NaqlColors.primarySoft,
        accent => NaqlColors.accentSoft,
        success => NaqlColors.successSoft,
        warning => NaqlColors.warningSoft,
        danger => NaqlColors.dangerSoft,
        femaleOnly => NaqlColors.femaleOnlySoft,
      };
}

/// Status = colour + icon/dot + word. [label] is required so colour is never the only signal.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = NaqlTone.neutral, this.icon});

  final String label;
  final NaqlTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s3),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(NaqlRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: tone.fg)
          else
            Container(width: 8, height: 8, decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle)),
          const SizedBox(width: NaqlSpace.s2),
          Text(label, style: NaqlText.caption.copyWith(color: tone.fg, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// "Live" pill: a pulsing red dot and a short value such as "17 min". Over maps and ride
/// headers. The pulse stops when the platform asks for reduced motion.
class NaqlLivePill extends StatefulWidget {
  const NaqlLivePill({super.key, required this.label, this.semanticLabel, this.floating = false});

  /// Short text, e.g. "17 min".
  final String label;

  /// Fuller text for screen readers ("Arriving in 17 minutes").
  final String? semanticLabel;

  /// Translucent surface with a soft shadow, for use over a map.
  final bool floating;

  @override
  State<NaqlLivePill> createState() => _NaqlLivePillState();
}

class _NaqlLivePillState extends State<NaqlLivePill> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  DateTime? _lastPulse;

  /// Three pulses, then rest; again when the value changes, at most every 30 s. A finite pulse
  /// keeps the "live" cue without an endless animation (battery, and screens can settle).
  void _pulse() {
    if (_reduce) {
      _c.stop();
      _c.value = 0;
      return;
    }
    _lastPulse = DateTime.now();
    _c.repeat(count: 3);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastPulse == null || _reduce) _pulse();
  }

  @override
  void didUpdateWidget(NaqlLivePill old) {
    super.didUpdateWidget(old);
    final last = _lastPulse;
    if (old.label != widget.label && (last == null || DateTime.now().difference(last) > const Duration(seconds: 30))) _pulse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final red = NaqlColors.danger;
    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      liveRegion: true,
      excludeSemantics: true,
      child: Container(
        height: widget.floating ? 44 : 32,
        padding: EdgeInsetsDirectional.only(start: widget.floating ? NaqlSpace.s4 : NaqlSpace.s3, end: widget.floating ? NaqlSpace.s4 : NaqlSpace.s3),
        decoration: BoxDecoration(
          color: widget.floating ? (naqlIsDark ? NaqlColors.surface.withValues(alpha: 0.95) : NaqlColors.surface) : NaqlColors.dangerSoft,
          borderRadius: BorderRadius.circular(NaqlRadius.pill),
          border: widget.floating && naqlIsDark ? Border.all(color: NaqlColors.border) : null,
          boxShadow: widget.floating && !naqlIsDark ? naqlFloatShadow : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: widget.floating ? 18 : 14,
            height: widget.floating ? 18 : 14,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                final t = Curves.easeOut.transform(_c.value);
                return Stack(alignment: Alignment.center, children: [
                  if (widget.floating) Container(width: 18, height: 18, decoration: BoxDecoration(color: red.withValues(alpha: 0.25), shape: BoxShape.circle)),
                  if (_c.isAnimating)
                    Container(
                      width: 8 + 6 * t,
                      height: 8 + 6 * t,
                      decoration: BoxDecoration(color: red.withValues(alpha: 0.45 * (1 - t)), shape: BoxShape.circle),
                    ),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: red, shape: BoxShape.circle)),
                ]);
              },
            ),
          ),
          SizedBox(width: widget.floating ? 10 : NaqlSpace.s2),
          Text(widget.label, style: NaqlText.label.copyWith(fontSize: widget.floating ? 15 : null, fontWeight: FontWeight.w600, color: widget.floating ? NaqlColors.text : red)),
        ]),
      ),
    );
  }
}
