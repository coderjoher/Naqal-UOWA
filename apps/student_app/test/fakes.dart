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
  FakeBackend({this.signedIn = false, this.withPoint = false}) {
    if (withPoint) profile['defaultPoint'] = {...points.first, 'tierId': 't-b'};
  }

  final bool signedIn;
  final bool withPoint;
  final requests = <http.Request>[];

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
