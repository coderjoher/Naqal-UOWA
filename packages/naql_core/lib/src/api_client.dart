import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models.dart';
import 'session.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, [this.details = const {}]);
  final int statusCode;
  final String message;

  /// Parsed JSON error body (e.g. `missing` for an incomplete driver application).
  final Map<String, dynamic> details;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

/// Thin JSON client for the NestJS API. Adds the bearer token and maps errors.
/// The OpenAPI-generated client replaces the hand-written calls as endpoints grow.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokens, http.Client? httpClient, this.timeout = const Duration(seconds: 15)})
      : _http = httpClient ?? http.Client();

  final Uri baseUrl;
  final TokenStore tokens;
  final Duration timeout;
  final http.Client _http;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);
  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body);

  Uri _url(String path) => baseUrl.resolve(path.startsWith('/') ? path.substring(1) : path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, _url(path))
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    return _handle(req);
  }

  Future<dynamic> _handle(http.BaseRequest req) async {
    final token = await tokens.read();
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    final res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    if (res.statusCode == 401) await tokens.write(null);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic> details = const {};
      var message = res.reasonPhrase ?? 'HTTP ${res.statusCode}';
      try {
        details = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final m = details['message'];
        if (m is String) message = m;
        if (m is List && m.isNotEmpty) message = m.join('\n');
      } catch (_) {}
      throw ApiException(res.statusCode, message, details);
    }
    return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Session> _session(Object? body) async {
    final session = Session.fromJson(body as Map<String, dynamic>);
    await tokens.write(session.accessToken);
    return session;
  }

  // ---------------- Public ----------------

  Future<List<UniversityInfo>> universities() async =>
      (await get('/public/universities') as List).map((u) => UniversityInfo.fromJson(u as Map<String, dynamic>)).toList();

  // ---------------- Students (ST-01, ST-02) ----------------

  Future<Session> studentLogin(String university, String studentId, String password) async =>
      _session(await post('/auth/student/login', {'university': university, 'studentId': studentId, 'password': password}));

  Future<Session> studentActivate(String university, String studentId, String code, String password) async =>
      _session(await post('/auth/student/activate', {'university': university, 'studentId': studentId, 'code': code, 'password': password}));

  Future<StudentProfile> studentProfile() async => StudentProfile.fromJson(await get('/students/me') as Map<String, dynamic>);

  Future<StudentProfile> updateStudentProfile({String? phone, String? defaultPointId}) async => StudentProfile.fromJson(
        await patch('/students/me', {'phone': ?phone, 'defaultPointId': ?defaultPointId}) as Map<String, dynamic>,
      );

  Future<SubscriptionInfo> subscription() async => SubscriptionInfo.fromJson(await get('/subscriptions/me') as Map<String, dynamic>);

  Future<List<GatheringPoint>> gatheringPoints() async =>
      (await get('/gathering-points') as List).map((p) => GatheringPoint.fromJson(p as Map<String, dynamic>)).where((p) => p.active).toList();

  // ---------------- Drivers (DR-01) ----------------

  /// Returns the code itself only on servers running with OTP_DEV_ECHO (local testing).
  Future<String?> driverRequestCode(String phone) async => (await post('/auth/driver/otp', {'phone': phone}) as Map<String, dynamic>)['devCode'] as String?;

  Future<Session> driverVerify(String phone, String code, {String? university}) async =>
      _session(await post('/auth/driver/verify', {'phone': phone, 'code': code, 'university': ?university}));

  Future<DriverApplication> driverApplication() async => DriverApplication.fromJson(await get('/drivers/me') as Map<String, dynamic>);

  Future<DriverApplication> updateDriverApplication(Map<String, Object?> fields) async =>
      DriverApplication.fromJson(await patch('/drivers/me', fields) as Map<String, dynamic>);

  Future<DriverApplication> uploadDriverDocument(String key, List<int> bytes, {required String filename, required String mime}) async {
    final req = http.MultipartRequest('PUT', _url('/drivers/me/documents/$key'))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _mediaType(mime)));
    return DriverApplication.fromJson(await _handle(req) as Map<String, dynamic>);
  }

  Future<DriverApplication> submitDriverApplication() async => DriverApplication.fromJson(await post('/drivers/me/submit') as Map<String, dynamic>);

  /// Email/password login (office & dev accounts). Student SSO arrives in P2.
  Future<Session> login(String email, String password) async {
    final session = Session.fromJson(await post('/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>);
    await tokens.write(session.accessToken);
    return session;
  }

  void close() => _http.close();
}

MediaType _mediaType(String mime) {
  final parts = mime.split('/');
  return MediaType(parts.first, parts.length > 1 ? parts[1] : 'octet-stream');
}
