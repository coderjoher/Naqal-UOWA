import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry DSN baked in at build time: `flutter build apk --dart-define=SENTRY_DSN=https://…`.
/// Empty (the default) means crash reporting is off and the app starts exactly as before.
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Starts the app, reporting uncaught errors to Sentry when [sentryDsn] is set (P8).
Future<void> runNaqlApp(Widget app, {required String release}) async {
  if (sentryDsn.isEmpty) return runApp(app);
  await SentryFlutter.init(
    (o) => o
      ..dsn = sentryDsn
      ..release = release
      ..environment = const String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'production')
      // No personal data: no IPs, no user details, no screenshots of what students see.
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..tracesSampleRate = 0,
    appRunner: () => runApp(app),
  );
}
