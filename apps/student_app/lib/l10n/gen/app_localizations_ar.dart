// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'نقل جامعة وارث';

  @override
  String get hello => 'أهلاً بك';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get noSubscription => 'لا يوجد اشتراك';

  @override
  String get noRideToday => 'لا توجد رحلة اليوم';

  @override
  String get noRideTodayBody => 'طلب الرحلات اليومية سيتوفر قريباً.';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabTrips => 'رحلاتي';

  @override
  String get tabAlerts => 'التنبيهات';

  @override
  String get tabProfile => 'حسابي';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get comingSoonBody => 'هذه الصفحة قيد التطوير.';
}
