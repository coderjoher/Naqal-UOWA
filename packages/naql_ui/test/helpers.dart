import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

/// Wraps [child] like an app screen: Naql theme, tinted background, given direction and brightness.
Widget harness(Widget child, {TextDirection dir = TextDirection.ltr, Brightness brightness = Brightness.light}) => NaqlThemeScope(
      brightness: brightness,
      child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildNaqlTheme(),
      darkTheme: buildNaqlTheme(NaqlPalette.dark),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: dir,
        child: Scaffold(
          body: Center(child: Padding(padding: const EdgeInsets.all(NaqlSpace.s5), child: child)),
        ),
      ),
    ));

/// Pumps [build] (called during the build, so styles read the active palette) in LTR and RTL and compares each with `goldens/<name>.<ltr|rtl>.png`.
/// With [dark], also compares the dark palette with `goldens/<name>.dark.<ltr|rtl>.png`.
Future<void> expectGoldens(
  WidgetTester tester,
  String name,
  Widget Function(TextDirection dir) build, {
  Size size = const Size(420, 320),
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  addTearDown(tester.view.reset);
  for (final dir in TextDirection.values) {
    await tester.pumpWidget(harness(Builder(builder: (_) => build(dir)), dir: dir));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/$name.${dir.name}.png'));
  }
  if (!dark) return;
  for (final dir in TextDirection.values) {
    await tester.pumpWidget(harness(Builder(builder: (_) => build(dir)), dir: dir, brightness: Brightness.dark));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/$name.dark.${dir.name}.png'));
  }
  // Leave the light palette active for whatever runs next.
  await tester.pumpWidget(harness(const SizedBox()));
}

/// Arabic copy in RTL, English in LTR, so goldens look like the real apps.
String tr(TextDirection dir, String en, String ar) => dir == TextDirection.rtl ? ar : en;
