import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../storage/secure_storage.dart';

/// BiometricService — wrapper รอบ local_auth สำหรับ fingerprint/face/device auth
class BiometricService {
  BiometricService._();

  final _auth = LocalAuthentication();

  /// device รองรับ biometric หรือไม่ (มี sensor + setup แล้ว)
  Future<bool> isSupported() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final available = await _auth.canCheckBiometrics;
      return available;
    } on PlatformException {
      return false;
    }
  }

  /// รายการ biometric ที่ใช้ได้ (สำหรับโชว์ icon ที่ตรง: fingerprint/face/iris)
  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  /// User เปิดใช้ biometric ใน app settings แล้ว (เก็บใน secure storage)
  Future<bool> isEnabled() => SecureStorage.readBiometricEnabled();

  Future<void> setEnabled(bool enabled) =>
      SecureStorage.writeBiometricEnabled(enabled);

  /// Prompt biometric — return true ถ้า user auth สำเร็จ
  /// ใช้ตอน login + ก่อนกลับเข้าแอพ (PIN gate)
  Future<bool> authenticate({
    String reason = 'ยืนยันตัวตนเพื่อเข้าใช้ Thaiprompt Admin',
    bool biometricOnly = false,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          // useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}

final biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService._());
