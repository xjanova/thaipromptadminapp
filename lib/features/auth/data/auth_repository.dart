import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/mock/mock_config.dart';
import '../../../core/mock/mock_data.dart';
import 'models/admin_user.dart';

/// Repository ที่ห่อ Admin Auth API endpoints
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  /// Step 1: login ด้วย email + password
  ///
  /// อาจคืน:
  ///  - { requires_2fa: true, challenge_token, expires_in } → ไป verify-2fa
  ///  - { token, admin } → login สำเร็จเลย
  Future<LoginResult> login({
    required String email,
    required String password,
    required String deviceId,
    String? deviceName,
  }) async {
    if (kMockMode) {
      return mockDelay(LoginResult(
        requiresTwoFactor: false,
        token: Mock.token,
        admin: Mock.admin(),
      ));
    }
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        'device_id': deviceId,
        if (deviceName != null) 'device_name': deviceName,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return LoginResult.fromJson(data);
  }

  /// Step 2: ยืนยัน 2FA code → ได้ token + admin
  Future<LoginResult> verifyTwoFactor({
    required String challengeToken,
    required String code,
  }) async {
    if (kMockMode) {
      return mockDelay(LoginResult(
        requiresTwoFactor: false,
        token: Mock.token,
        admin: Mock.admin(),
      ));
    }
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/verify-2fa',
      data: {
        'challenge_token': challengeToken,
        'code': code,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return LoginResult.fromJson(data);
  }

  /// QR Pairing: app ส่ง pair_code ที่สแกนได้
  Future<PairClaimResult> claimPair({
    required String pairCode,
    required String deviceId,
    String? deviceName,
    String? twoFactorCode,
  }) async {
    if (kMockMode) {
      return mockDelay(PairClaimResult(
        requiresTwoFactor: false,
        token: Mock.token,
        admin: Mock.admin(),
      ));
    }
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/pair/claim',
      data: {
        'pair_code': pairCode,
        'device_id': deviceId,
        if (deviceName != null) 'device_name': deviceName,
        if (twoFactorCode != null) 'code': twoFactorCode,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return PairClaimResult.fromJson(data);
  }

  /// ดึงข้อมูล admin ปัจจุบัน
  Future<AdminUser> me() async {
    if (kMockMode) return mockDelay(Mock.admin());
    final data = await _api.get<Map<String, dynamic>>(
      '/auth/me',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return AdminUser.fromJson((data['admin'] as Map).cast<String, dynamic>());
  }

  /// Logout — revoke current token
  Future<void> logout() async {
    if (kMockMode) return;
    await _api.post<dynamic>('/auth/logout');
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthRepository(api);
});
