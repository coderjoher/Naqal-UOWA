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

  test('student activation stores the session; profile parses gender and default point', () async {
    final tokens = MemoryTokenStore();
    final client = ApiClient(
      baseUrl: base,
      tokens: tokens,
      httpClient: MockClient((req) async {
        if (req.url.path == '/auth/student/activate') {
          expect(jsonDecode(req.body), {'university': 'warith', 'studentId': 'W-1', 'code': '123456', 'password': 'secret-pass'});
          return http.Response.bytes(utf8.encode(jsonEncode({'accessToken': 'st', 'user': {'id': 's', 'name': 'زينب', 'role': 'student', 'universityId': 'u'}})), 200);
        }
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'id': 's',
              'studentId': 'W-1',
              'name': 'Zainab',
              'nameAr': 'زينب',
              'gender': 'female',
              'phone': null,
              'defaultPoint': {'id': 'p', 'name': 'Abbas Sq', 'nameAr': 'ساحة العباس', 'tierId': 't', 'active': true},
            })),
            200);
      }),
    );
    await client.studentActivate('warith', 'W-1', '123456', 'secret-pass');
    expect(await tokens.read(), 'st');
    final me = await client.studentProfile();
    expect(me.gender, Gender.female);
    expect(me.displayName('ar'), 'زينب');
    expect(me.defaultPoint!.displayName('ar'), 'ساحة العباس');
  });

  test('driver application: errors carry the missing list; upload is multipart', () async {
    late http.BaseRequest upload;
    final client = ApiClient(
      baseUrl: base,
      tokens: MemoryTokenStore(),
      httpClient: MockClient((req) async {
        if (req.url.path == '/drivers/me/submit') {
          return http.Response(jsonEncode({'message': 'The application is incomplete', 'missing': ['plate', 'doc_driving_licence']}), 422);
        }
        upload = req;
        return http.Response(
            jsonEncode({'status': 'draft', 'application': {'phone': '+9647801112233'}, 'documents': [{'key': 'driving_licence'}], 'missing': [], 'form': []}), 200);
      }),
    );
    final err = await client.submitDriverApplication().then<ApiException?>((_) => null, onError: (e) => e as ApiException);
    expect(err!.statusCode, 422);
    expect(err.details['missing'], ['plate', 'doc_driving_licence']);
    final app = await client.uploadDriverDocument('driving_licence', [1, 2, 3], filename: 'l.jpg', mime: 'image/jpeg');
    expect(upload.method, 'PUT');
    expect(upload.headers['content-type'], startsWith('multipart/form-data'));
    expect(app.documents, {'driving_licence'});
  });
}
