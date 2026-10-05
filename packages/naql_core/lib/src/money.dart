/// P6 models: the driver's monthly earnings (DR-08).
library;

import 'rides.dart';

/// One run of the month and whether it counts towards the payout (SE-02).
class EarningRun {
  const EarningRun({required this.id, required this.date, required this.waveType, required this.waveMinute, required this.status, required this.counted, required this.flagged});

  factory EarningRun.fromJson(Map<String, dynamic> j) => EarningRun(
        id: j['id'] as String,
        date: j['date'] as String,
        waveType: j['waveType'] == 'return' ? WaveType.ret : WaveType.morning,
        waveMinute: (j['waveMinute'] as num).toInt(),
        status: j['status'] as String,
        counted: j['counted'] as bool? ?? false,
        flagged: j['flagged'] as bool? ?? false,
      );

  final String id;
  final String date;
  final WaveType waveType;
  final int waveMinute;
  final String status;
  final bool counted;

  /// Finished but not counted: the GPS track did not prove it (the office reviews these).
  final bool flagged;

  String get time => '${(waveMinute ~/ 60).toString().padLeft(2, '0')}:${(waveMinute % 60).toString().padLeft(2, '0')}';
}

class PastSettlement {
  const PastSettlement({required this.month, required this.runs, required this.cash, required this.payout, this.approvedAt});

  factory PastSettlement.fromJson(Map<String, dynamic> j) => PastSettlement(
        month: j['month'] as String,
        runs: (j['runs'] as num).toInt(),
        cash: (j['cash'] as num).toInt(),
        payout: (j['payout'] as num).toInt(),
        approvedAt: j['approvedAt'] == null ? null : DateTime.parse(j['approvedAt'] as String).toLocal(),
      );

  final String month;
  final int runs;
  final int cash;
  final int payout;
  final DateTime? approvedAt;
}

/// Where this month's figure comes from.
enum EarningsSource { estimate, draft, approved }

class DriverEarnings {
  const DriverEarnings({required this.month, required this.source, required this.runs, required this.cash, required this.cashCommission, required this.estimate, required this.list, required this.past});

  factory DriverEarnings.fromJson(Map<String, dynamic> j) => DriverEarnings(
        month: j['month'] as String,
        source: switch (j['source']) { 'approved' => EarningsSource.approved, 'draft' => EarningsSource.draft, _ => EarningsSource.estimate },
        runs: (j['runs'] as num).toInt(),
        cash: (j['cash'] as num).toInt(),
        cashCommission: (j['cashCommission'] as num).toInt(),
        estimate: (j['estimate'] as num).toInt(),
        list: [for (final r in j['list'] as List? ?? const []) EarningRun.fromJson(r as Map<String, dynamic>)],
        past: [for (final p in j['past'] as List? ?? const []) PastSettlement.fromJson(p as Map<String, dynamic>)],
      );

  final String month;
  final EarningsSource source;

  /// Verified runs counted so far.
  final int runs;
  final int cash;
  final int cashCommission;

  /// Same formula as the office's settlement (SE-01), for the month so far.
  final int estimate;
  final List<EarningRun> list;
  final List<PastSettlement> past;

  int get flagged => list.where((r) => r.flagged).length;
}
