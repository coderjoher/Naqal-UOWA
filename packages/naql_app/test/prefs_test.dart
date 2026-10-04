import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_app/naql_app.dart';

void main() {
  test('language and university are remembered in prefs', () {
    final prefs = MemoryPrefs();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    expect(c.read(localeProvider).languageCode, 'ar');
    c.read(localeProvider.notifier).toggle();
    c.read(universitySlugProvider.notifier).set('warith');
    final c2 = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(localeProvider).languageCode, 'en');
    expect(c2.read(universitySlugProvider), 'warith');
  });
}
