import 'package:flutter/material.dart';

import '../foundation/theme.dart';

/// Iraqi number plate: dark text in a bordered white box with the blue "IRQ" band, in both
/// light and dark mode, so it reads like the real plate a student looks for at the kerb.
/// Plates are always left-to-right.
class NaqlPlateBadge extends StatelessWidget {
  const NaqlPlateBadge(
    this.plate, {
    super.key,
    this.large = false,
    this.semanticLabel,
  });

  final String plate;

  /// Bigger text for the driver account and ride headers.
  final bool large;
  final String? semanticLabel;

  // Fixed colours on purpose: a plate looks the same whatever the phone's theme.
  static const _white = Color(0xFFFFFFFF);
  static const _ink = Color(0xFF0A1428);
  static const _band = Color(0xFF0F3D8C);

  @override
  Widget build(BuildContext context) {
    final h = large ? 40.0 : 30.0;
    return Semantics(
      label: semanticLabel ?? plate,
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _ink, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: large ? 22 : 16,
                color: _band,
                alignment: Alignment.center,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    'IRQ',
                    style: NaqlText.caption.copyWith(
                      color: _white,
                      fontSize: large ? 9 : 7,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8),
                child: Text(
                  plate,
                  maxLines: 1,
                  style: NaqlText.label.copyWith(
                    color: _ink,
                    fontSize: large ? 18 : 14,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
