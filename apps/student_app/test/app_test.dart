import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('first launch: welcome in Arabic RTL → university → sign in → choose point → home', (tester) async {
    usePhone(tester);
    final api = FakeBackend();
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    expect(find.text('تنقّلك اليومي إلى الجامعة'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('تنقّلك اليومي إلى الجامعة'))), TextDirection.rtl);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('جامعة وارث الأنبياء'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'W-1001');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(find.text('الرقم الجامعي أو كلمة المرور غير صحيحة'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'secret-pass');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    // No default point yet → onboarding asks for it.
    expect(find.text('نقطة التجمّع'), findsWidgets);
    await tester.tap(find.text('ساحة العباس'));
    await tester.pump();
    await tester.tap(find.text('اعتماد النقطة'));
    await tester.pumpAndSettle();

    expect(find.text('أهلاً، زينب'), findsOneWidget);
    expect(find.text('ساحة العباس'), findsOneWidget);
    expect(find.bySemanticsLabel('رحلاتي'), findsOneWidget);
  });

  testWidgets('activation with the office code signs the student in', (tester) async {
    usePhone(tester);
    final api = FakeBackend();
    await tester.pumpWidget(await api.app(lang: 'en'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warith Al-Anbiyaa University'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First time? Activate with the office code'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'W-1001');
    await tester.enterText(fields.at(1), '482913');
    await tester.enterText(fields.at(2), 'short');
    await tester.tap(find.text('Activate and sign in'));
    await tester.pumpAndSettle();
    expect(find.text('At least 8 characters'), findsWidgets);
    await tester.enterText(fields.at(2), 'secret-pass');
    await tester.tap(find.text('Activate and sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Gathering point'), findsWidgets);
    expect(api.requests.any((r) => r.url.path == '/auth/student/activate'), isTrue);
  });

  testWidgets('a signed-in student with a point lands on home; bottom nav switches tabs', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(await FakeBackend(signedIn: true, withPoint: true).app());
    await tester.pumpAndSettle();
    expect(find.text('أهلاً، زينب'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('رحلاتي'));
    await tester.pumpAndSettle();
    expect(find.text('قريباً'), findsOneWidget);
  });
}
