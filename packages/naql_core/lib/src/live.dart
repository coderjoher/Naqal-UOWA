import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

/// Live bus position. Only the bus — student locations are never broadcast (NF-12).
class BusPosition {
  const BusPosition({required this.runId, required this.lat, required this.lng, required this.at, this.speed, this.etas = const {}});

  factory BusPosition.fromJson(Map<String, dynamic> j) => BusPosition(
        runId: j['runId'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        at: DateTime.parse(j['at'] as String).toLocal(),
        speed: (j['speed'] as num?)?.toDouble(),
        etas: {for (final e in (j['etas'] as List? ?? const [])) (e as Map)['seq'] as int: (e['seconds'] as num).toInt()},
      );

  final String runId;
  final double lat;
  final double lng;
  final DateTime at;
  final double? speed;

  /// Seconds to each remaining stop, by stop number.
  final Map<int, int> etas;
}

/// ST-06: what the student app needs to follow its bus.
class TrackInfo {
  const TrackInfo({this.runId, required this.runStatus, this.stopSeq, this.stopLat, this.stopLng, this.stopName, this.stopNameAr, this.boarded = false, this.bus});

  factory TrackInfo.fromJson(Map<String, dynamic> j) {
    final stop = j['stop'] as Map<String, dynamic>?;
    return TrackInfo(
      runId: j['runId'] as String?,
      runStatus: j['status'] as String? ?? 'planned',
      stopSeq: stop?['seq'] as int?,
      stopLat: (stop?['lat'] as num?)?.toDouble(),
      stopLng: (stop?['lng'] as num?)?.toDouble(),
      stopName: stop?['name'] as String?,
      stopNameAr: stop?['nameAr'] as String?,
      boarded: j['boarded'] as bool? ?? false,
      bus: j['bus'] == null ? null : BusPosition.fromJson(j['bus'] as Map<String, dynamic>),
    );
  }

  final String? runId;
  final String runStatus;
  final int? stopSeq;
  final double? stopLat;
  final double? stopLng;
  final String? stopName;
  final String? stopNameAr;
  final bool boarded;
  final BusPosition? bus;

  bool get moving => runStatus == 'started' || runStatus == 'at_stop';
}

class AppNotification {
  const AppNotification({required this.id, required this.kind, required this.data, required this.createdAt, this.readAt});

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        kind: j['kind'] as String,
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        readAt: _date(j['readAt']),
      );

  final String id;
  final String kind;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;
}

/// Realtime events for one signed-in user. Implemented over Socket.IO; tests use a fake.
abstract class LiveFeed {
  Stream<BusPosition> get buses;

  /// Run status changes and DR-09 stop list updates (`run`, `run:updated`): the run id.
  Stream<String> get runChanges;
  Stream<Map<String, dynamic>> get notifications;
  Stream<bool> get connected;

  /// Joins a run's room; resolves with the last known position, if any.
  Future<BusPosition?> join(String runId);
  void dispose();
}

class SocketLiveFeed implements LiveFeed {
  SocketLiveFeed({required Uri apiBase, required String token}) {
    // The API base may carry a path prefix (e.g. /api/ behind nginx); Socket.IO lives under it.
    final prefix = apiBase.path.endsWith('/') ? apiBase.path.substring(0, apiBase.path.length - 1) : apiBase.path;
    _socket = io.io(
      '${apiBase.scheme}://${apiBase.authority}/live',
      io.OptionBuilder().setPath('$prefix/socket.io').setTransports(['websocket']).setAuth({'token': token}).enableReconnection().setReconnectionDelayMax(5000).build(),
    );
    _socket.onConnect((_) {
      _connected.add(true);
      for (final r in _rooms) {
        _socket.emit('join', {'runId': r});
      }
    });
    _socket.onDisconnect((_) => _connected.add(false));
    _socket.on('bus', (d) => _buses.add(BusPosition.fromJson((d as Map).cast<String, dynamic>())));
    _socket.on('run', (d) => _runs.add((d as Map)['runId'] as String));
    _socket.on('run:updated', (d) => _runs.add((d as Map)['runId'] as String));
    _socket.on('notification', (d) => _notes.add((d as Map).cast<String, dynamic>()));
  }

  late final io.Socket _socket;
  final _rooms = <String>{};
  final _buses = StreamController<BusPosition>.broadcast();
  final _runs = StreamController<String>.broadcast();
  final _notes = StreamController<Map<String, dynamic>>.broadcast();
  final _connected = StreamController<bool>.broadcast();

  @override
  Stream<BusPosition> get buses => _buses.stream;
  @override
  Stream<String> get runChanges => _runs.stream;
  @override
  Stream<Map<String, dynamic>> get notifications => _notes.stream;
  @override
  Stream<bool> get connected => _connected.stream;

  @override
  Future<BusPosition?> join(String runId) {
    _rooms.add(runId);
    final done = Completer<BusPosition?>();
    _socket.emitWithAck('join', {'runId': runId}, ack: (res) {
      final m = (res as Map?)?.cast<String, dynamic>();
      final bus = m?['bus'];
      if (!done.isCompleted) done.complete(bus == null ? null : BusPosition.fromJson((bus as Map).cast<String, dynamic>()));
    });
    return done.future.timeout(const Duration(seconds: 10), onTimeout: () => null);
  }

  @override
  void dispose() {
    _socket.dispose();
    _buses.close();
    _runs.close();
    _notes.close();
    _connected.close();
  }
}
