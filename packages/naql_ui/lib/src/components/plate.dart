import 'package:flutter/material.dart';

import '../foundation/theme.dart';

/// Iraqi number plate: a bordered white plate with the blue "IRQ" band, the number big and the
/// province under it ("12340" / "كربلاء"), in both light and dark mode, so it reads like the real
/// plate a student looks for at the kerb. Plates are always left-to-right. A plate without a
/// province name (or with several numbers) is shown on one line as written.
class NaqlPlateBadge extends StatelessWidget {
  const NaqlPlateBadge(
    this.plate, {
    super.key,
    this.large = false,
    this.semanticLabel,
  });

  final String plate;

  /// Bigger plate for ride headers and the driver account.
  final bool large;
  final String? semanticLabel;

  // Fixed colours on purpose: a plate looks the same whatever the phone's theme.
  static const _white = Color(0xFFFFFFFF);
  static const _ink = Color(0xFF0A0C11);
  static const _band = Color(0xFF0F3D8C);

  static final _arabic = RegExp(r'[؀-ۿ]');
  static final _digits = RegExp(r'^\d+$');

  /// The number and the province, or null to show the plate as one line.
  static (String number, String province)? split(String plate) {
    final parts = plate.trim().split(RegExp(r'\s+'));
    final numbers = parts.where(_digits.hasMatch).toList();
    final rest = parts.where((p) => !_digits.hasMatch(p)).toList();
    if (numbers.length != 1 || rest.isEmpty || !rest.any(_arabic.hasMatch)) return null;
    return (numbers.single, rest.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final h = large ? 40.0 : 36.0;
    final two = split(plate);
    final number = NaqlText.label.copyWith(color: _ink, fontSize: large ? 15 : 13, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: 1);
    return Semantics(
      container: true,
      label: semanticLabel ?? plate,
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _ink, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: large ? 18 : 16,
                color: _band,
                alignment: Alignment.center,
                child: Text(
                  'IRQ',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: NaqlText.caption.copyWith(color: _white, fontSize: large ? 8 : 7, height: 1, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8),
                child: two == null
                    ? Text(plate, maxLines: 1, style: number)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(two.$1, maxLines: 1, style: number),
                          Text(
                            two.$2,
                            maxLines: 1,
                            textDirection: TextDirection.rtl,
                            style: NaqlText.caption.copyWith(color: _ink, fontSize: large ? 9 : 8, height: 1.1, fontWeight: FontWeight.w600),
                          ),
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
