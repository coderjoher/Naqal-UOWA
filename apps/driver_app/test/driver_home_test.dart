import 'package:clock/clock.dart';
import 'package:driver_app/data/taxi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

import 'fakes.dart';

FakeDriverBackend taxiDriver() => FakeDriverBackend(status: 'approved')..state.addAll({'vehicleType': 'taxi', 'name': 'حيدر عباس', 'plate': '45670 كربلاء أجرة'});

/// Pumps fixed steps: the offer countdown ticks every second, so these screens never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await settle(tester);
}

Map<String, Object?> doneToday(String id, int fare) => {
      'id': id,
      'status': 'done',
      'direction': 'to_campus',
      'pickup': {'lat': 32.6, 'lng': 44.0},
      'dropoff': {'lat': 32.59, 'lng': 44.05},
      'label': null,
      'distanceKm': 5.0,
      'fare': fare,
      'acceptedAt': clock.now().toUtc().toIso8601String(),
      'endedAt': clock.now().toUtc().toIso8601String(),
      'createdAt': clock.now().toUtc().toIso8601String(),
      'student': {'name': 'Zahraa Ali', 'phone': null},
    };

void main() {
  testWidgets('taxi home: the big toggle card goes online and off; today\'s figures come from the trip history', (tester) async {
    usePhone(tester);
    final api = taxiDriver()..taxiRides.add(doneToday('t1', 4000));
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();

    // Header: greeting, name and plate.
    expect(find.text('حيدر عباس'), findsOneWidget);
    expect(find.bySemanticsLabel('رقم اللوحة: 45670 كربلاء أجرة'), findsOneWidget);
    // Off: a neutral card with the call to action, announced as an unchecked switch.
    expect(find.text('أنت غير متصل'), findsOneWidget);
    expect(find.text('ابدأ العمل'), findsOneWidget);
    final toggle = find.byKey(const ValueKey('taxi-online'));
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(132));
    expect(tester.getSemantics(find.descendant(of: toggle, matching: find.byType(Semantics)).first), isSemantics(isToggled: false, hasToggledState: true));
    // Real figures: one trip today, its cash, and the month.
    expect(find.text('مشاوير اليوم'), findsOneWidget);
    expect(find.text('4,000'), findsOneWidget);

    await tapKey(tester, 'taxi-online');
    expect(find.text('أنت متصل'), findsOneWidget);
    expect(find.text('تصلك طلبات التكسي القريبة · اضغط للإيقاف'), findsOneWidget);
    expect(find.text('ابدأ العمل'), findsNothing);
    expect(tester.getSemantics(find.descendant(of: toggle, matching: find.byType(Semantics)).first), isSemantics(isToggled: true, hasToggledState: true));

    await tapKey(tester, 'taxi-online');
    expect(api.requests.last.url.path, '/taxi/driver/offline');
    expect(find.text('أنت غير متصل'), findsOneWidget);
  });

  testWidgets('taxi home: offer cards with a countdown ring; skip hides one for good; accept fills the screen and hides the tab bar', (tester) async {
    usePhone(tester);
    final api = taxiDriver()..taxiOffers = [FakeDriverBackend.taxiOffer('r1', fare: 4500), FakeDriverBackend.taxiOffer('r2', direction: 'from_campus', fare: 3000)];
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tapKey(tester, 'taxi-online');

    expect(find.text('طلب جديد'), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-r2')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^باقي \d+ ثانية$')), findsNWidgets(2));
    // Big targets for the car.
    expect(tester.getSize(find.byKey(const ValueKey('accept-r1'))).height, greaterThanOrEqualTo(NaqlTouch.driver));
    expect(tester.getSize(find.byKey(const ValueKey('skip-r1'))).height, greaterThanOrEqualTo(NaqlTouch.driver));

    // Skip r2: it goes, and the next heartbeat does not bring it back.
    await tapKey(tester, 'skip-r2');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('offer-r2')), findsNothing);
    await tester.pump(taxiHeartbeat);
    await settle(tester);
    expect(find.byKey(const ValueKey('offer-r2')), findsNothing);
    expect(find.byKey(const ValueKey('offer-r1')), findsOneWidget);
    expect(api.requests.where((r) => r.url.path.contains('/r2/')), isEmpty);

    // Accept: the ride takes the screen, with no tab bar while driving.
    expect(find.byType(NaqlTabBar), findsOneWidget);
    await tapKey(tester, 'accept-r1');
    expect(find.text('زهراء علي'), findsOneWidget);
    expect(find.text('اذهب إلى الطالب'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NaqlTabBar), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('taxi-step'))).height, greaterThanOrEqualTo(64));

    // Through to the cash; the tab bar returns with the offers.
    await tapKey(tester, 'taxi-step');
    await tapKey(tester, 'taxi-step');
    await tapKey(tester, 'taxi-step');
    await tester.tap(find.text('نعم، استلمتها'));
    await settle(tester);
    expect(find.text('انتهت الرحلة'), findsOneWidget);
    await tester.pump(taxiDoneHold);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NaqlTabBar), findsOneWidget);
    expect(find.text('أنت متصل'), findsOneWidget);
  });

  testWidgets('bus home: the next run in place of the switch, today\'s figures, later runs; the card opens the run', (tester) async {
    usePhone(tester);
    final api = FakeDriverBackend(status: 'approved')..runs = FakeDriverBackend.sampleRuns();
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();

    final next = find.byKey(const ValueKey('next-run'));
    expect(find.descendant(of: next, matching: find.text('رحلتك القادمة')), findsOneWidget);
    expect(find.descendant(of: next, matching: find.text('ذهاب 08:00')), findsOneWidget);
    expect(find.descendant(of: next, matching: find.text('07:12')), findsOneWidget);
    expect(find.descendant(of: next, matching: find.text('3 محطات')), findsOneWidget);
    expect(find.descendant(of: next, matching: find.text('6 من 14 مقعد')), findsOneWidget);
    // Figures: two runs, the cash of both, eight riders.
    expect(find.text('رحلات اليوم'), findsOneWidget);
    expect(find.text('7,000 د.ع'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('لاحقاً اليوم'), findsOneWidget);
    expect(find.text('عودة 14:00'), findsOneWidget);
    expect(find.bySemanticsLabel('الجدول'), findsOneWidget);

    await tester.tap(next);
    await tester.pumpAndSettle();
    // The driving screen: the blue card, the stop, the big gold start.
    expect(find.text('توجّه إلى حي الحسين'), findsOneWidget);
    expect(find.text('ابدأ الرحلة'), findsOneWidget);
    expect(find.byType(NaqlTabBar), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('navigate'))).height, greaterThanOrEqualTo(NaqlTouch.driver));

    // A finished morning run: the return becomes the next one.
    api.runs.first['status'] = 'done';
    await tester.tap(find.bySemanticsLabel('رجوع').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.descendant(of: next, matching: find.text('عودة 14:00')), findsOneWidget);
  });

  for (final dark in [false, true]) {
    final mode = dark ? '.dark' : '';
    testWidgets('taxi home online with a request (golden${dark ? ', dark mode' : ''})', (tester) => atFixedTime(() async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      addTearDown(tester.view.reset);
      if (dark) useDark(tester);
      final api = taxiDriver()
        ..taxiOffers = [FakeDriverBackend.taxiOffer('r1', fare: 4500)]
        ..taxiRides.addAll([doneToday('t1', 4000), doneToday('t2', 6500)]);
      await tester.pumpWidget(await api.app(signedIn: true));
      await tester.pumpAndSettle();
      await tapKey(tester, 'taxi-online');
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/taxi_online$mode.rtl.png'));
    }));

    testWidgets('bus home and the run at a stop (golden${dark ? ', dark mode' : ''})', (tester) => atFixedTime(() async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      addTearDown(tester.view.reset);
      if (dark) useDark(tester);
      final api = FakeDriverBackend(status: 'approved')..runs = FakeDriverBackend.sampleRuns();
      api.state.addAll({'name': 'حيدر عباس', 'vehicleType': 'coaster', 'plate': '12340 كربلاء'});
      await tester.pumpWidget(await api.app(signedIn: true));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/bus_home$mode.rtl.png'));
      await tester.tap(find.byKey(const ValueKey('next-run')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ابدأ الرحلة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('وصلت إلى المحطة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('علي كريم'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/run_at_stop$mode.rtl.png'));
    }));
  }
}
