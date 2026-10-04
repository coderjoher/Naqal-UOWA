import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

import 'fakes.dart';

Future<FakeBackend> _openProfile(WidgetTester tester) async {
  usePhone(tester);
  final api = FakeBackend(signedIn: true, withPoint: true);
  await tester.pumpWidget(await api.app());
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('حسابي'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('[T2-03] profile shows read-only gender, editable phone and a default point picker', (tester) async {
    final api = await _openProfile(tester);

    // Gender (and name, student number) are shown with a lock and are not editable fields.
    expect(find.text('أنثى'), findsOneWidget);
    expect(find.byIcon(LucideIcons.lock), findsNWidgets(3));
    expect(find.widgetWithText(TextField, 'أنثى'), findsNothing);
    expect(find.text('من سجلات الجامعة ولا يمكن تعديله'), findsOneWidget);

    // Phone: invalid number is refused locally; valid number is saved.
    final phone = find.byType(TextField);
    expect(phone, findsOneWidget);
    await tester.enterText(phone, '12345');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل رقم موبايل عراقي صحيح'), findsOneWidget);
    await tester.enterText(phone, '0770 123 4567');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('تم الحفظ'), findsOneWidget);
    final patch = api.requests.lastWhere((r) => r.method == 'PATCH');
    expect(patch.body, contains('07701234567'));
    expect(patch.body, isNot(contains('gender')));

    // Default point picker changes the point.
    expect(find.text('ساحة العباس'), findsOneWidget);
    await tester.tap(find.text('نقطة التجمّع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('باب بغداد'));
    await tester.pump();
    await tester.tap(find.text('اعتماد النقطة'));
    await tester.pumpAndSettle();
    expect(find.text('باب بغداد'), findsOneWidget);
  });

  testWidgets('language switch from the profile flips the app to English LTR', (tester) async {
    await _openProfile(tester);
    await tester.tap(find.text('اللغة'));
    await tester.pumpAndSettle();
    expect(find.text('Personal information'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Personal information'))), TextDirection.ltr);
  });
}
