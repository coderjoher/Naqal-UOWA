import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.g.dart';

const _package = 'naql_ui';

/// Text styles from the token scale. Numbers use tabular figures so times do not jump.
/// Getters, so the colour always follows the active palette ([NaqlColors.current]).
abstract final class NaqlText {
  static TextStyle _s(({double size, double line, int weight}) spec, {Color? color}) => TextStyle(
        fontFamily: NaqlFontSpec.family,
        package: _package,
        fontSize: spec.size,
        height: spec.line / spec.size,
        fontWeight: FontWeight.values[(spec.weight ~/ 100) - 1],
        color: color ?? NaqlColors.text,
        fontFeatures: const [FontFeature.tabularFigures()],
        leadingDistribution: TextLeadingDistribution.even,
      );

  static TextStyle get display => _s(NaqlFontSpec.display);
  static TextStyle get title => _s(NaqlFontSpec.title);
  static TextStyle get headline => _s(NaqlFontSpec.headline);
  static TextStyle get body => _s(NaqlFontSpec.body);
  static TextStyle get label => _s(NaqlFontSpec.label);
  static TextStyle get caption => _s(NaqlFontSpec.caption, color: NaqlColors.textMuted);

  /// Big confident hero title (welcome screens, sheet headers): display size, tighter leading.
  static TextStyle get hero => _s(NaqlFontSpec.display).copyWith(fontSize: 34, height: 1.2, fontWeight: FontWeight.w600);
}

/// True while the dark palette is active.
bool get naqlIsDark => identical(NaqlColors.current, NaqlPalette.dark);

/// The single card shadow (design rule: one shadow only, nested cards are flat).
/// Dark mode uses borders instead of shadows, so this is empty there.
List<BoxShadow> get naqlCardShadow => naqlIsDark
    ? const []
    : [
        BoxShadow(
          offset: Offset(NaqlShadowSpec.card.x, NaqlShadowSpec.card.y),
          blurRadius: NaqlShadowSpec.card.blur,
          color: NaqlShadowSpec.card.color.withValues(alpha: NaqlShadowSpec.card.opacity),
        ),
      ];

/// Soft lift for controls that float over a map (both modes; darker in dark mode).
List<BoxShadow> get naqlFloatShadow => [
      BoxShadow(
        offset: const Offset(0, 6),
        blurRadius: 20,
        color: const Color(0xFF000000).withValues(alpha: naqlIsDark ? 0.45 : 0.12),
      ),
    ];

/// Ease-out-quart: things arriving or changing state settle quickly without bounce.
const naqlEaseOut = Cubic(0.165, 0.84, 0.44, 1);

/// Short, eased motion. Returns [Duration.zero] when the platform asks for reduced motion.
Duration naqlMotion(BuildContext context, [Duration d = NaqlMotion.fast]) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? Duration.zero : d;

/// Shared-axis slide + fade, mirrored automatically in RTL.
class NaqlPageTransitionsBuilder extends PageTransitionsBuilder {
  const NaqlPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
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

/// Builds the app theme for [palette] (defaults to light). Material is only used as plumbing:
/// no ink splashes, no elevation tint, no stock transitions. Visible UI comes from `naql_ui`
/// components, which read [NaqlColors] (kept in sync by [NaqlThemeScope]).
ThemeData buildNaqlTheme([NaqlPalette palette = NaqlPalette.light]) {
  final dark = identical(palette, NaqlPalette.dark);
  final base = dark ? const ColorScheme.dark() : const ColorScheme.light();
  final scheme = base.copyWith(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.accent,
    onSecondary: palette.onAccent,
    tertiary: palette.ink,
    onTertiary: palette.onInk,
    surface: palette.surface,
    onSurface: palette.text,
    onSurfaceVariant: palette.textMuted,
    error: palette.danger,
    outline: palette.border,
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    fontFamily: NaqlFontSpec.family,
    package: _package,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    dividerColor: palette.border,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.primary,
      selectionColor: palette.primarySoft,
      selectionHandleColor: palette.primary,
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: palette.surface, modalBackgroundColor: palette.surface, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: palette.surface, surfaceTintColor: Colors.transparent),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: NaqlPageTransitionsBuilder(),
      TargetPlatform.iOS: NaqlPageTransitionsBuilder(),
      TargetPlatform.linux: NaqlPageTransitionsBuilder(),
      TargetPlatform.macOS: NaqlPageTransitionsBuilder(),
      TargetPlatform.windows: NaqlPageTransitionsBuilder(),
    }),
  );
}

/// Picks the palette for a platform brightness.
NaqlPalette naqlPaletteFor(Brightness b) => b == Brightness.dark ? NaqlPalette.dark : NaqlPalette.light;

/// Keeps [NaqlColors.current] in step with the device's light/dark setting.
///
/// Put it above `MaterialApp` (it reads the platform brightness from the root `View`'s
/// MediaQuery). On its first build it selects the palette before any descendant builds; when the
/// phone switches mode it swaps the palette and marks the whole subtree dirty (like a hot
/// reload), so every widget repaints with the new colours while keeping its state.
/// It also sets readable status-bar icons for the active mode.
class NaqlThemeScope extends StatefulWidget {
  const NaqlThemeScope({super.key, required this.child, this.brightness});

  final Widget child;

  /// Forces a brightness (tests, previews). Null follows the device.
  final Brightness? brightness;

  @override
  State<NaqlThemeScope> createState() => _NaqlThemeScopeState();
}

class _NaqlThemeScopeState extends State<NaqlThemeScope> {
  NaqlPalette? _applied;

  static void _rebuildAll(Element e) {
    e.markNeedsBuild();
    e.visitChildren(_rebuildAll);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = widget.brightness ?? MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    final palette = naqlPaletteFor(brightness);
    NaqlColors.current = palette;
    if (_applied != null && !identical(_applied, palette)) {
      // Descendants of the widget being built may be marked dirty during build: they are
      // guaranteed to be rebuilt in this same frame.
      (context as Element).visitChildren(_rebuildAll);
    }
    _applied = palette;
    final dark = brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: palette.bg,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: widget.child,
    );
  }
}

/// Colour matrix that turns light OpenStreetMap tiles into a dark, low-saturation map:
/// invert, desaturate, then lift the blacks slightly toward the charcoal surface.
const naqlDarkMapMatrix = <double>[
  // Luminance (0.3 R + 0.59 G + 0.11 B), inverted and scaled by 0.9, with a cool charcoal offset.
  -0.27, -0.531, -0.099, 0, 248, //
  -0.27, -0.531, -0.099, 0, 251, //
  -0.27, -0.531, -0.099, 0, 262, //
  0, 0, 0, 1, 0,
];

/// Wraps map tiles: unchanged in light mode, inverted and desaturated in dark mode.
/// Wrap only the tile layer, so markers and attribution keep their real colours.
class NaqlMapTint extends StatelessWidget {
  const NaqlMapTint({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      naqlIsDark ? ColorFiltered(colorFilter: const ColorFilter.matrix(naqlDarkMapMatrix), child: child) : child;
}
