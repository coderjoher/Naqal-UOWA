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
  String get noRideTodayBody => 'اطلب مقعداً في حافلة اليوم أو الغد.';

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
  String get welcomeTitle => 'تنقّل جامعي مريح';

  @override
  String get welcomeBody => 'اطلب مقعدك، وتابع حافلتك، واعرف متى تصل.';

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

  @override
  String get subActive => 'اشتراك فعّال';

  @override
  String subExpiring(int days) {
    return 'ينتهي خلال $days أيام';
  }

  @override
  String get subExpired => 'الاشتراك منتهي';

  @override
  String get subNone => 'لا يوجد اشتراك';

  @override
  String subUntil(String date) {
    return 'حتى $date';
  }

  @override
  String get subMonthly => 'اشتراك شهري';

  @override
  String subTierPrice(String tier, String price) {
    return 'الفئة $tier · $price';
  }

  @override
  String get subPayAtOffice =>
      'ادفع نقداً في مكتب النقل وسيُفعّل اشتراكك فوراً.';

  @override
  String get subRenew => 'جدّد اشتراكك في مكتب النقل قبل انتهائه.';

  @override
  String subNext(String month) {
    return 'الشهر القادم مدفوع: $month';
  }

  @override
  String get subUnlimited => 'رحلات غير محدودة وأولوية في المقاعد';

  @override
  String subTier(String tier) {
    return 'الفئة $tier';
  }

  @override
  String get rideRequest => 'اطلب رحلة';

  @override
  String get rideRequestTitle => 'طلب رحلة';

  @override
  String get rideRequestBody => 'اختر الموعد ونقطة التجمّع، ونحجز لك مقعداً.';

  @override
  String get rideWhen => 'الموعد';

  @override
  String get rideWhere => 'نقطة التجمّع';

  @override
  String get rideToday => 'اليوم';

  @override
  String get rideTomorrow => 'غداً';

  @override
  String get rideMorning => 'ذهاب';

  @override
  String get rideReturn => 'عودة';

  @override
  String rideSlot(String day, String type, String time) {
    return '$day · $type $time';
  }

  @override
  String get rideNoSlots => 'لا توجد مواعيد متاحة اليوم أو غداً.';

  @override
  String get rideSend => 'أرسل الطلب';

  @override
  String get rideSent => 'وصل طلبك';

  @override
  String get rideConfirmed => 'مؤكد';

  @override
  String get rideCampus => 'الجامعة';

  @override
  String rideStopOf(String n, String total) {
    return 'المحطة $n من $total';
  }

  @override
  String ridePayDriver(String amount) {
    return 'ادفع $amount نقداً للسائق';
  }

  @override
  String get rideCovered => 'مشمول باشتراكك';

  @override
  String get rideCancel => 'إلغاء الطلب';

  @override
  String get rideCancelTitle => 'إلغاء الطلب؟';

  @override
  String get rideCancelBody => 'سيُعطى مقعدك لطالب آخر.';

  @override
  String get rideCancelYes => 'نعم، ألغِ';

  @override
  String get rideKeep => 'لا، أبقِه';

  @override
  String get rideCancelled => 'أُلغي الطلب';

  @override
  String get ridePendingTitle => 'وصل طلبك';

  @override
  String get ridePendingBody =>
      'نوزّع الحافلات قبل الموعد بساعة ونخبرك بحافلتك.';

  @override
  String get rideWaitTitle => 'أنت على قائمة الانتظار';

  @override
  String get rideWaitBody =>
      'كل المقاعد محجوزة الآن. سنحجز لك مقعداً فور تحرّر واحد.';

  @override
  String get rideWaitLeft => 'الوقت المتبقي';

  @override
  String rideExpired(String time) {
    return 'لم نجد مقعداً لرحلة $time. يمكنك طلب موعد آخر.';
  }

  @override
  String rideWave(String day, String type, String time) {
    return '$day · $type $time';
  }

  @override
  String get rideFemaleOnly => 'للطالبات فقط';

  @override
  String get trackBus => 'تتبّع الحافلة';

  @override
  String get trackTitle => 'حافلتك';

  @override
  String etaMinutes(int n) {
    return 'تصل خلال $n د';
  }

  @override
  String get etaNow => 'الحافلة في نقطتك الآن';

  @override
  String get onBus => 'أنت في الحافلة';

  @override
  String get notStarted => 'لم تنطلق الحافلة بعد';

  @override
  String updatedAgo(String time) {
    return 'آخر تحديث قبل $time';
  }

  @override
  String get lastKnown => 'آخر موقع معروف';

  @override
  String agoSeconds(int n) {
    return '$n ث';
  }

  @override
  String agoMinutes(int n) {
    return '$n د';
  }

  @override
  String get yourStop => 'نقطتك';

  @override
  String get busLabel => 'الحافلة';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get noNotificationsBody => 'ستصلك هنا أخبار مقعدك وحافلتك.';

  @override
  String get nAssignedTitle => 'تم تأكيد مقعدك';

  @override
  String get nAssignedBody => 'افتح التطبيق لترى حافلتك ووقت الصعود.';

  @override
  String get nWaitlistedTitle => 'أنت على قائمة الانتظار';

  @override
  String get nWaitlistedBody => 'سنخبرك فور توفر مقعد.';

  @override
  String get nBumpedTitle => 'نُقلت إلى قائمة الانتظار';

  @override
  String get nBumpedBody => 'أُعطي مقعدك لمشترك. سنحجز لك فور توفر مقعد.';

  @override
  String get nApproachingTitle => 'الحافلة تقترب';

  @override
  String nApproachingBody(int n) {
    return 'تصل إلى نقطتك خلال $n دقائق تقريباً.';
  }

  @override
  String get nArrivedTitle => 'الحافلة وصلت';

  @override
  String get nArrivedBody => 'الحافلة في نقطة التجمّع الآن.';

  @override
  String get nExpiredTitle => 'لم نجد مقعداً';

  @override
  String get nExpiredBody => 'انتهت مدة الانتظار وأُلغي الطلب.';

  @override
  String get nCancelledTitle => 'أُلغيت الرحلة';

  @override
  String get nCancelledBody => 'أُلغي طلب رحلتك.';

  @override
  String get historyRides => 'الرحلات';

  @override
  String get historyPayments => 'المدفوعات';

  @override
  String get historyNoRides => 'لا رحلات سابقة';

  @override
  String get historyNoRidesBody => 'تظهر هنا رحلاتك بعد انتهائها.';

  @override
  String get historyNoPayments => 'لا مدفوعات بعد';

  @override
  String get historyNoPaymentsBody =>
      'يظهر هنا كل ما دفعته للاشتراك أو للسائق.';

  @override
  String get historyEnd => 'لا شيء أقدم';

  @override
  String get historyDone => 'تمت';

  @override
  String get historyNoShow => 'لم تحضر';

  @override
  String get historyCancelled => 'أُلغيت';

  @override
  String get historyExpired => 'بلا مقعد';

  @override
  String get historyMissed => 'لم تتم';

  @override
  String get rateRide => 'قيّم الرحلة';

  @override
  String get rateTitle => 'كيف كانت الرحلة؟';

  @override
  String get rateBody => 'تقييمك يصل إلى مكتب النقل ويساعد في تحسين الخدمة.';

  @override
  String get rateComment => 'ملاحظة (اختياري)';

  @override
  String get rateSend => 'أرسل التقييم';

  @override
  String get rateThanks => 'شكراً لتقييمك';

  @override
  String get reportProblem => 'أبلغ عن مشكلة';

  @override
  String get reportProblemHint => 'يصل بلاغك إلى مكتب النقل مباشرة';

  @override
  String get problemTitle => 'ما المشكلة؟';

  @override
  String get problemBody =>
      'اختر نوع المشكلة واكتب ما حدث. سيرد عليك مكتب النقل.';

  @override
  String get problemLate => 'تأخير';

  @override
  String get problemDriver => 'السائق';

  @override
  String get problemVehicle => 'الحافلة';

  @override
  String get problemSafety => 'السلامة';

  @override
  String get problemApp => 'التطبيق';

  @override
  String get problemOther => 'أخرى';

  @override
  String get problemText => 'ماذا حدث؟';

  @override
  String get problemSend => 'أرسل البلاغ';

  @override
  String get problemSent => 'وصل بلاغك إلى مكتب النقل';

  @override
  String get paySubscription => 'اشتراك شهري';

  @override
  String paySubscriptionMonth(String month) {
    return 'اشتراك $month';
  }

  @override
  String get payTierDifference => 'فرق الفئة';

  @override
  String get payCashFare => 'أجرة رحلة نقداً';

  @override
  String payReversal(String what) {
    return 'إلغاء: $what';
  }

  @override
  String payReceipt(int no) {
    return 'إيصال $no';
  }

  @override
  String get nMovedTitle => 'تغيّرت حافلتك';

  @override
  String get nMovedBody =>
      'نقلك مكتب النقل إلى حافلة أخرى. افتح الرئيسية لترى التفاصيل.';

  @override
  String get nAnsweredTitle => 'ردّ مكتب النقل على بلاغك';

  @override
  String get dismiss => 'إخفاء';

  @override
  String get taxiTitle => 'تكسي الجامعة';

  @override
  String get taxiCardTitle => 'تكسي من الجامعة وإليها';

  @override
  String get taxiCardBody => 'تعرف الأجرة قبل الطلب، وتدفعها نقداً للسائق.';

  @override
  String get taxiDirection => 'وجهة الرحلة';

  @override
  String get taxiToCampus => 'إلى الجامعة';

  @override
  String get taxiFromCampus => 'من الجامعة للبيت';

  @override
  String get taxiPickupHint => 'حرّك الخريطة أو المسها لتحديد مكان الركوب';

  @override
  String get taxiDropoffHint => 'حرّك الخريطة أو المسها لتحديد مكان النزول';

  @override
  String get taxiMyLocation => 'استخدم موقعي الحالي';

  @override
  String get taxiLocationFailed =>
      'تعذّر تحديد موقعك. فعّل خدمة الموقع أو حرّك الخريطة.';

  @override
  String get taxiLabel => 'علامة دالّة (اختياري)';

  @override
  String get taxiLabelHint => 'مثلاً: قرب باب الجامع';

  @override
  String get taxiFare => 'الأجرة';

  @override
  String get taxiCash => 'تُدفع نقداً للسائق';

  @override
  String taxiKm(String km) {
    return '$km كم';
  }

  @override
  String taxiMinutes(int n) {
    return '$n د';
  }

  @override
  String taxiNearby(int n) {
    return 'سيارات قريبة: $n';
  }

  @override
  String get taxiNoneNearby => 'لا توجد سيارة قريبة الآن، ويمكنك الطلب مع ذلك.';

  @override
  String taxiPickupIn(int n) {
    return 'يصلك خلال $n د تقريباً';
  }

  @override
  String get taxiRequest => 'اطلب تكسي';

  @override
  String get taxiUnavailableHere => 'خدمة التكسي غير متاحة في هذا المكان';

  @override
  String get taxiSearching => 'نبحث عن تكسي قريب';

  @override
  String get taxiSearchingBody =>
      'وصل طلبك إلى السائقين القريبين، وأول من يقبل يأتي إليك.';

  @override
  String get taxiTimeLeft => 'الوقت المتبقي';

  @override
  String get taxiCancel => 'إلغاء الطلب';

  @override
  String get taxiCancelTitle => 'إلغاء التكسي؟';

  @override
  String get taxiCancelBody => 'سنُبلغ السائق بالإلغاء.';

  @override
  String get taxiCancelYes => 'نعم، ألغِ';

  @override
  String get taxiKeep => 'لا، أبقِه';

  @override
  String get taxiAccepted => 'التكسي في الطريق إليك';

  @override
  String get taxiArrived => 'وصل التكسي';

  @override
  String get taxiArrivedBody => 'السائق ينتظرك في مكان الركوب.';

  @override
  String get taxiOnTripToCampus => 'في الطريق إلى الجامعة';

  @override
  String get taxiOnTripHome => 'في الطريق إلى البيت';

  @override
  String taxiAway(int n) {
    return 'يصل خلال $n د';
  }

  @override
  String get taxiCall => 'اتصل بالسائق';

  @override
  String taxiPlate(String plate) {
    return 'اللوحة $plate';
  }

  @override
  String get taxiStepAccepted => 'قُبل';

  @override
  String get taxiStepArrived => 'وصل';

  @override
  String get taxiStepOnTrip => 'في الطريق';

  @override
  String get taxiStepDone => 'انتهت';

  @override
  String taxiStepOf(int n, String name) {
    return 'الخطوة $n من 4: $name';
  }

  @override
  String get taxiDone => 'وصلت بالسلامة';

  @override
  String taxiPayCash(String amount) {
    return 'ادفع للسائق $amount نقداً';
  }

  @override
  String get taxiSummary => 'ملخص الرحلة';

  @override
  String get taxiRoute => 'المسار';

  @override
  String get taxiCampus => 'الجامعة';

  @override
  String get taxiYourSpot => 'موقعك';

  @override
  String get taxiDriver => 'السائق';

  @override
  String get taxiDistance => 'المسافة';

  @override
  String get taxiBackHome => 'العودة للرئيسية';

  @override
  String get taxiExpired => 'لم يقبل أي سائق هذه المرة';

  @override
  String get taxiExpiredBody =>
      'قد يكون السائقون مشغولين. جرّب مرة أخرى بعد قليل.';

  @override
  String get taxiCancelledByYou => 'ألغيت الطلب';

  @override
  String get taxiCancelledOther => 'أُلغي الطلب';

  @override
  String get taxiCancelledBody => 'يمكنك طلب تكسي جديد متى شئت.';

  @override
  String get taxiTryAgain => 'حاول مرة أخرى';

  @override
  String get taxiPickupPin => 'مكان الركوب';

  @override
  String get taxiDropoffPin => 'مكان النزول';

  @override
  String get taxiCarPin => 'التكسي';

  @override
  String get taxiFollow => 'تابِع رحلتك';

  @override
  String get taxiPlateLabel => 'اللوحة';

  @override
  String get taxiChipHere => 'موقعي الحالي';

  @override
  String get taxiChipPoint => 'نقطة تجمّعي';

  @override
  String get taxiToCampusSub => 'من مكانك إلى بوابة الجامعة';

  @override
  String get taxiFromCampusSub => 'من الجامعة إلى مكانك';

  @override
  String get driverCaption => 'سائقك';

  @override
  String get vehicleCaption => 'الحافلة';

  @override
  String get rideSummaryTotal => 'المجموع';

  @override
  String get rideFare => 'الأجرة';
}
