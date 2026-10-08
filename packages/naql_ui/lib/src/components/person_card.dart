import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'top_bar.dart';

/// Round avatar: a photo when given, otherwise the person's initials on a soft tone.
class NaqlAvatar extends StatelessWidget {
  const NaqlAvatar({
    super.key,
    required this.name,
    this.photo,
    this.size = 52,
    this.icon,
    this.square = false,
    this.accent = false,
  });
  final String name;
  final ImageProvider? photo;
  final double size;

  /// Rounded square (person cards in ride sheets) instead of a circle.
  final bool square;

  /// Gold tone instead of blue.
  final bool accent;

  /// Shown instead of initials (e.g. a bus for a vehicle).
  final IconData? icon;

  /// First letter of the name (two isolated Arabic letters read oddly, so one is used).
  String get _initial {
    final n = name.trim();
    return n.isEmpty ? '' : n.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final fg = accent ? (naqlIsDark ? NaqlColors.accent : NaqlColors.onAccent) : NaqlColors.primary;
    final fallback = Center(
      child: icon != null
          ? Icon(icon, size: size * 0.46, color: fg)
          : Text(
              _initial,
              style: NaqlText.headline.copyWith(
                fontSize: size * 0.38,
                color: fg,
                height: 1,
              ),
            ),
    );
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: accent ? NaqlColors.accentSoft : NaqlColors.primarySoft,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(size * 0.31) : null,
        ),
        child: photo == null
            ? fallback
            : Image(
                image: photo!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Gold star + rating, e.g. "★ 4.9".
class NaqlRating extends StatelessWidget {
  const NaqlRating(this.value, {super.key, this.semanticLabel});
  final String value;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel ?? value,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size.square(14),
          painter: NaqlStarPainter(NaqlColors.accent),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: NaqlText.caption.copyWith(
            color: NaqlColors.text,
            fontWeight: FontWeight.w600,
          ),
          textDirection: TextDirection.ltr,
        ),
      ],
    ),
  );
}

/// One action on a [NaqlPersonCard] (call, message…).
class NaqlPersonAction {
  const NaqlPersonAction({
    this.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.positive = false,
  });

  /// Key for the action's button (tests, focus).
  final Key? key;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Solid style for the main action.
  final bool primary;

  /// Green style (call), as in the live ride sheet.
  final bool positive;
}

/// Person row: avatar, name, a small caption ("Your driver", or a [rating] with a gold star),
/// optional [trailingInfo] (e.g. a plate badge) and round action buttons.
/// Has no card of its own so it can sit inside a bigger card or sheet; use [NaqlCard] around it
/// when it stands alone.
class NaqlPersonCard extends StatelessWidget {
  const NaqlPersonCard({
    super.key,
    required this.name,
    this.caption,
    this.rating,
    this.photo,
    this.avatarIcon,
    this.actions = const [],
    this.below,
    this.actionSize = NaqlTouch.min,
    this.large = false,
    this.squareAvatar = false,
    this.avatarSize,
    this.accentAvatar = false,
  });

  final String name;
  final String? caption;

  /// e.g. "4.9" — drawn with a gold star after the caption.
  final String? rating;
  final ImageProvider? photo;
  final IconData? avatarIcon;
  final List<NaqlPersonAction> actions;

  /// Extra line under the name (e.g. the vehicle and plate).
  final Widget? below;

  /// 48 dp, or 56 dp in the driver app.
  final double actionSize;

  /// Bigger name and avatar, for reading at a glance in the car (driver app).
  final bool large;

  /// Rounded-square avatar (ride sheets) and its size.
  final bool squareAvatar;
  final double? avatarSize;
  final bool accentAvatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NaqlAvatar(
          name: name,
          photo: photo,
          icon: avatarIcon,
          size: avatarSize ?? (large ? 60 : 52),
          square: squareAvatar,
          accent: accentAvatar,
        ),
        const SizedBox(width: NaqlSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (caption != null || rating != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rating != null) NaqlRating(rating!),
                      if (caption != null && rating != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('·', style: NaqlText.caption),
                        ),
                      if (caption != null)
                        Flexible(
                          child: Text(
                            caption!,
                            style: large
                                ? NaqlText.body.copyWith(
                                    color: NaqlColors.textMuted,
                                  )
                                : NaqlText.caption,
                            maxLines: large ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              Text(
                name,
                style: large
                    ? NaqlText.title.copyWith(fontSize: 24, height: 1.25)
                    : NaqlText.headline.copyWith(fontSize: 19, height: 1.3),
                maxLines: large ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (below != null)
                Padding(
                  padding: const EdgeInsets.only(top: NaqlSpace.s2),
                  child: below!,
                ),
            ],
          ),
        ),
        for (final a in actions) ...[
          const SizedBox(width: NaqlSpace.s2),
          NaqlIconButton(
            key: a.key,
            icon: a.icon,
            onPressed: a.onPressed,
            semanticLabel: a.label,
            size: actionSize,
            style: a.positive
                ? NaqlIconButtonStyle.positive
                : a.primary
                ? NaqlIconButtonStyle.solid
                : NaqlIconButtonStyle.soft,
          ),
        ],
      ],
    );
  }
}

/// Solid five-point star (Lucide's star is outline-only).
class NaqlStarPainter extends CustomPainter {
  const NaqlStarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * radius, math.sin(a) * radius);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path..close(),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(NaqlStarPainter old) => old.color != color;
}
