import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

/// Six-digit code entry shown as separate boxes. Always left-to-right (digits), one hidden
/// text field underneath so paste, autofill (SMS) and screen readers work.
class NaqlOtpField extends StatefulWidget {
  const NaqlOtpField({super.key, required this.label, required this.onCompleted, this.length = 6, this.error, this.controller});

  final String label;
  final ValueChanged<String> onCompleted;
  final int length;
  final String? error;
  final TextEditingController? controller;

  @override
  State<NaqlOtpField> createState() => _NaqlOtpFieldState();
}

class _NaqlOtpFieldState extends State<NaqlOtpField> {
  late final TextEditingController _c = widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      setState(() {});
      if (_c.text.length == widget.length) widget.onCompleted(_c.text);
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _c.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: NaqlText.label),
        const SizedBox(height: NaqlSpace.s2),
        Stack(
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: NaqlSpace.s2),
                    Expanded(
                      child: AnimatedContainer(
                        duration: naqlMotion(context),
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: NaqlColors.surface,
                          borderRadius: BorderRadius.circular(NaqlRadius.md),
                          border: Border.all(
                            color: widget.error != null
                                ? NaqlColors.danger
                                : (_focus.hasFocus && i == text.length.clamp(0, widget.length - 1))
                                    ? NaqlColors.primary
                                    : NaqlColors.border,
                            width: _focus.hasFocus && i == text.length.clamp(0, widget.length - 1) ? 1.5 : 1,
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: naqlMotion(context),
                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                          child: Text(i < text.length ? text[i] : '', key: ValueKey('$i${i < text.length ? text[i] : ''}'), style: NaqlText.title),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                // Invisible (the boxes draw the digits) but still reachable by screen readers.
                alwaysIncludeSemantics: true,
                child: TextField(
                  controller: _c,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: widget.length,
                  showCursor: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(counterText: '', border: InputBorder.none, labelText: widget.label),
                  onTap: () => setState(() {}),
                ),
              ),
            ),
          ],
        ),
        if (widget.error != null) ...[
          const SizedBox(height: NaqlSpace.s2),
          Text(widget.error!, style: NaqlText.caption.copyWith(color: NaqlColors.danger)),
        ],
      ],
    );
  }
}
