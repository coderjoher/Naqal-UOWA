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
}
