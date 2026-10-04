// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'نقل جامعة وارث — السائق';

  @override
  String get todayRuns => 'رحلات اليوم';

  @override
  String get noRunsToday => 'لا توجد رحلات اليوم';

  @override
  String get noRunsTodayBody =>
      'ستظهر هنا رحلاتك ونقاط التوقف بعد تفعيل التوزيع.';

  @override
  String get tabToday => 'اليوم';

  @override
  String get tabEarnings => 'الأرباح';

  @override
  String get tabProfile => 'حسابي';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get comingSoonBody => 'هذه الصفحة قيد التطوير.';
}
