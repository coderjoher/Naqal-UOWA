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
  String get notifications => 'Notifications';

  @override
  String get noSubscription => 'No subscription';

  @override
  String get noRideToday => 'No ride today';

  @override
  String get noRideTodayBody => 'Daily ride requests are coming soon.';

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
}
