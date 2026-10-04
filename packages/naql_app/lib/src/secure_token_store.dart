import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:naql_core/naql_core.dart';

/// Keeps the access token in the platform keystore (Keychain / Android Keystore).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  static const _key = 'naql.token';
  String? _cache;
  bool _loaded = false;

  @override
  Future<String?> read() async {
    if (!_loaded) {
      _cache = await _s.read(key: _key);
      _loaded = true;
    }
    return _cache;
  }

  @override
  Future<void> write(String? token) async {
    _cache = token;
    _loaded = true;
    if (token == null) {
      await _s.delete(key: _key);
    } else {
      await _s.write(key: _key, value: token);
    }
  }
}
