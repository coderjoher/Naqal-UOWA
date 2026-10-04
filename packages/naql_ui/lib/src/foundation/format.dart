// Number and date formatting that matches how Iraqis read them.

const _iraqiMonths = ['كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'];
const _englishMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// "31 تشرين الأول" / "31 October" — Iraqi (Syriac) month names in Arabic.
String formatDayMonth(DateTime d, String lang) => '${d.day} ${(lang == 'ar' ? _iraqiMonths : _englishMonths)[d.month - 1]}';

/// "تشرين الأول 2026" / "October 2026" from "2026-10".
String formatMonth(String yyyyMm, String lang) {
  final parts = yyyyMm.split('-');
  final m = int.parse(parts[1]);
  return '${(lang == 'ar' ? _iraqiMonths : _englishMonths)[m - 1]} ${parts[0]}';
}

/// "60,000 د.ع" / "60,000 IQD" — Western digits with grouping, as on Iraqi receipts and price lists.
String formatIqd(int amount, String lang) {
  final s = amount.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${amount < 0 ? '-' : ''}$b ${lang == 'ar' ? 'د.ع' : 'IQD'}';
}
