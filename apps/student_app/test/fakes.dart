import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:student_app/app.dart';

/// In-memory stand-in for the Naql API with one university, two points and one roster student.
class FakeBackend {
  FakeBackend({this.signedIn = false, this.withPoint = false, Map<String, Object?>? subscription}) : subscription = subscription ?? noSubscription {
    if (withPoint) profile['defaultPoint'] = {...points.first, 'tierId': 't-b'};
  }

  final bool signedIn;
  final bool withPoint;

  /// What GET /subscriptions/me returns; tests may replace it to simulate the office recording a payment.
  Map<String, Object?> subscription;

  static const Map<String, Object?> noSubscription = {
    'status': 'none',
    'daysLeft': 0,
    'current': null,
    'upcoming': null,
    'price': 60000,
    'tierName': 'B',
    'payAt': {'officeNote': 'مكتب النقل — البناية ب، الطابق الأرضي'},
  };

  static Map<String, Object?> active({int daysLeft = 20, String status = 'active'}) => {
        'status': status,
        'daysLeft': daysLeft,
        'current': {'month': '2026-10', 'start': '2026-10-01T00:00:00.000Z', 'end': '2026-10-31T00:00:00.000Z', 'price': 60000},
        'upcoming': null,
        'price': 60000,
        'tierName': 'B',
        'payAt': {'officeNote': 'مكتب النقل — البناية ب، الطابق الأرضي'},
      };
  final requests = <http.Request>[];

  /// What GET /rides/me returns; tests change it to simulate dispatch (server side).
  List<Map<String, Object?>> rides = [];

  /// Baghdad civil dates, so "today" labels and goldens do not depend on when tests run.
  static String day([int plus = 0]) {
    final d = DateTime.now().toUtc().add(Duration(hours: 3, days: plus));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String get today => day();

  final slots = [
    {'waveId': 'w8', 'date': day(), 'type': 'morning', 'minuteOfDay': 480, 'time': '08:00', 'today': true},
    {'waveId': 'w14', 'date': day(), 'type': 'return', 'minuteOfDay': 840, 'time': '14:00', 'today': true},
    {'waveId': 'w8', 'date': day(1), 'type': 'morning', 'minuteOfDay': 480, 'time': '08:00', 'today': false},
  ];

  static Map<String, Object?> ride({
    String id = 'r1',
    String status = 'open',
    String? date,
    String time = '08:00',
    String type = 'morning',
    int fare = 0,
    DateTime? waitlistedUntil,
    String? cancelReason,
    Map<String, Object?>? assignment,
  }) =>
      {
        'id': id,
        'status': status,
        'date': date ?? today,
        'wave': {'id': 'w8', 'type': type, 'minuteOfDay': 480, 'time': time},
        'point': {'id': 'p1', 'name': 'Al-Abbas Square', 'nameAr': 'ساحة العباس'},
        'subscriber': fare == 0,
        'fare': fare,
        'waitlistedUntil': waitlistedUntil?.toUtc().toIso8601String(),
        'cancelReason': cancelReason,
        'assignment': assignment,
      };

  static Map<String, Object?> assignment({DateTime? pickupAt}) => {
        'runId': 'run1',
        'driverName': 'حيدر عباس',
        'driverPhone': '+9647801234567',
        'plate': '12345 كربلاء',
        'vehicleType': 'كوستر',
        'vehiclePhotoUrl': null,
        'pickupAt': (pickupAt ?? DateTime(2026, 10, 5, 7, 32)).toUtc().toIso8601String(),
        'stopNumber': 2,
        'stops': 3,
      };

  final points = [
    {'id': 'p1', 'name': 'Al-Abbas Square', 'nameAr': 'ساحة العباس', 'tierId': 't-b', 'tier': {'id': 't-b', 'name': 'B'}, 'distanceKm': 4.8, 'active': true},
    {'id': 'p2', 'name': 'Bab Baghdad', 'nameAr': 'باب بغداد', 'tierId': 't-a', 'tier': {'id': 't-a', 'name': 'A'}, 'distanceKm': 2.7, 'active': true},
  ];

  final Map<String, Object?> profile = {
    'id': 's1',
    'studentId': 'W-1001',
    'name': 'Zainab Kadhim',
    'nameAr': 'زينب كاظم',
    'gender': 'female',
    'phone': null,
    'defaultPoint': null,
  };

  http.Response _json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

  late final client = MockClient((req) async {
    requests.add(req);
    final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
    switch ('${req.method} ${req.url.path}') {
      case 'GET /public/universities':
        return _json([
          {'slug': 'warith', 'name': 'Warith Al-Anbiyaa University', 'nameAr': 'جامعة وارث الأنبياء', 'studentSignIn': 'manual'},
        ]);
      case 'POST /auth/student/login':
        if (body['studentId'] == 'W-1001' && body['password'] == 'secret-pass') return _json(_session);
        return _json({'message': 'Student number or password is incorrect'}, 401);
      case 'POST /auth/student/activate':
        if (body['code'] == '482913') return _json(_session);
        return _json({'message': 'bad code'}, 401);
      case 'GET /students/me':
        return _json(profile);
      case 'PATCH /students/me':
        if (body.containsKey('defaultPointId')) profile['defaultPoint'] = points.firstWhere((p) => p['id'] == body['defaultPointId']);
        if (body.containsKey('phone')) profile['phone'] = '+964${(body['phone'] as String).replaceFirst(RegExp(r'^(\+?964|0)'), '')}';
        return _json(profile);
      case 'GET /gathering-points':
        return _json(points);
      case 'GET /subscriptions/me':
        return _json(subscription);
      case 'GET /rides/options':
        return _json({'slots': slots, 'defaultPointId': (profile['defaultPoint'] as Map?)?['id'], 'gender': profile['gender']});
      case 'GET /rides/me':
        return _json(rides);
      case 'POST /rides':
        final slot = slots.firstWhere((x) => x['waveId'] == body['waveId'] && x['date'] == body['date']);
        final r = ride(id: 'r${rides.length + 1}', date: slot['date'] as String, time: slot['time'] as String, type: slot['type'] as String);
        rides = [r, ...rides];
        return _json(r, 201);
    }
    final cancel = RegExp(r'^/rides/([^/]+)/cancel$').firstMatch(req.url.path);
    if (req.method == 'POST' && cancel != null) {
      rides = [for (final r in rides) r['id'] == cancel.group(1) ? {...r, 'status': 'cancelled', 'cancelReason': 'student', 'assignment': null} : r];
      return _json(rides.firstWhere((r) => r['id'] == cancel.group(1)));
    }
    return _json({'message': 'not found'}, 404);
  });

  Map<String, Object> get _session => {
        'accessToken': 'tok',
        'user': {'id': 's1', 'name': 'Zainab Kadhim', 'role': 'student', 'universityId': 'u1'},
      };

  /// The app wired to this backend, optionally already signed in.
  Future<Widget> app({String lang = 'ar'}) async {
    final tokens = MemoryTokenStore();
    if (signedIn) await tokens.write('tok');
    return ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(MemoryPrefs({'naql.lang': lang, if (signedIn) 'naql.university': 'warith'})),
        tokenStoreProvider.overrideWithValue(tokens),
        apiProvider.overrideWithValue(ApiClient(baseUrl: Uri.parse('http://api.test/'), tokens: tokens, httpClient: client)),
      ],
      child: const StudentApp(),
    );
  }
}

/// Phone-sized surface for screen goldens and flows.
void usePhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  addTearDown(tester.view.reset);
}
