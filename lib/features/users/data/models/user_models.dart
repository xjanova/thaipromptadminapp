/// User record from /api/admin/users
class AdminListUser {
  AdminListUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role,
    required this.isSuperAdmin,
    required this.isBlocked,
    required this.phoneVerified,
    required this.lineVerified,
    required this.facebookVerified,
    this.walletBalance,
    this.rankName,
    this.rankColor,
    required this.rankLevel,
    this.referralCode,
    this.city,
    this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? role;
  final bool isSuperAdmin;
  final bool isBlocked;
  final bool phoneVerified;
  final bool lineVerified;
  final bool facebookVerified;
  final double? walletBalance;
  final String? rankName;
  final String? rankColor;
  final int rankLevel;
  final String? referralCode;
  final String? city;
  final DateTime? createdAt;

  factory AdminListUser.fromJson(Map<String, dynamic> json) {
    final wallet = (json['wallet'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rank = (json['rank'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AdminListUser(
      id: ((json['id'] as num?) ?? 0).toInt(),
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String?,
      isSuperAdmin: (json['is_super_admin'] as bool?) ?? false,
      isBlocked: (json['is_blocked'] as bool?) ?? false,
      phoneVerified: (json['phone_verified'] as bool?) ?? false,
      lineVerified: (json['line_verified'] as bool?) ?? false,
      facebookVerified: (json['facebook_verified'] as bool?) ?? false,
      walletBalance: (wallet['balance'] as num?)?.toDouble(),
      rankName: rank['name'] as String?,
      rankColor: rank['color'] as String?,
      rankLevel: ((rank['level'] as num?) ?? 0).toInt(),
      referralCode: json['referral_code'] as String?,
      city: json['city'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

/// User stats summary
class UsersStats {
  UsersStats({
    required this.total,
    required this.active,
    required this.blocked,
    required this.admins,
    required this.newToday,
    required this.newThisWeek,
  });

  final int total;
  final int active;
  final int blocked;
  final int admins;
  final int newToday;
  final int newThisWeek;

  factory UsersStats.fromJson(Map<String, dynamic> json) => UsersStats(
        total: ((json['total'] as num?) ?? 0).toInt(),
        active: ((json['active'] as num?) ?? 0).toInt(),
        blocked: ((json['blocked'] as num?) ?? 0).toInt(),
        admins: ((json['admins'] as num?) ?? 0).toInt(),
        newToday: ((json['new_today'] as num?) ?? 0).toInt(),
        newThisWeek: ((json['new_this_week'] as num?) ?? 0).toInt(),
      );
}

class AdminRank {
  AdminRank({
    required this.id,
    required this.name,
    this.nameTh,
    required this.level,
    this.color,
    required this.commissionRate,
    required this.isActive,
    required this.isTopTier,
  });

  final int id;
  final String name;
  final String? nameTh;
  final int level;
  final String? color;
  final double commissionRate;
  final bool isActive;
  final bool isTopTier;

  factory AdminRank.fromJson(Map<String, dynamic> json) => AdminRank(
        id: ((json['id'] as num?) ?? 0).toInt(),
        name: (json['name'] as String?) ?? '',
        nameTh: json['name_th'] as String?,
        level: ((json['level'] as num?) ?? 0).toInt(),
        color: json['color'] as String?,
        commissionRate: ((json['commission_rate'] as num?) ?? 0).toDouble(),
        isActive: (json['is_active'] as bool?) ?? false,
        isTopTier: (json['is_top_tier'] as bool?) ?? false,
      );

  String get displayName => nameTh ?? name;
}
