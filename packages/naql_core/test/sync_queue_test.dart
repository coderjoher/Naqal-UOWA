import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naql_core/naql_core.dart';
import 'package:test/test.dart';

/// Server stand-in: can be offline; applies action client ids once, like the API.
class FakeServer {
  bool online = false;
  final gps = <Map<String, dynamic>>[];
  final actions = <String>[];
  final calls = <String>[];
  late final client = MockClient((req) async {
    if (!online) throw http.ClientException('offline');
    calls.add(req.url.path);
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    if (req.url.path.endsWith('/gps')) gps.addAll((body['points'] as List).cast<Map<String, dynamic>>());
    if (req.url.path.endsWith('/actions')) {
      for (final a in (body['actions'] as List).cast<Map<String, dynamic>>()) {
        if (a['type'] == 'depart' && !actions.contains('arrive')) {
          return http.Response(jsonEncode({'message': 'Cannot leave a stop', 'waitLeftS': 30}), 409);
        }
        if (!actions.contains(a['clientId'])) actions.add(a['type'] as String);
      }
      return http.Response(jsonEncode({'results': [], 'run': {'id': 'run1', 'status': 'started'}}), 200);
    }
    return http.Response('{}', 200);
  });
}

void main() {
  test('everything recorded offline is sent in order, batched, once reconnected', () async {
    final server = FakeServer();
    final store = MemoryOutboxStore();
    final q = SyncQueue(store: store, api: ApiClient(baseUrl: Uri.parse('http://api.test/'), tokens: MemoryTokenStore(), httpClient: server.client));
    await q.add(OutboxItem(kind: 'action', runId: 'run1', payload: {'type': 'start'}));
    for (var i = 0; i < 5; i++) {
      await q.add(OutboxItem(kind: 'gps', runId: 'run1', payload: {'lat': 32.6, 'lng': 44.0 + i / 1000, 'at': DateTime.utc(2026, 10, 5, 4, 0, i * 5).toIso8601String()}));
    }
    await q.add(OutboxItem(kind: 'action', runId: 'run1', payload: {'type': 'arrive', 'seq': 1}));

    expect(await q.flush(), isFalse); // offline: nothing lost
    expect(store.items, hasLength(7));

    server.online = true;
    expect(await q.flush(), isTrue);
    expect(server.calls, ['/runs/run1/actions', '/runs/run1/gps', '/runs/run1/actions']); // 3 requests for 7 items
    expect(server.gps, hasLength(5));
    expect(server.actions, ['start', 'arrive']);
    expect(store.items, isEmpty);
  });

  test('a refused action is dropped and reported; the rest still goes', () async {
    final server = FakeServer()..online = true;
    final q = SyncQueue(store: MemoryOutboxStore(), api: ApiClient(baseUrl: Uri.parse('http://api.test/'), tokens: MemoryTokenStore(), httpClient: server.client));
    final rejected = <SyncRejection>[];
    q.rejected.listen(rejected.add);
    await q.add(OutboxItem(kind: 'action', runId: 'run1', payload: {'type': 'depart'}));
    await q.add(OutboxItem(kind: 'action', runId: 'run1', payload: {'type': 'arrive', 'seq': 1}));
    expect(await q.flush(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(rejected.single.details['waitLeftS'], 30);
    expect(server.actions, ['arrive']);
  });

  test('the queue survives an app restart (JSON store)', () async {
    String? disk;
    JsonOutboxStore file() => JsonOutboxStore(read: () async => disk, write: (s) async => disk = s);
    final server = FakeServer();
    final api = ApiClient(baseUrl: Uri.parse('http://api.test/'), tokens: MemoryTokenStore(), httpClient: server.client);
    final first = SyncQueue(store: file(), api: api);
    final item = OutboxItem(kind: 'fare', runId: 'run1', payload: {'requestId': 'r1'});
    await first.add(item);
    await first.flush();

    final afterRestart = SyncQueue(store: file(), api: api);
    await afterRestart.init();
    expect(afterRestart.items.single.id, item.id); // same idempotency key after restart
    server.online = true;
    expect(await afterRestart.flush(), isTrue);
    expect(server.calls, ['/runs/run1/fares']);
  });
}
