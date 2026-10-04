import 'package:flutter/widgets.dart';

/// Lively but quick entrance: fades in and rises 12 px, delayed by `index × 50 ms` so lists
/// appear one item after another. Disabled when the platform asks for reduced motion.
class NaqlEntrance extends StatefulWidget {
  const NaqlEntrance({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<NaqlEntrance> createState() => _NaqlEntranceState();
}

class _NaqlEntranceState extends State<NaqlEntrance> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 50 * widget.index.clamp(0, 10)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_curve), child: widget.child),
    );
  }
}
