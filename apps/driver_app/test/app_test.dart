import 'package:driver_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots in Arabic RTL on today\'s runs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DriverApp()));
    await tester.pumpAndSettle();
    expect(find.text('رحلات اليوم'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('رحلات اليوم'))), TextDirection.rtl);
    expect(find.text('لا توجد رحلات اليوم'), findsOneWidget);
  });

  testWidgets('bottom nav switches to earnings', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DriverApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('الأرباح'));
    await tester.pumpAndSettle();
    expect(find.text('الأرباح'), findsOneWidget);
    expect(find.text('قريباً'), findsOneWidget);
  });
}
