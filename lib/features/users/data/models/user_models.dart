import '../../../../shared/ui/tp_format.dart';

Map<String, dynamic> _m(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};

String? _s(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

/// สมาชิก 1 คน จาก `GET users` / `GET users/{id}` (AdminUserListResource)
class AdminListUser {
  const AdminListUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role,
    this.isSuperAdmin = false,
    this.isBlocked = false,
    this.blockedAt,
    this.phoneVerified = false,
    this.lineVerified = false,
    this.facebookVerified = false,
    this.hasWallet = false,
    this.walletBalance,
    this.walletAddress,
    this.rankId,
    this.rankName,
    this.rankColor,
    this.rankLevel = 0,
    this.referralCode,
    this.city,
    this.country,
    this.createdAt,
    this.lastLoginAt,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? role;
  final bool isSuperAdmin;
  final bool isBlocked;
  final DateTime? blockedAt;
  final bool phoneVerified;
  final bool lineVerified;
  final bool facebookVerified;

  /// backend ส่งก้อน wallet มาหรือไม่ (ไม่มี = สมาชิกยังไม่มีกระเป๋า)
  final bool hasWallet;
  final double? walletBalance;
  final String? walletAddress;
  final int? rankId;
  final String? rankName;

  /// สีระดับจากหลังบ้าน (#RRGGBB) — ใช้เป็นจุดสีเล็ก ๆ เท่านั้น
  final String? rankColor;
  final int rankLevel;
  final String? referralCode;
  final String? city;
  final String? country;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  /// ชื่อที่แสดง (ไม่มีชื่อ → อีเมล → รหัสสมาชิก)
  String get displayName {
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    return 'สมาชิก #$id';
  }

  bool get isAdmin => isSuperAdmin || role == 'admin';

  String? get roleLabel {
    if (isSuperAdmin) return 'ผู้ดูแลสูงสุด';
    if (role == 'admin') return 'แอดมิน';
    return null;
  }

  /// อีเมล · เบอร์ (บรรทัดรองในรายการ)
  String get contactLine => [email, phone].whereType<String>().where((e) => e.isNotEmpty).join(' · ');

  factory AdminListUser.fromJson(Map<String, dynamic> j) {
    // บาง endpoint ห่อ {data:{...}} มาอีกชั้น
    if (!j.containsKey('id') && j['data'] is Map) return AdminListUser.fromJson(_m(j['data']));
    final wallet = j['wallet'];
    final w = _m(wallet);
    final rank = _m(j['rank']);
    final rankName = _s(rank['name']);
    return AdminListUser(
      id: TpFmt.toInt(j['id']),
      name: _s(j['name']) ?? '',
      email: _s(j['email']) ?? '',
      phone: _s(j['phone']),
      avatarUrl: _s(j['avatar_url']),
      role: _s(j['role']),
      isSuperAdmin: _b(j['is_super_admin']),
      isBlocked: _b(j['is_blocked']) || j['blocked_at'] != null,
      blockedAt: TpFmt.parse(j['blocked_at']),
      phoneVerified: _b(j['phone_verified']),
      lineVerified: _b(j['line_verified']),
      facebookVerified: _b(j['facebook_verified']),
      hasWallet: wallet is Map && w['wallet_address'] != null,
      walletBalance: wallet is Map && w.containsKey('balance') ? TpFmt.toDouble(w['balance']) : null,
      walletAddress: _s(w['wallet_address']),
      rankId: rank['id'] == null ? null : TpFmt.toInt(rank['id']),
      rankName: rankName,
      rankColor: _s(rank['color']),
      rankLevel: TpFmt.toInt(rank['level']),
      referralCode: _s(j['referral_code']),
      city: _s(j['city']),
      country: _s(j['country']),
      createdAt: TpFmt.parse(j['created_at']),
      lastLoginAt: TpFmt.parse(j['last_login_at']),
    );
  }
}

/// สรุปจำนวนสมาชิก จาก `GET users/stats`
class UsersStats {
  const UsersStats({
    this.total = 0,
    this.active = 0,
    this.blocked = 0,
    this.admins = 0,
    this.superAdmins = 0,
    this.newToday = 0,
    this.newThisWeek = 0,
    this.newThisMonth,
  });

  final int total;
  final int active;
  final int blocked;
  final int admins;
  final int superAdmins;
  final int newToday;
  final int newThisWeek;

  /// backend ปัจจุบันยังไม่ส่ง (null) — ถ้าส่งมาเมื่อไรหน้าจอจะแสดงเอง
  final int? newThisMonth;

  factory UsersStats.fromJson(Map<String, dynamic> j) => UsersStats(
        total: TpFmt.toInt(j['total']),
        active: TpFmt.toInt(j['active']),
        blocked: TpFmt.toInt(j['blocked']),
        admins: TpFmt.toInt(j['admins']),
        superAdmins: TpFmt.toInt(j['super_admins']),
        newToday: TpFmt.toInt(j['new_today']),
        newThisWeek: TpFmt.toInt(j['new_this_week']),
        newThisMonth: j['new_this_month'] == null ? null : TpFmt.toInt(j['new_this_month']),
      );
}

/// ระดับสมาชิก จาก `GET ranks`
class AdminRank {
  const AdminRank({
    required this.id,
    required this.name,
    this.nameTh,
    this.level = 0,
    this.color,
    this.stars = 0,
    this.commissionRate = 0,
    this.isActive = true,
    this.isTopTier = false,
  });

  final int id;
  final String name;
  final String? nameTh;
  final int level;
  final String? color;
  final int stars;
  final double commissionRate;
  final bool isActive;
  final bool isTopTier;

  String get displayName => (nameTh != null && nameTh!.isNotEmpty) ? nameTh! : name;

  factory AdminRank.fromJson(Map<String, dynamic> j) => AdminRank(
        id: TpFmt.toInt(j['id']),
        name: _s(j['name']) ?? 'ระดับ ${j['level'] ?? ''}'.trim(),
        nameTh: _s(j['name_th']),
        level: TpFmt.toInt(j['level']),
        color: _s(j['color']),
        stars: TpFmt.toInt(j['stars']),
        commissionRate: TpFmt.toDouble(j['commission_rate']),
        isActive: j['is_active'] == null ? true : _b(j['is_active']),
        isTopTier: _b(j['is_top_tier']),
      );
}

/// ประวัติดูดวงของสมาชิก จาก `GET users/{id}/readings`
class UserReading {
  const UserReading({
    required this.id,
    this.questions = const [],
    this.aiModel,
    this.isPaid = false,
    this.pricePaid,
    this.rating,
    this.paidAt,
    this.respondedAt,
    this.createdAt,
  });

  final int id;
  final List<String> questions;
  final String? aiModel;
  final bool isPaid;
  final double? pricePaid;
  final int? rating;
  final DateTime? paidAt;
  final DateTime? respondedAt;
  final DateTime? createdAt;

  String? get firstQuestion => questions.isEmpty ? null : questions.first;

  factory UserReading.fromJson(Map<String, dynamic> j) {
    final raw = j['questions'];
    final qs = <String>[];
    if (raw is List) {
      for (final q in raw) {
        // คำถามเป็น string เป็นหลัก — กันไว้เผื่อบางแถวเป็น {question/text}
        final text = q is Map ? _s(q['question'] ?? q['text']) : _s(q);
        if (text != null) qs.add(text);
      }
    } else if (_s(raw) != null) {
      qs.add(_s(raw)!);
    }
    return UserReading(
      id: TpFmt.toInt(j['id']),
      questions: qs,
      aiModel: _s(j['ai_model']),
      isPaid: _b(j['is_paid']),
      pricePaid: j['price_paid_thb'] == null ? null : TpFmt.toDouble(j['price_paid_thb']),
      rating: j['rating'] == null ? null : TpFmt.toInt(j['rating']),
      paidAt: TpFmt.parse(j['paid_at']),
      respondedAt: TpFmt.parse(j['responded_at']),
      createdAt: TpFmt.parse(j['created_at']),
    );
  }
}

/// สถานะออนไลน์ของแอดมิน จาก `GET users/admins/online`
class AdminPresence {
  const AdminPresence({required this.id, this.isOnline = false, this.lastSeenAt});
  final int id;
  final bool isOnline;
  final DateTime? lastSeenAt;

  factory AdminPresence.fromJson(Map<String, dynamic> j) => AdminPresence(
        id: TpFmt.toInt(j['id']),
        isOnline: _b(j['is_online']),
        lastSeenAt: TpFmt.parse(j['last_seen_at']),
      );
}
