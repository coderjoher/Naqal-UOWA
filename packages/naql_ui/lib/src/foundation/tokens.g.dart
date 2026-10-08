// GENERATED from packages/design-tokens/tokens.json — do not edit by hand.
// ignore_for_file: constant_identifier_names

import 'dart:ui';

/// One full set of colours. [light] and [dark] follow the device setting.
final class NaqlPalette {
  const NaqlPalette({required this.bg, required this.surface, required this.surfaceMuted, required this.border, required this.text, required this.textMuted, required this.primary, required this.primaryPressed, required this.primarySoft, required this.onPrimary, required this.accent, required this.accentPressed, required this.accentSoft, required this.onAccent, required this.ink, required this.onInk, required this.success, required this.successSoft, required this.warning, required this.warningSoft, required this.danger, required this.dangerSoft, required this.femaleOnly, required this.femaleOnlySoft});
  final Color bg;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color primaryPressed;
  final Color primarySoft;
  final Color onPrimary;
  final Color accent;
  final Color accentPressed;
  final Color accentSoft;
  final Color onAccent;
  final Color ink;
  final Color onInk;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color femaleOnly;
  final Color femaleOnlySoft;
  static const light = NaqlPalette(bg: Color(0xFFF3F5F9), surface: Color(0xFFFFFFFF), surfaceMuted: Color(0xFFEDF0F5), border: Color(0xFFDCE2EB), text: Color(0xFF0A1428), textMuted: Color(0xFF525D72), primary: Color(0xFF0F3D8C), primaryPressed: Color(0xFF0A2F6E), primarySoft: Color(0xFFE6EDF8), onPrimary: Color(0xFFFFFFFF), accent: Color(0xFFE9B824), accentPressed: Color(0xFFCC9C0E), accentSoft: Color(0xFFFCF3D6), onAccent: Color(0xFF1C1500), ink: Color(0xFF0A1A3A), onInk: Color(0xFFFFFFFF), success: Color(0xFF047857), successSoft: Color(0xFFE3F6EF), warning: Color(0xFFA15A06), warningSoft: Color(0xFFFDF1E1), danger: Color(0xFFB91C1C), dangerSoft: Color(0xFFFDE8E8), femaleOnly: Color(0xFF7C3AED), femaleOnlySoft: Color(0xFFF1EAFE));
  static const dark = NaqlPalette(bg: Color(0xFF090B10), surface: Color(0xFF14171E), surfaceMuted: Color(0xFF1C2029), border: Color(0xFF2A303C), text: Color(0xFFF1F3F7), textMuted: Color(0xFFA2AABA), primary: Color(0xFF7FA6F5), primaryPressed: Color(0xFF9BB9F8), primarySoft: Color(0xFF16233D), onPrimary: Color(0xFF06112A), accent: Color(0xFFF2C53D), accentPressed: Color(0xFFF6D368), accentSoft: Color(0xFF2B2410), onAccent: Color(0xFF1C1500), ink: Color(0xFFF1F3F7), onInk: Color(0xFF0A0C11), success: Color(0xFF3CCB95), successSoft: Color(0xFF0E2A20), warning: Color(0xFFF5A93A), warningSoft: Color(0xFF2E2210), danger: Color(0xFFF58A8A), dangerSoft: Color(0xFF311617), femaleOnly: Color(0xFFB49CFB), femaleOnlySoft: Color(0xFF241B3B));
}

/// The active palette. NaqlTheme switches [current] with the platform brightness.
abstract final class NaqlColors {
  static NaqlPalette current = NaqlPalette.light;
  static Color get bg => current.bg;
  static Color get surface => current.surface;
  static Color get surfaceMuted => current.surfaceMuted;
  static Color get border => current.border;
  static Color get text => current.text;
  static Color get textMuted => current.textMuted;
  static Color get primary => current.primary;
  static Color get primaryPressed => current.primaryPressed;
  static Color get primarySoft => current.primarySoft;
  static Color get onPrimary => current.onPrimary;
  static Color get accent => current.accent;
  static Color get accentPressed => current.accentPressed;
  static Color get accentSoft => current.accentSoft;
  static Color get onAccent => current.onAccent;
  static Color get ink => current.ink;
  static Color get onInk => current.onInk;
  static Color get success => current.success;
  static Color get successSoft => current.successSoft;
  static Color get warning => current.warning;
  static Color get warningSoft => current.warningSoft;
  static Color get danger => current.danger;
  static Color get dangerSoft => current.dangerSoft;
  static Color get femaleOnly => current.femaleOnly;
  static Color get femaleOnlySoft => current.femaleOnlySoft;
}

abstract final class NaqlSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
}

abstract final class NaqlRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;
}

abstract final class NaqlFontSpec {
  static const family = 'IBM Plex Sans Arabic';
  static const display = (size: 32.0, line: 40.0, weight: 600);
  static const title = (size: 22.0, line: 28.0, weight: 600);
  static const headline = (size: 18.0, line: 24.0, weight: 600);
  static const body = (size: 16.0, line: 24.0, weight: 400);
  static const label = (size: 14.0, line: 20.0, weight: 500);
  static const caption = (size: 12.0, line: 16.0, weight: 400);
}

abstract final class NaqlShadowSpec {
  static const card = (x: 0.0, y: 4.0, blur: 16.0, color: Color(0xFF0F172A), opacity: 0.06);
}

abstract final class NaqlMotion {
  static const fast = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 280);
}

abstract final class NaqlTouch {
  static const double min = 48;
  static const double driver = 56;
}
