import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _deviceIdKey = 'device_id';
  static const _trustedKey = 'trusted_device';

  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);
  static Future<String?> getDeviceId() => _storage.read(key: _deviceIdKey);

  static Future<bool> isTrusted() async =>
      await _storage.read(key: _trustedKey) == 'true';

  static Future<void> saveTokens(String token, String refreshToken) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  static Future<void> saveDeviceId(String id) =>
      _storage.write(key: _deviceIdKey, value: id);

  static Future<void> setTrusted(bool trusted) =>
      _storage.write(key: _trustedKey, value: trusted.toString());

  static Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  static Future<void> clearAll() => _storage.deleteAll();
}
