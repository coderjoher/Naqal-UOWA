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
      'عيّن أيام عملك من تبويب «جدولي»، وتظهر رحلاتك هنا بعد توزيع الحافلات.';

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

  @override
  String get welcomeTitle => 'قُد مع نقل الجامعة';

  @override
  String get welcomeBody =>
      'سجّل مرة واحدة، وبعد موافقة مكتب النقل تصلك رحلاتك اليومية ونقاط التوقف.';

  @override
  String get chooseLanguage => 'اختر اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get chooseUniversity => 'اختر الجامعة';

  @override
  String get chooseUniversityBody => 'ستعمل مع مكتب النقل في هذه الجامعة.';

  @override
  String get loadFailed => 'تعذّر الاتصال. تحقّق من الإنترنت وحاول مجدداً.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get phoneTitle => 'رقم هاتفك';

  @override
  String get phoneBody => 'سنرسل رمز دخول برسالة نصية.';

  @override
  String get phone => 'رقم الموبايل';

  @override
  String get phoneHint => '07XX XXX XXXX';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get invalidPhone => 'أدخل رقم موبايل عراقي صحيح';

  @override
  String get waitMinute => 'انتظر دقيقة قبل طلب رمز جديد';

  @override
  String get codeTitle => 'رمز التحقق';

  @override
  String codeBody(String phone) {
    return 'أدخل الرمز المرسل إلى $phone';
  }

  @override
  String get code => 'الرمز';

  @override
  String get verify => 'تأكيد';

  @override
  String get wrongCode => 'الرمز غير صحيح أو منتهي';

  @override
  String testCode(String code) {
    return 'بيئة اختبار — الرمز: $code';
  }

  @override
  String get applyTitle => 'طلب التسجيل';

  @override
  String get applyBody =>
      'أكمل بياناتك ووثائقك ثم أرسلها لمكتب النقل للمراجعة.';

  @override
  String progress(int done, int total) {
    return '$done من $total مكتمل';
  }

  @override
  String get sectionDriver => 'السائق';

  @override
  String get sectionVehicle => 'المركبة';

  @override
  String get sectionDocuments => 'الوثائق';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get vehicleType => 'نوع المركبة';

  @override
  String get plate => 'رقم اللوحة';

  @override
  String get seats => 'عدد المقاعد';

  @override
  String get modelYear => 'سنة الصنع';

  @override
  String get saveInfo => 'حفظ البيانات';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get saveFailed => 'تعذّر الحفظ';

  @override
  String get takePhoto => 'تصوير';

  @override
  String get fromGallery => 'من المعرض';

  @override
  String get uploaded => 'تم الرفع';

  @override
  String get notUploaded => 'مطلوبة';

  @override
  String get optional => 'اختيارية';

  @override
  String get uploading => 'جارٍ الرفع…';

  @override
  String get uploadFailed => 'تعذّر رفع الملف';

  @override
  String get submit => 'إرسال للمراجعة';

  @override
  String get incomplete => 'أكمل الحقول والوثائق المطلوبة أولاً';

  @override
  String get coaster => 'كوستر';

  @override
  String get minibus => 'ميني باص';

  @override
  String get bus => 'باص كبير';

  @override
  String get van => 'فان';

  @override
  String get statusPendingTitle => 'طلبك قيد المراجعة';

  @override
  String get statusPendingBody =>
      'سيراجع مكتب النقل بياناتك ووثائقك. ستصلك رسالة عند الموافقة.';

  @override
  String get statusRejectedTitle => 'لم يُقبل الطلب';

  @override
  String get statusRejectedBody =>
      'اقرأ سبب الرفض، صحّح البيانات وأرسل الطلب من جديد.';

  @override
  String get statusSuspendedTitle => 'حسابك موقوف';

  @override
  String get statusSuspendedBody =>
      'لا يمكنك تشغيل الرحلات حالياً. تواصل مع مكتب النقل.';

  @override
  String get reason => 'السبب';

  @override
  String get editApplication => 'تعديل الطلب';

  @override
  String get refresh => 'تحديث الحالة';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get tabSchedule => 'جدولي';

  @override
  String get scheduleTitle => 'متى ستعمل؟';

  @override
  String get scheduleBody =>
      'اختر المواعيد التي ستعمل فيها خلال الأسبوع. يُقفل الموعد بعد توزيع الحافلات.';

  @override
  String get dayToday => 'اليوم';

  @override
  String get dayTomorrow => 'غداً';

  @override
  String get waveMorning => 'ذهاب';

  @override
  String get waveReturn => 'عودة';

  @override
  String waveLabel(String type, String time) {
    return '$type $time';
  }

  @override
  String get noWavesDay => 'لا توجد رحلات في هذا اليوم';

  @override
  String get lockedWave => 'مُقفل — تم التوزيع';

  @override
  String get availabilityFailed => 'تعذّر حفظ جدولك';

  @override
  String runSeats(int booked, int capacity) {
    return '$booked من $capacity مقعد';
  }

  @override
  String runStops(int count) {
    return '$count محطات';
  }

  @override
  String get departAt => 'الانطلاق';

  @override
  String get cashToCollect => 'نقد للتحصيل';

  @override
  String get femaleOnly => 'للطالبات فقط';

  @override
  String riders(int count) {
    return 'الركاب: $count';
  }

  @override
  String get campus => 'الجامعة';

  @override
  String arriveBy(String time) {
    return 'الوصول قبل $time';
  }

  @override
  String get leaveCampus => 'الانطلاق من الجامعة';

  @override
  String get subscriber => 'مشترك';

  @override
  String payCash(String amount) {
    return '$amount نقداً';
  }

  @override
  String get setSchedule => 'عيّن جدولك';

  @override
  String get stopsTitle => 'المحطات';

  @override
  String get seatsLabel => 'المقاعد';

  @override
  String get startRun => 'ابدأ الرحلة';

  @override
  String get leaveCampusNow => 'انطلق من الجامعة';

  @override
  String get boardAtCampus => 'سجّل من صعد في الجامعة';

  @override
  String get nextStop => 'المحطة التالية';

  @override
  String get atStop => 'في المحطة';

  @override
  String get imHere => 'وصلت إلى المحطة';

  @override
  String get navigate => 'ملاحة';

  @override
  String get navGoogle => 'خرائط Google';

  @override
  String get navWaze => 'Waze';

  @override
  String get boardHint => 'اضغط على اسم الطالب عند صعوده';

  @override
  String get onBoard => 'صعد';

  @override
  String get noShowLabel => 'لم يحضر';

  @override
  String get waiting => 'بالانتظار';

  @override
  String get departStop => 'انطلق';

  @override
  String departMissing(int n) {
    return 'انطلق — $n لم يحضر';
  }

  @override
  String waitLeft(String time) {
    return 'انتظر $time للمتأخرين';
  }

  @override
  String collectFare(String amount) {
    return 'استلمت $amount';
  }

  @override
  String get paidLabel => 'دُفع';

  @override
  String get arrivedCampus => 'وصلت إلى الجامعة';

  @override
  String get finishRun => 'إنهاء الرحلة';

  @override
  String get runDone => 'انتهت الرحلة';

  @override
  String get runDoneBody => 'شكراً لك! سُجّلت الرحلة كاملة.';

  @override
  String pendingSync(int n) {
    return 'بانتظار الإرسال: $n';
  }

  @override
  String get dropOff => 'نزول';

  @override
  String get endTitleMorning => 'توجّه إلى الجامعة';

  @override
  String get endTitleReturn => 'نزل جميع الطلبة';
}
