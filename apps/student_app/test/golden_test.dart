import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// [T2-04] Onboarding and home screens in Arabic (RTL) and English (LTR).
void main() {
  for (final lang in ['ar', 'en']) {
    final dir = lang == 'ar' ? 'rtl' : 'ltr';

    testWidgets('[T2-04] welcome screen ($lang)', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(await FakeBackend().app(lang: lang));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/welcome.$dir.png'));
    });

    testWidgets('[T2-04] sign-in screen ($lang)', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(await FakeBackend().app(lang: lang));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang == 'ar' ? 'متابعة' : 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang == 'ar' ? 'جامعة وارث الأنبياء' : 'Warith Al-Anbiyaa University'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/sign_in.$dir.png'));
    });

    testWidgets('[T2-04] home screen ($lang)', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(await FakeBackend(signedIn: true, withPoint: true).app(lang: lang));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home.$dir.png'));
    });
  }
}
