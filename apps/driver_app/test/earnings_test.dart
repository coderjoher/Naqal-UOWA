import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

import 'fakes.dart';

void main() {
  testWidgets('[T6-06] earnings screen shows runs, estimate and past settlements; estimate equals the API draft', (tester) async {
    usePhone(tester);
    final api = FakeDriverBackend(status: 'approved');
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('الأرباح'));
    await tester.pumpAndSettle();

    expect(find.text('أرباح تشرين الأول 2026'), findsOneWidget);
    expect(find.text('قيد المراجعة في المكتب'), findsOneWidget);
    // The big number is exactly the server's draft line for this driver.
    expect(tester.widget<Text>(find.byKey(const ValueKey('estimate'))).data, formatIqd(api.earnings['estimate'] as int, 'ar'));
    expect(find.text('631,550 د.ع'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('runs'))).data, '18');
    expect(find.text('42,000 د.ع'), findsOneWidget);
    expect(find.text('−4,200 د.ع'), findsOneWidget);

    // Runs of the month: counted, flagged by the GPS check, not finished yet.
    expect(find.byKey(const ValueKey('earning-run-e1')), findsOneWidget);
    expect(find.text('محتسبة'), findsOneWidget);
    expect(find.text('غير محتسبة'), findsOneWidget);
    expect(find.text('لم تنتهِ'), findsOneWidget);
    expect(find.byKey(const ValueKey('flagged')), findsOneWidget);
    expect(find.textContaining('1 رحلات لم يثبت مسارها'), findsOneWidget);

    // Past approved settlements.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('past-2026-09')), 200);
    expect(find.text('أيلول 2026'), findsOneWidget);
    expect(find.text('702,300 د.ع'), findsOneWidget);
    expect(find.text('21 رحلة'), findsOneWidget);
  });

  testWidgets('earnings: a driver who kept more cash than earned sees what they owe', (tester) async {
    usePhone(tester);
    final api = FakeDriverBackend(status: 'approved')
      ..earnings = {'month': '2026-10', 'source': 'estimate', 'runs': 1, 'cash': 50000, 'cashCommission': 5000, 'estimate': -5000, 'list': [], 'past': []};
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('الأرباح'));
    await tester.pumpAndSettle();
    expect(find.text('المبلغ التقديري حتى الآن'), findsOneWidget);
    expect(find.text('-5,000 د.ع'), findsOneWidget);
    expect(find.text('عليك للمكتب'), findsOneWidget);
    expect(find.text('لا رحلات هذا الشهر بعد'), findsOneWidget);
  });

  testWidgets('[T9-04] no cash commission reads 0, not −0', (tester) async {
    usePhone(tester);
    final api = FakeDriverBackend(status: 'approved')
      ..earnings = {'month': '2026-10', 'source': 'estimate', 'runs': 0, 'cash': 0, 'cashCommission': 0, 'estimate': 0, 'list': [], 'past': []};
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('الأرباح'));
    await tester.pumpAndSettle();
    expect(find.textContaining('−0'), findsNothing);
    expect(find.text('0 د.ع'), findsWidgets);
  });
}
