/// P4 models: ride requests (student) and runs / availability (driver).
library;

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

enum WaveType { morning, ret }

WaveType _wave(Object? v) => v == 'return' ? WaveType.ret : WaveType.morning;

/// A wave on a date the student can still request.
class RideSlot {
  const RideSlot({required this.waveId, required this.date, required this.type, required this.time, required this.today});

  factory RideSlot.fromJson(Map<String, dynamic> j) =>
      RideSlot(waveId: j['waveId'] as String, date: j['date'] as String, type: _wave(j['type']), time: j['time'] as String, today: j['today'] as bool? ?? true);

  final String waveId;
  final String date;
  final WaveType type;
  final String time;
  final bool today;
}

class RideOptions {
  const RideOptions({required this.slots, this.defaultPointId});

  factory RideOptions.fromJson(Map<String, dynamic> j) => RideOptions(
        slots: [for (final s in j['slots'] as List) RideSlot.fromJson(s as Map<String, dynamic>)],
        defaultPointId: j['defaultPointId'] as String?,
      );

  final List<RideSlot> slots;
  final String? defaultPointId;
}

enum RideStatus { open, assigned, waitlisted, cancelled, done }

class RideAssignment {
  const RideAssignment({required this.runId, required this.driverName, this.driverPhone, this.plate, this.vehicleType, this.vehiclePhotoUrl, this.pickupAt, this.stopNumber, this.stops, this.runStatus = 'planned'});

  factory RideAssignment.fromJson(Map<String, dynamic> j) => RideAssignment(
        runId: j['runId'] as String,
        driverName: j['driverName'] as String,
        driverPhone: j['driverPhone'] as String?,
        plate: j['plate'] as String?,
        vehicleType: j['vehicleType'] as String?,
        vehiclePhotoUrl: j['vehiclePhotoUrl'] as String?,
        pickupAt: _date(j['pickupAt']),
        stopNumber: j['stopNumber'] as int?,
        stops: j['stops'] as int?,
        runStatus: j['runStatus'] as String? ?? 'planned',
      );

  final String runId;
  final String driverName;
  final String? driverPhone;
  final String? plate;
  final String? vehicleType;

  /// Short-lived link, relative to the API base URL.
  final String? vehiclePhotoUrl;
  final DateTime? pickupAt;
  final int? stopNumber;
  final int? stops;

  /// `planned` | `started` | `at_stop` | `done` — the bus can be followed while it is under way.
  final String runStatus;
  bool get trackable => runStatus == 'started' || runStatus == 'at_stop';
}

class RideInfo {
  const RideInfo({
    required this.id,
    required this.status,
    required this.date,
    required this.waveId,
    required this.waveType,
    required this.waveTime,
    required this.pointName,
    this.pointNameAr,
    this.subscriber = false,
    this.fare = 0,
    this.waitlistedUntil,
    this.cancelReason,
    this.assignment,
  });

  factory RideInfo.fromJson(Map<String, dynamic> j) {
    final wave = j['wave'] as Map<String, dynamic>;
    final point = j['point'] as Map<String, dynamic>;
    return RideInfo(
      id: j['id'] as String,
      status: RideStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => RideStatus.open),
      date: j['date'] as String,
      waveId: wave['id'] as String,
      waveType: _wave(wave['type']),
      waveTime: wave['time'] as String,
      pointName: point['name'] as String,
      pointNameAr: point['nameAr'] as String?,
      subscriber: j['subscriber'] as bool? ?? false,
      fare: j['fare'] as int? ?? 0,
      waitlistedUntil: _date(j['waitlistedUntil']),
      cancelReason: j['cancelReason'] as String?,
      assignment: j['assignment'] == null ? null : RideAssignment.fromJson(j['assignment'] as Map<String, dynamic>),
    );
  }

  final String id;
  final RideStatus status;
  final String date;
  final String waveId;
  final WaveType waveType;
  final String waveTime;
  final String pointName;
  final String? pointNameAr;
  final bool subscriber;
  final int fare;
  final DateTime? waitlistedUntil;
  final String? cancelReason;
  final RideAssignment? assignment;

  bool get isLive => status == RideStatus.open || status == RideStatus.assigned || status == RideStatus.waitlisted;
  String point(String lang) => lang == 'ar' && pointNameAr != null ? pointNameAr! : pointName;
}

// ── driver ───────────────────────────────────────────────────────────────────

class AvailabilityWave {
  const AvailabilityWave({required this.waveId, required this.type, required this.time, required this.available, required this.locked});

  factory AvailabilityWave.fromJson(Map<String, dynamic> j) => AvailabilityWave(
        waveId: j['waveId'] as String,
        type: _wave(j['type']),
        time: j['time'] as String,
        available: j['available'] as bool? ?? false,
        locked: j['locked'] as bool? ?? false,
      );

  final String waveId;
  final WaveType type;
  final String time;
  final bool available;
  final bool locked;
}

class AvailabilityDay {
  const AvailabilityDay({required this.date, required this.waves});

  factory AvailabilityDay.fromJson(Map<String, dynamic> j) =>
      AvailabilityDay(date: j['date'] as String, waves: [for (final w in j['waves'] as List) AvailabilityWave.fromJson(w as Map<String, dynamic>)]);

  final String date;
  final List<AvailabilityWave> waves;
}

class RunPassenger {
  const RunPassenger({required this.requestId, required this.name, this.studentId, this.phone, this.fare = 0, this.subscriber = false, this.boarded = false, this.status = 'assigned', this.paid = false});

  factory RunPassenger.fromJson(Map<String, dynamic> j) => RunPassenger(
        requestId: j['requestId'] as String,
        name: j['name'] as String,
        studentId: j['studentId'] as String?,
        phone: j['phone'] as String?,
        fare: j['fare'] as int? ?? 0,
        subscriber: j['subscriber'] as bool? ?? false,
        boarded: j['boarded'] as bool? ?? false,
        status: j['status'] as String? ?? 'assigned',
        paid: j['paid'] as bool? ?? false,
      );

  /// `assigned` | `done` | `no_show`
  final String status;

  /// A cash fare has been recorded for this ride.
  final bool paid;
  final String requestId;
  final String name;
  final String? studentId;
  final String? phone;
  final int fare;
  final bool subscriber;
  final bool boarded;
}

class RunStopInfo {
  const RunStopInfo({required this.seq, required this.eta, required this.pointName, this.pointNameAr, required this.lat, required this.lng, required this.passengers, this.served = false, this.cashToCollect = 0, this.arrivedAt});

  factory RunStopInfo.fromJson(Map<String, dynamic> j) {
    final p = j['point'] as Map<String, dynamic>;
    return RunStopInfo(
      seq: j['seq'] as int,
      eta: DateTime.parse(j['eta'] as String).toLocal(),
      served: j['served'] as bool? ?? false,
      pointName: p['name'] as String,
      pointNameAr: p['nameAr'] as String?,
      lat: (p['lat'] as num).toDouble(),
      lng: (p['lng'] as num).toDouble(),
      cashToCollect: j['cashToCollect'] as int? ?? 0,
      arrivedAt: _date(j['arrivedAt']),
      passengers: [for (final x in j['passengers'] as List) RunPassenger.fromJson(x as Map<String, dynamic>)],
    );
  }

  final int seq;
  final DateTime eta;
  final bool served;
  final String pointName;
  final String? pointNameAr;
  final double lat;
  final double lng;
  final int cashToCollect;
  final List<RunPassenger> passengers;
  final DateTime? arrivedAt;

  String point(String lang) => lang == 'ar' && pointNameAr != null ? pointNameAr! : pointName;
}

class DriverRun {
  const DriverRun({
    required this.id,
    required this.date,
    required this.status,
    required this.femaleOnly,
    required this.capacity,
    required this.booked,
    required this.waveType,
    required this.waveTime,
    this.departAt,
    required this.stops,
    this.waitMinutes = 3,
  });

  factory DriverRun.fromJson(Map<String, dynamic> j) {
    final wave = j['wave'] as Map<String, dynamic>;
    return DriverRun(
      id: j['id'] as String,
      date: j['date'] as String,
      status: j['status'] as String,
      femaleOnly: j['femaleOnly'] as bool? ?? false,
      capacity: j['capacity'] as int,
      booked: j['booked'] as int,
      waveType: _wave(wave['type']),
      waveTime: wave['time'] as String,
      departAt: _date(j['departAt']),
      waitMinutes: j['waitMinutes'] as int? ?? 3,
      stops: [for (final s in j['stops'] as List) RunStopInfo.fromJson(s as Map<String, dynamic>)],
    );
  }

  final String id;
  final String date;
  final String status;
  final bool femaleOnly;
  final int capacity;
  final int booked;
  final WaveType waveType;
  final String waveTime;
  final DateTime? departAt;
  final List<RunStopInfo> stops;

  /// SM-04: minutes the bus waits at a stop for missing riders.
  final int waitMinutes;

  int get cashToCollect => stops.fold(0, (n, s) => n + s.cashToCollect);

  /// The next stop the bus has not left yet (null when all are done).
  RunStopInfo? get nextStop => stops.where((s) => !s.served).firstOrNull;
  bool get underway => status == 'started' || status == 'at_stop';
}
