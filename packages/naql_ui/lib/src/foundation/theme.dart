import 'package:flutter/material.dart';

import 'tokens.g.dart';

const _package = 'naql_ui';

/// Text styles from the token scale. Numbers use tabular figures so times do not jump.
abstract final class NaqlText {
  static TextStyle _s(({double size, double line, int weight}) spec, {Color color = NaqlColors.text}) => TextStyle(
        fontFamily: NaqlFontSpec.family,
        package: _package,
        fontSize: spec.size,
        height: spec.line / spec.size,
        fontWeight: FontWeight.values[(spec.weight ~/ 100) - 1],
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
        leadingDistribution: TextLeadingDistribution.even,
      );

  static final display = _s(NaqlFontSpec.display);
  static final title = _s(NaqlFontSpec.title);
  static final headline = _s(NaqlFontSpec.headline);
  static final body = _s(NaqlFontSpec.body);
  static final label = _s(NaqlFontSpec.label);
  static final caption = _s(NaqlFontSpec.caption, color: NaqlColors.textMuted);
}

/// The single card shadow (design rule: one shadow only, nested cards are flat).
final naqlCardShadow = [
  BoxShadow(
    offset: Offset(NaqlShadowSpec.card.x, NaqlShadowSpec.card.y),
    blurRadius: NaqlShadowSpec.card.blur,
    color: NaqlShadowSpec.card.color.withValues(alpha: NaqlShadowSpec.card.opacity),
  ),
];

/// Shared-axis slide + fade, mirrored automatically in RTL.
class NaqlPageTransitionsBuilder extends PageTransitionsBuilder {
  const NaqlPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: Offset(rtl ? -0.08 : 0.08, 0), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// Builds the app theme. Material is only used as plumbing: no ink splashes, no elevation
/// tint, no stock transitions. Visible UI comes from `naql_ui` components.
ThemeData buildNaqlTheme() {
  const scheme = ColorScheme.light(
    primary: NaqlColors.primary,
    onPrimary: NaqlColors.onPrimary,
    secondary: NaqlColors.ink,
    surface: NaqlColors.surface,
    onSurface: NaqlColors.text,
    error: NaqlColors.danger,
    outline: NaqlColors.border,
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NaqlColors.bg,
    fontFamily: NaqlFontSpec.family,
    package: _package,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: NaqlColors.primary,
      selectionColor: NaqlColors.primarySoft,
      selectionHandleColor: NaqlColors.primary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: NaqlPageTransitionsBuilder(),
      TargetPlatform.iOS: NaqlPageTransitionsBuilder(),
      TargetPlatform.linux: NaqlPageTransitionsBuilder(),
      TargetPlatform.macOS: NaqlPageTransitionsBuilder(),
      TargetPlatform.windows: NaqlPageTransitionsBuilder(),
    }),
  );
}
