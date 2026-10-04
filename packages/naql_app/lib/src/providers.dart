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
  final custom = ref.watch(serverUrlProvider);
  final client = ApiClient(baseUrl: custom == null ? apiBaseUrl() : Uri.parse(custom), tokens: ref.watch(tokenStoreProvider));
  ref.onDispose(client.close);
  return client;
});

/// Server address chosen in a demo build (null = the built-in default).
final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String?>(ServerUrlNotifier.new);

class ServerUrlNotifier extends Notifier<String?> {
  static const _key = 'naql.server';

  @override
  String? build() => demoBuild ? ref.read(prefsProvider).get(_key) : null;

  /// Accepts "192.168.1.20", "192.168.1.20:3000" or a full URL; returns false if it is not usable.
  bool set(String? input) {
    final v = normalizeServerUrl(input);
    if (input != null && input.trim().isNotEmpty && v == null) return false;
    state = v;
    ref.read(prefsProvider).set(_key, v);
    return true;
  }
}

String? normalizeServerUrl(String? input) {
  var s = input?.trim() ?? '';
  if (s.isEmpty) return null;
  // A bare host means the API port on that computer; a full URL is taken as given.
  final bare = !s.contains('://');
  if (bare) s = 'http://$s';
  final u = Uri.tryParse(s);
  if (u == null || u.host.isEmpty || !(u.scheme == 'http' || u.scheme == 'https')) return null;
  final withPort = bare && !u.hasPort ? u.replace(port: 3000) : u;
  final path = withPort.path.endsWith('/') ? withPort.path : '${withPort.path}/';
  return withPort.replace(path: path).toString();
}

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

/// Realtime feed for the signed-in user (Socket.IO). Tests override it with a fake.
final liveFeedProvider = FutureProvider.autoDispose<LiveFeed?>((ref) async {
  final token = await ref.watch(tokenStoreProvider).read();
  if (token == null) return null;
  final custom = ref.watch(serverUrlProvider);
  final feed = SocketLiveFeed(apiBase: custom == null ? apiBaseUrl() : Uri.parse(custom), token: token);
  ref.onDispose(feed.dispose);
  return feed;
});
