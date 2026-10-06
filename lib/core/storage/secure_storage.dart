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
  static const _kPinHash = 'pin_hash';
  static const _kPinSalt = 'pin_salt';
  static const _kBiometricEnabled = 'biometric_enabled';

  static Future<String?> readToken() => _storage.read(key: _kAdminToken);
  static Future<void> writeToken(String token) =>
      _storage.write(key: _kAdminToken, value: token);
  static Future<void> deleteToken() => _storage.delete(key: _kAdminToken);

  static Future<String?> readDeviceId() => _storage.read(key: _kDeviceId);
  static Future<void> writeDeviceId(String id) =>
      _storage.write(key: _kDeviceId, value: id);

  // ── PIN (sha256 + per-device salt, never store plaintext) ──
  static Future<String?> readPinHash() => _storage.read(key: _kPinHash);
  static Future<String?> readPinSalt() => _storage.read(key: _kPinSalt);
  static Future<void> writePin(String hash, String salt) async {
    await _storage.write(key: _kPinHash, value: hash);
    await _storage.write(key: _kPinSalt, value: salt);
  }

  static Future<void> deletePin() async {
    await _storage.delete(key: _kPinHash);
    await _storage.delete(key: _kPinSalt);
    await resetPinFails();
  }

  // ── Biometric ──
  static Future<bool> readBiometricEnabled() async {
    final v = await _storage.read(key: _kBiometricEnabled);
    return v == 'true';
  }

  static Future<void> writeBiometricEnabled(bool enabled) =>
      _storage.write(key: _kBiometricEnabled, value: enabled ? 'true' : 'false');

  // ── ข้อมูลแอดมินล่าสุด (ชื่อ/สิทธิ์) ไว้เปิดแอปตอนออฟไลน์ ──
  static const _kAdminCache = 'admin_profile_cache';
  static Future<String?> readAdminCache() => _storage.read(key: _kAdminCache);
  static Future<void> writeAdminCache(String json) => _storage.write(key: _kAdminCache, value: json);
  static Future<void> deleteAdminCache() => _storage.delete(key: _kAdminCache);

  // ── ตัวนับ PIN ผิด (เก็บถาวร — ปิดแอปเปิดใหม่ตัวนับไม่รีเซ็ต กันเดา PIN ไม่จำกัด) ──
  static const _kPinFails = 'pin_fail_count';
  static const _kPinLockUntil = 'pin_lock_until_ms';

  static Future<int> readPinFails() async =>
      int.tryParse(await _storage.read(key: _kPinFails) ?? '') ?? 0;

  static Future<DateTime?> readPinLockUntil() async {
    final ms = int.tryParse(await _storage.read(key: _kPinLockUntil) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> writePinFails(int count, {DateTime? lockUntil}) async {
    await _storage.write(key: _kPinFails, value: '$count');
    if (lockUntil != null) {
      await _storage.write(key: _kPinLockUntil, value: '${lockUntil.millisecondsSinceEpoch}');
    }
  }

  static Future<void> resetPinFails() async {
    await _storage.delete(key: _kPinFails);
    await _storage.delete(key: _kPinLockUntil);
  }
}

/// token ปัจจุบัน (ใช้แนบหัว Authorization ให้รูปที่ต้องยืนยันตัวตน เช่น สลิป)
final authTokenProvider = FutureProvider<String?>((ref) => SecureStorage.readToken());

final secureStorageProvider =
    Provider<SecureStorage>((ref) => SecureStorage._());
