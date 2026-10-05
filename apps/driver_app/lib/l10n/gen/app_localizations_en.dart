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
      'Set the days you drive in Schedule; your runs appear here once buses are assigned.';

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

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get scheduleTitle => 'When will you drive?';

  @override
  String get scheduleBody =>
      'Pick the waves you will drive this week. A wave locks once buses are assigned.';

  @override
  String get dayToday => 'Today';

  @override
  String get dayTomorrow => 'Tomorrow';

  @override
  String get waveMorning => 'To campus';

  @override
  String get waveReturn => 'Home';

  @override
  String waveLabel(String type, String time) {
    return '$type $time';
  }

  @override
  String get noWavesDay => 'No waves on this day';

  @override
  String get lockedWave => 'Locked — buses assigned';

  @override
  String get availabilityFailed => 'Could not save your schedule';

  @override
  String runSeats(int booked, int capacity) {
    return '$booked of $capacity seats';
  }

  @override
  String runStops(int count) {
    return '$count stops';
  }

  @override
  String get departAt => 'Leave at';

  @override
  String get cashToCollect => 'Cash to collect';

  @override
  String get femaleOnly => 'Female only';

  @override
  String riders(int count) {
    return 'Riders: $count';
  }

  @override
  String get campus => 'Campus';

  @override
  String arriveBy(String time) {
    return 'Arrive by $time';
  }

  @override
  String get leaveCampus => 'Leave campus';

  @override
  String get subscriber => 'Subscriber';

  @override
  String payCash(String amount) {
    return '$amount cash';
  }

  @override
  String get setSchedule => 'Set your schedule';

  @override
  String get stopsTitle => 'Stops';

  @override
  String get seatsLabel => 'Seats';

  @override
  String get startRun => 'Start run';

  @override
  String get leaveCampusNow => 'Leave campus';

  @override
  String get boardAtCampus => 'Mark who got on at campus';

  @override
  String get nextStop => 'Next stop';

  @override
  String get atStop => 'At the stop';

  @override
  String get imHere => 'I\'m at the stop';

  @override
  String get navigate => 'Navigate';

  @override
  String get navGoogle => 'Google Maps';

  @override
  String get navWaze => 'Waze';

  @override
  String get boardHint => 'Tap a rider as they get on';

  @override
  String get onBoard => 'On board';

  @override
  String get noShowLabel => 'No-show';

  @override
  String get waiting => 'Waiting';

  @override
  String get departStop => 'Leave stop';

  @override
  String departMissing(int n) {
    return 'Leave — $n no-show';
  }

  @override
  String waitLeft(String time) {
    return 'Wait $time for latecomers';
  }

  @override
  String collectFare(String amount) {
    return 'Got $amount';
  }

  @override
  String get paidLabel => 'Paid';

  @override
  String get arrivedCampus => 'Arrived at campus';

  @override
  String get finishRun => 'Finish run';

  @override
  String get runDone => 'Run finished';

  @override
  String get runDoneBody => 'Thank you! The run is recorded.';

  @override
  String pendingSync(int n) {
    return '$n waiting to send';
  }

  @override
  String get dropOff => 'Drop-off';

  @override
  String get endTitleMorning => 'Head to campus';

  @override
  String get endTitleReturn => 'Everyone is dropped off';

  @override
  String earningsTitle(String month) {
    return 'Earnings for $month';
  }

  @override
  String get earningsEstimate => 'Estimated payout so far';

  @override
  String get earningsApproved => 'Amount approved by the office';

  @override
  String get earningsDraft => 'Being reviewed by the office';

  @override
  String get earningsHint =>
      'Based on your GPS-verified runs and your share of the tier\'s subscriptions after commission, minus the commission on cash fares.';

  @override
  String get earningsRuns => 'Runs counted';

  @override
  String get earningsCash => 'Cash you collected';

  @override
  String get earningsCashCommission => 'Commission on cash';

  @override
  String earningsFlagged(String count) {
    return '$count runs whose track did not verify — the office will review them';
  }

  @override
  String get earningsRunsTitle => 'This month\'s runs';

  @override
  String get earningsNoRuns => 'No runs this month yet';

  @override
  String get earningsCounted => 'Counted';

  @override
  String get earningsNotCounted => 'Not counted';

  @override
  String get earningsPending => 'Not finished';

  @override
  String get earningsPast => 'Past settlements';

  @override
  String earningsPastRuns(String runs) {
    return '$runs runs';
  }

  @override
  String get earningsOwe => 'You owe the office';
}
