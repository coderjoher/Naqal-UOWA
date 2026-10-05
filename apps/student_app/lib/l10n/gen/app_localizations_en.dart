// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Naql Jamiat Warith';

  @override
  String get hello => 'Welcome';

  @override
  String helloName(String name) {
    return 'Hello, $name';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get noSubscription => 'No subscription';

  @override
  String get noRideToday => 'No ride today';

  @override
  String get noRideTodayBody =>
      'Ask for a seat on today\'s or tomorrow\'s bus.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabTrips => 'My trips';

  @override
  String get tabAlerts => 'Alerts';

  @override
  String get tabProfile => 'Account';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get comingSoonBody => 'This page is under construction.';

  @override
  String get welcomeTitle => 'Your daily ride to campus';

  @override
  String get welcomeBody =>
      'Request a seat every day, follow your bus on the map and know when it arrives.';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get continueLabel => 'Continue';

  @override
  String get chooseUniversity => 'Choose your university';

  @override
  String get chooseUniversityBody =>
      'You will sign in with your university account.';

  @override
  String get loadFailed =>
      'Could not connect. Check your internet and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get studentNumber => 'Student number';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInFailed => 'Student number or password is incorrect';

  @override
  String get firstTime => 'First time? Activate with the office code';

  @override
  String get activateTitle => 'Activate your account';

  @override
  String get activateBody =>
      'Enter the code the transport office gave you, then choose a password.';

  @override
  String get activationCode => 'Activation code';

  @override
  String get newPassword => 'New password';

  @override
  String get passwordHint => 'At least 8 characters';

  @override
  String get activate => 'Activate and sign in';

  @override
  String get activateFailed =>
      'The code is wrong or has expired. Ask the transport office for a new one.';

  @override
  String get changeUniversity => 'Change university';

  @override
  String get choosePointTitle => 'Gathering point';

  @override
  String get choosePointBody =>
      'Pick the point closest to you. You board the bus there every day, and your subscription price follows its tier.';

  @override
  String get searchPoints => 'Search points';

  @override
  String tierLabel(String tier) {
    return 'Tier $tier';
  }

  @override
  String kmAway(String km) {
    return '$km km from campus';
  }

  @override
  String get savePoint => 'Use this point';

  @override
  String get noPoints => 'No gathering points yet';

  @override
  String get noPointsBody => 'The transport office will add them soon.';

  @override
  String get yourPoint => 'Your gathering point';

  @override
  String get change => 'Change';

  @override
  String get profileTitle => 'Account';

  @override
  String get personalInfo => 'Personal information';

  @override
  String get name => 'Name';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get fromUniversity => 'From university records, cannot be changed';

  @override
  String get phone => 'Phone number';

  @override
  String get phoneHint => '07XX XXX XXXX';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get saveFailed => 'Could not save';

  @override
  String get invalidPhone => 'Enter a valid Iraqi mobile number';

  @override
  String get language => 'Language';

  @override
  String get signOut => 'Sign out';

  @override
  String get defaultPoint => 'Gathering point';

  @override
  String get notSet => 'Not set';

  @override
  String get subActive => 'Subscription active';

  @override
  String subExpiring(int days) {
    return 'Ends in $days days';
  }

  @override
  String get subExpired => 'Subscription ended';

  @override
  String get subNone => 'No subscription';

  @override
  String subUntil(String date) {
    return 'Until $date';
  }

  @override
  String get subMonthly => 'Monthly subscription';

  @override
  String subTierPrice(String tier, String price) {
    return 'Tier $tier · $price';
  }

  @override
  String get subPayAtOffice =>
      'Pay in cash at the transport office and your subscription is active immediately.';

  @override
  String get subRenew => 'Renew at the transport office before it ends.';

  @override
  String subNext(String month) {
    return 'Next month is paid: $month';
  }

  @override
  String get subUnlimited => 'Unlimited rides and seat priority';

  @override
  String subTier(String tier) {
    return 'Tier $tier';
  }

  @override
  String get rideRequest => 'Request a ride';

  @override
  String get rideRequestTitle => 'Request a ride';

  @override
  String get rideRequestBody =>
      'Pick a time and a gathering point and we will find you a seat.';

  @override
  String get rideWhen => 'When';

  @override
  String get rideWhere => 'Gathering point';

  @override
  String get rideToday => 'Today';

  @override
  String get rideTomorrow => 'Tomorrow';

  @override
  String get rideMorning => 'To campus';

  @override
  String get rideReturn => 'Home';

  @override
  String rideSlot(String day, String type, String time) {
    return '$day · $type $time';
  }

  @override
  String get rideNoSlots => 'No times are open today or tomorrow.';

  @override
  String get rideSend => 'Send request';

  @override
  String get rideSent => 'Request sent';

  @override
  String get rideConfirmed => 'Confirmed';

  @override
  String get rideCampus => 'Campus';

  @override
  String rideStopOf(String n, String total) {
    return 'Stop $n of $total';
  }

  @override
  String ridePayDriver(String amount) {
    return 'Pay $amount cash to the driver';
  }

  @override
  String get rideCovered => 'Covered by your subscription';

  @override
  String get rideCancel => 'Cancel request';

  @override
  String get rideCancelTitle => 'Cancel this request?';

  @override
  String get rideCancelBody => 'Your seat will go to another student.';

  @override
  String get rideCancelYes => 'Yes, cancel';

  @override
  String get rideKeep => 'No, keep it';

  @override
  String get rideCancelled => 'Request cancelled';

  @override
  String get ridePendingTitle => 'Request received';

  @override
  String get ridePendingBody =>
      'Buses are assigned an hour before departure. We will tell you your bus.';

  @override
  String get rideWaitTitle => 'You are on the waitlist';

  @override
  String get rideWaitBody =>
      'All seats are taken right now. We will seat you as soon as one frees up.';

  @override
  String get rideWaitLeft => 'Time left';

  @override
  String rideExpired(String time) {
    return 'No seat was found for the $time ride. You can request another time.';
  }

  @override
  String rideWave(String day, String type, String time) {
    return '$day · $type $time';
  }

  @override
  String get rideFemaleOnly => 'Female only';

  @override
  String get trackBus => 'Track the bus';

  @override
  String get trackTitle => 'Your bus';

  @override
  String etaMinutes(int n) {
    return 'Arrives in $n min';
  }

  @override
  String get etaNow => 'The bus is at your stop';

  @override
  String get onBus => 'You are on the bus';

  @override
  String get notStarted => 'The bus has not left yet';

  @override
  String updatedAgo(String time) {
    return 'Updated $time ago';
  }

  @override
  String get lastKnown => 'Last known position';

  @override
  String agoSeconds(int n) {
    return '$n s';
  }

  @override
  String agoMinutes(int n) {
    return '$n min';
  }

  @override
  String get yourStop => 'Your stop';

  @override
  String get busLabel => 'The bus';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get noNotificationsBody =>
      'News about your seat and bus will appear here.';

  @override
  String get nAssignedTitle => 'Your seat is confirmed';

  @override
  String get nAssignedBody => 'See your bus and pickup time.';

  @override
  String get nWaitlistedTitle => 'You are on the waitlist';

  @override
  String get nWaitlistedBody => 'We will tell you as soon as a seat frees up.';

  @override
  String get nBumpedTitle => 'Moved to the waitlist';

  @override
  String get nBumpedBody =>
      'Your seat went to a subscriber. We will seat you when one frees up.';

  @override
  String get nApproachingTitle => 'Your bus is close';

  @override
  String nApproachingBody(int n) {
    return 'About $n minutes to your stop.';
  }

  @override
  String get nArrivedTitle => 'Your bus is here';

  @override
  String get nArrivedBody => 'The bus is at your gathering point now.';

  @override
  String get nExpiredTitle => 'No seat found';

  @override
  String get nExpiredBody =>
      'The waiting time ended and the request was cancelled.';

  @override
  String get nCancelledTitle => 'Ride cancelled';

  @override
  String get nCancelledBody => 'Your ride request was cancelled.';

  @override
  String get historyRides => 'Rides';

  @override
  String get historyPayments => 'Payments';

  @override
  String get historyNoRides => 'No past rides';

  @override
  String get historyNoRidesBody => 'Your rides appear here once they are over.';

  @override
  String get historyNoPayments => 'No payments yet';

  @override
  String get historyNoPaymentsBody =>
      'Everything you paid for a subscription or to a driver shows here.';

  @override
  String get historyEnd => 'Nothing older';

  @override
  String get historyDone => 'Done';

  @override
  String get historyNoShow => 'Missed the bus';

  @override
  String get historyCancelled => 'Cancelled';

  @override
  String get historyExpired => 'No seat';

  @override
  String get historyMissed => 'Did not happen';

  @override
  String get rateRide => 'Rate the ride';

  @override
  String get rateTitle => 'How was the ride?';

  @override
  String get rateBody =>
      'Your rating goes to the transport office and helps improve the service.';

  @override
  String get rateComment => 'Comment (optional)';

  @override
  String get rateSend => 'Send rating';

  @override
  String get rateThanks => 'Thanks for your rating';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get reportProblemHint =>
      'Your report goes straight to the transport office';

  @override
  String get problemTitle => 'What went wrong?';

  @override
  String get problemBody =>
      'Pick the kind of problem and tell us what happened. The transport office will answer.';

  @override
  String get problemLate => 'Late';

  @override
  String get problemDriver => 'Driver';

  @override
  String get problemVehicle => 'Vehicle';

  @override
  String get problemSafety => 'Safety';

  @override
  String get problemApp => 'App';

  @override
  String get problemOther => 'Other';

  @override
  String get problemText => 'What happened?';

  @override
  String get problemSend => 'Send report';

  @override
  String get problemSent => 'Your report reached the transport office';

  @override
  String get paySubscription => 'Monthly subscription';

  @override
  String paySubscriptionMonth(String month) {
    return 'Subscription $month';
  }

  @override
  String get payTierDifference => 'Tier difference';

  @override
  String get payCashFare => 'Ride fare (cash)';

  @override
  String payReversal(String what) {
    return 'Reversed: $what';
  }

  @override
  String payReceipt(int no) {
    return 'Receipt $no';
  }

  @override
  String get nMovedTitle => 'Your bus changed';

  @override
  String get nMovedBody =>
      'The transport office moved you to another bus. Open Home for details.';

  @override
  String get nAnsweredTitle => 'The transport office answered your report';

  @override
  String get dismiss => 'Dismiss';
}
