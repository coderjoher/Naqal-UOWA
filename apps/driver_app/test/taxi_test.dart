import 'package:driver_app/data/taxi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

import 'fakes.dart';

FakeDriverBackend taxiDriver() => FakeDriverBackend(status: 'approved')..state['vehicleType'] = 'taxi';

/// Lets requests and short animations finish. The offer countdown ticks every second, so taxi
/// screens with offers never "settle"; these tests pump fixed steps instead.
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

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await settle(tester);
}

void main() {
  testWidgets('[T10-11] taxi driver: taxi home instead of runs and schedule, go online, offer from heartbeat, accept shows the student; bus drivers unchanged', (tester) async {
    usePhone(tester);
    final api = taxiDriver()..taxiOffers = [FakeDriverBackend.taxiOffer('r1')];
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();

    // Taxi home, no bus runs, no Schedule tab.
    expect(find.text('تكسي الجامعة'), findsOneWidget);
    expect(find.text('أنت غير متصل'), findsOneWidget);
    expect(find.text('رحلات اليوم'), findsNothing);
    expect(find.bySemanticsLabel('الجدول'), findsNothing);
    expect(find.bySemanticsLabel('الرئيسية'), findsOneWidget);
    expect(find.bySemanticsLabel('الأرباح'), findsOneWidget);
    expect(api.requests.where((r) => r.url.path == '/drivers/me/runs'), isEmpty);
    expect(api.requests.where((r) => r.url.path == '/drivers/me/availability'), isEmpty);
    // The switch is big enough to hit while driving.
    expect(tester.getSize(find.byKey(const ValueKey('taxi-online'))).height, greaterThanOrEqualTo(NaqlTouch.driver));

    // Go online: the heartbeat carries the GPS fix and brings back the open offer.
    await tapKey(tester, 'taxi-online');
    expect(api.taxiHeartbeats, [
      {'lat': 32.616, 'lng': 44.024},
    ]);
    expect(find.text('أنت متصل'), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-r1')), findsOneWidget);
    expect(find.text('4,500 د.ع'), findsOneWidget);
    expect(find.text('إلى الجامعة'), findsOneWidget);
    expect(find.text('رحلة 6.2 كم'), findsOneWidget);
    expect(find.text('يبعد 1.4 كم'), findsOneWidget);
    // A screen reader hears the whole offer, with the time left, on the Accept button.
    expect(find.bySemanticsLabel(RegExp(r'باقي \d+ ثانية[\s\S]*اقبل الطلب')), findsOneWidget);

    // Heartbeats keep coming while online.
    await tester.pump(taxiHeartbeat);
    await settle(tester);
    expect(api.taxiHeartbeats, hasLength(2));

    // Accept: the active ride with the student's name replaces the offers.
    await tapKey(tester, 'accept-r1');
    expect(api.requests.last.url.path, '/taxi/rides/r1/accept');
    expect(find.text('زهراء علي'), findsOneWidget);
    expect(find.text('اذهب إلى الطالب'), findsOneWidget);
    expect(find.text('وصلت'), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-r1')), findsNothing);
    expect(find.byKey(const ValueKey('taxi-online')), findsNothing);

    // A bus driver still gets today's runs and the Schedule tab.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final bus = FakeDriverBackend(status: 'approved')..runs = FakeDriverBackend.sampleRuns();
    await tester.pumpWidget(await bus.app(signedIn: true));
    await tester.pumpAndSettle();
    expect(find.text('رحلات اليوم'), findsOneWidget);
    expect(find.text('ذهاب 08:00'), findsOneWidget);
    expect(find.bySemanticsLabel('الجدول'), findsOneWidget);
    expect(find.text('تكسي الجامعة'), findsNothing);
    expect(bus.requests.where((r) => r.url.path.startsWith('/taxi/')), isEmpty);
  });

  testWidgets('taxi: a ride from arrival to cash, with call and navigation', (tester) async {
    usePhone(tester);
    final api = taxiDriver()..taxiOffers = [FakeDriverBackend.taxiOffer('r1', fare: 6250)];
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tapKey(tester, 'taxi-online');
    await tapKey(tester, 'accept-r1');

    await tapKey(tester, 'taxi-call');
    expect(api.launched.last, Uri(scheme: 'tel', path: '07701234567'));
    await tapKey(tester, 'taxi-navigate');
    expect(api.launched.last.toString(), contains('32.6151'));

    await tapText(tester, 'وصلت');
    expect(find.text('بانتظار صعود الطالب'), findsOneWidget);
    await tapText(tester, 'ابدأ الرحلة');
    expect(find.text('في الطريق إلى الجامعة'), findsOneWidget);
    expect(find.byKey(const ValueKey('taxi-cancel')), findsNothing);

    // Navigation now goes to the drop-off.
    await tapKey(tester, 'taxi-navigate');
    expect(api.launched.last.toString(), contains('32.59'));

    // End asks whether the cash was collected; "not yet" keeps the trip going.
    await tapText(tester, 'أنهِ الرحلة واستلم 6,250 د.ع');
    expect(find.text('هل استلمت 6,250 د.ع نقداً؟'), findsOneWidget);
    await tapText(tester, 'ليس بعد');
    expect(api.requests.where((r) => r.url.path.endsWith('/end')), isEmpty);
    await tapText(tester, 'أنهِ الرحلة واستلم 6,250 د.ع');
    await tapText(tester, 'نعم، استلمتها');
    expect(api.requests.where((r) => r.url.path == '/taxi/rides/r1/end'), hasLength(1));

    // The success moment with the cash, then back to the requests.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('انتهت الرحلة'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('taxi-done-cash'))).data, '6,250 د.ع');
    await tester.pump(taxiDoneHold);
    await settle(tester);
    expect(find.text('انتهت الرحلة'), findsNothing);
    expect(find.text('بانتظار الطلبات'), findsOneWidget);
  });

  testWidgets('taxi: another driver took it — gentle message and the card goes away', (tester) async {
    usePhone(tester);
    final api = taxiDriver()
      ..taxiOffers = [FakeDriverBackend.taxiOffer('r1'), FakeDriverBackend.taxiOffer('r2', direction: 'from_campus', fare: 3000)]
      ..taxiTaken.add('r1');
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tapKey(tester, 'taxi-online');
    expect(find.text('من الجامعة'), findsOneWidget);

    await tapKey(tester, 'accept-r1');
    expect(find.text('سبقك سائق آخر لهذا الطلب.'), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-r1')), findsNothing);
    expect(find.byKey(const ValueKey('offer-r2')), findsOneWidget);
    expect(find.text('زهراء علي'), findsNothing);

    // The message fades after a few seconds.
    await tester.pump(taxiNoticeHold);
    await settle(tester);
    expect(find.text('سبقك سائق آخر لهذا الطلب.'), findsNothing);
  });

  testWidgets('taxi: live offers arrive and leave over the socket; going offline stops the heartbeat', (tester) async {
    usePhone(tester);
    final api = taxiDriver();
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tapKey(tester, 'taxi-online');
    expect(find.text('بانتظار الطلبات'), findsOneWidget);

    api.taxiEvents.offersCtl.add(TaxiOffer.fromJson(FakeDriverBackend.taxiOffer('r9', fare: 5000)));
    await settle(tester);
    expect(find.byKey(const ValueKey('offer-r9')), findsOneWidget);
    expect(find.text('5,000 د.ع'), findsOneWidget);

    api.taxiEvents.goneCtl.add('r9');
    await settle(tester);
    expect(find.byKey(const ValueKey('offer-r9')), findsNothing);

    // An offer whose time runs out disappears by itself.
    api.taxiEvents.offersCtl.add(TaxiOffer.fromJson(FakeDriverBackend.taxiOffer('r10', seconds: 3)));
    await settle(tester);
    expect(find.byKey(const ValueKey('offer-r10')), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await settle(tester);
    expect(find.byKey(const ValueKey('offer-r10')), findsNothing);

    await tapKey(tester, 'taxi-online');
    expect(api.requests.last.url.path, '/taxi/driver/offline');
    expect(find.text('أنت غير متصل'), findsOneWidget);
    final beats = api.taxiHeartbeats.length;
    await tester.pump(taxiHeartbeat * 3);
    expect(api.taxiHeartbeats, hasLength(beats));
  });

  testWidgets('taxi: an accepted ride comes back after a restart; driver cancel asks first', (tester) async {
    usePhone(tester);
    final api = taxiDriver()..taxiOffers = [FakeDriverBackend.taxiOffer('r1')];
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tapKey(tester, 'taxi-online');
    await tapKey(tester, 'accept-r1');

    // Restart the app: the first heartbeat returns the active ride.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tapKey(tester, 'taxi-online');
    expect(find.text('زهراء علي'), findsOneWidget);

    await tapKey(tester, 'taxi-cancel');
    expect(find.text('إلغاء هذه الرحلة؟'), findsOneWidget);
    await tapText(tester, 'أكمل الرحلة');
    expect(find.text('زهراء علي'), findsOneWidget);
    await tapKey(tester, 'taxi-cancel');
    await tapText(tester, 'نعم، ألغِ الرحلة');
    expect(api.requests.where((r) => r.url.path == '/taxi/rides/r1/cancel'), hasLength(1));
    expect(find.text('زهراء علي'), findsNothing);
    expect(find.text('بانتظار الطلبات'), findsOneWidget);
  });

  testWidgets('taxi: no location means no going online', (tester) async {
    usePhone(tester);
    final api = taxiDriver();
    api.location.fix = null;
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tapKey(tester, 'taxi-online');
    expect(find.text('شغّل الموقع لتبدأ العمل.'), findsOneWidget);
    expect(find.text('أنت غير متصل'), findsOneWidget);
    expect(api.taxiHeartbeats, isEmpty);
  });

  testWidgets('taxi earnings: this month\'s taxi trips and recent trips (English)', (tester) async {
    usePhone(tester);
    final api = taxiDriver()
      ..taxiRides.addAll([
        {
          'id': 't1',
          'status': 'done',
          'direction': 'to_campus',
          'pickup': {'lat': 32.6, 'lng': 44.0},
          'dropoff': {'lat': 32.59, 'lng': 44.05},
          'label': null,
          'distanceKm': 5.0,
          'fare': 4000,
          'acceptedAt': '2026-10-06T07:00:00Z',
          'endedAt': '2026-10-06T07:20:00Z',
          'createdAt': '2026-10-06T06:58:00Z',
          'student': {'name': 'Zahraa Ali', 'phone': null},
        },
        {
          'id': 't2',
          'status': 'done',
          'direction': 'from_campus',
          'pickup': {'lat': 32.59, 'lng': 44.05},
          'dropoff': {'lat': 32.6, 'lng': 44.0},
          'label': null,
          'distanceKm': 3.0,
          'fare': 3500,
          'acceptedAt': '2026-10-07T13:00:00Z',
          'endedAt': '2026-10-07T13:15:00Z',
          'createdAt': '2026-10-07T12:58:00Z',
          'student': {'name': 'Ali Hassan', 'phone': null},
        },
      ]);
    await tester.pumpWidget(await api.app(lang: 'en', signedIn: true));
    await tester.pumpAndSettle();
    expect(find.text('Campus taxi'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Earnings'));
    await tester.pumpAndSettle();
    expect(find.text('Taxi trips this month'), findsOneWidget);
    expect(find.text('2 trips · 7,500 IQD'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('taxi-ride-t2')), 200);
    expect(find.text('From campus'), findsOneWidget);
    expect(find.text('3,500 IQD'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    final mode = dark ? '.dark' : '';
    testWidgets('[T10-11] taxi home: offline switch and an accepted ride (golden${dark ? ', dark mode' : ''})', (tester) => atFixedTime(() async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      addTearDown(tester.view.reset);
      if (dark) useDark(tester);
      final api = taxiDriver()..taxiOffers = [FakeDriverBackend.taxiOffer('r1', fare: 6250)];
      api.state.addAll({'name': 'حيدر عباس', 'plate': '45670 كربلاء أجرة'});
      await tester.pumpWidget(await api.app(signedIn: true));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/taxi_home$mode.rtl.png'));

      await tapKey(tester, 'taxi-online');
      await tapKey(tester, 'accept-r1');
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/taxi_ride$mode.rtl.png'));
    }));
  }
}
