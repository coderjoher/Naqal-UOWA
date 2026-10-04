import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'card.dart';
import 'status_pill.dart';

/// The core "answer card": pickup time and place → arrival, bus and driver, status.
/// Times are the biggest text on the card (design principle 1).
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.departTime,
    required this.arriveTime,
    required this.from,
    required this.to,
    required this.status,
    this.statusTone = NaqlTone.primary,
    this.duration,
    this.busLabel,
    this.driverName,
    this.plate,
    this.femaleOnly = false,
    this.femaleOnlyLabel,
    this.photo,
    this.footer,
    this.onTap,
  });

  final String departTime;
  final String arriveTime;
  final String from;
  final String to;
  final String status;
  final NaqlTone statusTone;
  final String? duration;
  final String? busLabel;
  final String? driverName;
  final String? plate;
  final bool femaleOnly;
  final String? femaleOnlyLabel;

  /// Vehicle photo shown next to the driver (ST-05). Falls back to a bus icon if it fails.
  final ImageProvider? photo;

  /// Extra content under the driver row (fare, actions).
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = NaqlText.title.copyWith(fontSize: 24);
    return NaqlCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(departTime, style: time, textDirection: TextDirection.ltr),
                  const SizedBox(height: NaqlSpace.s1),
                  Text(from, style: NaqlText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Expanded(child: _Route(duration: duration)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(arriveTime, style: time, textDirection: TextDirection.ltr),
                  const SizedBox(height: NaqlSpace.s1),
                  Text(to, style: NaqlText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: NaqlSpace.s4), child: Divider(height: 1, color: NaqlColors.border)),
          Row(
            children: [
              if (photo != null) ...[
                _Photo(image: photo!),
                const SizedBox(width: NaqlSpace.s3),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (driverName != null) Text(driverName!, style: NaqlText.label),
                  if (busLabel != null || plate != null)
                    Text([busLabel, plate].whereType<String>().join(' · '), style: NaqlText.caption),
                ]),
              ),
              if (femaleOnly) ...[
                StatusPill(label: femaleOnlyLabel ?? 'Female only', tone: NaqlTone.femaleOnly, icon: LucideIcons.users),
                const SizedBox(width: NaqlSpace.s2),
              ],
              StatusPill(label: status, tone: statusTone),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: NaqlSpace.s4), footer!],
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.image});
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NaqlRadius.sm),
      child: Container(
        width: 56,
        height: 44,
        color: NaqlColors.primarySoft,
        child: Image(
          image: image,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(LucideIcons.busFront, color: NaqlColors.primary, size: 22),
        ),
      ),
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({this.duration});
  final String? duration;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          const Expanded(child: _Dash()),
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: NaqlSpace.s1),
            decoration: const BoxDecoration(color: NaqlColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(LucideIcons.busFront, size: 18, color: NaqlColors.primary),
          ),
          const Expanded(child: _Dash()),
        ]),
        if (duration != null) ...[
          const SizedBox(height: NaqlSpace.s1),
          Text(duration!, style: NaqlText.caption, textDirection: TextDirection.ltr),
        ],
      ],
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final n = (c.maxWidth / 6).floor().clamp(1, 40);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(n, (_) => Container(width: 3, height: 1.5, color: NaqlColors.border)),
      );
    });
  }
}
