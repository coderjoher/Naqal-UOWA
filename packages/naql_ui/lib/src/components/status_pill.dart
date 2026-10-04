import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

enum NaqlTone {
  neutral(NaqlColors.textMuted, NaqlColors.surfaceMuted),
  primary(NaqlColors.primary, NaqlColors.primarySoft),
  success(NaqlColors.success, NaqlColors.successSoft),
  warning(NaqlColors.warning, NaqlColors.warningSoft),
  danger(NaqlColors.danger, NaqlColors.dangerSoft),
  femaleOnly(NaqlColors.femaleOnly, NaqlColors.femaleOnlySoft);

  const NaqlTone(this.fg, this.bg);
  final Color fg;
  final Color bg;
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
