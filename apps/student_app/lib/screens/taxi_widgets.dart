import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:naql_ui/naql_ui.dart';

// Small building blocks of the campus taxi screens (P10).

/// True when the platform asks for reduced motion.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A duration that collapses to zero under reduced motion.
Duration motion(BuildContext context, Duration d) => reduceMotion(context) ? Duration.zero : d;

/// Two-option segmented control with a sliding thumb. Each option is a 48 dp button.
class TaxiSegmented<T> extends StatelessWidget {
  const TaxiSegmented({super.key, required this.label, required this.options, required this.value, required this.onChanged});

  /// Read by screen readers for the whole group.
  final String label;
  final List<(T, String, IconData)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = options.indexWhere((o) => o.$1 == value);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = options.length < 2 ? 0.0 : -1 + 2 * index / (options.length - 1);
    return Semantics(
      container: true,
      label: label,
      child: Container(
        height: NaqlTouch.min + 8,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: NaqlColors.surfaceMuted,
          borderRadius: BorderRadius.circular(NaqlRadius.pill),
          border: Border.all(color: NaqlColors.border),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: motion(context, NaqlMotion.fast),
              curve: Curves.easeOutCubic,
              alignment: Alignment(rtl ? -x : x, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / options.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: NaqlColors.surface, borderRadius: BorderRadius.circular(NaqlRadius.pill), boxShadow: naqlCardShadow),
                ),
              ),
            ),
            Row(
              children: [
                for (final (v, text, icon) in options)
                  Expanded(
                    child: Semantics(
                      selected: v == value,
                      button: true,
                      label: text,
                      excludeSemantics: true,
                      child: InkResponse(
                        key: ValueKey('taxi-dir-$v'),
                        onTap: v == value ? null : () => onChanged(v),
                        containedInkWell: true,
                        highlightShape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(NaqlRadius.pill),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 18, color: v == value ? NaqlColors.primary : NaqlColors.textMuted),
                              const SizedBox(width: NaqlSpace.s2),
                              Flexible(
                                child: AnimatedDefaultTextStyle(
                                  duration: motion(context, NaqlMotion.fast),
                                  style: NaqlText.label.copyWith(
                                    color: v == value ? NaqlColors.text : NaqlColors.textMuted,
                                    fontWeight: v == value ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                  child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Round (or rounded-square) map marker with a white ring and a screen-reader label.
class TaxiMapPin extends StatelessWidget {
  const TaxiMapPin({super.key, required this.icon, required this.label, required this.color, this.square = false});
  final IconData icon;
  final String label;
  final Color color;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(14) : null,
          border: Border.all(color: NaqlColors.surface, width: 3),
          boxShadow: naqlCardShadow,
        ),
        child: Icon(icon, color: NaqlColors.onPrimary, size: 22),
      ),
    );
  }
}

/// The pin fixed at the map's centre while the student moves the map. It lifts while moving and
/// settles when the map stops, so the point being chosen is always under its tip.
class TaxiCenterPin extends StatelessWidget {
  const TaxiCenterPin({super.key, required this.lifted, required this.label});
  final bool lifted;
  final String label;

  @override
  Widget build(BuildContext context) {
    final d = motion(context, NaqlMotion.fast);
    return IgnorePointer(
      child: Semantics(
        label: label,
        child: SizedBox(
          width: 56,
          height: 72,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Shadow dot on the exact point.
              AnimatedContainer(
                duration: d,
                curve: Curves.easeOutCubic,
                width: lifted ? 14 : 10,
                height: lifted ? 6 : 4,
                decoration: BoxDecoration(
                  color: NaqlColors.text.withValues(alpha: lifted ? 0.18 : 0.28),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              AnimatedPadding(
                duration: d,
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: lifted ? 12 : 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: NaqlColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: NaqlColors.surface, width: 3),
                        boxShadow: naqlCardShadow,
                      ),
                      child: const Icon(LucideIcons.mapPin, color: NaqlColors.onPrimary, size: 22),
                    ),
                    Container(width: 3, height: 12, color: NaqlColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calm radar while drivers are being asked: three soft ripples from the centre, one every
/// 0.8 s. Under reduced motion the rings stand still.
class TaxiRadar extends StatefulWidget {
  const TaxiRadar({super.key, this.size = 220, required this.child});
  final double size;
  final Widget child;

  @override
  State<TaxiRadar> createState() => _TaxiRadarState();
}

class _TaxiRadarState extends State<TaxiRadar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _RipplePainter(_c, still: still),
          child: Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: NaqlColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: NaqlColors.surface, width: 4),
                boxShadow: naqlCardShadow,
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.anim, {required this.still}) : super(repaint: anim);
  final Animation<double> anim;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    const minR = 38.0;
    const rings = 3;
    for (var i = 0; i < rings; i++) {
      final phase = still ? (i + 1) / (rings + 1) : (anim.value + i / rings) % 1;
      final eased = Curves.easeOutCubic.transform(phase);
      final r = minR + (maxR - minR) * eased;
      final alpha = (1 - phase) * 0.14;
      canvas.drawCircle(c, r, Paint()..color = NaqlColors.primary.withValues(alpha: alpha));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = NaqlColors.primary.withValues(alpha: math.min(0.4, alpha * 2.5)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.still != still;
}

/// "02:41" until [until], ticking every second and never below zero.
class TaxiCountdown extends StatefulWidget {
  const TaxiCountdown({super.key, required this.until, required this.style, this.semanticPrefix});
  final DateTime until;
  final TextStyle style;
  final String? semanticPrefix;

  @override
  State<TaxiCountdown> createState() => _TaxiCountdownState();
}

class _TaxiCountdownState extends State<TaxiCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = formatCountdown(widget.until.difference(clock.now()));
    return Text(
      text,
      key: const ValueKey('taxi-countdown'),
      style: widget.style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      textDirection: TextDirection.ltr,
      semanticsLabel: widget.semanticPrefix == null ? text : '${widget.semanticPrefix} $text',
    );
  }
}

/// accepted → arrived → on trip → done, with the current step highlighted.
class TaxiStepper extends StatelessWidget {
  const TaxiStepper({super.key, required this.steps, required this.current, required this.semanticLabel});
  final List<String> steps;
  final int current;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final d = motion(context, NaqlMotion.sheet);
    final last = steps.length - 1;
    Widget line(bool filled, bool visible) => Expanded(
      child: visible ? AnimatedContainer(duration: d, curve: Curves.easeOutCubic, height: 3, color: filled ? NaqlColors.primary : NaqlColors.border) : const SizedBox.shrink(),
    );
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 24,
                    child: Row(
                      children: [
                        line(i <= current, i > 0),
                        AnimatedContainer(
                          duration: d,
                          curve: Curves.easeOutCubic,
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: i < current || (i == current && i == last) ? NaqlColors.primary : (i == current ? NaqlColors.primarySoft : NaqlColors.surface),
                            shape: BoxShape.circle,
                            border: Border.all(color: i <= current ? NaqlColors.primary : NaqlColors.border, width: 2),
                          ),
                          child: i < current || (i == current && i == last)
                              ? const Icon(LucideIcons.check, size: 14, color: NaqlColors.onPrimary)
                              : i == current
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: NaqlColors.primary, shape: BoxShape.circle),
                                  ),
                                )
                              : null,
                        ),
                        line(i < current, i < last),
                      ],
                    ),
                  ),
                  const SizedBox(height: NaqlSpace.s2),
                  Text(
                    steps[i],
                    textAlign: TextAlign.center,
                    style: NaqlText.caption.copyWith(color: i <= current ? NaqlColors.text : NaqlColors.textMuted, fontWeight: i == current ? FontWeight.w600 : FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "3.2" — one decimal, Western digits.
String formatKm(double km) => km.toStringAsFixed(1);
