import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:student_app/data/taxi.dart';

import 'fakes.dart';

/// Pumps a few frames: the searching radar repeats forever, so pumpAndSettle cannot be used.
Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('[T10-10] taxi: home card follows taxiEnabled; quote → request → searching; accepted shows driver and plate', (tester) async {
    usePhone(tester);

    // Taxis switched off: no card on Home.
    final off = FakeBackend(signedIn: true, withPoint: true);
    await tester.pumpWidget(await off.app());
    await tester.pumpAndSettle();
    expect(find.text('تكسي من الجامعة وإليها'), findsNothing);
    expect(off.requests.any((r) => r.url.path.startsWith('/taxi')), isFalse);

    // Switched on: the card shows and opens the taxi screen.
    final api = FakeBackend(signedIn: true, withPoint: true)..profile['taxiEnabled'] = true;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    expect(find.text('تكسي من الجامعة وإليها'), findsOneWidget);
    await tester.tap(find.text('تكسي من الجامعة وإليها'));
    await tester.pumpAndSettle();

    // Plan: direction, the map pin, and the fare before booking.
    expect(find.text('تكسي الجامعة'), findsOneWidget);
    expect(find.text('إلى الجامعة'), findsOneWidget);
    expect(find.text('من الجامعة للبيت'), findsOneWidget);
    expect(find.text('4,500 د.ع'), findsOneWidget);
    expect(find.text('6.4 كم · 14 د'), findsOneWidget);
    expect(find.text('سيارات قريبة: 3'), findsOneWidget);
    expect(find.text('يصلك خلال 4 د تقريباً'), findsOneWidget);

    // Switching direction asks for a new quote for the trip home.
    await tester.tap(find.text('من الجامعة للبيت'));
    await tester.pumpAndSettle();
    expect(api.requests.last.url.queryParameters['direction'], 'from_campus');
    await tester.tap(find.text('إلى الجامعة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'قرب باب الجامع');
    await tester.tap(find.text('اطلب تكسي'));
    await _frames(tester);

    final sent = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/taxi/rides');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['direction'], 'to_campus');
    expect(body['label'], 'قرب باب الجامع');
    expect((body['clientId'] as String).length, inInclusiveRange(8, 64));

    // Searching: radar, countdown and cancel.
    expect(find.text('نبحث عن تكسي قريب'), findsOneWidget);
    expect(find.byKey(const ValueKey('taxi-countdown')), findsOneWidget);
    expect(find.text('إلغاء الطلب'), findsOneWidget);

    // A driver accepts: the socket says so and the ride is refetched.
    api.taxiActive = FakeBackend.taxiRide(
      status: 'accepted',
      driver: true,
      label: 'قرب باب الجامع',
      taxi: {'lat': 32.62, 'lng': 44.04, 'at': DateTime.now().toUtc().toIso8601String()},
      etaMin: 4,
    );
    api.taxiLive.ridesCtl.add('tx1');
    await tester.pumpAndSettle();
    expect(find.text('التكسي في الطريق إليك'), findsOneWidget);
    expect(find.text('علي حسين'), findsOneWidget);
    expect(find.text('45678 كربلاء'), findsOneWidget);
    expect(find.text('4 د'), findsOneWidget);
    expect(find.byKey(const ValueKey('taxi-car-pin')), findsOneWidget);
    expect(find.byKey(const ValueKey('taxi-pickup-pin')), findsOneWidget);
    expect(find.byKey(const ValueKey('taxi-dropoff-pin')), findsOneWidget);

    // A live position updates the ETA without a refetch.
    api.taxiLive.positionsCtl.add(TaxiPosition(rideId: 'tx1', point: const LatLng(32.612, 44.035), at: DateTime.now(), etaMin: 2));
    await tester.pumpAndSettle();
    expect(find.text('2 د'), findsOneWidget);

    // Call the driver.
    await tester.tap(find.byKey(const ValueKey('taxi-call')));
    await tester.pump();
    expect(api.dialed.single.toString(), 'tel:07800000011');
  });

  testWidgets('taxi: done shows the cash to pay; expired offers try again with a new request key', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true)..profile['taxiEnabled'] = true;
    // A ride already on its way: Home shows its status and opens it.
    api.taxiActive = FakeBackend.taxiRide(status: 'on_trip', driver: true, etaMin: 9);
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    expect(find.text('في الطريق إلى الجامعة'), findsOneWidget);
    await tester.tap(find.text('تابِع رحلتك'));
    await tester.pumpAndSettle();
    expect(find.text('في الطريق إلى الجامعة'), findsOneWidget);

    // The driver ends the trip.
    api.taxiActive = {...api.taxiActive!, 'status': 'done', 'taxi': null, 'etaMin': null};
    api.taxiLive.ridesCtl.add('tx1');
    await tester.pumpAndSettle();
    expect(find.text('وصلت بالسلامة'), findsOneWidget);
    expect(find.text('ادفع للسائق 4,500 د.ع نقداً'), findsOneWidget);
    expect(find.text('علي حسين'), findsOneWidget);

    // Back home, then book again; nobody accepts in time.
    await tester.tap(find.text('العودة للرئيسية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تكسي من الجامعة وإليها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اطلب تكسي'));
    await _frames(tester);
    final first = jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/taxi/rides').body)['clientId'];
    expect(find.text('نبحث عن تكسي قريب'), findsOneWidget);

    api.taxiActive = {...api.taxiActive!, 'status': 'expired'};
    await tester.pump(taxiPollActive);
    await tester.pumpAndSettle();
    expect(find.text('لم يقبل أي سائق هذه المرة'), findsOneWidget);

    await tester.tap(find.text('حاول مرة أخرى'));
    await tester.pumpAndSettle();
    expect(find.text('4,500 د.ع'), findsOneWidget);
    await tester.tap(find.text('اطلب تكسي'));
    await _frames(tester);
    final second = jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/taxi/rides').body)['clientId'];
    expect(second, isNot(first));
    expect(find.text('نبحث عن تكسي قريب'), findsOneWidget);
  });
}
