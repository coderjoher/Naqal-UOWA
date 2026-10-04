import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// [T2-05] Every key in ar.arb exists in en.arb and vice versa, and no screen hard-codes
/// user-facing text (all copy goes through AppLocalizations).
void main() {
  Map<String, dynamic> arb(String lang) => jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
  Set<String> keys(Map<String, dynamic> m) => m.keys.where((k) => !k.startsWith('@')).toSet();

  test('[T2-05] ar.arb and en.arb have the same keys and no empty values', () {
    final ar = arb('ar');
    final en = arb('en');
    expect(keys(ar).difference(keys(en)), isEmpty, reason: 'missing in en');
    expect(keys(en).difference(keys(ar)), isEmpty, reason: 'missing in ar');
    for (final k in keys(ar)) {
      expect((ar[k] as String).trim(), isNotEmpty, reason: 'ar.$k');
      expect((en[k] as String).trim(), isNotEmpty, reason: 'en.$k');
    }
  });

  test('[T2-05] no hard-coded user-facing strings in lib/', () {
    // Text('…'), label: '…', title: '…', message: '…', hint: '…', semanticLabel: '…' with letters.
    final pattern = RegExp(r"(Text\(|label:\s*|title:\s*|message:\s*|hint:\s*|semanticLabel:\s*|subtitle:\s*)'[^'$]*[A-Za-z\u0600-\u06FF][^']*'");
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('l10n/gen')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
