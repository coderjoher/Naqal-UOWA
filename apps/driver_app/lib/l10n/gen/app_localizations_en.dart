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

  @override
  String get taxi => 'Taxi';

  @override
  String get taxiTitle => 'Campus taxi';

  @override
  String get taxiOnline => 'You\'re online';

  @override
  String get taxiOffline => 'You\'re offline';

  @override
  String get taxiOnlineHint => 'Ride requests near you will show here';

  @override
  String get taxiOfflineHint => 'Tap to start getting rides';

  @override
  String get taxiGoOnline => 'Go online';

  @override
  String get taxiGoOffline => 'Go offline';

  @override
  String get taxiConnecting => 'Connecting…';

  @override
  String get taxiWaitingTitle => 'Waiting for requests';

  @override
  String get taxiWaitingBody => 'Keep the app open. New requests appear here.';

  @override
  String get taxiOfflineTitle => 'You won\'t get requests now';

  @override
  String get taxiOfflineBody =>
      'Go online to get ride requests from students near you.';

  @override
  String get taxiToCampus => 'To campus';

  @override
  String get taxiFromCampus => 'From campus';

  @override
  String taxiTripKm(String km) {
    return '$km km trip';
  }

  @override
  String taxiAwayKm(String km) {
    return '$km km away';
  }

  @override
  String get taxiAccept => 'Accept';

  @override
  String taxiSecondsLeft(int seconds) {
    return '$seconds seconds left';
  }

  @override
  String get taxiNewRequest => 'New request';

  @override
  String get taxiTaken => 'Another driver took this ride.';

  @override
  String get taxiNoLocation => 'Turn on location to go online.';

  @override
  String get taxisOff => 'The office has switched taxis off for now.';

  @override
  String get taxiStudentCancelled => 'The student cancelled the ride.';

  @override
  String get taxiFailed => 'Couldn\'t connect. Try again.';

  @override
  String get taxiDismiss => 'Dismiss';

  @override
  String get taxiGoToStudent => 'Go to the student';

  @override
  String get taxiGoToGate => 'Go to the campus gate';

  @override
  String get taxiWaitingStudent => 'Waiting for the student';

  @override
  String get taxiOnTripCampus => 'On the way to campus';

  @override
  String get taxiOnTripHome => 'On the way to the student\'s place';

  @override
  String taxiStep(int n) {
    return 'Step $n of 3';
  }

  @override
  String get taxiCall => 'Call';

  @override
  String taxiCallStudent(String name) {
    return 'Call $name';
  }

  @override
  String get taxiArrived => 'I\'ve arrived';

  @override
  String get taxiStartTrip => 'Start trip';

  @override
  String taxiEndTrip(String amount) {
    return 'End trip & collect $amount';
  }

  @override
  String taxiEndConfirmTitle(String amount) {
    return 'Did you collect $amount in cash?';
  }

  @override
  String get taxiEndConfirmBody =>
      'The fare is recorded to you when the trip ends.';

  @override
  String get taxiEndConfirmYes => 'Yes, I collected it';

  @override
  String get taxiNotYet => 'Not yet';

  @override
  String get taxiCancelRide => 'Cancel ride';

  @override
  String get taxiCancelConfirmTitle => 'Cancel this ride?';

  @override
  String get taxiCancelConfirmBody => 'The request goes back to other drivers.';

  @override
  String get taxiCancelYes => 'Yes, cancel ride';

  @override
  String get taxiKeepRide => 'Keep the ride';

  @override
  String get taxiFare => 'Cash fare';

  @override
  String get taxiDistance => 'Distance';

  @override
  String taxiKm(String km) {
    return '$km km';
  }

  @override
  String get taxiDoneTitle => 'Trip done';

  @override
  String get taxiDoneBody => 'The cash is recorded to you.';

  @override
  String get taxiBackToRequests => 'Back to requests';

  @override
  String get taxiMonthTitle => 'Taxi trips this month';

  @override
  String taxiMonthSummary(int trips, String amount) {
    return '$trips trips · $amount';
  }

  @override
  String get taxiRecent => 'Recent taxi trips';

  @override
  String get taxiNoTrips => 'No taxi trips yet';

  @override
  String get taxiStatusDone => 'Done';

  @override
  String get taxiStatusCancelled => 'Cancelled';

  @override
  String get taxiStatusActive => 'In progress';

  @override
  String get taxiCashCollected => 'Cash collected';

  @override
  String get accountApproved => 'Approved';

  @override
  String get accountVehicle => 'Your vehicle';

  @override
  String get accountFromOffice => 'Approved by the transport office';

  @override
  String get accountChangeHint =>
      'To change your vehicle details, contact the transport office.';

  @override
  String get accountNotSet => 'Not set';

  @override
  String get accountDocuments => 'Documents';

  @override
  String accountDocumentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents uploaded',
      one: '1 document uploaded',
      zero: 'No documents uploaded',
    );
    return '$_temp0';
  }

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountSignOutTitle => 'Sign out?';

  @override
  String get accountSignOutBody =>
      'You will need a new code sent to your phone to sign in again.';

  @override
  String get accountStay => 'Stay signed in';

  @override
  String get accountDocumentsHint =>
      'The documents the transport office asked for. To update one, contact the office.';

  @override
  String get accountDocUploaded => 'Uploaded';

  @override
  String get accountDocMissing => 'Missing';

  @override
  String get accountClose => 'Close';

  @override
  String get greetMorning => 'Good morning';

  @override
  String get greetEvening => 'Good evening';

  @override
  String get tabHome => 'Home';

  @override
  String get kpiTaxiToday => 'Today\'s trips';

  @override
  String get kpiCash => 'Cash';

  @override
  String get kpiMonth => 'This month';

  @override
  String get kpiRiders => 'Today\'s riders';

  @override
  String get taxiOnlineSub => 'Nearby taxi requests reach you · tap to stop';

  @override
  String get watermarkOn => 'ON';

  @override
  String get taxiSkipOffer => 'Skip this request';

  @override
  String taxiOfferLine(String direction, String km) {
    return '$direction · $km km';
  }

  @override
  String get nextRunTitle => 'Your next run';

  @override
  String get laterToday => 'Later today';

  @override
  String runRidersCount(int n) {
    return '$n riders';
  }

  @override
  String stopOfTotal(int n, String total) {
    return 'Stop $n of $total';
  }

  @override
  String riderCash(String amount) {
    return '$amount cash';
  }

  @override
  String distanceM(String m) {
    return '$m m';
  }

  @override
  String distanceKmShort(String km) {
    return '$km km';
  }

  @override
  String headTo(String place) {
    return 'Head to $place';
  }

  @override
  String leaveAt(String time) {
    return 'Leave at $time';
  }

  @override
  String arriveAround(String time) {
    return 'Arrive around $time';
  }

  @override
  String get ridersHere => 'Riders at this stop';

  @override
  String get noRidersHere => 'No riders at this stop';

  @override
  String get studentCaption => 'Student';

  @override
  String get pickupPlace => 'Pickup';

  @override
  String get dropoffPlace => 'Drop-off';

  @override
  String get openNavigation => 'Open navigation';

  @override
  String runProgress(String done, String total) {
    return '$done of $total stops served';
  }
}
