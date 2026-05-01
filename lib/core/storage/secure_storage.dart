import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Secure storage wrapper สำหรับ token + sensitive data
///
/// ใช้ Keychain (iOS) / Keystore (Android) — ห้ามใช้ SharedPreferences กับ token
class SecureStorage {
  SecureStorage._();

  static final _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys
  static const _kAdminToken = 'admin_api_token';
  static const _kDeviceId = 'device_id';

  static Future<String?> readToken() => _storage.read(key: _kAdminToken);
  static Future<void> writeToken(String token) =>
      _storage.write(key: _kAdminToken, value: token);
  static Future<void> deleteToken() => _storage.delete(key: _kAdminToken);

  static Future<String?> readDeviceId() => _storage.read(key: _kDeviceId);
  static Future<void> writeDeviceId(String id) =>
      _storage.write(key: _kDeviceId, value: id);
}

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage._());
