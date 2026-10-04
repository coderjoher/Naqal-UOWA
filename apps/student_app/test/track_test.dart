import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';
import 'package:naql_core/naql_core.dart';

import 'fakes.dart';

void main() {
  testWidgets('[T5-07] map shows the bus and ETA; when the socket drops it shows the last known position with "updated X ago"', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true);
    api.rides = [FakeBackend.ride(status: 'assigned', assignment: FakeBackend.assignment(runStatus: 'started'))];
    api.track = {
      ...api.track,
      'bus': {'runId': 'run1', 'lat': 32.62, 'lng': 44.0, 'at': clock.now().toUtc().toIso8601String(), 'speed': 8.0, 'heading': null, 'etas': [{'seq': 2, 'seconds': 230}]},
    };
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();

    // The assignment card offers live tracking while the bus is on its way.
    await tester.tap(find.text('تتبّع الحافلة'));
    await tester.pumpAndSettle();
    expect(find.text('حافلتك'), findsOneWidget);
    expect(find.text('تصل خلال 4 د'), findsOneWidget);
    expect(find.byKey(const ValueKey('bus-pin')), findsOneWidget);
    expect(find.byKey(const ValueKey('stop-pin')), findsOneWidget);
    expect(find.text('نقطتك: ساحة العباس'), findsOneWidget);
    expect(api.feed.joined, ['run1']);

    // Live update over the socket: the bus is now at the stop.
    api.feed.busesCtl.add(BusPosition(runId: 'run1', lat: 32.616, lng: 44.025, at: clock.now(), etas: const {2: 20}));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('الحافلة في نقطتك الآن'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^آخر تحديث قبل [0-2] ث$')), findsOneWidget);

    // Connection lost: keep the last position and say how old it is (NF-10).
    api.feed.connectedCtl.add(false);
    await tester.pump(const Duration(seconds: 40));
    expect(find.textContaining(RegExp(r'^آخر موقع معروف · آخر تحديث قبل 4\d ث$')), findsOneWidget);
    expect(find.byKey(const ValueKey('bus-pin')), findsOneWidget);
  });

  testWidgets('notifications list shows Arabic messages and live ones arrive', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true);
    final now = clock.now().toUtc();
    api.notifications = [
      {'id': 'n1', 'kind': 'ride.assigned', 'data': {}, 'createdAt': now.subtract(const Duration(minutes: 30)).toIso8601String(), 'readAt': null},
    ];
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.bell).first);
    await tester.pumpAndSettle();
    expect(find.text('تم تأكيد مقعدك'), findsOneWidget);

    api.notifications = [
      {'id': 'n2', 'kind': 'ride.approaching', 'data': {'minutes': 4}, 'createdAt': now.toIso8601String(), 'readAt': null},
      ...api.notifications,
    ];
    api.feed.notesCtl.add({'id': 'n2', 'kind': 'ride.approaching'});
    await tester.pumpAndSettle();
    expect(find.text('الحافلة تقترب'), findsOneWidget);
    expect(find.text('تصل إلى نقطتك خلال 4 دقائق تقريباً.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(api.requests.any((r) => r.url.path == '/notifications/read'), isTrue);
  });
}
