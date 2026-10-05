import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

/// Sentry DSN baked in at build time: `flutter build apk --dart-define=SENTRY_DSN=https://…`.
/// Empty (the default) means crash reporting is off and the app starts exactly as before.
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Starts the app, reporting uncaught Flutter and Dart errors to Sentry when [sentryDsn] is set
/// (P8). Uses the pure-Dart client: no native plugin, so it builds on every platform.
Future<void> runNaqlApp(Widget app, {required String release}) async {
  if (sentryDsn.isEmpty) return runApp(app);
  await Sentry.init((o) => o
    ..dsn = sentryDsn
    ..release = release
    ..environment = const String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'production')
    // No personal data: no IPs or user details.
    ..sendDefaultPii = false
    ..tracesSampleRate = 0);
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    Sentry.captureException(details.exception, stackTrace: details.stack);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return false;
  };
  runApp(app);
}
