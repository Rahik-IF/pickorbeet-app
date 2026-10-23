import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the JWT pair in the platform keystore, cached in memory so reads stay synchronous.
class AuthLocalRepository {
  AuthLocalRepository([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  String? _access;
  String? _refresh;

  /// Loads the saved tokens. [clearExisting] drops tokens left in the iOS keychain by a previous
  /// install, which survives an uninstall.
  Future<void> init({bool clearExisting = false}) async {
    try {
      if (clearExisting) {
        await _storage.delete(key: _accessKey);
        await _storage.delete(key: _refreshKey);
        return;
      }
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
    } on PlatformException {
      // An unreadable keystore (for example after a device restore) starts the app signed out.
      _access = null;
      _refresh = null;
    }
  }

  String? getAccessToken() => _access;

  String? getRefreshToken() => _refresh;

  bool get hasSession => (_refresh ?? '').isNotEmpty;

  Future<void> saveSession(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    try {
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
    } on PlatformException {
      // The in-memory session still works for this launch.
    }
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } on PlatformException {
      // Nothing to recover; the cache is already empty.
    }
  }
}
