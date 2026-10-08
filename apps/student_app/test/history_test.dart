import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

import 'fakes.dart';

Future<void> openTrips(WidgetTester tester, FakeBackend api) async {
  usePhone(tester);
  await tester.pumpWidget(await api.app());
  await tester.pumpAndSettle();
  await openFromMenu(tester, 'رحلاتي');
}

void main() {
  testWidgets('[T7-01] history lists rides and payments with infinite scroll, empty and error states', (tester) async {
    final api = FakeBackend(signedIn: true, withPoint: true)
      ..rideHistory = [for (var i = 0; i < 3; i++) FakeBackend.pastRide(i, status: i == 2 ? 'cancelled' : 'done')]
      ..paymentHistory = [
        for (var i = 45; i > 2; i--) FakeBackend.payment(i),
        FakeBackend.payment(2, amount: -60000, type: 'subscription', month: '2026-09'),
        FakeBackend.payment(1, amount: 60000, type: 'subscription', month: '2026-09'),
      ];
    await openTrips(tester, api);

    // Rides: newest first with their status; a cancelled one says why.
    expect(find.byKey(const ValueKey('ride-h0')), findsOneWidget);
    expect(find.text('تمت'), findsNWidgets(2));
    expect(find.text('بلا مقعد'), findsOneWidget);
    expect(find.text('لا شيء أقدم'), findsOneWidget);

    // Payments: 45 receipts in pages of 20, loaded as the list scrolls.
    await tester.tap(find.byKey(const ValueKey('tab-payments')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payment-45')), findsOneWidget);
    int pageCalls() => api.requests.where((r) => r.url.path == '/payments/me').length;
    expect(pageCalls(), 1);

    await tester.scrollUntilVisible(find.byKey(const ValueKey('payment-10')), 400, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(pageCalls(), greaterThanOrEqualTo(2));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('payment-1')), 400, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(pageCalls(), 3);
    expect(api.requests.where((r) => r.url.path == '/payments/me').last.url.queryParameters['cursor'], 'pay6');
    expect(find.text('اشتراك أيلول 2026'), findsOneWidget);
    expect(find.text('إلغاء: اشتراك أيلول 2026'), findsOneWidget);
    expect(find.text('-60,000 د.ع'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('لا شيء أقدم'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('لا شيء أقدم'), findsOneWidget);
    // At the end no more pages are asked for.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(pageCalls(), 3);
  });

  testWidgets('history: empty lists explain themselves', (tester) async {
    final api = FakeBackend(signedIn: true, withPoint: true);
    await openTrips(tester, api);
    expect(find.text('لا رحلات سابقة'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tab-payments')));
    await tester.pumpAndSettle();
    expect(find.text('لا مدفوعات بعد'), findsOneWidget);
  });

  testWidgets('history: a failed load shows retry; a failed next page keeps the list and retries at the end', (tester) async {
    final api = FakeBackend(signedIn: true, withPoint: true)
      ..historyFails = true
      ..paymentHistory = [for (var i = 30; i > 0; i--) FakeBackend.payment(i)];
    await openTrips(tester, api);
    expect(find.byKey(const ValueKey('history-error')), findsOneWidget);
    api.historyFails = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('لا رحلات سابقة'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-payments')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payment-30')), findsOneWidget);
    api.historyFails = true;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('more-retry')), 400, scrollable: find.byType(Scrollable).last);
    expect(find.byKey(const ValueKey('payment-11')), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300)); // clear the floating tab bar
    await tester.pumpAndSettle();
    api.historyFails = false;
    await tester.tap(find.byKey(const ValueKey('more-retry')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('payment-1')), 400, scrollable: find.byType(Scrollable).last);
    expect(find.byKey(const ValueKey('payment-1')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ST-11: rate a finished ride once, and report a problem about it', (tester) async {
    final api = FakeBackend(signedIn: true, withPoint: true)..rideHistory = [FakeBackend.pastRide(0), FakeBackend.pastRide(1, rating: 3)];
    await openTrips(tester, api);
    expect(find.byKey(const ValueKey('stars-h1')), findsOneWidget);
    expect(find.byKey(const ValueKey('rate-h1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('rate-h0')));
    await tester.pumpAndSettle();
    expect(find.text('كيف كانت الرحلة؟'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('star-4')));
    await tester.enterText(find.byType(TextField), 'سائق محترم');
    await tester.tap(find.text('أرسل التقييم'));
    await tester.pumpAndSettle();
    expect(api.ratings.single, {'requestId': 'h0', 'stars': 4, 'comment': 'سائق محترم'});
    expect(find.byKey(const ValueKey('rate-h0')), findsNothing);
    expect(find.byKey(const ValueKey('stars-h0')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // the thank-you snack bar goes away
    await tester.pumpAndSettle();

    await tester.tap(find.text('أبلغ عن مشكلة').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cat-late')));
    await tester.enterText(find.byType(TextField), 'تأخرت الحافلة ربع ساعة');
    await tester.pump();
    await tester.tap(find.text('أرسل البلاغ'));
    await tester.pumpAndSettle();
    expect(api.problems.single, {'category': 'late', 'text': 'تأخرت الحافلة ربع ساعة', 'requestId': 'h0'});
    expect(find.text('وصل بلاغك إلى مكتب النقل'), findsOneWidget);
  });

  testWidgets('TO-11: an announcement shows on Home until dismissed', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true)
      ..announcements = [
        {'id': 'n1', 'announcementId': 'a1', 'title': 'تغيير مكان التجمع', 'body': 'نقطة باب بغداد تنتقل ٥٠ متراً.', 'expiresAt': '2099-01-01T00:00:00Z', 'createdAt': '2026-10-05T06:00:00Z'},
      ];
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    expect(find.text('تغيير مكان التجمع'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('announcement-n1')), matching: find.byType(NaqlIconButton)));
    await tester.pumpAndSettle();
    expect(find.text('تغيير مكان التجمع'), findsNothing);
    final read = api.requests.lastWhere((r) => r.url.path == '/notifications/read');
    expect(read.body, '{"ids":["n1"]}');
  });
}
