import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

/// Wraps [child] like an app screen: Naql theme, tinted background, given direction.
Widget harness(Widget child, {TextDirection dir = TextDirection.ltr}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildNaqlTheme(),
      home: Directionality(
        textDirection: dir,
        child: Scaffold(
          body: Center(child: Padding(padding: const EdgeInsets.all(NaqlSpace.s5), child: child)),
        ),
      ),
    );

/// Pumps [build] in LTR and RTL and compares each with `goldens/<name>.<ltr|rtl>.png`.
Future<void> expectGoldens(
  WidgetTester tester,
  String name,
  Widget Function(TextDirection dir) build, {
  Size size = const Size(420, 320),
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  addTearDown(tester.view.reset);
  for (final dir in TextDirection.values) {
    await tester.pumpWidget(harness(build(dir), dir: dir));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/$name.${dir.name}.png'));
  }
}

/// Arabic copy in RTL, English in LTR, so goldens look like the real apps.
String tr(TextDirection dir, String en, String ar) => dir == TextDirection.rtl ? ar : en;
