import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'نقل جامعة وارث — السائق'**
  String get appTitle;

  /// No description provided for @todayRuns.
  ///
  /// In ar, this message translates to:
  /// **'رحلات اليوم'**
  String get todayRuns;

  /// No description provided for @noRunsToday.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات اليوم'**
  String get noRunsToday;

  /// No description provided for @noRunsTodayBody.
  ///
  /// In ar, this message translates to:
  /// **'عيّن أيام عملك من تبويب «جدولي»، وتظهر رحلاتك هنا بعد توزيع الحافلات.'**
  String get noRunsTodayBody;

  /// No description provided for @tabToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get tabToday;

  /// No description provided for @tabEarnings.
  ///
  /// In ar, this message translates to:
  /// **'الأرباح'**
  String get tabEarnings;

  /// No description provided for @tabProfile.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get tabProfile;

  /// No description provided for @comingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get comingSoon;

  /// No description provided for @comingSoonBody.
  ///
  /// In ar, this message translates to:
  /// **'هذه الصفحة قيد التطوير.'**
  String get comingSoonBody;

  /// No description provided for @welcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'قُد مع نقل الجامعة'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'سجّل مرة واحدة، وبعد موافقة مكتب النقل تصلك رحلاتك اليومية ونقاط التوقف.'**
  String get welcomeBody;

  /// No description provided for @chooseLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اختر اللغة'**
  String get chooseLanguage;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @continueLabel.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueLabel;

  /// No description provided for @chooseUniversity.
  ///
  /// In ar, this message translates to:
  /// **'اختر الجامعة'**
  String get chooseUniversity;

  /// No description provided for @chooseUniversityBody.
  ///
  /// In ar, this message translates to:
  /// **'ستعمل مع مكتب النقل في هذه الجامعة.'**
  String get chooseUniversityBody;

  /// No description provided for @loadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال. تحقّق من الإنترنت وحاول مجدداً.'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @phoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'رقم هاتفك'**
  String get phoneTitle;

  /// No description provided for @phoneBody.
  ///
  /// In ar, this message translates to:
  /// **'سنرسل رمز دخول برسالة نصية.'**
  String get phoneBody;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الموبايل'**
  String get phone;

  /// No description provided for @phoneHint.
  ///
  /// In ar, this message translates to:
  /// **'07XX XXX XXXX'**
  String get phoneHint;

  /// No description provided for @sendCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرمز'**
  String get sendCode;

  /// No description provided for @invalidPhone.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم موبايل عراقي صحيح'**
  String get invalidPhone;

  /// No description provided for @waitMinute.
  ///
  /// In ar, this message translates to:
  /// **'انتظر دقيقة قبل طلب رمز جديد'**
  String get waitMinute;

  /// No description provided for @codeTitle.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق'**
  String get codeTitle;

  /// No description provided for @codeBody.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز المرسل إلى {phone}'**
  String codeBody(String phone);

  /// No description provided for @code.
  ///
  /// In ar, this message translates to:
  /// **'الرمز'**
  String get code;

  /// No description provided for @verify.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get verify;

  /// No description provided for @wrongCode.
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح أو منتهي'**
  String get wrongCode;

  /// No description provided for @testCode.
  ///
  /// In ar, this message translates to:
  /// **'بيئة اختبار — الرمز: {code}'**
  String testCode(String code);

  /// No description provided for @applyTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب التسجيل'**
  String get applyTitle;

  /// No description provided for @applyBody.
  ///
  /// In ar, this message translates to:
  /// **'أكمل بياناتك ووثائقك ثم أرسلها لمكتب النقل للمراجعة.'**
  String get applyBody;

  /// No description provided for @progress.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} مكتمل'**
  String progress(int done, int total);

  /// No description provided for @sectionDriver.
  ///
  /// In ar, this message translates to:
  /// **'السائق'**
  String get sectionDriver;

  /// No description provided for @sectionVehicle.
  ///
  /// In ar, this message translates to:
  /// **'المركبة'**
  String get sectionVehicle;

  /// No description provided for @sectionDocuments.
  ///
  /// In ar, this message translates to:
  /// **'الوثائق'**
  String get sectionDocuments;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get fullName;

  /// No description provided for @vehicleType.
  ///
  /// In ar, this message translates to:
  /// **'نوع المركبة'**
  String get vehicleType;

  /// No description provided for @plate.
  ///
  /// In ar, this message translates to:
  /// **'رقم اللوحة'**
  String get plate;

  /// No description provided for @seats.
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد'**
  String get seats;

  /// No description provided for @modelYear.
  ///
  /// In ar, this message translates to:
  /// **'سنة الصنع'**
  String get modelYear;

  /// No description provided for @saveInfo.
  ///
  /// In ar, this message translates to:
  /// **'حفظ البيانات'**
  String get saveInfo;

  /// No description provided for @saved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get saved;

  /// No description provided for @saveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ'**
  String get saveFailed;

  /// No description provided for @takePhoto.
  ///
  /// In ar, this message translates to:
  /// **'تصوير'**
  String get takePhoto;

  /// No description provided for @fromGallery.
  ///
  /// In ar, this message translates to:
  /// **'من المعرض'**
  String get fromGallery;

  /// No description provided for @uploaded.
  ///
  /// In ar, this message translates to:
  /// **'تم الرفع'**
  String get uploaded;

  /// No description provided for @notUploaded.
  ///
  /// In ar, this message translates to:
  /// **'مطلوبة'**
  String get notUploaded;

  /// No description provided for @optional.
  ///
  /// In ar, this message translates to:
  /// **'اختيارية'**
  String get optional;

  /// No description provided for @uploading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الرفع…'**
  String get uploading;

  /// No description provided for @uploadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر رفع الملف'**
  String get uploadFailed;

  /// No description provided for @submit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال للمراجعة'**
  String get submit;

  /// No description provided for @incomplete.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الحقول والوثائق المطلوبة أولاً'**
  String get incomplete;

  /// No description provided for @coaster.
  ///
  /// In ar, this message translates to:
  /// **'كوستر'**
  String get coaster;

  /// No description provided for @minibus.
  ///
  /// In ar, this message translates to:
  /// **'ميني باص'**
  String get minibus;

  /// No description provided for @bus.
  ///
  /// In ar, this message translates to:
  /// **'باص كبير'**
  String get bus;

  /// No description provided for @van.
  ///
  /// In ar, this message translates to:
  /// **'فان'**
  String get van;

  /// No description provided for @statusPendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبك قيد المراجعة'**
  String get statusPendingTitle;

  /// No description provided for @statusPendingBody.
  ///
  /// In ar, this message translates to:
  /// **'سيراجع مكتب النقل بياناتك ووثائقك. ستصلك رسالة عند الموافقة.'**
  String get statusPendingBody;

  /// No description provided for @statusRejectedTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم يُقبل الطلب'**
  String get statusRejectedTitle;

  /// No description provided for @statusRejectedBody.
  ///
  /// In ar, this message translates to:
  /// **'اقرأ سبب الرفض، صحّح البيانات وأرسل الطلب من جديد.'**
  String get statusRejectedBody;

  /// No description provided for @statusSuspendedTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابك موقوف'**
  String get statusSuspendedTitle;

  /// No description provided for @statusSuspendedBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك تشغيل الرحلات حالياً. تواصل مع مكتب النقل.'**
  String get statusSuspendedBody;

  /// No description provided for @reason.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get reason;

  /// No description provided for @editApplication.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الطلب'**
  String get editApplication;

  /// No description provided for @refresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الحالة'**
  String get refresh;

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// No description provided for @tabSchedule.
  ///
  /// In ar, this message translates to:
  /// **'الجدول'**
  String get tabSchedule;

  /// No description provided for @scheduleTitle.
  ///
  /// In ar, this message translates to:
  /// **'متى ستعمل؟'**
  String get scheduleTitle;

  /// No description provided for @scheduleBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر المواعيد التي ستعمل فيها خلال الأسبوع. يُقفل الموعد بعد توزيع الحافلات.'**
  String get scheduleBody;

  /// No description provided for @dayToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get dayToday;

  /// No description provided for @dayTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غداً'**
  String get dayTomorrow;

  /// No description provided for @waveMorning.
  ///
  /// In ar, this message translates to:
  /// **'ذهاب'**
  String get waveMorning;

  /// No description provided for @waveReturn.
  ///
  /// In ar, this message translates to:
  /// **'عودة'**
  String get waveReturn;

  /// No description provided for @waveLabel.
  ///
  /// In ar, this message translates to:
  /// **'{type} {time}'**
  String waveLabel(String type, String time);

  /// No description provided for @noWavesDay.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات في هذا اليوم'**
  String get noWavesDay;

  /// No description provided for @lockedWave.
  ///
  /// In ar, this message translates to:
  /// **'مُقفل — تم التوزيع'**
  String get lockedWave;

  /// No description provided for @availabilityFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ جدولك'**
  String get availabilityFailed;

  /// No description provided for @runSeats.
  ///
  /// In ar, this message translates to:
  /// **'{booked} من {capacity} مقعد'**
  String runSeats(int booked, int capacity);

  /// No description provided for @runStops.
  ///
  /// In ar, this message translates to:
  /// **'{count} محطات'**
  String runStops(int count);

  /// No description provided for @departAt.
  ///
  /// In ar, this message translates to:
  /// **'الانطلاق'**
  String get departAt;

  /// No description provided for @cashToCollect.
  ///
  /// In ar, this message translates to:
  /// **'نقد للتحصيل'**
  String get cashToCollect;

  /// No description provided for @femaleOnly.
  ///
  /// In ar, this message translates to:
  /// **'للطالبات فقط'**
  String get femaleOnly;

  /// No description provided for @riders.
  ///
  /// In ar, this message translates to:
  /// **'الركاب: {count}'**
  String riders(int count);

  /// No description provided for @campus.
  ///
  /// In ar, this message translates to:
  /// **'الجامعة'**
  String get campus;

  /// No description provided for @arriveBy.
  ///
  /// In ar, this message translates to:
  /// **'الوصول قبل {time}'**
  String arriveBy(String time);

  /// No description provided for @leaveCampus.
  ///
  /// In ar, this message translates to:
  /// **'الانطلاق من الجامعة'**
  String get leaveCampus;

  /// No description provided for @subscriber.
  ///
  /// In ar, this message translates to:
  /// **'مشترك'**
  String get subscriber;

  /// No description provided for @payCash.
  ///
  /// In ar, this message translates to:
  /// **'{amount} نقداً'**
  String payCash(String amount);

  /// No description provided for @setSchedule.
  ///
  /// In ar, this message translates to:
  /// **'عيّن جدولك'**
  String get setSchedule;

  /// No description provided for @stopsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحطات'**
  String get stopsTitle;

  /// No description provided for @seatsLabel.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد'**
  String get seatsLabel;

  /// No description provided for @startRun.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الرحلة'**
  String get startRun;

  /// No description provided for @leaveCampusNow.
  ///
  /// In ar, this message translates to:
  /// **'انطلق من الجامعة'**
  String get leaveCampusNow;

  /// No description provided for @boardAtCampus.
  ///
  /// In ar, this message translates to:
  /// **'سجّل من صعد في الجامعة'**
  String get boardAtCampus;

  /// No description provided for @nextStop.
  ///
  /// In ar, this message translates to:
  /// **'المحطة التالية'**
  String get nextStop;

  /// No description provided for @atStop.
  ///
  /// In ar, this message translates to:
  /// **'في المحطة'**
  String get atStop;

  /// No description provided for @imHere.
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى المحطة'**
  String get imHere;

  /// No description provided for @navigate.
  ///
  /// In ar, this message translates to:
  /// **'ملاحة'**
  String get navigate;

  /// No description provided for @navGoogle.
  ///
  /// In ar, this message translates to:
  /// **'خرائط Google'**
  String get navGoogle;

  /// No description provided for @navWaze.
  ///
  /// In ar, this message translates to:
  /// **'Waze'**
  String get navWaze;

  /// No description provided for @boardHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على اسم الطالب عند صعوده'**
  String get boardHint;

  /// No description provided for @onBoard.
  ///
  /// In ar, this message translates to:
  /// **'صعد'**
  String get onBoard;

  /// No description provided for @noShowLabel.
  ///
  /// In ar, this message translates to:
  /// **'لم يحضر'**
  String get noShowLabel;

  /// No description provided for @waiting.
  ///
  /// In ar, this message translates to:
  /// **'بالانتظار'**
  String get waiting;

  /// No description provided for @departStop.
  ///
  /// In ar, this message translates to:
  /// **'انطلق'**
  String get departStop;

  /// No description provided for @departMissing.
  ///
  /// In ar, this message translates to:
  /// **'انطلق — {n} لم يحضر'**
  String departMissing(int n);

  /// No description provided for @waitLeft.
  ///
  /// In ar, this message translates to:
  /// **'انتظر {time} للمتأخرين'**
  String waitLeft(String time);

  /// No description provided for @collectFare.
  ///
  /// In ar, this message translates to:
  /// **'استلمت {amount}'**
  String collectFare(String amount);

  /// No description provided for @paidLabel.
  ///
  /// In ar, this message translates to:
  /// **'دُفع'**
  String get paidLabel;

  /// No description provided for @arrivedCampus.
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى الجامعة'**
  String get arrivedCampus;

  /// No description provided for @finishRun.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الرحلة'**
  String get finishRun;

  /// No description provided for @runDone.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الرحلة'**
  String get runDone;

  /// No description provided for @runDoneBody.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لك! سُجّلت الرحلة كاملة.'**
  String get runDoneBody;

  /// No description provided for @pendingSync.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الإرسال: {n}'**
  String pendingSync(int n);

  /// No description provided for @dropOff.
  ///
  /// In ar, this message translates to:
  /// **'نزول'**
  String get dropOff;

  /// No description provided for @endTitleMorning.
  ///
  /// In ar, this message translates to:
  /// **'توجّه إلى الجامعة'**
  String get endTitleMorning;

  /// No description provided for @endTitleReturn.
  ///
  /// In ar, this message translates to:
  /// **'نزل جميع الطلبة'**
  String get endTitleReturn;

  /// No description provided for @earningsTitle.
  ///
  /// In ar, this message translates to:
  /// **'أرباح {month}'**
  String earningsTitle(String month);

  /// No description provided for @earningsEstimate.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ التقديري حتى الآن'**
  String get earningsEstimate;

  /// No description provided for @earningsApproved.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المعتمد من المكتب'**
  String get earningsApproved;

  /// No description provided for @earningsDraft.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة في المكتب'**
  String get earningsDraft;

  /// No description provided for @earningsHint.
  ///
  /// In ar, this message translates to:
  /// **'يُحسب من الرحلات الموثّقة بالـ GPS وحصتك من اشتراكات الفئة بعد العمولة، ناقص عمولة الأجرة النقدية.'**
  String get earningsHint;

  /// No description provided for @earningsRuns.
  ///
  /// In ar, this message translates to:
  /// **'رحلات محتسبة'**
  String get earningsRuns;

  /// No description provided for @earningsCash.
  ///
  /// In ar, this message translates to:
  /// **'نقد استلمته'**
  String get earningsCash;

  /// No description provided for @earningsCashCommission.
  ///
  /// In ar, this message translates to:
  /// **'عمولة النقد'**
  String get earningsCashCommission;

  /// No description provided for @earningsFlagged.
  ///
  /// In ar, this message translates to:
  /// **'{count} رحلات لم يثبت مسارها — يراجعها المكتب'**
  String earningsFlagged(String count);

  /// No description provided for @earningsRunsTitle.
  ///
  /// In ar, this message translates to:
  /// **'رحلات هذا الشهر'**
  String get earningsRunsTitle;

  /// No description provided for @earningsNoRuns.
  ///
  /// In ar, this message translates to:
  /// **'لا رحلات هذا الشهر بعد'**
  String get earningsNoRuns;

  /// No description provided for @earningsCounted.
  ///
  /// In ar, this message translates to:
  /// **'محتسبة'**
  String get earningsCounted;

  /// No description provided for @earningsNotCounted.
  ///
  /// In ar, this message translates to:
  /// **'غير محتسبة'**
  String get earningsNotCounted;

  /// No description provided for @earningsPending.
  ///
  /// In ar, this message translates to:
  /// **'لم تنتهِ'**
  String get earningsPending;

  /// No description provided for @earningsPast.
  ///
  /// In ar, this message translates to:
  /// **'التسويات السابقة'**
  String get earningsPast;

  /// No description provided for @earningsPastRuns.
  ///
  /// In ar, this message translates to:
  /// **'{runs} رحلة'**
  String earningsPastRuns(String runs);

  /// No description provided for @earningsOwe.
  ///
  /// In ar, this message translates to:
  /// **'عليك للمكتب'**
  String get earningsOwe;

  /// No description provided for @taxi.
  ///
  /// In ar, this message translates to:
  /// **'تكسي'**
  String get taxi;

  /// No description provided for @taxiTitle.
  ///
  /// In ar, this message translates to:
  /// **'تكسي الجامعة'**
  String get taxiTitle;

  /// No description provided for @taxiOnline.
  ///
  /// In ar, this message translates to:
  /// **'أنت متصل'**
  String get taxiOnline;

  /// No description provided for @taxiOffline.
  ///
  /// In ar, this message translates to:
  /// **'أنت غير متصل'**
  String get taxiOffline;

  /// No description provided for @taxiOnlineHint.
  ///
  /// In ar, this message translates to:
  /// **'تصلك طلبات الطلبة القريبين'**
  String get taxiOnlineHint;

  /// No description provided for @taxiOfflineHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لتبدأ باستلام الطلبات'**
  String get taxiOfflineHint;

  /// No description provided for @taxiGoOnline.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ العمل'**
  String get taxiGoOnline;

  /// No description provided for @taxiGoOffline.
  ///
  /// In ar, this message translates to:
  /// **'توقّف عن العمل'**
  String get taxiGoOffline;

  /// No description provided for @taxiConnecting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الاتصال…'**
  String get taxiConnecting;

  /// No description provided for @taxiWaitingTitle.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الطلبات'**
  String get taxiWaitingTitle;

  /// No description provided for @taxiWaitingBody.
  ///
  /// In ar, this message translates to:
  /// **'أبقِ التطبيق مفتوحاً. تظهر الطلبات الجديدة هنا.'**
  String get taxiWaitingBody;

  /// No description provided for @taxiOfflineTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا تصلك طلبات الآن'**
  String get taxiOfflineTitle;

  /// No description provided for @taxiOfflineBody.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ العمل لتصلك طلبات الطلبة القريبين منك.'**
  String get taxiOfflineBody;

  /// No description provided for @taxiToCampus.
  ///
  /// In ar, this message translates to:
  /// **'إلى الجامعة'**
  String get taxiToCampus;

  /// No description provided for @taxiFromCampus.
  ///
  /// In ar, this message translates to:
  /// **'من الجامعة'**
  String get taxiFromCampus;

  /// No description provided for @taxiTripKm.
  ///
  /// In ar, this message translates to:
  /// **'رحلة {km} كم'**
  String taxiTripKm(String km);

  /// No description provided for @taxiAwayKm.
  ///
  /// In ar, this message translates to:
  /// **'يبعد {km} كم'**
  String taxiAwayKm(String km);

  /// No description provided for @taxiAccept.
  ///
  /// In ar, this message translates to:
  /// **'اقبل الطلب'**
  String get taxiAccept;

  /// No description provided for @taxiSecondsLeft.
  ///
  /// In ar, this message translates to:
  /// **'باقي {seconds} ثانية'**
  String taxiSecondsLeft(int seconds);

  /// No description provided for @taxiNewRequest.
  ///
  /// In ar, this message translates to:
  /// **'طلب جديد'**
  String get taxiNewRequest;

  /// No description provided for @taxiTaken.
  ///
  /// In ar, this message translates to:
  /// **'سبقك سائق آخر لهذا الطلب.'**
  String get taxiTaken;

  /// No description provided for @taxiNoLocation.
  ///
  /// In ar, this message translates to:
  /// **'شغّل الموقع لتبدأ العمل.'**
  String get taxiNoLocation;

  /// No description provided for @taxisOff.
  ///
  /// In ar, this message translates to:
  /// **'خدمة التكسي متوقفة الآن من المكتب.'**
  String get taxisOff;

  /// No description provided for @taxiStudentCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ألغى الطالب الرحلة.'**
  String get taxiStudentCancelled;

  /// No description provided for @taxiFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال. حاول مرة أخرى.'**
  String get taxiFailed;

  /// No description provided for @taxiDismiss.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get taxiDismiss;

  /// No description provided for @taxiGoToStudent.
  ///
  /// In ar, this message translates to:
  /// **'اذهب إلى الطالب'**
  String get taxiGoToStudent;

  /// No description provided for @taxiGoToGate.
  ///
  /// In ar, this message translates to:
  /// **'اذهب إلى باب الجامعة'**
  String get taxiGoToGate;

  /// No description provided for @taxiWaitingStudent.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار صعود الطالب'**
  String get taxiWaitingStudent;

  /// No description provided for @taxiOnTripCampus.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق إلى الجامعة'**
  String get taxiOnTripCampus;

  /// No description provided for @taxiOnTripHome.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق إلى مكان الطالب'**
  String get taxiOnTripHome;

  /// No description provided for @taxiStep.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {n} من 3'**
  String taxiStep(int n);

  /// No description provided for @taxiCall.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get taxiCall;

  /// No description provided for @taxiCallStudent.
  ///
  /// In ar, this message translates to:
  /// **'اتصل بـ {name}'**
  String taxiCallStudent(String name);

  /// No description provided for @taxiArrived.
  ///
  /// In ar, this message translates to:
  /// **'وصلت'**
  String get taxiArrived;

  /// No description provided for @taxiStartTrip.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الرحلة'**
  String get taxiStartTrip;

  /// No description provided for @taxiEndTrip.
  ///
  /// In ar, this message translates to:
  /// **'أنهِ الرحلة واستلم {amount}'**
  String taxiEndTrip(String amount);

  /// No description provided for @taxiEndConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'هل استلمت {amount} نقداً؟'**
  String taxiEndConfirmTitle(String amount);

  /// No description provided for @taxiEndConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'تُسجَّل الأجرة باسمك عند إنهاء الرحلة.'**
  String get taxiEndConfirmBody;

  /// No description provided for @taxiEndConfirmYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم، استلمتها'**
  String get taxiEndConfirmYes;

  /// No description provided for @taxiNotYet.
  ///
  /// In ar, this message translates to:
  /// **'ليس بعد'**
  String get taxiNotYet;

  /// No description provided for @taxiCancelRide.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الرحلة'**
  String get taxiCancelRide;

  /// No description provided for @taxiCancelConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء هذه الرحلة؟'**
  String get taxiCancelConfirmTitle;

  /// No description provided for @taxiCancelConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيعود الطلب إلى السائقين الآخرين.'**
  String get taxiCancelConfirmBody;

  /// No description provided for @taxiCancelYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم، ألغِ الرحلة'**
  String get taxiCancelYes;

  /// No description provided for @taxiKeepRide.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الرحلة'**
  String get taxiKeepRide;

  /// No description provided for @taxiFare.
  ///
  /// In ar, this message translates to:
  /// **'الأجرة نقداً'**
  String get taxiFare;

  /// No description provided for @taxiDistance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة'**
  String get taxiDistance;

  /// No description provided for @taxiKm.
  ///
  /// In ar, this message translates to:
  /// **'{km} كم'**
  String taxiKm(String km);

  /// No description provided for @taxiDoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الرحلة'**
  String get taxiDoneTitle;

  /// No description provided for @taxiDoneBody.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل المبلغ النقدي باسمك.'**
  String get taxiDoneBody;

  /// No description provided for @taxiBackToRequests.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى الطلبات'**
  String get taxiBackToRequests;

  /// No description provided for @taxiMonthTitle.
  ///
  /// In ar, this message translates to:
  /// **'رحلات التكسي هذا الشهر'**
  String get taxiMonthTitle;

  /// No description provided for @taxiMonthSummary.
  ///
  /// In ar, this message translates to:
  /// **'{trips} رحلة · {amount}'**
  String taxiMonthSummary(int trips, String amount);

  /// No description provided for @taxiRecent.
  ///
  /// In ar, this message translates to:
  /// **'آخر رحلات التكسي'**
  String get taxiRecent;

  /// No description provided for @taxiNoTrips.
  ///
  /// In ar, this message translates to:
  /// **'لا رحلات تكسي بعد'**
  String get taxiNoTrips;

  /// No description provided for @taxiStatusDone.
  ///
  /// In ar, this message translates to:
  /// **'منتهية'**
  String get taxiStatusDone;

  /// No description provided for @taxiStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get taxiStatusCancelled;

  /// No description provided for @taxiStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'جارية'**
  String get taxiStatusActive;

  /// No description provided for @taxiCashCollected.
  ///
  /// In ar, this message translates to:
  /// **'النقد المستلم'**
  String get taxiCashCollected;

  /// No description provided for @accountApproved.
  ///
  /// In ar, this message translates to:
  /// **'معتمد'**
  String get accountApproved;

  /// No description provided for @accountVehicle.
  ///
  /// In ar, this message translates to:
  /// **'مركبتك'**
  String get accountVehicle;

  /// No description provided for @accountFromOffice.
  ///
  /// In ar, this message translates to:
  /// **'اعتمدها مكتب النقل'**
  String get accountFromOffice;

  /// No description provided for @accountChangeHint.
  ///
  /// In ar, this message translates to:
  /// **'لتغيير بيانات المركبة راجع مكتب النقل.'**
  String get accountChangeHint;

  /// No description provided for @accountNotSet.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get accountNotSet;

  /// No description provided for @accountDocuments.
  ///
  /// In ar, this message translates to:
  /// **'المستمسكات'**
  String get accountDocuments;

  /// No description provided for @accountDocumentsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم تُرفع مستمسكات} =1{مستمسك واحد مرفوع} =2{مستمسكان مرفوعان} few{{count} مستمسكات مرفوعة} other{{count} مستمسكاً مرفوعاً}}'**
  String accountDocumentsCount(int count);

  /// No description provided for @accountLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get accountLanguage;

  /// No description provided for @accountSignOutTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج؟'**
  String get accountSignOutTitle;

  /// No description provided for @accountSignOutBody.
  ///
  /// In ar, this message translates to:
  /// **'ستحتاج رمزاً جديداً يصل إلى هاتفك لتدخل مرة أخرى.'**
  String get accountSignOutBody;

  /// No description provided for @accountStay.
  ///
  /// In ar, this message translates to:
  /// **'البقاء مسجّلاً'**
  String get accountStay;

  /// No description provided for @accountDocumentsHint.
  ///
  /// In ar, this message translates to:
  /// **'المستمسكات التي طلبها مكتب النقل. لتحديث أي منها راجع المكتب.'**
  String get accountDocumentsHint;

  /// No description provided for @accountDocUploaded.
  ///
  /// In ar, this message translates to:
  /// **'مرفوع'**
  String get accountDocUploaded;

  /// No description provided for @accountDocMissing.
  ///
  /// In ar, this message translates to:
  /// **'غير مرفوع'**
  String get accountDocMissing;

  /// No description provided for @accountClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get accountClose;

  /// No description provided for @greetMorning.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير'**
  String get greetMorning;

  /// No description provided for @greetEvening.
  ///
  /// In ar, this message translates to:
  /// **'مساء الخير'**
  String get greetEvening;

  /// No description provided for @tabHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get tabHome;

  /// No description provided for @kpiTaxiToday.
  ///
  /// In ar, this message translates to:
  /// **'مشاوير اليوم'**
  String get kpiTaxiToday;

  /// No description provided for @kpiCash.
  ///
  /// In ar, this message translates to:
  /// **'نقداً'**
  String get kpiCash;

  /// No description provided for @kpiMonth.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get kpiMonth;

  /// No description provided for @kpiRiders.
  ///
  /// In ar, this message translates to:
  /// **'ركاب اليوم'**
  String get kpiRiders;

  /// No description provided for @taxiOnlineSub.
  ///
  /// In ar, this message translates to:
  /// **'تصلك طلبات التكسي القريبة · اضغط للإيقاف'**
  String get taxiOnlineSub;

  /// No description provided for @watermarkOn.
  ///
  /// In ar, this message translates to:
  /// **'ON'**
  String get watermarkOn;

  /// No description provided for @taxiSkipOffer.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل الطلب'**
  String get taxiSkipOffer;

  /// No description provided for @taxiOfferLine.
  ///
  /// In ar, this message translates to:
  /// **'{direction} · {km} كم'**
  String taxiOfferLine(String direction, String km);

  /// No description provided for @nextRunTitle.
  ///
  /// In ar, this message translates to:
  /// **'رحلتك القادمة'**
  String get nextRunTitle;

  /// No description provided for @laterToday.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً اليوم'**
  String get laterToday;

  /// No description provided for @runRidersCount.
  ///
  /// In ar, this message translates to:
  /// **'{n} راكب'**
  String runRidersCount(int n);

  /// No description provided for @stopOfTotal.
  ///
  /// In ar, this message translates to:
  /// **'المحطة {n} من {total}'**
  String stopOfTotal(int n, String total);

  /// No description provided for @riderCash.
  ///
  /// In ar, this message translates to:
  /// **'{amount} نقداً'**
  String riderCash(String amount);

  /// No description provided for @distanceM.
  ///
  /// In ar, this message translates to:
  /// **'{m} م'**
  String distanceM(String m);

  /// No description provided for @distanceKmShort.
  ///
  /// In ar, this message translates to:
  /// **'{km} كم'**
  String distanceKmShort(String km);

  /// No description provided for @headTo.
  ///
  /// In ar, this message translates to:
  /// **'توجّه إلى {place}'**
  String headTo(String place);

  /// No description provided for @leaveAt.
  ///
  /// In ar, this message translates to:
  /// **'انطلق الساعة {time}'**
  String leaveAt(String time);

  /// No description provided for @arriveAround.
  ///
  /// In ar, this message translates to:
  /// **'الوصول نحو {time}'**
  String arriveAround(String time);

  /// No description provided for @ridersHere.
  ///
  /// In ar, this message translates to:
  /// **'الركاب في هذه المحطة'**
  String get ridersHere;

  /// No description provided for @noRidersHere.
  ///
  /// In ar, this message translates to:
  /// **'لا ركاب في هذه المحطة'**
  String get noRidersHere;

  /// No description provided for @studentCaption.
  ///
  /// In ar, this message translates to:
  /// **'الطالب'**
  String get studentCaption;

  /// No description provided for @pickupPlace.
  ///
  /// In ar, this message translates to:
  /// **'مكان الركوب'**
  String get pickupPlace;

  /// No description provided for @dropoffPlace.
  ///
  /// In ar, this message translates to:
  /// **'مكان النزول'**
  String get dropoffPlace;

  /// No description provided for @openNavigation.
  ///
  /// In ar, this message translates to:
  /// **'فتح الملاحة'**
  String get openNavigation;

  /// No description provided for @runProgress.
  ///
  /// In ar, this message translates to:
  /// **'خُدمت {done} من {total} محطات'**
  String runProgress(String done, String total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
