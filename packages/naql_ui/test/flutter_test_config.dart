import 'dart:async';

import 'package:naql_ui/testing.dart';

/// Real fonts in goldens and a tolerant comparator (see lib/testing.dart).
Future<void> testExecutable(FutureOr<void> Function() testMain) => naqlTestExecutable(() async => testMain());
