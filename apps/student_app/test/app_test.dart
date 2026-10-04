import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/app.dart';

void main() {
  testWidgets('boots in Arabic RTL on the home tab with the floating nav', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudentApp()));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.text('أهلاً بك'))), TextDirection.rtl);
    expect(find.text('لا توجد رحلة اليوم'), findsOneWidget);
    expect(find.bySemanticsLabel('رحلاتي'), findsOneWidget);
  });

  testWidgets('bottom nav switches tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudentApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('حسابي'));
    await tester.pumpAndSettle();
    expect(find.text('قريباً'), findsOneWidget);
  });

  testWidgets('English is available and switches to LTR', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const StudentApp()));
    container.read(localeProvider.notifier).toggle();
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Welcome'))), TextDirection.ltr);
  });
}
