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

  // Dark mode follows the phone: the same screens with the dark palette.
  testWidgets('[T2-04] home screen, dark mode (ar)', (tester) async {
    usePhone(tester);
    useDark(tester);
    await tester.pumpWidget(await FakeBackend(signedIn: true, withPoint: true).app());
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home.dark.rtl.png'));
  });

  testWidgets('[T2-04] welcome screen, dark mode (ar)', (tester) async {
    usePhone(tester);
    useDark(tester);
    await tester.pumpWidget(await FakeBackend().app());
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/welcome.dark.rtl.png'));
  });

  for (final dark in [false, true]) {
    final mode = dark ? '.dark' : '';

    testWidgets('[T10-10] taxi planning screen${dark ? ', dark mode' : ''} (ar)', (tester) async {
      usePhone(tester);
      if (dark) useDark(tester);
      final api = FakeBackend(signedIn: true, withPoint: true)..profile['taxiEnabled'] = true;
      await tester.pumpWidget(await api.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('تكسي من الجامعة وإليها'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/taxi_plan$mode.rtl.png'));
    });

    testWidgets('[T10-10] taxi ride on its way${dark ? ', dark mode' : ''} (ar)', (tester) async {
      usePhone(tester);
      if (dark) useDark(tester);
      final api = FakeBackend(signedIn: true, withPoint: true)..profile['taxiEnabled'] = true;
      api.taxiActive = FakeBackend.taxiRide(status: 'accepted', driver: true, label: 'قرب باب الجامع', etaMin: 4);
      await tester.pumpWidget(await api.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('تابِع رحلتك'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/taxi_ride$mode.rtl.png'));
    });
  }
}
