import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('account: shows the driver and the approved vehicle, switches language, signs out after confirming', (tester) async {
    usePhone(tester);
    final api = FakeDriverBackend(status: 'approved');
    api.state.addAll({'name': 'حيدر عباس', 'vehicleType': 'coaster', 'plate': '12340 كربلاء', 'seats': 14, 'modelYear': 2019});
    api.docs.addAll({'driving_licence', 'vehicle_registration'});
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('حسابي'));
    await tester.pumpAndSettle();

    expect(find.text('قريباً'), findsNothing);
    expect(find.text('حيدر عباس'), findsOneWidget);
    expect(find.text('07801112233'), findsOneWidget);
    expect(find.text('معتمد'), findsOneWidget);
    expect(find.text('كوستر'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('رقم اللوحة: 12340 كربلاء\\.')), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
    expect(find.text('مستمسكان مرفوعان'), findsOneWidget);

    // Tapping Documents lists each one the office asked for, with its state.
    await tester.tap(find.text('المستمسكات'));
    await tester.pumpAndSettle();
    expect(find.text('إجازة السوق'), findsOneWidget);
    expect(find.text('سنوية السيارة'), findsOneWidget);
    expect(find.text('مرفوع'), findsNWidgets(2));
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.text('إجازة السوق'), findsNothing);

    await tester.tap(find.text('اللغة'));
    await tester.pumpAndSettle();
    expect(find.text('Your vehicle'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    expect(find.text('Your vehicle'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(find.text('Your vehicle'), findsNothing);
  });
}
