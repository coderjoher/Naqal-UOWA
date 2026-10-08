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
  /// **'اطلب مقعداً في حافلة اليوم أو الغد.'**
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

  /// No description provided for @subActive.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك فعّال'**
  String get subActive;

  /// No description provided for @subExpiring.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي خلال {days} أيام'**
  String subExpiring(int days);

  /// No description provided for @subExpired.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك منتهي'**
  String get subExpired;

  /// No description provided for @subNone.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اشتراك'**
  String get subNone;

  /// No description provided for @subUntil.
  ///
  /// In ar, this message translates to:
  /// **'حتى {date}'**
  String subUntil(String date);

  /// No description provided for @subMonthly.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك شهري'**
  String get subMonthly;

  /// No description provided for @subTierPrice.
  ///
  /// In ar, this message translates to:
  /// **'الفئة {tier} · {price}'**
  String subTierPrice(String tier, String price);

  /// No description provided for @subPayAtOffice.
  ///
  /// In ar, this message translates to:
  /// **'ادفع نقداً في مكتب النقل وسيُفعّل اشتراكك فوراً.'**
  String get subPayAtOffice;

  /// No description provided for @subRenew.
  ///
  /// In ar, this message translates to:
  /// **'جدّد اشتراكك في مكتب النقل قبل انتهائه.'**
  String get subRenew;

  /// No description provided for @subNext.
  ///
  /// In ar, this message translates to:
  /// **'الشهر القادم مدفوع: {month}'**
  String subNext(String month);

  /// No description provided for @subUnlimited.
  ///
  /// In ar, this message translates to:
  /// **'رحلات غير محدودة وأولوية في المقاعد'**
  String get subUnlimited;

  /// No description provided for @subTier.
  ///
  /// In ar, this message translates to:
  /// **'الفئة {tier}'**
  String subTier(String tier);

  /// No description provided for @rideRequest.
  ///
  /// In ar, this message translates to:
  /// **'اطلب رحلة'**
  String get rideRequest;

  /// No description provided for @rideRequestTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب رحلة'**
  String get rideRequestTitle;

  /// No description provided for @rideRequestBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر الموعد ونقطة التجمّع، ونحجز لك مقعداً.'**
  String get rideRequestBody;

  /// No description provided for @rideWhen.
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get rideWhen;

  /// No description provided for @rideWhere.
  ///
  /// In ar, this message translates to:
  /// **'نقطة التجمّع'**
  String get rideWhere;

  /// No description provided for @rideToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get rideToday;

  /// No description provided for @rideTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غداً'**
  String get rideTomorrow;

  /// No description provided for @rideMorning.
  ///
  /// In ar, this message translates to:
  /// **'ذهاب'**
  String get rideMorning;

  /// No description provided for @rideReturn.
  ///
  /// In ar, this message translates to:
  /// **'عودة'**
  String get rideReturn;

  /// No description provided for @rideSlot.
  ///
  /// In ar, this message translates to:
  /// **'{day} · {type} {time}'**
  String rideSlot(String day, String type, String time);

  /// No description provided for @rideNoSlots.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواعيد متاحة اليوم أو غداً.'**
  String get rideNoSlots;

  /// No description provided for @rideSend.
  ///
  /// In ar, this message translates to:
  /// **'أرسل الطلب'**
  String get rideSend;

  /// No description provided for @rideSent.
  ///
  /// In ar, this message translates to:
  /// **'وصل طلبك'**
  String get rideSent;

  /// No description provided for @rideConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'مؤكد'**
  String get rideConfirmed;

  /// No description provided for @rideCampus.
  ///
  /// In ar, this message translates to:
  /// **'الجامعة'**
  String get rideCampus;

  /// No description provided for @rideStopOf.
  ///
  /// In ar, this message translates to:
  /// **'المحطة {n} من {total}'**
  String rideStopOf(String n, String total);

  /// No description provided for @ridePayDriver.
  ///
  /// In ar, this message translates to:
  /// **'ادفع {amount} نقداً للسائق'**
  String ridePayDriver(String amount);

  /// No description provided for @rideCovered.
  ///
  /// In ar, this message translates to:
  /// **'مشمول باشتراكك'**
  String get rideCovered;

  /// No description provided for @rideCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get rideCancel;

  /// No description provided for @rideCancelTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب؟'**
  String get rideCancelTitle;

  /// No description provided for @rideCancelBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُعطى مقعدك لطالب آخر.'**
  String get rideCancelBody;

  /// No description provided for @rideCancelYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم، ألغِ'**
  String get rideCancelYes;

  /// No description provided for @rideKeep.
  ///
  /// In ar, this message translates to:
  /// **'لا، أبقِه'**
  String get rideKeep;

  /// No description provided for @rideCancelled.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي الطلب'**
  String get rideCancelled;

  /// No description provided for @ridePendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'وصل طلبك'**
  String get ridePendingTitle;

  /// No description provided for @ridePendingBody.
  ///
  /// In ar, this message translates to:
  /// **'نوزّع الحافلات قبل الموعد بساعة ونخبرك بحافلتك.'**
  String get ridePendingBody;

  /// No description provided for @rideWaitTitle.
  ///
  /// In ar, this message translates to:
  /// **'أنت على قائمة الانتظار'**
  String get rideWaitTitle;

  /// No description provided for @rideWaitBody.
  ///
  /// In ar, this message translates to:
  /// **'كل المقاعد محجوزة الآن. سنحجز لك مقعداً فور تحرّر واحد.'**
  String get rideWaitBody;

  /// No description provided for @rideWaitLeft.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتبقي'**
  String get rideWaitLeft;

  /// No description provided for @rideExpired.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد مقعداً لرحلة {time}. يمكنك طلب موعد آخر.'**
  String rideExpired(String time);

  /// No description provided for @rideWave.
  ///
  /// In ar, this message translates to:
  /// **'{day} · {type} {time}'**
  String rideWave(String day, String type, String time);

  /// No description provided for @rideFemaleOnly.
  ///
  /// In ar, this message translates to:
  /// **'للطالبات فقط'**
  String get rideFemaleOnly;

  /// No description provided for @trackBus.
  ///
  /// In ar, this message translates to:
  /// **'تتبّع الحافلة'**
  String get trackBus;

  /// No description provided for @trackTitle.
  ///
  /// In ar, this message translates to:
  /// **'حافلتك'**
  String get trackTitle;

  /// No description provided for @etaMinutes.
  ///
  /// In ar, this message translates to:
  /// **'تصل خلال {n} د'**
  String etaMinutes(int n);

  /// No description provided for @etaNow.
  ///
  /// In ar, this message translates to:
  /// **'الحافلة في نقطتك الآن'**
  String get etaNow;

  /// No description provided for @onBus.
  ///
  /// In ar, this message translates to:
  /// **'أنت في الحافلة'**
  String get onBus;

  /// No description provided for @notStarted.
  ///
  /// In ar, this message translates to:
  /// **'لم تنطلق الحافلة بعد'**
  String get notStarted;

  /// No description provided for @updatedAgo.
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث قبل {time}'**
  String updatedAgo(String time);

  /// No description provided for @lastKnown.
  ///
  /// In ar, this message translates to:
  /// **'آخر موقع معروف'**
  String get lastKnown;

  /// No description provided for @agoSeconds.
  ///
  /// In ar, this message translates to:
  /// **'{n} ث'**
  String agoSeconds(int n);

  /// No description provided for @agoMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{n} د'**
  String agoMinutes(int n);

  /// No description provided for @yourStop.
  ///
  /// In ar, this message translates to:
  /// **'نقطتك'**
  String get yourStop;

  /// No description provided for @busLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحافلة'**
  String get busLabel;

  /// No description provided for @notificationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notificationsTitle;

  /// No description provided for @noNotifications.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات'**
  String get noNotifications;

  /// No description provided for @noNotificationsBody.
  ///
  /// In ar, this message translates to:
  /// **'ستصلك هنا أخبار مقعدك وحافلتك.'**
  String get noNotificationsBody;

  /// No description provided for @nAssignedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد مقعدك'**
  String get nAssignedTitle;

  /// No description provided for @nAssignedBody.
  ///
  /// In ar, this message translates to:
  /// **'افتح التطبيق لترى حافلتك ووقت الصعود.'**
  String get nAssignedBody;

  /// No description provided for @nWaitlistedTitle.
  ///
  /// In ar, this message translates to:
  /// **'أنت على قائمة الانتظار'**
  String get nWaitlistedTitle;

  /// No description provided for @nWaitlistedBody.
  ///
  /// In ar, this message translates to:
  /// **'سنخبرك فور توفر مقعد.'**
  String get nWaitlistedBody;

  /// No description provided for @nBumpedTitle.
  ///
  /// In ar, this message translates to:
  /// **'نُقلت إلى قائمة الانتظار'**
  String get nBumpedTitle;

  /// No description provided for @nBumpedBody.
  ///
  /// In ar, this message translates to:
  /// **'أُعطي مقعدك لمشترك. سنحجز لك فور توفر مقعد.'**
  String get nBumpedBody;

  /// No description provided for @nApproachingTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحافلة تقترب'**
  String get nApproachingTitle;

  /// No description provided for @nApproachingBody.
  ///
  /// In ar, this message translates to:
  /// **'تصل إلى نقطتك خلال {n} دقائق تقريباً.'**
  String nApproachingBody(int n);

  /// No description provided for @nArrivedTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحافلة وصلت'**
  String get nArrivedTitle;

  /// No description provided for @nArrivedBody.
  ///
  /// In ar, this message translates to:
  /// **'الحافلة في نقطة التجمّع الآن.'**
  String get nArrivedBody;

  /// No description provided for @nExpiredTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد مقعداً'**
  String get nExpiredTitle;

  /// No description provided for @nExpiredBody.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مدة الانتظار وأُلغي الطلب.'**
  String get nExpiredBody;

  /// No description provided for @nCancelledTitle.
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت الرحلة'**
  String get nCancelledTitle;

  /// No description provided for @nCancelledBody.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي طلب رحلتك.'**
  String get nCancelledBody;

  /// No description provided for @historyRides.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات'**
  String get historyRides;

  /// No description provided for @historyPayments.
  ///
  /// In ar, this message translates to:
  /// **'المدفوعات'**
  String get historyPayments;

  /// No description provided for @historyNoRides.
  ///
  /// In ar, this message translates to:
  /// **'لا رحلات سابقة'**
  String get historyNoRides;

  /// No description provided for @historyNoRidesBody.
  ///
  /// In ar, this message translates to:
  /// **'تظهر هنا رحلاتك بعد انتهائها.'**
  String get historyNoRidesBody;

  /// No description provided for @historyNoPayments.
  ///
  /// In ar, this message translates to:
  /// **'لا مدفوعات بعد'**
  String get historyNoPayments;

  /// No description provided for @historyNoPaymentsBody.
  ///
  /// In ar, this message translates to:
  /// **'يظهر هنا كل ما دفعته للاشتراك أو للسائق.'**
  String get historyNoPaymentsBody;

  /// No description provided for @historyEnd.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء أقدم'**
  String get historyEnd;

  /// No description provided for @historyDone.
  ///
  /// In ar, this message translates to:
  /// **'تمت'**
  String get historyDone;

  /// No description provided for @historyNoShow.
  ///
  /// In ar, this message translates to:
  /// **'لم تحضر'**
  String get historyNoShow;

  /// No description provided for @historyCancelled.
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت'**
  String get historyCancelled;

  /// No description provided for @historyExpired.
  ///
  /// In ar, this message translates to:
  /// **'بلا مقعد'**
  String get historyExpired;

  /// No description provided for @historyMissed.
  ///
  /// In ar, this message translates to:
  /// **'لم تتم'**
  String get historyMissed;

  /// No description provided for @rateRide.
  ///
  /// In ar, this message translates to:
  /// **'قيّم الرحلة'**
  String get rateRide;

  /// No description provided for @rateTitle.
  ///
  /// In ar, this message translates to:
  /// **'كيف كانت الرحلة؟'**
  String get rateTitle;

  /// No description provided for @rateBody.
  ///
  /// In ar, this message translates to:
  /// **'تقييمك يصل إلى مكتب النقل ويساعد في تحسين الخدمة.'**
  String get rateBody;

  /// No description provided for @rateComment.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختياري)'**
  String get rateComment;

  /// No description provided for @rateSend.
  ///
  /// In ar, this message translates to:
  /// **'أرسل التقييم'**
  String get rateSend;

  /// No description provided for @rateThanks.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لتقييمك'**
  String get rateThanks;

  /// No description provided for @reportProblem.
  ///
  /// In ar, this message translates to:
  /// **'أبلغ عن مشكلة'**
  String get reportProblem;

  /// No description provided for @reportProblemHint.
  ///
  /// In ar, this message translates to:
  /// **'يصل بلاغك إلى مكتب النقل مباشرة'**
  String get reportProblemHint;

  /// No description provided for @problemTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما المشكلة؟'**
  String get problemTitle;

  /// No description provided for @problemBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع المشكلة واكتب ما حدث. سيرد عليك مكتب النقل.'**
  String get problemBody;

  /// No description provided for @problemLate.
  ///
  /// In ar, this message translates to:
  /// **'تأخير'**
  String get problemLate;

  /// No description provided for @problemDriver.
  ///
  /// In ar, this message translates to:
  /// **'السائق'**
  String get problemDriver;

  /// No description provided for @problemVehicle.
  ///
  /// In ar, this message translates to:
  /// **'الحافلة'**
  String get problemVehicle;

  /// No description provided for @problemSafety.
  ///
  /// In ar, this message translates to:
  /// **'السلامة'**
  String get problemSafety;

  /// No description provided for @problemApp.
  ///
  /// In ar, this message translates to:
  /// **'التطبيق'**
  String get problemApp;

  /// No description provided for @problemOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get problemOther;

  /// No description provided for @problemText.
  ///
  /// In ar, this message translates to:
  /// **'ماذا حدث؟'**
  String get problemText;

  /// No description provided for @problemSend.
  ///
  /// In ar, this message translates to:
  /// **'أرسل البلاغ'**
  String get problemSend;

  /// No description provided for @problemSent.
  ///
  /// In ar, this message translates to:
  /// **'وصل بلاغك إلى مكتب النقل'**
  String get problemSent;

  /// No description provided for @paySubscription.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك شهري'**
  String get paySubscription;

  /// No description provided for @paySubscriptionMonth.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك {month}'**
  String paySubscriptionMonth(String month);

  /// No description provided for @payTierDifference.
  ///
  /// In ar, this message translates to:
  /// **'فرق الفئة'**
  String get payTierDifference;

  /// No description provided for @payCashFare.
  ///
  /// In ar, this message translates to:
  /// **'أجرة رحلة نقداً'**
  String get payCashFare;

  /// No description provided for @payReversal.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء: {what}'**
  String payReversal(String what);

  /// No description provided for @payReceipt.
  ///
  /// In ar, this message translates to:
  /// **'إيصال {no}'**
  String payReceipt(int no);

  /// No description provided for @nMovedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيّرت حافلتك'**
  String get nMovedTitle;

  /// No description provided for @nMovedBody.
  ///
  /// In ar, this message translates to:
  /// **'نقلك مكتب النقل إلى حافلة أخرى. افتح الرئيسية لترى التفاصيل.'**
  String get nMovedBody;

  /// No description provided for @nAnsweredTitle.
  ///
  /// In ar, this message translates to:
  /// **'ردّ مكتب النقل على بلاغك'**
  String get nAnsweredTitle;

  /// No description provided for @dismiss.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get dismiss;

  /// No description provided for @taxiTitle.
  ///
  /// In ar, this message translates to:
  /// **'تكسي الجامعة'**
  String get taxiTitle;

  /// No description provided for @taxiCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'تكسي من الجامعة وإليها'**
  String get taxiCardTitle;

  /// No description provided for @taxiCardBody.
  ///
  /// In ar, this message translates to:
  /// **'تعرف الأجرة قبل الطلب، وتدفعها نقداً للسائق.'**
  String get taxiCardBody;

  /// No description provided for @taxiDirection.
  ///
  /// In ar, this message translates to:
  /// **'وجهة الرحلة'**
  String get taxiDirection;

  /// No description provided for @taxiToCampus.
  ///
  /// In ar, this message translates to:
  /// **'إلى الجامعة'**
  String get taxiToCampus;

  /// No description provided for @taxiFromCampus.
  ///
  /// In ar, this message translates to:
  /// **'من الجامعة للبيت'**
  String get taxiFromCampus;

  /// No description provided for @taxiPickupHint.
  ///
  /// In ar, this message translates to:
  /// **'حرّك الخريطة أو المسها لتحديد مكان الركوب'**
  String get taxiPickupHint;

  /// No description provided for @taxiDropoffHint.
  ///
  /// In ar, this message translates to:
  /// **'حرّك الخريطة أو المسها لتحديد مكان النزول'**
  String get taxiDropoffHint;

  /// No description provided for @taxiMyLocation.
  ///
  /// In ar, this message translates to:
  /// **'استخدم موقعي الحالي'**
  String get taxiMyLocation;

  /// No description provided for @taxiLocationFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد موقعك. فعّل خدمة الموقع أو حرّك الخريطة.'**
  String get taxiLocationFailed;

  /// No description provided for @taxiLabel.
  ///
  /// In ar, this message translates to:
  /// **'علامة دالّة (اختياري)'**
  String get taxiLabel;

  /// No description provided for @taxiLabelHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: قرب باب الجامع'**
  String get taxiLabelHint;

  /// No description provided for @taxiFare.
  ///
  /// In ar, this message translates to:
  /// **'الأجرة'**
  String get taxiFare;

  /// No description provided for @taxiCash.
  ///
  /// In ar, this message translates to:
  /// **'تُدفع نقداً للسائق'**
  String get taxiCash;

  /// No description provided for @taxiKm.
  ///
  /// In ar, this message translates to:
  /// **'{km} كم'**
  String taxiKm(String km);

  /// No description provided for @taxiMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{n} د'**
  String taxiMinutes(int n);

  /// No description provided for @taxiNearby.
  ///
  /// In ar, this message translates to:
  /// **'سيارات قريبة: {n}'**
  String taxiNearby(int n);

  /// No description provided for @taxiNoneNearby.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد سيارة قريبة الآن، ويمكنك الطلب مع ذلك.'**
  String get taxiNoneNearby;

  /// No description provided for @taxiPickupIn.
  ///
  /// In ar, this message translates to:
  /// **'يصلك خلال {n} د تقريباً'**
  String taxiPickupIn(int n);

  /// No description provided for @taxiRequest.
  ///
  /// In ar, this message translates to:
  /// **'اطلب تكسي'**
  String get taxiRequest;

  /// No description provided for @taxiUnavailableHere.
  ///
  /// In ar, this message translates to:
  /// **'خدمة التكسي غير متاحة في هذا المكان'**
  String get taxiUnavailableHere;

  /// No description provided for @taxiSearching.
  ///
  /// In ar, this message translates to:
  /// **'نبحث عن تكسي قريب'**
  String get taxiSearching;

  /// No description provided for @taxiSearchingBody.
  ///
  /// In ar, this message translates to:
  /// **'وصل طلبك إلى السائقين القريبين، وأول من يقبل يأتي إليك.'**
  String get taxiSearchingBody;

  /// No description provided for @taxiTimeLeft.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتبقي'**
  String get taxiTimeLeft;

  /// No description provided for @taxiCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get taxiCancel;

  /// No description provided for @taxiCancelTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التكسي؟'**
  String get taxiCancelTitle;

  /// No description provided for @taxiCancelBody.
  ///
  /// In ar, this message translates to:
  /// **'سنُبلغ السائق بالإلغاء.'**
  String get taxiCancelBody;

  /// No description provided for @taxiCancelYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم، ألغِ'**
  String get taxiCancelYes;

  /// No description provided for @taxiKeep.
  ///
  /// In ar, this message translates to:
  /// **'لا، أبقِه'**
  String get taxiKeep;

  /// No description provided for @taxiAccepted.
  ///
  /// In ar, this message translates to:
  /// **'التكسي في الطريق إليك'**
  String get taxiAccepted;

  /// No description provided for @taxiArrived.
  ///
  /// In ar, this message translates to:
  /// **'وصل التكسي'**
  String get taxiArrived;

  /// No description provided for @taxiArrivedBody.
  ///
  /// In ar, this message translates to:
  /// **'السائق ينتظرك في مكان الركوب.'**
  String get taxiArrivedBody;

  /// No description provided for @taxiOnTripToCampus.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق إلى الجامعة'**
  String get taxiOnTripToCampus;

  /// No description provided for @taxiOnTripHome.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق إلى البيت'**
  String get taxiOnTripHome;

  /// No description provided for @taxiAway.
  ///
  /// In ar, this message translates to:
  /// **'يصل خلال {n} د'**
  String taxiAway(int n);

  /// No description provided for @taxiCall.
  ///
  /// In ar, this message translates to:
  /// **'اتصل بالسائق'**
  String get taxiCall;

  /// No description provided for @taxiPlate.
  ///
  /// In ar, this message translates to:
  /// **'اللوحة {plate}'**
  String taxiPlate(String plate);

  /// No description provided for @taxiStepAccepted.
  ///
  /// In ar, this message translates to:
  /// **'قُبل'**
  String get taxiStepAccepted;

  /// No description provided for @taxiStepArrived.
  ///
  /// In ar, this message translates to:
  /// **'وصل'**
  String get taxiStepArrived;

  /// No description provided for @taxiStepOnTrip.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق'**
  String get taxiStepOnTrip;

  /// No description provided for @taxiStepDone.
  ///
  /// In ar, this message translates to:
  /// **'انتهت'**
  String get taxiStepDone;

  /// No description provided for @taxiStepOf.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {n} من 4: {name}'**
  String taxiStepOf(int n, String name);

  /// No description provided for @taxiDone.
  ///
  /// In ar, this message translates to:
  /// **'وصلت بالسلامة'**
  String get taxiDone;

  /// No description provided for @taxiPayCash.
  ///
  /// In ar, this message translates to:
  /// **'ادفع للسائق {amount} نقداً'**
  String taxiPayCash(String amount);

  /// No description provided for @taxiSummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الرحلة'**
  String get taxiSummary;

  /// No description provided for @taxiRoute.
  ///
  /// In ar, this message translates to:
  /// **'المسار'**
  String get taxiRoute;

  /// No description provided for @taxiCampus.
  ///
  /// In ar, this message translates to:
  /// **'الجامعة'**
  String get taxiCampus;

  /// No description provided for @taxiYourSpot.
  ///
  /// In ar, this message translates to:
  /// **'موقعك'**
  String get taxiYourSpot;

  /// No description provided for @taxiDriver.
  ///
  /// In ar, this message translates to:
  /// **'السائق'**
  String get taxiDriver;

  /// No description provided for @taxiDistance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة'**
  String get taxiDistance;

  /// No description provided for @taxiBackHome.
  ///
  /// In ar, this message translates to:
  /// **'العودة للرئيسية'**
  String get taxiBackHome;

  /// No description provided for @taxiExpired.
  ///
  /// In ar, this message translates to:
  /// **'لم يقبل أي سائق هذه المرة'**
  String get taxiExpired;

  /// No description provided for @taxiExpiredBody.
  ///
  /// In ar, this message translates to:
  /// **'قد يكون السائقون مشغولين. جرّب مرة أخرى بعد قليل.'**
  String get taxiExpiredBody;

  /// No description provided for @taxiCancelledByYou.
  ///
  /// In ar, this message translates to:
  /// **'ألغيت الطلب'**
  String get taxiCancelledByYou;

  /// No description provided for @taxiCancelledOther.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي الطلب'**
  String get taxiCancelledOther;

  /// No description provided for @taxiCancelledBody.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك طلب تكسي جديد متى شئت.'**
  String get taxiCancelledBody;

  /// No description provided for @taxiTryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get taxiTryAgain;

  /// No description provided for @taxiPickupPin.
  ///
  /// In ar, this message translates to:
  /// **'مكان الركوب'**
  String get taxiPickupPin;

  /// No description provided for @taxiDropoffPin.
  ///
  /// In ar, this message translates to:
  /// **'مكان النزول'**
  String get taxiDropoffPin;

  /// No description provided for @taxiCarPin.
  ///
  /// In ar, this message translates to:
  /// **'التكسي'**
  String get taxiCarPin;

  /// No description provided for @taxiFollow.
  ///
  /// In ar, this message translates to:
  /// **'تابِع رحلتك'**
  String get taxiFollow;

  /// No description provided for @taxiPlateLabel.
  ///
  /// In ar, this message translates to:
  /// **'اللوحة'**
  String get taxiPlateLabel;
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
