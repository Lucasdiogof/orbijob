import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _sessionKey = 'orbijob.supabase.session';

/// Auth session persisted in the platform keystore (Android Keystore-wrapped AES, iOS Keychain), not in plain
/// SharedPreferences. On web the browser offers no equivalent: supabase_flutter's default storage is used there.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: _sessionKey)) != null;
  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);
  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);
}

/// PKCE code verifiers (short-lived) also go to the keystore.
class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) => _storage.read(key: key);
  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> removeItem({required String key}) => _storage.delete(key: key);
}
