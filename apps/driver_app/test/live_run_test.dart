import 'package:clock/clock.dart';
import 'package:driver_app/data/run_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<FakeDriverBackend> openRun(WidgetTester tester, {String run = 'ذهاب 08:00'}) async {
  usePhone(tester);
  final api = FakeDriverBackend(status: 'approved')..runs = FakeDriverBackend.sampleRuns();
  await tester.pumpWidget(await api.app(signedIn: true));
  await tester.pumpAndSettle();
  await tester.tap(find.text(run));
  await tester.pumpAndSettle();
  return api;
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.tap(find.text(text).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('[T5-03] 10 minutes offline during a run: every GPS point and action syncs on reconnect, no duplicates', (tester) async {
    final api = await openRun(tester);
    await tapText(tester, 'ابدأ الرحلة');
    await tester.pump(const Duration(seconds: 1));
    expect(api.actionsReceived.map((a) => a['type']), ['start']);

    // Coverage drops for 10 minutes. GPS keeps coming every 5 s and the driver keeps working.
    api.online = false;
    for (var i = 0; i < 120; i++) {
      api.location.controller.add(GpsFix(lat: 32.62 + i * 1e-4, lng: 44.0, at: clock.now(), speed: 8));
      await tester.pump(const Duration(seconds: 5));
      if (i == 60) {
        await tapText(tester, 'وصلت إلى المحطة');
        await tapText(tester, 'علي كريم');
        await tapText(tester, 'عمر سعد');
        await tapText(tester, 'استلمت 2,000 د.ع');
      }
    }
    // Both riders are on board, so the bus may leave without waiting.
    await tapText(tester, 'انطلق');
    expect(find.textContaining('بانتظار الإرسال'), findsOneWidget); // the driver can see it is queued
    expect(api.gpsReceived, isEmpty);

    // Back online; the first reply is lost after the server applied it — the retry must not duplicate.
    api.online = true;
    api.loseNextReply = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(api.gpsReceived, hasLength(120));
    expect(api.gpsReceived.map((p) => p['at']).toSet(), hasLength(120)); // no point twice
    expect(api.actionsReceived.map((a) => a['type']), ['start', 'arrive', 'board', 'board', 'depart']);
    expect(api.actionsReceived.map((a) => a['clientId']).toSet(), hasLength(5));
    expect(api.faresReceived, hasLength(1));
    expect(find.textContaining('بانتظار الإرسال'), findsNothing);
    // Device times are kept: the arrival was recorded ~5 minutes into the outage, not at reconnect.
    final arrive = DateTime.parse(api.actionsReceived[1]['at'] as String);
    final depart = DateTime.parse(api.actionsReceived[4]['at'] as String);
    expect(depart.difference(arrive).inMinutes, inInclusiveRange(4, 6));
  });

  testWidgets('stop flow: board, cash fare, no-show wait, then leave; a live update adds a rider', (tester) async {
    final api = await openRun(tester);
    await tapText(tester, 'ابدأ الرحلة');
    await tapText(tester, 'وصلت إلى المحطة');
    await tapText(tester, 'علي كريم'); // subscriber; عمر سعد does not come

    // SM-04: the bus must wait the university's 3 minutes for the missing rider.
    expect(find.textContaining('انتظر 02:5'), findsOneWidget);
    await tapText(tester, 'انطلق');
    expect(api.actionsReceived.where((a) => a['type'] == 'depart'), isEmpty);
    await tester.pump(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('انطلق — 1 لم يحضر'), findsOneWidget);
    await tapText(tester, 'انطلق — 1 لم يحضر');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(api.actionsReceived.map((a) => a['type']), ['start', 'arrive', 'board', 'depart']);
    await tester.tap(find.text('حي الحسين').last);
    await tester.pumpAndSettle();
    expect(find.text('لم يحضر'), findsOneWidget); // shown on the timeline
    expect(find.text('صعد'), findsOneWidget);

    // DR-09: the office/dispatcher adds a rider to stop 3; the screen refreshes on the live event.
    final stops = (api.runs.first['stops'] as List).cast<Map<String, Object?>>();
    (stops[2]['passengers'] as List).add({'requestId': 'new1', 'name': 'منتظر جواد', 'fare': 2000, 'subscriber': false});
    api.feed.runChangesCtl.add('run-m');
    await tester.pumpAndSettle();
    await tester.tap(find.text('باب بغداد').last);
    await tester.pumpAndSettle();
    expect(find.text('منتظر جواد'), findsOneWidget);
  });

  testWidgets('[T5-11] Navigate opens Google Maps / Waze with the next stop', (tester) async {
    final api = await openRun(tester);
    await tester.tap(find.byKey(const ValueKey('navigate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خرائط Google'));
    await tester.pumpAndSettle();
    expect(api.launched.single.toString(), 'google.navigation:q=32.6,44.0&mode=d');

    await tester.tap(find.byKey(const ValueKey('navigate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Waze'));
    await tester.pumpAndSettle();
    expect(api.launched.last.toString(), 'https://waze.com/ul?ll=32.6,44.0&navigate=yes');
  });

  testWidgets('return run: mark who boarded on campus, leave, drop off, finish', (tester) async {
    final api = await openRun(tester, run: 'عودة 14:00');
    expect(find.text('سجّل من صعد في الجامعة'), findsOneWidget);
    await tapText(tester, 'زينب كاظم');
    await tapText(tester, 'مريم حسين');
    await tapText(tester, 'انطلق من الجامعة');
    await tapText(tester, 'وصلت إلى المحطة');
    await tapText(tester, 'انطلق');
    expect(find.text('نزل جميع الطلبة'), findsOneWidget);
    await tapText(tester, 'إنهاء الرحلة');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(api.actionsReceived.map((a) => a['type']), ['start', 'arrive', 'depart', 'end']);
    expect((api.actionsReceived.first['requestIds'] as List), hasLength(2));
    expect(find.text('انتهت الرحلة'), findsOneWidget);
  });
}
