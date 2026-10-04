import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/screens/runs/run_screen.dart';
import 'package:naql_ui/naql_ui.dart';

import 'fakes.dart';

void main() {
  testWidgets('[T4-12] run screen lists stops in order with rider counts and 56 dp targets', (tester) async {
    usePhone(tester);
    final api = FakeDriverBackend(status: 'approved')..runs = FakeDriverBackend.sampleRuns();
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();

    // Today: both runs, when to leave, stops, seats and cash.
    expect(find.text('ذهاب 08:00'), findsOneWidget);
    expect(find.text('عودة 14:00'), findsOneWidget);
    expect(find.text('07:12'), findsOneWidget);
    expect(find.text('6 من 14 مقعد'), findsOneWidget);
    expect(find.text('للطالبات فقط'), findsOneWidget);
    expect(find.text('5,500 د.ع'), findsOneWidget);

    await tester.tap(find.text('ذهاب 08:00'));
    await tester.pumpAndSettle();

    // Stops in driving order (far → near), then campus.
    Finder inTimeline(String text) => text == 'الجامعة' ? find.text(text) : find.descendant(of: find.byType(StopTile), matching: find.text(text));
    final names = ['حي الحسين', 'ساحة العباس', 'باب بغداد', 'الجامعة'];
    final ys = [for (final n in names) tester.getTopLeft(inTimeline(n)).dy];
    expect([...ys]..sort(), ys);
    expect(find.text('الركاب: 2'), findsOneWidget);
    expect(find.text('الركاب: 3'), findsOneWidget);
    expect(find.text('الركاب: 1'), findsOneWidget);
    expect(find.text('الوصول قبل 08:00'), findsOneWidget);
    for (final seq in [1, 2, 3]) {
      expect(tester.getSize(find.byKey(ValueKey('stop-$seq'))).height, greaterThanOrEqualTo(NaqlTouch.driver));
    }

    // Tapping a stop shows who boards there and who pays cash.
    await tester.tap(inTimeline('ساحة العباس'));
    await tester.pumpAndSettle();
    expect(find.text('حسن جاسم'), findsOneWidget);
    expect(find.text('أحمد فلاح'), findsOneWidget);
    expect(find.text('2,000 د.ع نقداً'), findsOneWidget);
    expect(find.text('مشترك'), findsNWidgets(2));
    expect(tester.getSize(find.ancestor(of: find.text('حسن جاسم'), matching: find.byType(ConstrainedBox)).first).height, greaterThanOrEqualTo(NaqlTouch.driver));
  });

  testWidgets('availability: offer a wave, planned waves are locked', (tester) async {
    usePhone(tester);
    final api = FakeDriverBackend(status: 'approved');
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد رحلات اليوم'), findsOneWidget);
    await tester.tap(find.text('عيّن جدولك'));
    await tester.pumpAndSettle();
    expect(find.text('متى ستعمل؟'), findsOneWidget);
    expect(find.text('مُقفل — تم التوزيع'), findsOneWidget);

    // Locked: tapping does nothing.
    final before = api.requests.length;
    await tester.tap(find.byKey(ValueKey('wave-${FakeDriverBackend.day()}-w8')));
    await tester.pumpAndSettle();
    expect(api.requests.length, before);

    // Tomorrow's return: on, saved with PUT.
    await tester.tap(find.byKey(ValueKey('wave-${FakeDriverBackend.day(1)}-w14')));
    await tester.pumpAndSettle();
    final put = api.requests.lastWhere((r) => r.method == 'PUT');
    expect(put.url.path, '/drivers/me/availability');
    final saved = (api.days[1]['waves'] as List).cast<Map<String, Object?>>();
    expect(saved.firstWhere((w) => w['waveId'] == 'w14')['available'], isTrue);
  });

  testWidgets('[T4-12] today, run and schedule screens (golden)', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    addTearDown(tester.view.reset);
    final api = FakeDriverBackend(status: 'approved')..runs = FakeDriverBackend.sampleRuns();
    // Fixed dates so the golden does not change with the calendar.
    for (final (i, d) in api.days.indexed) {
      d['date'] = '2026-10-0${4 + i}';
    }
    await tester.pumpWidget(await api.app(signedIn: true));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/today.rtl.png'));
    await tester.tap(find.text('ذهاب 08:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(StopTile), matching: find.text('ساحة العباس')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/run.rtl.png'));
    await tester.tap(find.byIcon(LucideIcons.calendarDays));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/schedule.rtl.png'));
  });
}
