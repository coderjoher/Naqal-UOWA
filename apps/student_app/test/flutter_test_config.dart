import 'dart:async';

import 'package:naql_ui/testing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) => naqlTestExecutable(() async => testMain());
