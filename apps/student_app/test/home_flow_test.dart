import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';
import 'package:student_app/data/rides.dart';

import 'fakes.dart';

/// Whether the card or tile with [key] is announced as selected.
bool _selected(WidgetTester tester, String key) =>
    isSemantics(isSelected: true).matches(tester.getSemantics(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Semantics)).first), {});

void main() {
  testWidgets('home sheet: choosing a service card switches the call to action and where it leads', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true, subscription: FakeBackend.active())..profile['taxiEnabled'] = true;
    useFullTimetable(api);
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();

    // Bus is chosen first: "Included" for a subscriber, the next wave with a seat, and the CTA
    // names it (the full 06:45 is skipped).
    expect(find.text('حافلة الجامعة'), findsOneWidget);
    expect(find.text('مشمول'), findsOneWidget);
    expect(find.text('القادمة 07:30'), findsOneWidget);
    expect(find.text('احجز مقعدي في حافلة 07:30'), findsOneWidget);
    expect(_selected(tester, 'service-bus'), isTrue);
    expect(_selected(tester, 'service-taxi'), isFalse);
    // The taxi card shows the real quote: pickup time and the fare from the gathering point.
    expect(find.text('4 د'), findsOneWidget);
    expect(find.text('من 4,500 د.ع'), findsOneWidget);

    // Taxi: the CTA becomes "Request a taxi".
    await tester.tap(find.byKey(const ValueKey('service-taxi')));
    await tester.pumpAndSettle();
    expect(_selected(tester, 'service-taxi'), isTrue);
    expect(find.text('احجز مقعدي في حافلة 07:30'), findsNothing);
    expect(find.text('اطلب تكسي'), findsOneWidget);

    // "Where to?" and the campus chip open the chosen service: the taxi, heading to campus.
    await tester.tap(find.byKey(const ValueKey('chip-campus')));
    await tester.pumpAndSettle();
    expect(find.text('تكسي الجامعة'), findsOneWidget);
    expect(api.requests.last.url.queryParameters['direction'], 'to_campus');
    await tester.tap(find.bySemanticsLabel('رجوع').first);
    await tester.pumpAndSettle();
    // The home chip heads home.
    await tester.tap(find.byKey(const ValueKey('chip-home')));
    await tester.pumpAndSettle();
    expect(api.requests.last.url.queryParameters['direction'], 'from_campus');
    await tester.tap(find.bySemanticsLabel('رجوع').first);
    await tester.pumpAndSettle();

    // Back to the bus: the CTA opens the booking screen with that wave already chosen.
    await tester.tap(find.byKey(const ValueKey('service-bus')));
    await tester.pumpAndSettle();
    expect(find.text('احجز مقعدي في حافلة 07:30'), findsOneWidget);
    await tester.tap(find.text('احجز مقعدي في حافلة 07:30'));
    await tester.pumpAndSettle();
    expect(find.text('اختر الموعد'), findsOneWidget);
    expect(_selected(tester, 'slot-w730-${FakeBackend.today}'), isTrue);
    await tester.tap(find.bySemanticsLabel('رجوع').first);
    await tester.pumpAndSettle();

    // With the bus chosen, the home chip opens booking on the first return wave.
    await tester.tap(find.byKey(const ValueKey('chip-home')));
    await tester.pumpAndSettle();
    expect(_selected(tester, 'slot-w1330-${FakeBackend.today}'), isTrue);
  });

  testWidgets('home without taxis shows only the bus; a ride that is going replaces the choice with its live summary', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true);
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('service-bus')), findsOneWidget);
    expect(find.byKey(const ValueKey('service-taxi')), findsNothing);
    // Not a subscriber: the bus is paid in cash.
    expect(find.text('نقداً'), findsOneWidget);

    api.rides = [FakeBackend.ride(status: 'assigned', assignment: FakeBackend.assignment(runStatus: 'started'))];
    await tester.pump(ridePollIdle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('service-bus')), findsNothing);
    expect(find.text('حيدر عباس'), findsOneWidget);
    // Tapping the summary opens the live screen.
    await tester.tap(find.text('حيدر عباس'));
    await tester.pumpAndSettle();
    expect(find.text('نقطتك: ساحة العباس'), findsOneWidget);
  });

  testWidgets('bus booking: pick tomorrow and a slot, change the boarding point, confirm → request; offline keeps the screen with an error', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true);
    useFullTimetable(api);
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('where-to')));
    await tester.pumpAndSettle();

    // Slot tiles say whether a seat is free.
    expect(find.text('ممتلئة'), findsOneWidget);
    expect(find.text('6 مقاعد متاحة'), findsOneWidget);
    expect(find.text('عودة 14:30'), findsOneWidget);
    // Not a subscriber: the cost line says cash to the driver.
    expect(find.text('تُدفع نقداً للسائق'), findsOneWidget);
    // Tiles are big enough to hit.
    expect(tester.getSize(find.byKey(ValueKey('slot-w815-${FakeBackend.today}'))).height, greaterThanOrEqualTo(NaqlTouch.min));

    // Tomorrow has one wave.
    await tester.tap(find.byKey(const ValueKey('day-tomorrow')));
    await tester.pumpAndSettle();
    expect(find.text('ممتلئة'), findsNothing);
    expect(_selected(tester, 'slot-w730-${FakeBackend.day(1)}'), isTrue);

    // Board at Bab Baghdad instead.
    await tester.tap(find.byKey(const ValueKey('change-point')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('point-p2')));
    await tester.pumpAndSettle();
    expect(find.text('باب بغداد'), findsOneWidget);

    // No coverage: the request fails, the screen stays with the message and nothing is lost.
    api.rideRequestFails = true;
    await tester.tap(find.text('تأكيد الحجز'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('book-error')), findsOneWidget);
    expect(find.text('اختر الموعد'), findsOneWidget);

    api.rideRequestFails = false;
    await tester.tap(find.text('تأكيد الحجز'));
    await tester.pumpAndSettle();
    final sent = jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/rides').body) as Map<String, dynamic>;
    expect(sent, {'waveId': 'w730', 'date': FakeBackend.day(1), 'pointId': 'p2'});
    // Back on Home with the request received.
    expect(find.text('وصل طلبك'), findsOneWidget);
    expect(find.text('اختر الموعد'), findsNothing);
  });

  testWidgets('bus booking: a full wave joins the waitlist, shown on Home with its countdown; cancelling brings the choice back', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true);
    useFullTimetable(api);
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('where-to')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('slot-w645-${FakeBackend.today}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('قائمة الانتظار'), findsOneWidget);
    await tester.tap(find.text('تأكيد الحجز'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('أنت على قائمة الانتظار'), findsOneWidget);
    expect(find.byKey(const ValueKey('countdown')), findsOneWidget);

    await tester.ensureVisible(find.text('إلغاء الطلب'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('إلغاء الطلب'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('نعم، ألغِ'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(api.requests.any((r) => r.url.path == '/rides/r1/cancel'), isTrue);
    expect(find.byKey(const ValueKey('service-bus')), findsOneWidget);
  });

  testWidgets('the bell shows unread notifications and opens them; the subscription row opens the subscription page', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true, subscription: FakeBackend.active());
    api.notifications = [
      {'id': 'n1', 'kind': 'ride.assigned', 'data': {}, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'readAt': null},
    ];
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('الإشعارات، 1 غير مقروءة'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('الإشعارات، 1 غير مقروءة'));
    await tester.pumpAndSettle();
    expect(find.text('تم تأكيد مقعدك'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('رجوع').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('subscription-row')));
    await tester.pumpAndSettle();
    expect(find.text('حتى 31 تشرين الأول'), findsOneWidget);
    expect(find.text('60,000 د.ع'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
