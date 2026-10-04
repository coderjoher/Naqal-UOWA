import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

/// Loading placeholder: a flat block whose opacity pulses (no shimmer gradient).
class NaqlSkeleton extends StatefulWidget {
  const NaqlSkeleton({super.key, this.width = double.infinity, required this.height, this.radius = NaqlRadius.sm});

  final double width;
  final double height;
  final double radius;

  @override
  State<NaqlSkeleton> createState() => _NaqlSkeletonState();
}

class _NaqlSkeletonState extends State<NaqlSkeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100), lowerBound: 0.45, upperBound: 1)
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final block = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: NaqlColors.border, borderRadius: BorderRadius.circular(widget.radius)),
    );
    return Semantics(label: 'loading', child: reduce ? block : FadeTransition(opacity: _c, child: block));
  }
}

/// Empty / error state: icon in a soft circle, a title, one sentence, optional action.
class NaqlEmptyState extends StatelessWidget {
  const NaqlEmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: NaqlColors.primarySoft, shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: NaqlColors.primary),
        ),
        const SizedBox(height: NaqlSpace.s4),
        Text(title, style: NaqlText.headline, textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: NaqlSpace.s2),
          Text(message!, style: NaqlText.body.copyWith(color: NaqlColors.textMuted), textAlign: TextAlign.center),
        ],
        if (action != null) ...[const SizedBox(height: NaqlSpace.s5), action!],
      ],
    );
  }
}

/// Bottom sheet with 24 radius and a grab handle.
Future<T?> showNaqlSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: NaqlColors.surface,
    elevation: 0,
    isScrollControlled: true,
    showDragHandle: false,
    barrierColor: NaqlColors.text.withValues(alpha: 0.32),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(NaqlRadius.lg))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s3, NaqlSpace.s5, NaqlSpace.s5),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: NaqlSpace.s4),
              decoration: BoxDecoration(color: NaqlColors.border, borderRadius: BorderRadius.circular(NaqlRadius.pill)),
            ),
          ),
          builder(ctx),
        ]),
      ),
    ),
  );
}
