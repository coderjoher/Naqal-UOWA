// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Naql Jamiat Warith — Driver';

  @override
  String get todayRuns => 'Today\'s runs';

  @override
  String get noRunsToday => 'No runs today';

  @override
  String get noRunsTodayBody =>
      'Your runs and stops will appear here once dispatch is live.';

  @override
  String get tabToday => 'Today';

  @override
  String get tabEarnings => 'Earnings';

  @override
  String get tabProfile => 'Account';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get comingSoonBody => 'This page is under construction.';

  @override
  String get welcomeTitle => 'Drive with university transport';

  @override
  String get welcomeBody =>
      'Register once. After the transport office approves you, your daily runs and stops come to this app.';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get continueLabel => 'Continue';

  @override
  String get chooseUniversity => 'Choose the university';

  @override
  String get chooseUniversityBody =>
      'You will work with this university\'s transport office.';

  @override
  String get loadFailed =>
      'Could not connect. Check your internet and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get phoneTitle => 'Your phone number';

  @override
  String get phoneBody => 'We will text you a sign-in code.';

  @override
  String get phone => 'Mobile number';

  @override
  String get phoneHint => '07XX XXX XXXX';

  @override
  String get sendCode => 'Send code';

  @override
  String get invalidPhone => 'Enter a valid Iraqi mobile number';

  @override
  String get waitMinute => 'Wait a minute before requesting a new code';

  @override
  String get codeTitle => 'Verification code';

  @override
  String codeBody(String phone) {
    return 'Enter the code sent to $phone';
  }

  @override
  String get code => 'Code';

  @override
  String get verify => 'Confirm';

  @override
  String get wrongCode => 'The code is wrong or has expired';

  @override
  String testCode(String code) {
    return 'Test environment — code: $code';
  }

  @override
  String get applyTitle => 'Registration';

  @override
  String get applyBody =>
      'Complete your details and documents, then send them to the transport office for review.';

  @override
  String progress(int done, int total) {
    return '$done of $total complete';
  }

  @override
  String get sectionDriver => 'Driver';

  @override
  String get sectionVehicle => 'Vehicle';

  @override
  String get sectionDocuments => 'Documents';

  @override
  String get fullName => 'Full name';

  @override
  String get vehicleType => 'Vehicle type';

  @override
  String get plate => 'Plate number';

  @override
  String get seats => 'Passenger seats';

  @override
  String get modelYear => 'Model year';

  @override
  String get saveInfo => 'Save details';

  @override
  String get saved => 'Saved';

  @override
  String get saveFailed => 'Could not save';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get fromGallery => 'From gallery';

  @override
  String get uploaded => 'Uploaded';

  @override
  String get notUploaded => 'Required';

  @override
  String get optional => 'Optional';

  @override
  String get uploading => 'Uploading…';

  @override
  String get uploadFailed => 'Could not upload the file';

  @override
  String get submit => 'Send for review';

  @override
  String get incomplete => 'Complete the required fields and documents first';

  @override
  String get coaster => 'Coaster';

  @override
  String get minibus => 'Minibus';

  @override
  String get bus => 'Large bus';

  @override
  String get van => 'Van';

  @override
  String get statusPendingTitle => 'Your application is being reviewed';

  @override
  String get statusPendingBody =>
      'The transport office will check your details and documents. You will be notified when approved.';

  @override
  String get statusRejectedTitle => 'Application not accepted';

  @override
  String get statusRejectedBody =>
      'Read the reason, correct your details and send the application again.';

  @override
  String get statusSuspendedTitle => 'Your account is suspended';

  @override
  String get statusSuspendedBody =>
      'You cannot run trips for now. Contact the transport office.';

  @override
  String get reason => 'Reason';

  @override
  String get editApplication => 'Edit application';

  @override
  String get refresh => 'Refresh status';

  @override
  String get signOut => 'Sign out';
}
