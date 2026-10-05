import 'package:flutter/material.dart';

import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

/// Text field with the label always visible above it (never placeholder-only).
class NaqlField extends StatelessWidget {
  const NaqlField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.error,
    this.keyboardType,
    this.obscureText = false,
    this.textDirection,
    this.prefixIcon,
    this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;
  final bool obscureText;

  /// Force LTR for phone numbers, emails and IDs inside an RTL screen.
  final TextDirection? textDirection;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;

  /// More than 1 for free text (e.g. a problem report).
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(NaqlRadius.md), borderSide: BorderSide(color: c, width: w));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: NaqlText.label),
        const SizedBox(height: NaqlSpace.s2),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textDirection: textDirection,
          onChanged: onChanged,
          minLines: maxLines > 1 ? 3 : null,
          maxLines: maxLines,
          style: NaqlText.body,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: NaqlColors.surface,
            hintText: hint,
            hintStyle: NaqlText.body.copyWith(color: NaqlColors.textMuted),
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20, color: NaqlColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: 14),
            enabledBorder: border(error == null ? NaqlColors.border : NaqlColors.danger),
            focusedBorder: border(error == null ? NaqlColors.primary : NaqlColors.danger, 1.5),
            errorText: error,
            errorStyle: NaqlText.caption.copyWith(color: NaqlColors.danger),
            errorBorder: border(NaqlColors.danger),
            focusedErrorBorder: border(NaqlColors.danger, 1.5),
          ),
        ),
      ],
    );
  }
}
