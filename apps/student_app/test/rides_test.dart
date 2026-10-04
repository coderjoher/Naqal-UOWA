import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';
import 'package:student_app/l10n/gen/app_localizations.dart';
import 'package:student_app/screens/ride_cards.dart';

import 'fakes.dart';

Widget _host(Widget child, {String lang = 'ar'}) => MaterialApp(
      theme: buildNaqlTheme(),
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    );

/// 1×1 PNG standing in for the vehicle photo.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, //
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('[T4-10] assignment card shows bus, driver, plate, photo and pickup time', (tester) async {
    final ride = RideInfo.fromJson(FakeBackend.ride(status: 'assigned', fare: 1500, assignment: FakeBackend.assignment(pickupAt: DateTime(2026, 10, 5, 7, 32))));
    await tester.pumpWidget(_host(AssignmentCard(ride: ride, lang: 'ar', photo: MemoryImage(_png), femaleOnly: true, onCancel: () {})));
    await tester.pumpAndSettle();
    expect(find.text('07:32'), findsOneWidget); // pickup time, biggest text
    expect(find.text('08:00'), findsOneWidget); // at campus by the wave time
    expect(find.text('ساحة العباس'), findsOneWidget);
    expect(find.text('حيدر عباس'), findsOneWidget);
    expect(find.text('كوستر · 12345 كربلاء'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage), findsOneWidget);
    expect(find.text('مؤكد'), findsOneWidget);
    expect(find.text('للطالبات فقط'), findsOneWidget);
    expect(find.text('المحطة 2 من 3'), findsOneWidget);
    expect(find.text('ادفع 1,500 د.ع نقداً للسائق'), findsOneWidget);
    expect(find.text('إلغاء الطلب'), findsOneWidget);

    // Return wave: leaves campus at the wave time, drop-off time at the point.
    final back = RideInfo.fromJson(FakeBackend.ride(status: 'assigned', type: 'return', time: '14:00', assignment: FakeBackend.assignment(pickupAt: DateTime(2026, 10, 5, 14, 18))));
    await tester.pumpWidget(_host(AssignmentCard(ride: back, lang: 'en'), lang: 'en'));
    await tester.pumpAndSettle();
    final times = tester.widgetList<Text>(find.textContaining(RegExp(r'^\d\d:\d\d$'))).map((t) => t.data).toList();
    expect(times, ['14:00', '14:18']);
    expect(find.text('Campus'), findsOneWidget);
    expect(find.text('Covered by your subscription'), findsOneWidget);
  });

  testWidgets('[T4-10] waitlist card counts down and updates', (tester) async {
    final ride = RideInfo.fromJson(FakeBackend.ride(status: 'waitlisted', waitlistedUntil: clock.now().add(const Duration(minutes: 5))));
    await tester.pumpWidget(_host(WaitlistCard(ride: ride, onCancel: () {})));
    await tester.pump();
    expect(find.text('أنت على قائمة الانتظار'), findsOneWidget);
    String shown() => tester.widget<Text>(find.byKey(const ValueKey('countdown'))).data!;
    expect(shown(), anyOf('05:00', '04:59'));
    await tester.pump(const Duration(seconds: 1));
    final a = shown();
    await tester.pump(const Duration(seconds: 61));
    expect(shown(), isNot(a));
    expect(shown(), anyOf('03:58', '03:57'));
    // Never goes below zero.
    await tester.pump(const Duration(minutes: 10));
    expect(shown(), '00:00');
  });

  testWidgets('[T4-11] student requests a ride against the API and sees the assignment', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true);
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('اطلب رحلة'));
    await tester.pumpAndSettle();
    expect(find.text('طلب رحلة'), findsOneWidget);
    // Choose the 14:00 return and keep the default point.
    await tester.tap(find.byKey(ValueKey('slot-w14-${FakeBackend.today}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أرسل الطلب'));
    await tester.pumpAndSettle();
    final sent = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/rides');
    expect(sent.body, contains('"waveId":"w14"'));
    expect(sent.body, contains('"pointId":"p1"'));
    expect(find.text('وصل طلبك'), findsOneWidget);

    // Dispatch assigns a bus on the server; the app shows it within seconds without user action.
    api.rides = [FakeBackend.ride(status: 'assigned', assignment: FakeBackend.assignment())];
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('حيدر عباس'), findsOneWidget);
    expect(find.text('07:32'), findsOneWidget);
    expect(find.text('وصل طلبك'), findsNothing);

    // Cancel with confirmation → back to the request button.
    await tester.tap(find.text('إلغاء الطلب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نعم، ألغِ'));
    await tester.pumpAndSettle();
    expect(api.requests.any((r) => r.url.path == '/rides/r1/cancel'), isTrue);
    expect(find.text('اطلب رحلة'), findsOneWidget);
  });

  for (final state in ['assigned', 'waitlisted']) {
    testWidgets('[T4-10] home with a $state ride (golden)', (tester) async {
      usePhone(tester);
      final api = FakeBackend(signedIn: true, withPoint: true, subscription: FakeBackend.active());
      api.rides = [
        state == 'assigned'
            ? FakeBackend.ride(status: 'assigned', fare: 1500, assignment: FakeBackend.assignment())
            : FakeBackend.ride(status: 'waitlisted', waitlistedUntil: clock.now().add(const Duration(minutes: 18, seconds: 30))),
      ];
      await tester.pumpWidget(await api.app());
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_$state.rtl.png'));
    });
  }
}
