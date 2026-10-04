import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

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

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final token = await tokens.read();
    final req = http.Request(method, baseUrl.resolve(path.startsWith('/') ? path.substring(1) : path))
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = 'application/json';
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    final res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    if (res.statusCode == 401) await tokens.write(null);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, res.reasonPhrase ?? 'HTTP ${res.statusCode}');
    }
    return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Email/password login (office & dev accounts). Student SSO arrives in P2.
  Future<Session> login(String email, String password) async {
    final session = Session.fromJson(await post('/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>);
    await tokens.write(session.accessToken);
    return session;
  }

  void close() => _http.close();
}
