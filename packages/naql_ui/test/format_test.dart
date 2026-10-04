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
}
