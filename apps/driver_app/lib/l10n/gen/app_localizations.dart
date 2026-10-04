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
  /// **'ستظهر هنا رحلاتك ونقاط التوقف بعد تفعيل التوزيع.'**
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
