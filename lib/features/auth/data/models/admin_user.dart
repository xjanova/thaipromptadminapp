/// Admin user model — รับมาจาก /api/admin/auth/login response
///
/// ใช้ manual JSON parsing เพื่อความตรงไปตรงมา (ไม่ต้อง code-gen)
class AdminUser {
  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role,
    required this.isSuperAdmin,
    required this.permissions,
    required this.twoFactorEnabled,
    this.rankName,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? role;
  final bool isSuperAdmin;
  final List<String> permissions;
  final bool twoFactorEnabled;
  final String? rankName;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final twoFactor = (json['two_factor'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rank = (json['rank'] as Map?)?.cast<String, dynamic>() ?? const {};
    final perms = (json['permissions'] as List?) ?? const [];
    return AdminUser(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String?,
      isSuperAdmin: (json['is_super_admin'] as bool?) ?? false,
      permissions: perms.map((e) => e.toString()).toList(),
      twoFactorEnabled: (twoFactor['enabled'] as bool?) ?? false,
      rankName: rank['name'] as String?,
    );
  }

  /// สิทธิ์ "*" หมายถึง super admin (ทำได้ทุกอย่าง)
  bool can(String permission) =>
      isSuperAdmin || permissions.contains('*') || permissions.contains(permission);
}

/// ผลลัพธ์ของ login (อาจจะต้อง 2FA หรือได้ token เลย)
class LoginResult {
  LoginResult({
    required this.requiresTwoFactor,
    this.token,
    this.admin,
    this.challengeToken,
    this.challengeExpiresInSec,
  });

  final bool requiresTwoFactor;
  final String? token;
  final AdminUser? admin;
  final String? challengeToken;
  final int? challengeExpiresInSec;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final requires = (json['requires_2fa'] as bool?) ?? false;
    final adminJson = (json['admin'] as Map?)?.cast<String, dynamic>();
    return LoginResult(
      requiresTwoFactor: requires,
      token: json['token'] as String?,
      admin: adminJson != null ? AdminUser.fromJson(adminJson) : null,
      challengeToken: json['challenge_token'] as String?,
      challengeExpiresInSec: (json['expires_in'] as num?)?.toInt(),
    );
  }
}

/// ผลลัพธ์ของ pair claim (อาจจะต้อง 2FA ก่อน)
class PairClaimResult {
  PairClaimResult({
    required this.requiresTwoFactor,
    this.token,
    this.admin,
  });

  final bool requiresTwoFactor;
  final String? token;
  final AdminUser? admin;

  factory PairClaimResult.fromJson(Map<String, dynamic> json) {
    final adminJson = (json['admin'] as Map?)?.cast<String, dynamic>();
    return PairClaimResult(
      requiresTwoFactor: (json['requires_2fa'] as bool?) ?? false,
      token: json['token'] as String?,
      admin: adminJson != null ? AdminUser.fromJson(adminJson) : null,
    );
  }
}
