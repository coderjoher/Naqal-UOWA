import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naql_core/naql_core.dart';
import 'package:test/test.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status);

void main() {
  final base = Uri.parse('http://api.test/');

  test('requestRide posts the slot and parses the assignment', () async {
    late http.Request sent;
    final client = ApiClient(
      baseUrl: base,
      tokens: MemoryTokenStore(),
      httpClient: MockClient((req) async {
        sent = req;
        return _json({
          'id': 'r1',
          'status': 'assigned',
          'date': '2026-10-05',
          'wave': {'id': 'w1', 'type': 'morning', 'minuteOfDay': 480, 'time': '08:00'},
          'point': {'id': 'p1', 'name': 'Al-Abbas Square', 'nameAr': 'ساحة العباس'},
          'subscriber': true,
          'fare': 0,
          'waitlistedUntil': null,
          'assignment': {'runId': 'run1', 'driverName': 'حيدر', 'plate': '12345 كربلاء', 'vehiclePhotoUrl': '/files/abc', 'pickupAt': '2026-10-05T04:32:00.000Z', 'stopNumber': 2, 'stops': 3},
        }, 201);
      }),
    );
    final r = await client.requestRide(waveId: 'w1', date: '2026-10-05');
    expect(sent.method, 'POST');
    expect(jsonDecode(sent.body), {'waveId': 'w1', 'date': '2026-10-05'});
    expect(r.status, RideStatus.assigned);
    expect(r.isLive, isTrue);
    expect(r.point('ar'), 'ساحة العباس');
    expect(r.assignment!.pickupAt!.toUtc(), DateTime.utc(2026, 10, 5, 4, 32));
    expect(client.resolve(r.assignment!.vehiclePhotoUrl!).toString(), 'http://api.test/files/abc');
  });

  test('availability and runs parse; setAvailability uses PUT', () async {
    final methods = <String>[];
    final client = ApiClient(
      baseUrl: base,
      tokens: MemoryTokenStore(),
      httpClient: MockClient((req) async {
        methods.add('${req.method} ${req.url.path}');
        if (req.url.path == '/drivers/me/runs') {
          return _json([
            {
              'id': 'run1', 'date': '2026-10-05', 'status': 'planned', 'femaleOnly': true, 'capacity': 14, 'booked': 2,
              'wave': {'id': 'w1', 'type': 'return', 'time': '14:00'},
              'departAt': '2026-10-05T11:00:00.000Z',
              'stops': [
                {'seq': 1, 'eta': '2026-10-05T11:12:00.000Z', 'served': false, 'point': {'id': 'p1', 'name': 'A', 'nameAr': 'أ', 'lat': 32.6, 'lng': 44.0}, 'count': 2, 'cashToCollect': 3000,
                  'passengers': [{'requestId': 'q1', 'name': 'زينب', 'fare': 1500}, {'requestId': 'q2', 'name': 'مريم', 'fare': 1500}]},
              ],
            },
          ]);
        }
        final day = {'date': '2026-10-05', 'waves': [{'waveId': 'w1', 'type': 'morning', 'time': '08:00', 'available': true, 'locked': false}]};
        return _json(req.method == 'PUT' ? day : [day]);
      }),
    );
    final days = await client.availability();
    expect(days.single.waves.single.available, isTrue);
    await client.setAvailability('2026-10-05', ['w1']);
    final runs = await client.driverRuns(date: '2026-10-05');
    expect(runs.single.waveType, WaveType.ret);
    expect(runs.single.cashToCollect, 3000);
    expect(runs.single.stops.single.passengers.map((p) => p.name), ['زينب', 'مريم']);
    expect(methods, ['GET /drivers/me/availability', 'PUT /drivers/me/availability', 'GET /drivers/me/runs']);
  });

  test('ride options read seat availability when the server sends it, and stay open when it does not', () {
    final o = RideOptions.fromJson({
      'slots': [
        {'waveId': 'w1', 'date': '2026-10-08', 'type': 'morning', 'time': '06:45', 'today': true, 'seatsLeft': 0},
        {'waveId': 'w2', 'date': '2026-10-08', 'type': 'morning', 'time': '07:30', 'today': true, 'seatsLeft': 6},
        {'waveId': 'w3', 'date': '2026-10-08', 'type': 'return', 'time': '14:00', 'today': true},
        {'waveId': 'w4', 'date': '2026-10-09', 'type': 'morning', 'time': '08:00', 'today': false, 'full': true},
      ],
      'defaultPointId': 'p1',
    });
    expect([for (final s in o.slots) s.full], [true, false, false, true]);
    expect([for (final s in o.slots) s.seatsLeft], [0, 6, null, null]);
    expect(o.slots[2].type, WaveType.ret);
  });
}

