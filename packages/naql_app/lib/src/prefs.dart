import 'package:shared_preferences/shared_preferences.dart';

/// Small key/value store for non-secret preferences (language, chosen university).
abstract interface class Prefs {
  String? get(String key);
  Future<void> set(String key, String? value);
}

class SharedPrefs implements Prefs {
  SharedPrefs(this._p);
  final SharedPreferences _p;

  static Future<SharedPrefs> load() async => SharedPrefs(await SharedPreferences.getInstance());

  @override
  String? get(String key) => _p.getString(key);

  @override
  Future<void> set(String key, String? value) async {
    if (value == null) {
      await _p.remove(key);
    } else {
      await _p.setString(key, value);
    }
  }
}

class MemoryPrefs implements Prefs {
  MemoryPrefs([Map<String, String>? initial]) : _m = {...?initial};
  final Map<String, String> _m;

  @override
  String? get(String key) => _m[key];

  @override
  Future<void> set(String key, String? value) async => value == null ? _m.remove(key) : _m[key] = value;
}
