/// Test helpers shared by naql_ui and the apps: real fonts in goldens and a tolerant comparator.
/// Import only from test code.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads every font in the font manifest (IBM Plex Sans Arabic, Lucide icons) under both its
/// own name and the `packages/naql_ui/` alias used by naql_ui text styles.
Future<void> loadNaqlFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final names = {family, if (!family.startsWith('packages/')) 'packages/naql_ui/$family'};
    for (final name in names) {
      final loader = FontLoader(name);
      for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  }
}

/// Golden comparator tolerating up to 0.5 % differing pixels (anti-aliasing across machines).
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile);

  static const tolerance = 0.005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

/// Call from a package's `test/flutter_test_config.dart`.
Future<void> naqlTestExecutable(Future<void> Function() testMain, {String goldenTestFile = 'golden_test.dart'}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadNaqlFonts();
  final base = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = TolerantGoldenComparator(base.basedir.resolve(goldenTestFile));
  await testMain();
}
