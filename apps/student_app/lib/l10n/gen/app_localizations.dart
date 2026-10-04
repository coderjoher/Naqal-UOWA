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
  /// **'نقل جامعة وارث'**
  String get appTitle;

  /// No description provided for @hello.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك'**
  String get hello;

  /// No description provided for @helloName.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً، {name}'**
  String helloName(String name);

  /// No description provided for @notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// No description provided for @noSubscription.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اشتراك'**
  String get noSubscription;

  /// No description provided for @noRideToday.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلة اليوم'**
  String get noRideToday;

  /// No description provided for @noRideTodayBody.
  ///
  /// In ar, this message translates to:
  /// **'طلب الرحلات اليومية سيتوفر قريباً.'**
  String get noRideTodayBody;

  /// No description provided for @tabHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get tabHome;

  /// No description provided for @tabTrips.
  ///
  /// In ar, this message translates to:
  /// **'رحلاتي'**
  String get tabTrips;

  /// No description provided for @tabAlerts.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get tabAlerts;

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
  /// **'تنقّلك اليومي إلى الجامعة'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'اطلب مقعدك كل يوم، وتابع حافلتك على الخريطة، واعرف متى تصل.'**
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
  /// **'اختر جامعتك'**
  String get chooseUniversity;

  /// No description provided for @chooseUniversityBody.
  ///
  /// In ar, this message translates to:
  /// **'ستستخدم حساب جامعتك لتسجيل الدخول.'**
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

  /// No description provided for @signInTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get signInTitle;

  /// No description provided for @studentNumber.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الجامعي'**
  String get studentNumber;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get signIn;

  /// No description provided for @signInFailed.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الجامعي أو كلمة المرور غير صحيحة'**
  String get signInFailed;

  /// No description provided for @firstTime.
  ///
  /// In ar, this message translates to:
  /// **'أول مرة؟ فعّل حسابك برمز المكتب'**
  String get firstTime;

  /// No description provided for @activateTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الحساب'**
  String get activateTitle;

  /// No description provided for @activateBody.
  ///
  /// In ar, this message translates to:
  /// **'ادخل الرمز الذي سلّمه لك مكتب النقل، ثم اختر كلمة مرور.'**
  String get activateBody;

  /// No description provided for @activationCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز التفعيل'**
  String get activationCode;

  /// No description provided for @newPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة مرور جديدة'**
  String get newPassword;

  /// No description provided for @passwordHint.
  ///
  /// In ar, this message translates to:
  /// **'٨ أحرف على الأقل'**
  String get passwordHint;

  /// No description provided for @activate.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل ودخول'**
  String get activate;

  /// No description provided for @activateFailed.
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح أو منتهي. اطلب رمزاً جديداً من مكتب النقل.'**
  String get activateFailed;

  /// No description provided for @changeUniversity.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الجامعة'**
  String get changeUniversity;

  /// No description provided for @choosePointTitle.
  ///
  /// In ar, this message translates to:
  /// **'نقطة التجمّع'**
  String get choosePointTitle;

  /// No description provided for @choosePointBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر النقطة الأقرب إليك. تركب الحافلة منها كل يوم ويُحسب سعر اشتراكك حسب فئتها.'**
  String get choosePointBody;

  /// No description provided for @searchPoints.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن نقطة'**
  String get searchPoints;

  /// No description provided for @tierLabel.
  ///
  /// In ar, this message translates to:
  /// **'الفئة {tier}'**
  String tierLabel(String tier);

  /// No description provided for @kmAway.
  ///
  /// In ar, this message translates to:
  /// **'{km} كم عن الجامعة'**
  String kmAway(String km);

  /// No description provided for @savePoint.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد النقطة'**
  String get savePoint;

  /// No description provided for @noPoints.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نقاط تجمّع بعد'**
  String get noPoints;

  /// No description provided for @noPointsBody.
  ///
  /// In ar, this message translates to:
  /// **'سيضيفها مكتب النقل قريباً.'**
  String get noPointsBody;

  /// No description provided for @yourPoint.
  ///
  /// In ar, this message translates to:
  /// **'نقطة تجمّعك'**
  String get yourPoint;

  /// No description provided for @change.
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get change;

  /// No description provided for @profileTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get profileTitle;

  /// No description provided for @personalInfo.
  ///
  /// In ar, this message translates to:
  /// **'المعلومات الشخصية'**
  String get personalInfo;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get name;

  /// No description provided for @gender.
  ///
  /// In ar, this message translates to:
  /// **'الجنس'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In ar, this message translates to:
  /// **'ذكر'**
  String get male;

  /// No description provided for @female.
  ///
  /// In ar, this message translates to:
  /// **'أنثى'**
  String get female;

  /// No description provided for @fromUniversity.
  ///
  /// In ar, this message translates to:
  /// **'من سجلات الجامعة ولا يمكن تعديله'**
  String get fromUniversity;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phone;

  /// No description provided for @phoneHint.
  ///
  /// In ar, this message translates to:
  /// **'07XX XXX XXXX'**
  String get phoneHint;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

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

  /// No description provided for @invalidPhone.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم موبايل عراقي صحيح'**
  String get invalidPhone;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// No description provided for @defaultPoint.
  ///
  /// In ar, this message translates to:
  /// **'نقطة التجمّع'**
  String get defaultPoint;

  /// No description provided for @notSet.
  ///
  /// In ar, this message translates to:
  /// **'غير محدّدة'**
  String get notSet;
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
