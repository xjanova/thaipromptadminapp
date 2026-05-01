import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';
import '../data/models/admin_user.dart';

/// Auth state — แทน user ปัจจุบัน + token (ดึงจาก secure storage)
class AuthState {
  AuthState({this.admin, this.loading = false, this.error});

  final AdminUser? admin;
  final bool loading;
  final String? error;

  bool get isAuthenticated => admin != null;

  AuthState copyWith({AdminUser? admin, bool? loading, String? error, bool clearError = false}) =>
      AuthState(
        admin: admin ?? this.admin,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(AuthState());
  final AuthRepository _repo;

  /// เรียกตอนเปิดแอป — ถ้ามี token แล้ว ลอง /me เพื่อ resume session
  Future<void> bootstrap() async {
    final token = await SecureStorage.readToken();
    if (token == null || token.isEmpty) return;

    state = state.copyWith(loading: true);
    try {
      final admin = await _repo.me();
      state = state.copyWith(admin: admin, loading: false, clearError: true);
    } catch (_) {
      // token หมดอายุ → ลบทิ้ง
      await SecureStorage.deleteToken();
      state = AuthState();
    }
  }

  /// Login ด้วย email + password
  /// คืน LoginResult เผื่อ UI จะใช้ navigate ไป 2FA screen
  Future<LoginResult> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final deviceInfo = await _readDeviceInfo();
      final result = await _repo.login(
        email: email,
        password: password,
        deviceId: deviceInfo.$1,
        deviceName: deviceInfo.$2,
      );

      // ถ้าไม่ต้อง 2FA → save token แล้วเซ็ต admin
      if (!result.requiresTwoFactor && result.token != null && result.admin != null) {
        await SecureStorage.writeToken(result.token!);
        state = state.copyWith(admin: result.admin, loading: false);
      } else {
        state = state.copyWith(loading: false);
      }
      return result;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> verifyTwoFactor(String challengeToken, String code) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _repo.verifyTwoFactor(
        challengeToken: challengeToken,
        code: code,
      );
      if (result.token != null && result.admin != null) {
        await SecureStorage.writeToken(result.token!);
        state = state.copyWith(admin: result.admin, loading: false);
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      rethrow;
    }
  }

  Future<PairClaimResult> claimPair(String pairCode, {String? twoFactorCode}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final deviceInfo = await _readDeviceInfo();
      final result = await _repo.claimPair(
        pairCode: pairCode,
        deviceId: deviceInfo.$1,
        deviceName: deviceInfo.$2,
        twoFactorCode: twoFactorCode,
      );
      if (result.token != null && result.admin != null) {
        await SecureStorage.writeToken(result.token!);
        state = state.copyWith(admin: result.admin, loading: false);
      } else {
        state = state.copyWith(loading: false);
      }
      return result;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {
      // ignore — เรา clear local เสมอ
    }
    await SecureStorage.deleteToken();
    state = AuthState();
  }

  /// อ่าน device id (persist) + device name
  Future<(String, String)> _readDeviceInfo() async {
    var deviceId = await SecureStorage.readDeviceId();
    String deviceName = 'Mobile';

    final info = DeviceInfoPlugin();
    final pkg = await PackageInfo.fromPlatform();

    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        deviceId ??= 'android_${a.id}_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = '${a.brand} ${a.model}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        deviceId ??= 'ios_${i.identifierForVendor ?? DateTime.now().millisecondsSinceEpoch}';
        deviceName = '${i.name} (${i.model})';
      } else {
        deviceId ??= 'other_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (_) {
      deviceId ??= 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }

    deviceName = '$deviceName — ${pkg.appName} v${pkg.version}';
    if (deviceId.isNotEmpty) await SecureStorage.writeDeviceId(deviceId);
    return (deviceId, deviceName);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});
