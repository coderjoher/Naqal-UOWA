import 'package:driver_app/data/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('[T2-07] driver signs in by phone, fills the form, photographs documents with the (mocked) camera and submits', (tester) async {
    usePhone(tester);
    final api = FakeDriverBackend();
    final camera = FakeCamera();
    await tester.pumpWidget(await api.app(camera: camera));
    await tester.pumpAndSettle();

    // Onboarding: language → university → phone → code (test env shows the code).
    await tapText(tester, 'متابعة');
    await tapText(tester, 'جامعة وارث الأنبياء');
    await tester.enterText(find.byType(TextField), '123');
    await tapText(tester, 'إرسال الرمز');
    expect(find.text('أدخل رقم موبايل عراقي صحيح'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0780 111 2233');
    await tapText(tester, 'إرسال الرمز');
    expect(find.textContaining('135790'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '135790');
    await tester.pumpAndSettle();

    // Registration form generated from the office requirements.
    expect(find.text('طلب التسجيل'), findsOneWidget);
    expect(find.text('1 من 8 مكتمل'), findsOneWidget);
    expect(find.text('إجازة السوق'), findsOneWidget);

    // Submitting too early is refused with a clear message.
    await tester.tap(find.text('إرسال للمراجعة'));
    await tester.pumpAndSettle();
    expect(find.text('أكمل الحقول والوثائق المطلوبة أولاً'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'علي حسن');
    await tapText(tester, 'كوستر');
    await tester.enterText(fields.at(1), '45 ك 12345');
    await tester.enterText(fields.at(2), '20');
    await tester.enterText(fields.at(3), '2019');
    await tapText(tester, 'حفظ البيانات');
    expect(find.text('6 من 8 مكتمل'), findsOneWidget);

    // Both documents via the camera.
    for (var i = 0; i < 2; i++) {
      final take = find.text('تصوير').at(i);
      await tester.ensureVisible(take);
      await tester.tap(take);
      await tester.pumpAndSettle();
    }
    expect(camera.sources, [DocumentSource.camera, DocumentSource.camera]);
    expect(api.docs, {'driving_licence', 'vehicle_registration'});
    expect(find.text('8 من 8 مكتمل'), findsOneWidget);

    await tester.tap(find.text('إرسال للمراجعة'));
    await tester.pumpAndSettle();
    expect(find.text('طلبك قيد المراجعة'), findsOneWidget);
    expect(api.state['status'], 'pending');
  });

  testWidgets('a rejected driver sees the reason and can edit the application again', (tester) async {
    usePhone(tester);
    final api = FakeDriverBackend(status: 'rejected', note: 'صورة الإجازة غير واضحة');
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    expect(find.text('لم يُقبل الطلب'), findsOneWidget);
    expect(find.textContaining('صورة الإجازة غير واضحة'), findsOneWidget);
    await tapText(tester, 'تعديل الطلب');
    expect(find.text('طلب التسجيل'), findsOneWidget);
  });

  testWidgets('a suspended driver cannot reach runs; an approved one lands on today', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(await FakeDriverBackend(status: 'suspended', note: 'تأخر متكرر').app(signedIn: true));
    await tester.pumpAndSettle();
    expect(find.text('حسابك موقوف'), findsOneWidget);
    expect(find.text('رحلات اليوم'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(await FakeDriverBackend(status: 'approved').app(signedIn: true, lang: 'en'));
    await tester.pumpAndSettle();
    expect(find.text("Today's runs"), findsOneWidget);
    expect(Directionality.of(tester.element(find.text("Today's runs"))), TextDirection.ltr);
  });
}
