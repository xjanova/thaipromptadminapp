import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';

/// PinManager — hashed-PIN auth ที่ใช้ secure storage (Keychain/Keystore)
///
/// Storage layout:
/// - `pin_salt`: random 16 bytes base64 (per device)
/// - `pin_hash`: sha256(salt + pin)  base64
///
/// Plaintext PIN ไม่ถูกเก็บไว้เลย · brute-force ต้อง break Keystore ก่อน
class PinManager {
  PinManager._();

  /// มี PIN ตั้งไว้ไหม
  Future<bool> hasPin() async {
    final hash = await SecureStorage.readPinHash();
    return hash != null && hash.isNotEmpty;
  }

  /// ตั้ง PIN ใหม่ (overwrite ถ้ามีอยู่แล้ว)
  Future<void> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 8) {
      throw ArgumentError('PIN ต้อง 4-8 หลัก');
    }
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await SecureStorage.writePin(hash, salt);
  }

  /// Verify PIN — true ถ้าตรง
  Future<bool> verifyPin(String pin) async {
    final hash = await SecureStorage.readPinHash();
    final salt = await SecureStorage.readPinSalt();
    if (hash == null || salt == null) return false;
    final candidate = _hash(pin, salt);
    return _constantTimeEquals(candidate, hash);
  }

  /// ลบ PIN (ตอน logout หรือ user disable)
  Future<void> clearPin() => SecureStorage.deletePin();

  // ── Helpers ──

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  String _hash(String pin, String salt) {
    final input = utf8.encode('$salt:$pin');
    return base64Encode(sha256.convert(input).bytes);
  }

  /// constant-time string compare เพื่อกัน timing attack
  /// (CLAUDE.md trap: "String comparison for secrets")
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

final pinManagerProvider = Provider<PinManager>((ref) => PinManager._());
