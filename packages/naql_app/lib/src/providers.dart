import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_core/naql_core.dart';

import 'config.dart';
import 'prefs.dart';
import 'secure_token_store.dart';

/// Overridden in `main()` with the loaded SharedPrefs, and in tests with MemoryPrefs.
final prefsProvider = Provider<Prefs>((ref) => MemoryPrefs());

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: apiBaseUrl(), tokens: ref.watch(tokenStoreProvider));
  ref.onDispose(client.close);
  return client;
});

/// Arabic (RTL) by default, English optional (ST-12). Remembered across launches.
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'naql.lang';

  @override
  Locale build() => Locale(ref.read(prefsProvider).get(_key) == 'en' ? 'en' : 'ar');

  void set(String lang) {
    state = Locale(lang);
    ref.read(prefsProvider).set(_key, lang);
  }

  void toggle() => set(state.languageCode == 'ar' ? 'en' : 'ar');
}

/// The university the user picked during onboarding.
final universitySlugProvider = NotifierProvider<UniversitySlugNotifier, String?>(UniversitySlugNotifier.new);

class UniversitySlugNotifier extends Notifier<String?> {
  static const _key = 'naql.university';

  @override
  String? build() => ref.read(prefsProvider).get(_key);

  void set(String? slug) {
    state = slug;
    ref.read(prefsProvider).set(_key, slug);
  }
}

final universitiesProvider = FutureProvider<List<UniversityInfo>>((ref) => ref.watch(apiProvider).universities());

/// Human message for an API error, falling back to a generic one.
String apiErrorMessage(Object e, String fallback) {
  if (e is ApiException && e.statusCode != 500 && e.message.isNotEmpty) return e.message;
  return fallback;
}
