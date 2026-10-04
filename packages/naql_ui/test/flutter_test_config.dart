import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file in this package:
///  * loads the real fonts (IBM Plex Sans Arabic + Lucide icons) so goldens show real glyphs
///    instead of the Ahem test font;
///  * installs a golden comparator that tolerates tiny anti-aliasing differences between
///    machines (CI vs. local), but still fails on any visible change.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFonts();
  final base = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _TolerantComparator(base.basedir.resolve('golden_test.dart'));
  await testMain();
}

Future<void> _loadFonts() async {
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

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  /// Max share of differing pixels (0.5 %).
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
