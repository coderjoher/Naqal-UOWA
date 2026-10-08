import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

/// Label / value line for fares, earnings and ride details. [total] makes a bold, larger row
/// with a hairline above it. Values are kept in their own direction (digits stay LTR).
class NaqlSummaryRow extends StatelessWidget {
  const NaqlSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.total = false,
    this.valueColor,
    this.icon,
  });

  final String label;
  final String value;
  final bool total;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final row = Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: total ? NaqlSpace.s3 : NaqlSpace.s2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: NaqlColors.textMuted),
              const SizedBox(width: NaqlSpace.s2),
            ],
            Expanded(
              child: Text(
                label,
                style: total
                    ? NaqlText.headline
                    : NaqlText.body.copyWith(color: NaqlColors.textMuted),
              ),
            ),
            const SizedBox(width: NaqlSpace.s3),
            Text(
              value,
              style:
                  (total
                          ? NaqlText.title
                          : NaqlText.body.copyWith(fontWeight: FontWeight.w600))
                      .copyWith(color: valueColor),
            ),
          ],
        ),
      ),
    );
    if (!total) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: NaqlSpace.s1),
          child: Divider(height: 1, thickness: 1, color: NaqlColors.border),
        ),
        row,
      ],
    );
  }
}
