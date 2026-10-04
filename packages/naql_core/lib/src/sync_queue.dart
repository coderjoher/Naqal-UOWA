import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'api_client.dart';

const _uuid = Uuid();

String newClientId() => _uuid.v4();

/// One thing the driver did that the server must learn about (NF-09).
class OutboxItem {
  OutboxItem({String? id, required this.kind, required this.runId, required this.payload, DateTime? createdAt})
      : id = id ?? newClientId(),
        createdAt = createdAt ?? DateTime.now();

  factory OutboxItem.fromJson(Map<String, dynamic> j) =>
      OutboxItem(id: j['id'] as String, kind: j['kind'] as String, runId: j['runId'] as String, payload: (j['payload'] as Map).cast<String, dynamic>(), createdAt: DateTime.parse(j['createdAt'] as String));

  /// `gps` | `action` | `fare`
  final String kind;
  final String runId;
  final String id;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind, 'runId': runId, 'payload': payload, 'createdAt': createdAt.toIso8601String()};
}

abstract class OutboxStore {
  Future<List<OutboxItem>> load();
  Future<void> save(List<OutboxItem> items);
}

class MemoryOutboxStore implements OutboxStore {
  List<OutboxItem> items = [];
  @override
  Future<List<OutboxItem>> load() async => [...items];
  @override
  Future<void> save(List<OutboxItem> next) async => items = [...next];
}

/// Stores the queue as JSON through any read/write pair (a file on the phone).
class JsonOutboxStore implements OutboxStore {
  JsonOutboxStore({required this.read, required this.write});
  final Future<String?> Function() read;
  final Future<void> Function(String) write;

  @override
  Future<List<OutboxItem>> load() async {
    final raw = await read();
    if (raw == null || raw.isEmpty) return [];
    try {
      return [for (final j in jsonDecode(raw) as List) OutboxItem.fromJson((j as Map).cast<String, dynamic>())];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<OutboxItem> items) => write(jsonEncode([for (final i in items) i.toJson()]));
}

class SyncRejection {
  const SyncRejection(this.item, this.message, [this.details = const {}]);
  final OutboxItem item;
  final String message;
  final Map<String, dynamic> details;
}

/// Offline-first outbox for the driver app: GPS points, run actions and cash fares are written
/// here first and sent in order. Network failures keep everything for the next flush; the
/// server applies each item once (client ids), so a retry after a lost reply never duplicates.
class SyncQueue {
  SyncQueue({required this.store, required this.api, this.maxBatch = 200});

  final OutboxStore store;
  final ApiClient api;
  final int maxBatch;
  final _items = <OutboxItem>[];
  final _pending = StreamController<int>.broadcast();
  final _rejected = StreamController<SyncRejection>.broadcast();
  final _applied = StreamController<Map<String, dynamic>>.broadcast();
  bool _loaded = false;
  Future<void>? _flushing;

  Stream<int> get pending => _pending.stream;
  Stream<SyncRejection> get rejected => _rejected.stream;

  /// Latest run view returned by the server after actions.
  Stream<Map<String, dynamic>> get runUpdates => _applied.stream;
  int get length => _items.length;
  List<OutboxItem> get items => List.unmodifiable(_items);

  Future<void> init() async {
    if (_loaded) return;
    _items.addAll(await store.load());
    _loaded = true;
    _pending.add(_items.length);
  }

  Future<void> add(OutboxItem item) async {
    await init();
    _items.add(item);
    await store.save(_items);
    _pending.add(_items.length);
  }

  /// Sends what can be sent now. Returns true when the queue is empty afterwards.
  Future<bool> flush() async {
    await init();
    // One flush at a time; concurrent callers wait for it.
    final running = _flushing;
    if (running != null) {
      await running;
      return _items.isEmpty;
    }
    final f = _flush();
    _flushing = f;
    try {
      await f;
    } finally {
      _flushing = null;
    }
    return _items.isEmpty;
  }

  Future<void> _flush() async {
    while (_items.isNotEmpty) {
      final head = _items.first;
      // Consecutive items of the same kind and run go in one request, in order.
      var n = 1;
      while (n < _items.length && n < maxBatch && _items[n].kind == head.kind && _items[n].runId == head.runId && head.kind != 'fare') {
        n++;
      }
      final batch = _items.sublist(0, n);
      try {
        switch (head.kind) {
          case 'gps':
            await api.postGps(head.runId, [for (final b in batch) b.payload]);
          case 'action':
            final res = await api.runActions(head.runId, [for (final b in batch) {...b.payload, 'clientId': b.id}]);
            final run = (res as Map?)?['run'];
            if (run is Map) _applied.add(run.cast<String, dynamic>());
          case 'fare':
            await api.recordFare(head.runId, head.payload['requestId'] as String, head.id);
        }
      } on ApiException catch (e) {
        if (e.statusCode >= 500 || e.statusCode == 401 || e.statusCode == 408 || e.statusCode == 429) return; // try later
        // The server refused (e.g. leaving a stop too early): drop it and tell the driver.
        _rejected.add(SyncRejection(head, e.message, e.details));
        if (batch.length > 1 && head.kind == 'action') {
          // Retry the rest of the batch one by one so one bad action does not drop the others.
          await _remove(1);
          continue;
        }
        await _remove(batch.length);
        continue;
      } catch (_) {
        return; // offline: keep everything
      }
      await _remove(batch.length);
    }
  }

  Future<void> _remove(int n) async {
    _items.removeRange(0, n);
    await store.save(_items);
    _pending.add(_items.length);
  }

  void dispose() {
    _pending.close();
    _rejected.close();
    _applied.close();
  }
}
