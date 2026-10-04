import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPrefs.load();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const DriverApp()));
}
