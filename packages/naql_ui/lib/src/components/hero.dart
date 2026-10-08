import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

/// Brand hero for welcome screens: a rounded university-blue panel with gold orbit lines and a
/// big icon in a white disc. Decorative only (hidden from screen readers).
class NaqlHeroArt extends StatelessWidget {
  const NaqlHeroArt({super.key, required this.icon, this.height = 260});
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = naqlIsDark;
    // Fixed university blue in both modes: the panel is brand art, not a surface.
    const blue = Color(0xFF0F3D8C);
    const deep = Color(0xFF0A2F6E);
    return ExcludeSemantics(
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NaqlRadius.lg + 8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [blue, deep],
          ),
          border: dark ? Border.all(color: NaqlColors.border) : null,
        ),
        child: CustomPaint(
          painter: _OrbitPainter(gold: NaqlPalette.light.accent),
          child: Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(icon, size: 52, color: blue),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.gold});
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.12);
    for (final r in [90.0, 140.0, 200.0, 270.0]) {
      canvas.drawCircle(c, r, line);
    }
    // A gold arc and two gold "stops" on the orbits: a route around campus.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = gold;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 140),
      -math.pi * 0.95,
      math.pi * 0.55,
      false,
      arc,
    );
    final dot = Paint()..color = gold;
    final a1 = -math.pi * 0.95;
    final a2 = -math.pi * 0.40;
    canvas.drawCircle(c + Offset(math.cos(a1), math.sin(a1)) * 140, 6, dot);
    canvas.drawCircle(
      c + Offset(math.cos(a2), math.sin(a2)) * 140,
      8,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(c + Offset(math.cos(a2), math.sin(a2)) * 140, 4, dot);
    final a3 = math.pi * 0.2;
    canvas.drawCircle(
      c + Offset(math.cos(a3), math.sin(a3)) * 200,
      5,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.gold != gold;
}
