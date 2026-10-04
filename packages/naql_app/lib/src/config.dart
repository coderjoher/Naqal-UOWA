import 'package:flutter/foundation.dart';

/// API base URL. Set at build time with `--dart-define=API_URL=https://api.example/`.
/// Defaults: the web build talks to `/api/` on its own origin (served behind the same nginx);
/// the Android emulator reaches the host machine at 10.0.2.2; desktop/iOS simulator use localhost.
Uri apiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return Uri.parse(fromEnv.endsWith('/') ? fromEnv : '$fromEnv/');
  if (kIsWeb) return Uri.base.resolve('/api/');
  if (defaultTargetPlatform == TargetPlatform.android) return Uri.parse('http://10.0.2.2:3000/');
  return Uri.parse('http://localhost:3000/');
}
