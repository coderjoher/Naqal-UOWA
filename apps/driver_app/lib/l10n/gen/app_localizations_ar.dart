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
  String get tabSchedule => 'الجدول';

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

  @override
  String earningsTitle(String month) {
    return 'أرباح $month';
  }

  @override
  String get earningsEstimate => 'المبلغ التقديري حتى الآن';

  @override
  String get earningsApproved => 'المبلغ المعتمد من المكتب';

  @override
  String get earningsDraft => 'قيد المراجعة في المكتب';

  @override
  String get earningsHint =>
      'يُحسب من الرحلات الموثّقة بالـ GPS وحصتك من اشتراكات الفئة بعد العمولة، ناقص عمولة الأجرة النقدية.';

  @override
  String get earningsRuns => 'رحلات محتسبة';

  @override
  String get earningsCash => 'نقد استلمته';

  @override
  String get earningsCashCommission => 'عمولة النقد';

  @override
  String earningsFlagged(String count) {
    return '$count رحلات لم يثبت مسارها — يراجعها المكتب';
  }

  @override
  String get earningsRunsTitle => 'رحلات هذا الشهر';

  @override
  String get earningsNoRuns => 'لا رحلات هذا الشهر بعد';

  @override
  String get earningsCounted => 'محتسبة';

  @override
  String get earningsNotCounted => 'غير محتسبة';

  @override
  String get earningsPending => 'لم تنتهِ';

  @override
  String get earningsPast => 'التسويات السابقة';

  @override
  String earningsPastRuns(String runs) {
    return '$runs رحلة';
  }

  @override
  String get earningsOwe => 'عليك للمكتب';

  @override
  String get taxi => 'تكسي';

  @override
  String get taxiTitle => 'تكسي الجامعة';

  @override
  String get taxiOnline => 'أنت متصل';

  @override
  String get taxiOffline => 'أنت غير متصل';

  @override
  String get taxiOnlineHint => 'تصلك طلبات الطلبة القريبين';

  @override
  String get taxiOfflineHint => 'اضغط لتبدأ باستلام الطلبات';

  @override
  String get taxiGoOnline => 'ابدأ العمل';

  @override
  String get taxiGoOffline => 'توقّف عن العمل';

  @override
  String get taxiConnecting => 'جارٍ الاتصال…';

  @override
  String get taxiWaitingTitle => 'بانتظار الطلبات';

  @override
  String get taxiWaitingBody =>
      'أبقِ التطبيق مفتوحاً. تظهر الطلبات الجديدة هنا.';

  @override
  String get taxiOfflineTitle => 'لا تصلك طلبات الآن';

  @override
  String get taxiOfflineBody => 'ابدأ العمل لتصلك طلبات الطلبة القريبين منك.';

  @override
  String get taxiToCampus => 'إلى الجامعة';

  @override
  String get taxiFromCampus => 'من الجامعة';

  @override
  String taxiTripKm(String km) {
    return 'رحلة $km كم';
  }

  @override
  String taxiAwayKm(String km) {
    return 'يبعد $km كم';
  }

  @override
  String get taxiAccept => 'اقبل الطلب';

  @override
  String taxiSecondsLeft(int seconds) {
    return 'باقي $seconds ثانية';
  }

  @override
  String get taxiNewRequest => 'طلب جديد';

  @override
  String get taxiTaken => 'سبقك سائق آخر لهذا الطلب.';

  @override
  String get taxiNoLocation => 'شغّل الموقع لتبدأ العمل.';

  @override
  String get taxisOff => 'خدمة التكسي متوقفة الآن من المكتب.';

  @override
  String get taxiStudentCancelled => 'ألغى الطالب الرحلة.';

  @override
  String get taxiFailed => 'تعذّر الاتصال. حاول مرة أخرى.';

  @override
  String get taxiDismiss => 'إغلاق';

  @override
  String get taxiGoToStudent => 'اذهب إلى الطالب';

  @override
  String get taxiGoToGate => 'اذهب إلى باب الجامعة';

  @override
  String get taxiWaitingStudent => 'بانتظار صعود الطالب';

  @override
  String get taxiOnTripCampus => 'في الطريق إلى الجامعة';

  @override
  String get taxiOnTripHome => 'في الطريق إلى مكان الطالب';

  @override
  String taxiStep(int n) {
    return 'الخطوة $n من 3';
  }

  @override
  String get taxiCall => 'اتصال';

  @override
  String taxiCallStudent(String name) {
    return 'اتصل بـ $name';
  }

  @override
  String get taxiArrived => 'وصلت';

  @override
  String get taxiStartTrip => 'ابدأ الرحلة';

  @override
  String taxiEndTrip(String amount) {
    return 'أنهِ الرحلة واستلم $amount';
  }

  @override
  String taxiEndConfirmTitle(String amount) {
    return 'هل استلمت $amount نقداً؟';
  }

  @override
  String get taxiEndConfirmBody => 'تُسجَّل الأجرة باسمك عند إنهاء الرحلة.';

  @override
  String get taxiEndConfirmYes => 'نعم، استلمتها';

  @override
  String get taxiNotYet => 'ليس بعد';

  @override
  String get taxiCancelRide => 'إلغاء الرحلة';

  @override
  String get taxiCancelConfirmTitle => 'إلغاء هذه الرحلة؟';

  @override
  String get taxiCancelConfirmBody => 'سيعود الطلب إلى السائقين الآخرين.';

  @override
  String get taxiCancelYes => 'نعم، ألغِ الرحلة';

  @override
  String get taxiKeepRide => 'أكمل الرحلة';

  @override
  String get taxiFare => 'الأجرة نقداً';

  @override
  String get taxiDistance => 'المسافة';

  @override
  String taxiKm(String km) {
    return '$km كم';
  }

  @override
  String get taxiDoneTitle => 'انتهت الرحلة';

  @override
  String get taxiDoneBody => 'سُجّل المبلغ النقدي باسمك.';

  @override
  String get taxiBackToRequests => 'العودة إلى الطلبات';

  @override
  String get taxiMonthTitle => 'رحلات التكسي هذا الشهر';

  @override
  String taxiMonthSummary(int trips, String amount) {
    return '$trips رحلة · $amount';
  }

  @override
  String get taxiRecent => 'آخر رحلات التكسي';

  @override
  String get taxiNoTrips => 'لا رحلات تكسي بعد';

  @override
  String get taxiStatusDone => 'منتهية';

  @override
  String get taxiStatusCancelled => 'ملغاة';

  @override
  String get taxiStatusActive => 'جارية';

  @override
  String get taxiCashCollected => 'النقد المستلم';

  @override
  String get accountApproved => 'معتمد';

  @override
  String get accountVehicle => 'مركبتك';

  @override
  String get accountFromOffice => 'اعتمدها مكتب النقل';

  @override
  String get accountChangeHint => 'لتغيير بيانات المركبة راجع مكتب النقل.';

  @override
  String get accountNotSet => 'غير محدد';

  @override
  String get accountDocuments => 'المستمسكات';

  @override
  String accountDocumentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مستمسكاً مرفوعاً',
      few: '$count مستمسكات مرفوعة',
      two: 'مستمسكان مرفوعان',
      one: 'مستمسك واحد مرفوع',
      zero: 'لم تُرفع مستمسكات',
    );
    return '$_temp0';
  }

  @override
  String get accountLanguage => 'اللغة';

  @override
  String get accountSignOutTitle => 'تسجيل الخروج؟';

  @override
  String get accountSignOutBody =>
      'ستحتاج رمزاً جديداً يصل إلى هاتفك لتدخل مرة أخرى.';

  @override
  String get accountStay => 'البقاء مسجّلاً';

  @override
  String get accountDocumentsHint =>
      'المستمسكات التي طلبها مكتب النقل. لتحديث أي منها راجع المكتب.';

  @override
  String get accountDocUploaded => 'مرفوع';

  @override
  String get accountDocMissing => 'غير مرفوع';

  @override
  String get accountClose => 'إغلاق';

  @override
  String get greetMorning => 'صباح الخير';

  @override
  String get greetEvening => 'مساء الخير';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get kpiTaxiToday => 'مشاوير اليوم';

  @override
  String get kpiCash => 'نقداً';

  @override
  String get kpiMonth => 'هذا الشهر';

  @override
  String get kpiRiders => 'ركاب اليوم';

  @override
  String get taxiOnlineSub => 'تصلك طلبات التكسي القريبة · اضغط للإيقاف';

  @override
  String get watermarkOn => 'ON';

  @override
  String get taxiSkipOffer => 'تجاهل الطلب';

  @override
  String taxiOfferLine(String direction, String km) {
    return '$direction · $km كم';
  }

  @override
  String get nextRunTitle => 'رحلتك القادمة';

  @override
  String get laterToday => 'لاحقاً اليوم';

  @override
  String runRidersCount(int n) {
    return '$n راكب';
  }

  @override
  String stopOfTotal(int n, String total) {
    return 'المحطة $n من $total';
  }

  @override
  String riderCash(String amount) {
    return '$amount نقداً';
  }

  @override
  String distanceM(String m) {
    return '$m م';
  }

  @override
  String distanceKmShort(String km) {
    return '$km كم';
  }

  @override
  String headTo(String place) {
    return 'توجّه إلى $place';
  }

  @override
  String leaveAt(String time) {
    return 'انطلق الساعة $time';
  }

  @override
  String arriveAround(String time) {
    return 'الوصول نحو $time';
  }

  @override
  String get ridersHere => 'الركاب في هذه المحطة';

  @override
  String get noRidersHere => 'لا ركاب في هذه المحطة';

  @override
  String get studentCaption => 'الطالب';

  @override
  String get pickupPlace => 'مكان الركوب';

  @override
  String get dropoffPlace => 'مكان النزول';

  @override
  String get openNavigation => 'فتح الملاحة';

  @override
  String runProgress(String done, String total) {
    return 'خُدمت $done من $total محطات';
  }
}
