/// P7 models: ride and payment history (ST-10), ratings and problem reports (ST-11), announcements (TO-11).
library;

import 'rides.dart';

/// One page of a cursor-paginated list.
class Paged<T> {
  const Paged({required this.items, this.next});

  final List<T> items;

  /// Pass back to get the following page; null at the end.
  final String? next;
}

class RideHistoryItem {
  const RideHistoryItem({
    required this.id,
    required this.date,
    required this.waveType,
    required this.waveTime,
    required this.pointName,
    required this.pointNameAr,
    required this.status,
    required this.fare,
    this.cancelReason,
    this.driverName,
    this.plate,
    this.rating,
    this.canRate = false,
  });

  factory RideHistoryItem.fromJson(Map<String, dynamic> j) {
    final point = (j['point'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RideHistoryItem(
      id: j['id'] as String,
      date: j['date'] as String,
      waveType: j['waveType'] == 'return' ? WaveType.ret : WaveType.morning,
      waveTime: j['waveTime'] as String,
      pointName: point['name'] as String? ?? '',
      pointNameAr: point['nameAr'] as String?,
      status: j['status'] as String,
      fare: (j['fare'] as num?)?.toInt() ?? 0,
      cancelReason: j['cancelReason'] as String?,
      driverName: j['driverName'] as String?,
      plate: j['plate'] as String?,
      rating: (j['rating'] as num?)?.toInt(),
      canRate: j['canRate'] as bool? ?? false,
    );
  }

  final String id;
  final String date;
  final WaveType waveType;
  final String waveTime;
  final String pointName;
  final String? pointNameAr;

  /// done | no_show | cancelled | open | assigned | waitlisted
  final String status;
  final int fare;
  final String? cancelReason;
  final String? driverName;
  final String? plate;
  final int? rating;
  final bool canRate;

  String point(String lang) => lang == 'ar' && pointNameAr != null ? pointNameAr! : pointName;

  RideHistoryItem rated(int stars) => RideHistoryItem(
        id: id,
        date: date,
        waveType: waveType,
        waveTime: waveTime,
        pointName: pointName,
        pointNameAr: pointNameAr,
        status: status,
        fare: fare,
        cancelReason: cancelReason,
        driverName: driverName,
        plate: plate,
        rating: stars,
        canRate: false,
      );
}

class PaymentItem {
  const PaymentItem({required this.id, required this.type, required this.method, required this.amount, required this.receiptNo, required this.createdAt, this.month});

  factory PaymentItem.fromJson(Map<String, dynamic> j) => PaymentItem(
        id: j['id'] as String,
        type: j['type'] as String,
        method: j['method'] as String,
        amount: (j['amount'] as num).toInt(),
        receiptNo: (j['receiptNo'] as num).toInt(),
        month: j['month'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      );

  final String id;

  /// subscription | cash_fare | tier_difference
  final String type;
  final String method;

  /// Negative for a reversal.
  final int amount;
  final int receiptNo;
  final String? month;
  final DateTime createdAt;

  bool get reversal => amount < 0;
}

/// ST-11 problem categories, in the order the form shows them.
const problemCategories = ['late', 'driver', 'vehicle', 'safety', 'app', 'other'];

/// TO-11: an office message shown as a banner until dismissed or expired.
class Announcement {
  const Announcement({required this.id, required this.title, required this.body, required this.createdAt});

  factory Announcement.fromJson(Map<String, dynamic> j) =>
      Announcement(id: j['id'] as String, title: j['title'] as String? ?? '', body: j['body'] as String? ?? '', createdAt: DateTime.parse(j['createdAt'] as String).toLocal());

  /// The notification id: dismissing marks it read.
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
}
