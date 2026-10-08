import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:student_app/app.dart';
import 'package:student_app/data/taxi.dart';
import 'package:student_app/data/track.dart';

/// Socket stand-in: tests push bus positions, connection changes and notifications.
class FakeLiveFeed implements LiveFeed {
  final busesCtl = StreamController<BusPosition>.broadcast();
  final connectedCtl = StreamController<bool>.broadcast();
  final runsCtl = StreamController<String>.broadcast();
  final notesCtl = StreamController<Map<String, dynamic>>.broadcast();
  final joined = <String>[];
  @override
  Stream<BusPosition> get buses => busesCtl.stream;
  @override
  Stream<String> get runChanges => runsCtl.stream;
  @override
  Stream<Map<String, dynamic>> get notifications => notesCtl.stream;
  @override
  Stream<bool> get connected => connectedCtl.stream;
  @override
  Future<BusPosition?> join(String runId) async {
    joined.add(runId);
    connectedCtl.add(true);
    return null;
  }

  @override
  void dispose() {}
}

/// Taxi socket stand-in (P10): tests push 'taxi:ride' and 'taxi:position' events.
class FakeTaxiLive implements TaxiLive {
  final ridesCtl = StreamController<String>.broadcast();
  final positionsCtl = StreamController<TaxiPosition>.broadcast();
  @override
  Stream<String> get rides => ridesCtl.stream;
  @override
  Stream<TaxiPosition> get positions => positionsCtl.stream;
  @override
  void dispose() {}
}

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
  final feed = FakeLiveFeed();

  /// GET /rides/:id/track (P5).
  Map<String, Object?> track = {'runId': 'run1', 'status': 'started', 'boarded': false, 'stop': {'seq': 2, 'lat': 32.616, 'lng': 44.025, 'name': 'Al-Abbas Square', 'nameAr': 'ساحة العباس'}, 'bus': null};

  /// GET /notifications/me (P5).
  List<Map<String, Object?>> notifications = [];

  /// ST-10: everything the history endpoints page through (20 per page), newest first.
  List<Map<String, Object?>> rideHistory = [];
  List<Map<String, Object?>> paymentHistory = [];

  /// While true the history endpoints fail like a phone without coverage.
  bool historyFails = false;
  final ratings = <Map<String, dynamic>>[];
  final problems = <Map<String, dynamic>>[];

  /// GET /announcements/active (TO-11).
  List<Map<String, Object?>> announcements = [];

  /// P10 campus taxis: the quote, the student's active ride and past rides; tests change the
  /// active ride to simulate a driver accepting, arriving and finishing.
  final taxiLive = FakeTaxiLive();
  Map<String, Object?> taxiQuote = {
    'direction': 'to_campus',
    'distanceKm': 6.4,
    'durationMin': 14,
    'fare': 4500,
    'tariff': {'baseFare': 1500, 'perKm': 500, 'minFare': 2000},
    'taxisNearby': 3,
    'pickupMin': 4,
    'campus': {'lat': 32.6086, 'lng': 44.0322},
  };
  Map<String, Object?>? taxiActive;
  List<Map<String, Object?>> taxiHistory = [];

  /// What "use my location" returns (null = location off) and the numbers the app dialled.
  LatLng? myLocation;
  final dialed = <Uri>[];

  bool get _taxiGoing => const ['requested', 'accepted', 'arrived', 'on_trip'].contains(taxiActive?['status']);

  static Map<String, Object?> taxiRide({
    String id = 'tx1',
    String status = 'requested',
    String direction = 'to_campus',
    int fare = 4500,
    String? label,
    DateTime? expiresAt,
    bool driver = false,
    Map<String, Object?>? taxi,
    int? etaMin,
    String? cancelledBy,
  }) =>
      {
        'id': id,
        'status': status,
        'direction': direction,
        'lat': 32.6086,
        'lng': 44.0322,
        'label': label,
        'distanceKm': 6.4,
        'fare': fare,
        'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(seconds: 90))).toUtc().toIso8601String(),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'acceptedAt': null,
        'arrivedAt': null,
        'startedAt': null,
        'endedAt': null,
        'cancelledBy': cancelledBy,
        'pickup': {'lat': 32.6086, 'lng': 44.0322},
        'dropoff': {'lat': 32.6160, 'lng': 44.0250},
        'driver': driver ? {'id': 'd11', 'name': 'علي حسين', 'phone': '07800000011', 'plate': '45678 كربلاء', 'seats': 4} : null,
        'taxi': taxi,
        'etaMin': etaMin,
      };

  static Map<String, Object?> pastRide(int i, {String status = 'done', bool canRate = true, int? rating}) => {
        'id': 'h$i',
        'date': '2026-09-${(30 - (i % 28)).toString().padLeft(2, '0')}',
        'waveType': i.isEven ? 'morning' : 'return',
        'waveTime': i.isEven ? '08:00' : '14:00',
        'point': {'name': 'Al-Abbas Square', 'nameAr': 'ساحة العباس'},
        'status': status,
        'cancelReason': status == 'cancelled' ? 'expired' : null,
        'fare': 0,
        'driverName': 'حيدر عباس',
        'plate': '12345',
        'rating': rating,
        'canRate': canRate && rating == null && status == 'done',
      };

  static Map<String, Object?> payment(int receiptNo, {int amount = 2000, String type = 'cash_fare', String? month}) => {
        'id': 'pay$receiptNo',
        'type': type,
        'method': type == 'subscription' ? 'cash_office' : 'cash_driver',
        'amount': amount,
        'receiptNo': receiptNo,
        'month': month,
        'reversal': amount < 0,
        'createdAt': DateTime.utc(2026, 9, 1 + receiptNo % 28, 9).toIso8601String(),
      };

  http.Response _page(List<Map<String, Object?>> all, String? cursor) {
    final start = cursor == null ? 0 : all.indexWhere((x) => x['id'] == cursor) + 1;
    final items = all.skip(start).take(20).toList();
    final more = start + 20 < all.length;
    return _json({'items': items, 'next': more ? items.last['id'] : null});
  }

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

  static Map<String, Object?> assignment({DateTime? pickupAt, String runStatus = 'planned'}) => {
        'runStatus': runStatus,
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
      case 'GET /notifications/me':
        return _json(notifications);
      case 'POST /notifications/read':
        final ids = (body['ids'] as List?)?.cast<String>();
        notifications = [for (final n in notifications) ids == null || ids.contains(n['id']) ? {...n, 'readAt': DateTime.now().toUtc().toIso8601String()} : n];
        if (ids != null) announcements = [for (final a in announcements) if (!ids.contains(a['id'])) a];
        return _json({'updated': notifications.length});
      case 'GET /rides/options':
        return _json({'slots': slots, 'defaultPointId': (profile['defaultPoint'] as Map?)?['id'], 'gender': profile['gender']});
      case 'GET /rides/me':
        return _json(rides);
      case 'GET /taxi/quote':
        return _json({...taxiQuote, 'direction': req.url.queryParameters['direction']});
      case 'GET /taxi/rides/me':
        return _json({'active': _taxiGoing ? taxiActive : null, 'history': taxiHistory});
      case 'POST /taxi/rides':
        if (_taxiGoing) return _json({'message': 'You already have a taxi ride in progress'}, 409);
        final r = taxiRide(direction: body['direction'] as String, fare: taxiQuote['fare'] as int, label: body['label'] as String?);
        taxiActive = r;
        return _json(r, 201);
      case 'POST /rides':
        final slot = slots.firstWhere((x) => x['waveId'] == body['waveId'] && x['date'] == body['date']);
        final r = ride(id: 'r${rides.length + 1}', date: slot['date'] as String, time: slot['time'] as String, type: slot['type'] as String);
        rides = [r, ...rides];
        return _json(r, 201);
    }
    if (req.url.path == '/rides/history' || req.url.path == '/payments/me') {
      if (historyFails) throw http.ClientException('offline');
      return _page(req.url.path == '/rides/history' ? rideHistory : paymentHistory, req.url.queryParameters['cursor']);
    }
    final rate = RegExp(r'^/rides/([^/]+)/rating$').firstMatch(req.url.path);
    if (req.method == 'POST' && rate != null) {
      if (ratings.any((r) => r['requestId'] == rate.group(1))) return _json({'message': 'You have already rated this ride'}, 409);
      ratings.add({'requestId': rate.group(1), ...body});
      return _json({'id': 'rt${ratings.length}', 'requestId': rate.group(1), 'stars': body['stars']}, 201);
    }
    if (req.method == 'POST' && req.url.path == '/problems') {
      problems.add(body);
      return _json({'id': 'pr${problems.length}', 'status': 'open', ...body}, 201);
    }
    if (req.url.path == '/announcements/active') return _json(announcements);
    final taxi = RegExp(r'^/taxi/rides/([^/]+)(/cancel)?$').firstMatch(req.url.path);
    if (taxi != null) {
      final r = taxiActive;
      if (r == null || r['id'] != taxi.group(1)) return _json({'message': 'not found'}, 404);
      if (req.method == 'POST' && taxi.group(2) != null) taxiActive = {...r, 'status': 'cancelled', 'cancelledBy': 'student'};
      return _json(taxiActive!);
    }
    if (RegExp(r'^/rides/[^/]+/track$').hasMatch(req.url.path)) return _json(track);
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
        liveFeedProvider.overrideWith((ref) async => feed),
        mapTilesProvider.overrideWithValue(false),
        taxiLiveProvider.overrideWith((ref) async => taxiLive),
        taxiLocatorProvider.overrideWithValue(() async => myLocation),
        taxiDialerProvider.overrideWithValue((uri) async {
          dialed.add(uri);
          return true;
        }),
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
