import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

enum NaqlVehicleKind { bus, taxi }

/// Side view of a campus bus or taxi, drawn with paths (no image assets) and coloured from the
/// active palette. [hero] is the large receipt version with a ground shadow (the taxi becomes a
/// silver saloon with a gold roof sign, as on the ride details screen). Decorative only.
class NaqlVehicleArt extends StatelessWidget {
  const NaqlVehicleArt({super.key, required this.kind, this.width = 132, this.hero = false});
  const NaqlVehicleArt.bus({super.key, this.width = 132, this.hero = false}) : kind = NaqlVehicleKind.bus;
  const NaqlVehicleArt.taxi({super.key, this.width = 132, this.hero = false}) : kind = NaqlVehicleKind.taxi;

  final NaqlVehicleKind kind;
  final double width;
  final bool hero;

  /// The mockups' view boxes.
  Size get _box => hero ? const Size(330, 130) : (kind == NaqlVehicleKind.bus ? const Size(132, 62) : const Size(132, 56));

  @override
  Widget build(BuildContext context) {
    final box = _box;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: width * box.height / box.width,
        child: CustomPaint(painter: _VehiclePainter(kind: kind, hero: hero, dark: naqlIsDark, palette: NaqlColors.current)),
      ),
    );
  }
}

class _VehiclePainter extends CustomPainter {
  _VehiclePainter({required this.kind, required this.hero, required this.dark, required this.palette});
  final NaqlVehicleKind kind;
  final bool hero;
  final bool dark;
  final NaqlPalette palette;

  // Paint colours that are the vehicle's own, not the theme's (a silver car stays silver).
  static const _blue = Color(0xFF0F3D8C);
  static const _silver = Color(0xFFC9CED8);
  static const _glass = Color(0xFF20252F);
  static const _tyre = Color(0xFF0D1016);
  static const _hub = Color(0xFF6B7385);

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  void _wheel(Canvas canvas, Offset c, double r, Color fill, Color rim, double stroke) {
    canvas.drawCircle(c, r, _fill(fill));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  RRect _r(double x, double y, double w, double h, double r) => RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  @override
  void paint(Canvas canvas, Size size) {
    if (hero) {
      _paintHero(canvas, size);
      return;
    }
    canvas.scale(size.width / 132);
    final wheelFill = dark ? _tyre : palette.text;
    final wheelRim = dark ? palette.textMuted : palette.border;
    if (kind == NaqlVehicleKind.bus) {
      _bus(canvas, body: dark ? palette.ink : _blue, glass: dark ? palette.border : palette.primarySoft, stripe: dark ? _blue : palette.accent, wheelFill: wheelFill, wheelRim: wheelRim);
    } else {
      _taxi(canvas, body: palette.accent, glass: dark ? palette.border : palette.text, sign: dark ? palette.ink : null, wheelFill: wheelFill, wheelRim: wheelRim);
    }
  }

  void _bus(Canvas canvas, {required Color body, required Color glass, required Color stripe, required Color wheelFill, required Color wheelRim}) {
    canvas.drawRRect(_r(4, 6, 120, 42, 10), _fill(body));
    for (final x in [12.0, 38.0, 64.0]) {
      canvas.drawRRect(_r(x, 13, 22, 14, 3), _fill(glass));
    }
    canvas.drawRRect(_r(90, 13, 26, 22, 3), _fill(glass));
    canvas.drawRect(const Rect.fromLTWH(4, 34, 120, 5), _fill(stripe));
    _wheel(canvas, const Offset(30, 50), 8, wheelFill, wheelRim, 3);
    _wheel(canvas, const Offset(98, 50), 8, wheelFill, wheelRim, 3);
  }

  void _taxi(Canvas canvas, {required Color body, required Color glass, Color? sign, required Color wheelFill, required Color wheelRim}) {
    final shell = Path()
      ..moveTo(10, 34)
      ..lineTo(26, 16)
      ..quadraticBezierTo(32, 10, 42, 10)
      ..lineTo(86, 10)
      ..quadraticBezierTo(96, 10, 104, 18)
      ..lineTo(116, 30)
      ..quadraticBezierTo(124, 32, 124, 40)
      ..lineTo(124, 44)
      ..lineTo(8, 44)
      ..lineTo(8, 38)
      ..quadraticBezierTo(8, 35, 10, 34)
      ..close();
    canvas.drawPath(shell, _fill(body));
    canvas.drawPath(
      Path()
        ..moveTo(30, 18)
        ..lineTo(42, 14)
        ..lineTo(60, 14)
        ..lineTo(60, 30)
        ..lineTo(22, 30)
        ..close(),
      _fill(glass),
    );
    canvas.drawPath(
      Path()
        ..moveTo(66, 14)
        ..lineTo(86, 14)
        ..quadraticBezierTo(94, 14, 100, 22)
        ..lineTo(104, 30)
        ..lineTo(66, 30)
        ..close(),
      _fill(glass),
    );
    if (sign != null) canvas.drawRRect(_r(54, 4, 22, 6, 2), _fill(sign));
    _wheel(canvas, const Offset(34, 44), 8, wheelFill, wheelRim, 3);
    _wheel(canvas, const Offset(100, 44), 8, wheelFill, wheelRim, 3);
  }

  void _paintHero(Canvas canvas, Size size) {
    canvas.scale(size.width / 330);
    canvas.drawOval(Rect.fromCenter(center: const Offset(165, 118), width: 300, height: 16), _fill(const Color(0xFF000000).withValues(alpha: dark ? 0.5 : 0.12)));
    if (kind == NaqlVehicleKind.bus) {
      canvas.save();
      canvas.translate(25, 2);
      canvas.scale(280 / 132);
      _bus(canvas, body: dark ? palette.ink : _blue, glass: dark ? palette.border : palette.primarySoft, stripe: dark ? _blue : palette.accent, wheelFill: _tyre, wheelRim: _hub);
      canvas.restore();
      return;
    }
    final shell = Path()
      ..moveTo(20, 84)
      ..lineTo(60, 44)
      ..quadraticBezierTo(74, 30, 96, 30)
      ..lineTo(210, 30)
      ..quadraticBezierTo(232, 30, 248, 46)
      ..lineTo(276, 74)
      ..quadraticBezierTo(300, 78, 306, 94)
      ..lineTo(306, 104)
      ..lineTo(14, 104)
      ..lineTo(14, 92)
      ..quadraticBezierTo(14, 86, 20, 84)
      ..close();
    canvas.drawPath(shell, _fill(_silver));
    canvas.drawPath(
      Path()
        ..moveTo(70, 50)
        ..lineTo(98, 38)
        ..lineTo(150, 38)
        ..lineTo(150, 74)
        ..lineTo(52, 74)
        ..close(),
      _fill(_glass),
    );
    canvas.drawPath(
      Path()
        ..moveTo(160, 38)
        ..lineTo(208, 38)
        ..quadraticBezierTo(226, 38, 238, 52)
        ..lineTo(254, 74)
        ..lineTo(160, 74)
        ..close(),
      _fill(_glass),
    );
    canvas.drawRRect(_r(128, 20, 46, 10, 3), _fill(palette.accent));
    for (final x in [80.0, 246.0]) {
      canvas.drawCircle(Offset(x, 104), 20, _fill(_tyre));
      canvas.drawCircle(Offset(x, 104), 10, _fill(_hub));
    }
  }

  @override
  bool shouldRepaint(_VehiclePainter old) => old.kind != kind || old.hero != hero || old.dark != dark || !identical(old.palette, palette);
}

/// Big faded word behind a card or header ("BUS", "تكسي", "ON"). Decorative only.
class NaqlWatermark extends StatelessWidget {
  const NaqlWatermark(this.text, {super.key, this.size = 52, this.color, this.opacity = 0.06});
  final String text;
  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: NaqlText.display.copyWith(fontSize: size, height: 1, fontWeight: FontWeight.w700, color: (color ?? NaqlColors.text).withValues(alpha: opacity)),
        ),
      );
}
