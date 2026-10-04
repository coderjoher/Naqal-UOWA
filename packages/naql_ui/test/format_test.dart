import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

void main() {
  test('Iraqi month names, IQD amounts', () {
    expect(formatDayMonth(DateTime.utc(2026, 10, 31), 'ar'), '31 تشرين الأول');
    expect(formatDayMonth(DateTime.utc(2027, 1, 5), 'en'), '5 January');
    expect(formatMonth('2026-12', 'ar'), 'كانون الأول 2026');
    expect(formatIqd(60000, 'ar'), '60,000 د.ع');
    expect(formatIqd(1500, 'en'), '1,500 IQD');
    expect(formatIqd(-60000, 'en'), '-60,000 IQD');
  });

  test('clock and countdown', () {
    expect(formatClock(DateTime(2026, 10, 5, 7, 5)), '07:05');
    expect(formatCountdown(const Duration(minutes: 4, seconds: 59)), '04:59');
    expect(formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatCountdown(const Duration(seconds: -5)), '00:00');
    expect(formatDayName('2026-10-04', 'ar'), 'الأحد 4 تشرين الأول');
    expect(formatDayName('2026-10-09', 'en'), 'Friday 9 October');
  });
}
