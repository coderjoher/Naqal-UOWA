import 'package:clock/clock.dart';
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

    testWidgets('[T2-04] home screen ($lang)', (tester) => atFixedTime(() async {
      usePhone(tester);
      await tester.pumpWidget(await FakeBackend(signedIn: true, withPoint: true).app(lang: lang));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home.$dir.png'));
    }));
  }

  // Dark mode follows the phone: the same screens with the dark palette.
  testWidgets('[T2-04] home screen, dark mode (ar)', (tester) => atFixedTime(() async {
    usePhone(tester);
    useDark(tester);
    await tester.pumpWidget(await FakeBackend(signedIn: true, withPoint: true).app());
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home.dark.rtl.png'));
  }));

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
      await openTaxiFromHome(tester);
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

  // The new screens, light and dark (see the design mockups).
  for (final dark in [false, true]) {
    final mode = dark ? '.dark' : '';

    testWidgets('home with taxis: bus and taxi service cards${dark ? ', dark mode' : ''} (ar)', (tester) => atFixedTime(() async {
      usePhone(tester);
      if (dark) useDark(tester);
      final api = FakeBackend(signedIn: true, withPoint: true, subscription: FakeBackend.active())..profile['taxiEnabled'] = true;
      useFullTimetable(api);
      await tester.pumpWidget(await api.app());
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_services$mode.rtl.png'));
    }));

    testWidgets('bus booking screen${dark ? ', dark mode' : ''} (ar)', (tester) => atFixedTime(() async {
      usePhone(tester);
      if (dark) useDark(tester);
      final api = FakeBackend(signedIn: true, withPoint: true, subscription: FakeBackend.active());
      useFullTimetable(api);
      await tester.pumpWidget(await api.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-cta-true')));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/bus_booking$mode.rtl.png'));
    }));

    testWidgets('live bus screen${dark ? ', dark mode' : ''} (ar)', (tester) => atFixedTime(() async {
      usePhone(tester);
      if (dark) useDark(tester);
      final api = FakeBackend(signedIn: true, withPoint: true, subscription: FakeBackend.active());
      api.rides = [FakeBackend.ride(status: 'assigned', assignment: FakeBackend.assignment(runStatus: 'started'))];
      api.track = {
        ...api.track,
        'bus': {'runId': 'run1', 'lat': 32.625, 'lng': 44.012, 'at': clock.now().toUtc().toIso8601String(), 'speed': 8.0, 'heading': null, 'etas': [{'seq': 2, 'seconds': 360}]},
      };
      await tester.pumpWidget(await api.app());
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_live$mode.rtl.png'));
      await tester.tap(find.text('تتبّع الحافلة'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/live_bus$mode.rtl.png'));
    }));

    testWidgets('ride details from the trips history${dark ? ', dark mode' : ''} (ar)', (tester) => atFixedTime(() async {
      usePhone(tester);
      if (dark) useDark(tester);
      final api = FakeBackend(signedIn: true, withPoint: true)..rideHistory = [{...FakeBackend.pastRide(1), 'fare': 1500, 'plate': '12340 كربلاء'}];
      await tester.pumpWidget(await api.app());
      await tester.pumpAndSettle();
      await openFromMenu(tester, 'رحلاتي');
      await tester.tap(find.byKey(const ValueKey('ride-h1')));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/ride_details$mode.rtl.png'));
    }));

    testWidgets('taxi ride done: receipt${dark ? ', dark mode' : ''} (ar)', (tester) => atFixedTime(() async {
      usePhone(tester);
      if (dark) useDark(tester);
      final api = FakeBackend(signedIn: true, withPoint: true)..profile['taxiEnabled'] = true;
      api.taxiActive = FakeBackend.taxiRide(status: 'on_trip', driver: true, etaMin: 9, label: 'حي الحسين، قرب الجامع');
      await tester.pumpWidget(await api.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('تابِع رحلتك'));
      await tester.pumpAndSettle();
      api.taxiActive = {...api.taxiActive!, 'status': 'done', 'taxi': null, 'etaMin': null, 'endedAt': clock.now().toUtc().toIso8601String()};
      api.taxiLive.ridesCtl.add('tx1');
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/taxi_receipt$mode.rtl.png'));
    }));

    testWidgets('account menu${dark ? ', dark mode' : ''} (ar)', (tester) => atFixedTime(() async {
      usePhone(tester);
      if (dark) useDark(tester);
      final api = FakeBackend(signedIn: true, withPoint: true, subscription: FakeBackend.active());
      await tester.pumpWidget(await api.app());
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('حسابي'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/menu$mode.rtl.png'));
    }));
  }
}
