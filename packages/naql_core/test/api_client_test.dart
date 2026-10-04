import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naql_core/naql_core.dart';
import 'package:test/test.dart';

void main() {
  final base = Uri.parse('http://api.test/');

  test('login stores the token and later requests send it', () async {
    final seen = <http.BaseRequest>[];
    final client = ApiClient(
      baseUrl: base,
      tokens: MemoryTokenStore(),
      httpClient: MockClient((req) async {
        seen.add(req);
        if (req.url.path == '/auth/login') {
          expect(jsonDecode(req.body), {'email': 'a@b.iq', 'password': 'password123'});
          return http.Response.bytes(
              utf8.encode(jsonEncode({'accessToken': 'tok', 'user': {'id': 'u', 'name': 'علي', 'role': 'student', 'universityId': 'uni'}})), 200);
        }
        return http.Response.bytes(utf8.encode(jsonEncode({'name': 'علي'})), 200);
      }),
    );
    final s = await client.login('a@b.iq', 'password123');
    expect(s.user.role, Role.student);
    expect(s.user.name, 'علي');
    final me = await client.get('/me');
    expect(me['name'], 'علي');
    expect(seen.last.headers['authorization'], 'Bearer tok');
  });

  test('401 clears the token and throws', () async {
    final tokens = MemoryTokenStore();
    await tokens.write('old');
    final client = ApiClient(baseUrl: base, tokens: tokens, httpClient: MockClient((_) async => http.Response('', 401)));
    await expectLater(client.get('/me'), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'unauthorized', true)));
    expect(await tokens.read(), isNull);
  });

  test('maps API roles', () {
    expect(roleFromJson('super_admin'), Role.superAdmin);
    expect(() => roleFromJson('x'), throwsFormatException);
  });
}
