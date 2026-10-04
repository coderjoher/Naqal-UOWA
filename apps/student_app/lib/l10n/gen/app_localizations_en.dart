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
}
