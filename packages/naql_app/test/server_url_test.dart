import 'package:flutter_test/flutter_test.dart';
import 'package:naql_app/naql_app.dart';

void main() {
  test('server addresses are normalised to an API base URL', () {
    expect(normalizeServerUrl('192.168.1.20'), 'http://192.168.1.20:3000/');
    expect(normalizeServerUrl(' 192.168.1.20:8081 '), 'http://192.168.1.20:8081/');
    expect(normalizeServerUrl('https://naql.example/api'), 'https://naql.example/api/');
    expect(normalizeServerUrl(''), isNull);
    expect(normalizeServerUrl('ftp://x'), isNull);
    expect(normalizeServerUrl(null), isNull);
  });
}
