import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

/// Press feedback used by every tappable component: a small scale-down plus haptic tick,
/// instead of Material ink ripples. Keyboard and screen-reader activation are supported.
class NaqlPressable extends StatefulWidget {
  const NaqlPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.semanticLabel,
    this.minSize = NaqlTouch.min,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double minSize;
  final double pressedScale;

  @override
  State<NaqlPressable> createState() => _NaqlPressableState();
}

class _NaqlPressableState extends State<NaqlPressable> {
  bool _down = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    widget.onPressed!();
  }

  void _setDown(bool v) {
    if (_enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? _activate : null,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setDown(true),
          onTapUp: (_) => _setDown(false),
          onTapCancel: () => _setDown(false),
          onTap: _enabled ? _activate : null,
          excludeFromSemantics: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: widget.minSize, minHeight: widget.minSize),
            child: AnimatedScale(
              scale: _down ? widget.pressedScale : 1,
              duration: naqlMotion(context, const Duration(milliseconds: 120)),
              curve: Curves.easeOut,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NaqlRadius.md),
                  border: _focused ? Border.all(color: NaqlColors.primary, width: 2) : null,
                ),
                child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
