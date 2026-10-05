import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';

/// DR-08: this month's runs and estimate, and past settlements.
final earningsProvider = FutureProvider.autoDispose<DriverEarnings>((ref) => ref.watch(apiProvider).driverEarnings());
