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
}
