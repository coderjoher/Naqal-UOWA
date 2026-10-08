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

/// Round (or rounded-square) map marker with a white ring and a screen-reader label.
class TaxiMapPin extends StatelessWidget {
  const TaxiMapPin({super.key, required this.icon, required this.label, required this.color, this.onColor, this.square = false});
  final IconData icon;
  final String label;
  final Color color;

  /// Icon colour; defaults to the on-primary colour.
  final Color? onColor;
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
          boxShadow: naqlFloatShadow,
        ),
        child: Icon(icon, color: onColor ?? NaqlColors.onPrimary, size: 22),
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
                  color: const Color(0xFF000000).withValues(alpha: lifted ? 0.22 : 0.35),
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
                        color: naqlIsDark ? NaqlColors.ink : NaqlColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: naqlIsDark ? NaqlColors.primary : NaqlColors.surface, width: 3),
                        boxShadow: naqlFloatShadow,
                      ),
                      child: Icon(LucideIcons.mapPin, color: naqlIsDark ? NaqlColors.onInk : NaqlColors.onPrimary, size: 22),
                    ),
                    Container(width: 3, height: 12, color: naqlIsDark ? NaqlColors.ink : NaqlColors.primary),
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
                              ? Icon(LucideIcons.check, size: 14, color: NaqlColors.onPrimary)
                              : i == current
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: NaqlColors.primary, shape: BoxShape.circle),
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

/// Floating controls over the top of a full-bleed map: a round back button and the screen title
/// in a pill, with optional [below] (a hint or a live pill) centred under them.
class TaxiMapTop extends StatelessWidget {
  const TaxiMapTop({super.key, required this.title, required this.onBack, required this.backLabel, this.below, this.trailing});
  final String title;
  final VoidCallback onBack;
  final String backLabel;
  final Widget? below;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s2, NaqlSpace.s4, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                NaqlIconButton.floating(icon: rtl ? LucideIcons.arrowRight : LucideIcons.arrowLeft, onPressed: onBack, semanticLabel: backLabel),
                const SizedBox(width: NaqlSpace.s2),
                Expanded(
                  child: Center(
                    child: Container(
                      height: NaqlTouch.min,
                      padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: NaqlColors.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(NaqlRadius.pill),
                        boxShadow: naqlFloatShadow,
                      ),
                      child: Semantics(header: true, child: Text(title, style: NaqlText.headline.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ),
                  ),
                ),
                const SizedBox(width: NaqlSpace.s2),
                SizedBox(width: NaqlTouch.min, child: trailing),
              ],
            ),
            if (below != null) ...[const SizedBox(height: NaqlSpace.s2), below!],
          ],
        ),
      ),
    );
  }
}

/// Small translucent hint over a map ("Move the map to set the pickup").
class TaxiMapHint extends StatelessWidget {
  const TaxiMapHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s3, vertical: 6),
    decoration: BoxDecoration(color: NaqlColors.surface.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(NaqlRadius.pill), boxShadow: naqlFloatShadow),
    child: Text(text, style: NaqlText.caption.copyWith(color: NaqlColors.text), textAlign: TextAlign.center),
  );
}

/// Map credit kept readable above a sheet that overlaps the map's bottom edge.
class TaxiAttribution extends StatelessWidget {
  const TaxiAttribution({super.key, required this.text, this.bottom = 0});
  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottom),
    child: Align(
      alignment: AlignmentDirectional.bottomEnd,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: NaqlColors.surface.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: NaqlText.caption.copyWith(fontSize: 10, height: 1.3, color: NaqlColors.text), textDirection: TextDirection.ltr),
      ),
    ),
  );
}

/// Non-map taxi phases: the usual top bar with a back button, then the content.
class TaxiBarFrame extends StatelessWidget {
  const TaxiBarFrame({super.key, required this.title, required this.onBack, required this.child});
  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        NaqlTopBar(title: title, onBack: onBack, backLabel: MaterialLocalizations.of(context).backButtonTooltip),
        Expanded(child: child),
      ],
    ),
  );
}
