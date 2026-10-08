import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

/// One stop on a [NaqlTripTimeline].
class NaqlTimelineStop {
  const NaqlTimelineStop({required this.title, this.subtitle, this.time});

  /// Place name.
  final String title;

  /// Small caption above the place ("Pickup", "Drop-off").
  final String? subtitle;

  /// Shown on the trailing side, always left-to-right digits.
  final String? time;
}

/// Pickup → drop-off timeline: a ring dot for the start, a dotted connector, and a filled dot
/// for the end (red by default, gold with [accentEnd]). Times sit on the trailing side.
class NaqlTripTimeline extends StatelessWidget {
  const NaqlTripTimeline({
    super.key,
    required this.stops,
    this.accentEnd = false,
    this.dense = false,
  });

  final List<NaqlTimelineStop> stops;
  final bool accentEnd;

  /// Tighter rows with label-size text, for lists.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < stops.length; i++)
          _StopRow(
            stop: stops[i],
            first: i == 0,
            last: i == stops.length - 1,
            endColor: accentEnd ? NaqlColors.accent : NaqlColors.danger,
            dense: dense,
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.first,
    required this.last,
    required this.endColor,
    required this.dense,
  });
  final NaqlTimelineStop stop;
  final bool first;
  final bool last;
  final Color endColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final startColor = naqlIsDark ? NaqlColors.ink : NaqlColors.primary;
    final dot = first
        ? Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: startColor, width: 4),
            ),
          )
        : last
        ? Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: endColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: endColor.withValues(alpha: 0.25),
                width: 3,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
          )
        : Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: NaqlColors.textMuted,
              shape: BoxShape.circle,
            ),
          );
    return Semantics(
      label: [
        stop.subtitle,
        stop.title,
        stop.time,
      ].whereType<String>().join(', '),
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  // Align the dot with the title line.
                  SizedBox(
                    height: stop.subtitle != null ? 20 : (dense ? 2 : 4),
                  ),
                  SizedBox(height: 16, child: Center(child: dot)),
                  if (!last)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _DottedLine(
                          color: NaqlColors.textMuted.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: NaqlSpace.s3),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: last ? 0 : (dense ? NaqlSpace.s3 : NaqlSpace.s4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (stop.subtitle != null)
                      Text(stop.subtitle!, style: NaqlText.caption),
                    Text(
                      stop.title,
                      style: (dense ? NaqlText.label : NaqlText.body).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: dense ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            if (stop.time != null) ...[
              const SizedBox(width: NaqlSpace.s3),
              Padding(
                padding: EdgeInsets.only(top: stop.subtitle != null ? 16 : 0),
                child: Text(
                  stop.time!,
                  style: NaqlText.label.copyWith(color: NaqlColors.textMuted),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DotsPainter(color),
    child: const SizedBox(width: 2, height: double.infinity),
  );
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final x = size.width / 2;
    for (var y = 1.0; y < size.height; y += 6) {
      canvas.drawCircle(Offset(x, y), 1.2, p);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}
