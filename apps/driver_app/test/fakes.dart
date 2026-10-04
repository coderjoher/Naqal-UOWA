import 'dart:convert';

import 'package:driver_app/app.dart';
import 'package:driver_app/data/image_document_picker.dart';
import 'package:driver_app/data/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';

/// Camera stand-in: returns a tiny JPEG and records which source was used.
class FakeCamera implements DocumentPicker {
  final sources = <DocumentSource>[];

  @override
  Future<PickedDocument?> pick(DocumentSource source) async {
    sources.add(source);
    return const PickedDocument(bytes: [0xff, 0xd8, 0xff, 0xd9], filename: 'photo.jpg', mime: 'image/jpeg');
  }
}

/// In-memory driver backend implementing the P2 endpoints with the default office requirements.
class FakeDriverBackend {
  FakeDriverBackend({String status = 'draft', String? note}) {
    state['status'] = status;
    state['reviewNote'] = note;
  }

  final requests = <http.BaseRequest>[];

  /// GET /drivers/me/runs (P4).
  List<Map<String, Object?>> runs = [];

  /// GET /drivers/me/availability: three days, two waves each; the first morning is already planned.
  late List<Map<String, Object?>> days = [
    for (var i = 0; i < 3; i++)
      {
        'date': day(i),
        'waves': [
          {'waveId': 'w8', 'type': 'morning', 'time': '08:00', 'available': i == 0, 'locked': i == 0},
          {'waveId': 'w14', 'type': 'return', 'time': '14:00', 'available': false, 'locked': false},
        ],
      },
  ];

  static String day([int plus = 0]) {
    final d = DateTime.now().toUtc().add(Duration(hours: 3, days: plus));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Map<String, Object?> _stop(int seq, String name, String nameAr, int h, int m, List<(String, int)> riders) => {
        'seq': seq,
        'eta': DateTime(2026, 10, 5, h, m).toUtc().toIso8601String(),
        'served': false,
        'point': {'id': 'p$seq', 'name': name, 'nameAr': nameAr, 'lat': 32.6, 'lng': 44.0},
        'count': riders.length,
        'cashToCollect': riders.fold<int>(0, (n, r) => n + r.$2),
        'passengers': [
          for (final (i, r) in riders.indexed) {'requestId': 'q$seq$i', 'name': r.$1, 'studentId': 'W-$seq$i', 'fare': r.$2, 'subscriber': r.$2 == 0},
        ],
      };

  /// A morning run with three stops (far → near) and a female-only return run.
  static List<Map<String, Object?>> sampleRuns() => [
        {
          'id': 'run-m',
          'date': day(),
          'status': 'planned',
          'gender': 'male',
          'femaleOnly': false,
          'capacity': 14,
          'booked': 6,
          'wave': {'id': 'w8', 'type': 'morning', 'time': '08:00'},
          'departAt': DateTime(2026, 10, 5, 7, 12).toUtc().toIso8601String(),
          'stops': [
            _stop(1, 'Hay Al-Hussein', 'حي الحسين', 7, 12, [('علي كريم', 0), ('عمر سعد', 2000)]),
            _stop(2, 'Al-Abbas Square', 'ساحة العباس', 7, 24, [('حسن جاسم', 0), ('مصطفى علي', 0), ('أحمد فلاح', 2000)]),
            _stop(3, 'Bab Baghdad', 'باب بغداد', 7, 38, [('كرار حيدر', 1500)]),
          ],
        },
        {
          'id': 'run-r',
          'date': day(),
          'status': 'planned',
          'gender': 'female',
          'femaleOnly': true,
          'capacity': 14,
          'booked': 2,
          'wave': {'id': 'w14', 'type': 'return', 'time': '14:00'},
          'departAt': DateTime(2026, 10, 5, 14, 0).toUtc().toIso8601String(),
          'stops': [
            _stop(1, 'Bab Baghdad', 'باب بغداد', 14, 9, [('زينب كاظم', 0), ('مريم حسين', 1500)]),
          ],
        },
      ];
  final Map<String, Object?> state = {'name': null, 'vehicleType': null, 'plate': null, 'seats': null, 'modelYear': null};
  final docs = <String>{};

  static const form = [
    {'key': 'name', 'kind': 'text', 'label': 'Full name', 'labelAr': 'الاسم الكامل', 'required': true},
    {'key': 'phone', 'kind': 'phone', 'label': 'Phone', 'labelAr': 'رقم الهاتف', 'required': true},
    {'key': 'vehicle_type', 'kind': 'select', 'label': 'Vehicle type', 'labelAr': 'نوع المركبة', 'required': true, 'options': ['coaster', 'minibus']},
    {'key': 'plate', 'kind': 'text', 'label': 'Plate number', 'labelAr': 'رقم اللوحة', 'required': true},
    {'key': 'seats', 'kind': 'number', 'label': 'Passenger seats', 'labelAr': 'عدد المقاعد', 'required': true, 'min': 10, 'max': 80},
    {'key': 'model_year', 'kind': 'year', 'label': 'Model year', 'labelAr': 'سنة الصنع', 'required': true, 'min': 2011, 'max': 2027},
    {'key': 'doc_driving_licence', 'kind': 'document', 'label': 'Driving licence', 'labelAr': 'إجازة السوق', 'required': true},
    {'key': 'doc_vehicle_registration', 'kind': 'document', 'label': 'Vehicle registration', 'labelAr': 'سنوية السيارة', 'required': true},
  ];

  List<String> get missing => [
        if (state['name'] == null) 'name',
        if (state['vehicleType'] == null) 'vehicle_type',
        if (state['plate'] == null) 'plate',
        if (state['seats'] == null || (state['seats'] as int) < 10) 'seats',
        if (state['modelYear'] == null) 'model_year',
        for (final d in ['driving_licence', 'vehicle_registration'])
          if (!docs.contains(d)) 'doc_$d',
      ];

  Map<String, Object?> get me => {
        'status': state['status'],
        'reviewNote': state['reviewNote'],
        'application': {...state, 'phone': '+9647801112233'}..remove('status')..remove('reviewNote'),
        'documents': [for (final d in docs) {'key': d}],
        'missing': missing,
        'form': form,
      };

  http.Response _json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

  late final client = MockClient.streaming((req, bodyStream) async {
    requests.add(req);
    final bytes = await bodyStream.toBytes();
    final path = '${req.method} ${req.url.path}';
    http.Response res;
    if (path == 'GET /public/universities') {
      res = _json([{'slug': 'warith', 'name': 'Warith Al-Anbiyaa University', 'nameAr': 'جامعة وارث الأنبياء', 'studentSignIn': 'manual'}]);
    } else if (path == 'POST /auth/driver/otp') {
      res = _json({'devCode': '135790'});
    } else if (path == 'POST /auth/driver/verify') {
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      res = body['code'] == '135790'
          ? _json({'accessToken': 'dt', 'user': {'id': 'd1', 'name': '', 'role': 'driver', 'universityId': 'u1'}})
          : _json({'message': 'The code is wrong or has expired'}, 401);
    } else if (path == 'GET /drivers/me') {
      res = _json(me);
    } else if (path == 'PATCH /drivers/me') {
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      state.addAll(body);
      res = _json(me);
    } else if (req.method == 'PUT' && req.url.path.startsWith('/drivers/me/documents/')) {
      expect(req.headers['content-type'], startsWith('multipart/form-data'));
      docs.add(req.url.pathSegments.last);
      res = _json(me);
    } else if (path == 'GET /drivers/me/runs') {
      res = _json(runs);
    } else if (path == 'GET /drivers/me/availability') {
      res = _json(days);
    } else if (path == 'PUT /drivers/me/availability') {
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final want = (body['waveIds'] as List).cast<String>();
      final d = days.firstWhere((x) => x['date'] == body['date']);
      d['waves'] = [for (final w in d['waves'] as List) {...(w as Map<String, Object?>), 'available': want.contains(w['waveId'])}];
      res = _json(d);
    } else if (path == 'POST /drivers/me/submit') {
      if (missing.isNotEmpty) {
        res = _json({'message': 'The application is incomplete', 'missing': missing}, 422);
      } else {
        state['status'] = 'pending';
        res = _json(me);
      }
    } else {
      res = _json({'message': 'not found'}, 404);
    }
    return http.StreamedResponse(Stream.value(res.bodyBytes), res.statusCode, headers: res.headers);
  });

  Future<Widget> app({String lang = 'ar', bool signedIn = false, DocumentPicker? camera}) async {
    final tokens = MemoryTokenStore();
    if (signedIn) await tokens.write('dt');
    return ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(MemoryPrefs({'naql.lang': lang})),
        tokenStoreProvider.overrideWithValue(tokens),
        apiProvider.overrideWithValue(ApiClient(baseUrl: Uri.parse('http://api.test/'), tokens: tokens, httpClient: client)),
        documentPickerProvider.overrideWithValue(camera ?? FakeCamera()),
      ],
      child: const DriverApp(),
    );
  }
}

void usePhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
  addTearDown(tester.view.reset);
}
