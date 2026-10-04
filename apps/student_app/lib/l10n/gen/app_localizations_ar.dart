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
  String helloName(String name) {
    return 'أهلاً، $name';
  }

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

  @override
  String get welcomeTitle => 'تنقّلك اليومي إلى الجامعة';

  @override
  String get welcomeBody =>
      'اطلب مقعدك كل يوم، وتابع حافلتك على الخريطة، واعرف متى تصل.';

  @override
  String get chooseLanguage => 'اختر اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get chooseUniversity => 'اختر جامعتك';

  @override
  String get chooseUniversityBody => 'ستستخدم حساب جامعتك لتسجيل الدخول.';

  @override
  String get loadFailed => 'تعذّر الاتصال. تحقّق من الإنترنت وحاول مجدداً.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get signInTitle => 'تسجيل الدخول';

  @override
  String get studentNumber => 'الرقم الجامعي';

  @override
  String get password => 'كلمة المرور';

  @override
  String get signIn => 'دخول';

  @override
  String get signInFailed => 'الرقم الجامعي أو كلمة المرور غير صحيحة';

  @override
  String get firstTime => 'أول مرة؟ فعّل حسابك برمز المكتب';

  @override
  String get activateTitle => 'تفعيل الحساب';

  @override
  String get activateBody =>
      'ادخل الرمز الذي سلّمه لك مكتب النقل، ثم اختر كلمة مرور.';

  @override
  String get activationCode => 'رمز التفعيل';

  @override
  String get newPassword => 'كلمة مرور جديدة';

  @override
  String get passwordHint => '٨ أحرف على الأقل';

  @override
  String get activate => 'تفعيل ودخول';

  @override
  String get activateFailed =>
      'الرمز غير صحيح أو منتهي. اطلب رمزاً جديداً من مكتب النقل.';

  @override
  String get changeUniversity => 'تغيير الجامعة';

  @override
  String get choosePointTitle => 'نقطة التجمّع';

  @override
  String get choosePointBody =>
      'اختر النقطة الأقرب إليك. تركب الحافلة منها كل يوم ويُحسب سعر اشتراكك حسب فئتها.';

  @override
  String get searchPoints => 'ابحث عن نقطة';

  @override
  String tierLabel(String tier) {
    return 'الفئة $tier';
  }

  @override
  String kmAway(String km) {
    return '$km كم عن الجامعة';
  }

  @override
  String get savePoint => 'اعتماد النقطة';

  @override
  String get noPoints => 'لا توجد نقاط تجمّع بعد';

  @override
  String get noPointsBody => 'سيضيفها مكتب النقل قريباً.';

  @override
  String get yourPoint => 'نقطة تجمّعك';

  @override
  String get change => 'تغيير';

  @override
  String get profileTitle => 'حسابي';

  @override
  String get personalInfo => 'المعلومات الشخصية';

  @override
  String get name => 'الاسم';

  @override
  String get gender => 'الجنس';

  @override
  String get male => 'ذكر';

  @override
  String get female => 'أنثى';

  @override
  String get fromUniversity => 'من سجلات الجامعة ولا يمكن تعديله';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get phoneHint => '07XX XXX XXXX';

  @override
  String get save => 'حفظ';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get saveFailed => 'تعذّر الحفظ';

  @override
  String get invalidPhone => 'أدخل رقم موبايل عراقي صحيح';

  @override
  String get language => 'اللغة';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get defaultPoint => 'نقطة التجمّع';

  @override
  String get notSet => 'غير محدّدة';
}
