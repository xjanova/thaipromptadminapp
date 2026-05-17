/// Fortune Dashboard summary — from /api/admin/fortune/dashboard
class FortuneDashboardData {
  FortuneDashboardData({
    required this.monthlyRevenueThb,
    required this.sessionsCount,
    required this.avgRating,
    required this.activeNow,
    required this.services,
  });

  final double monthlyRevenueThb;
  final int sessionsCount;
  final double avgRating;
  final int activeNow;
  final List<FortuneService> services;

  factory FortuneDashboardData.fromJson(Map<String, dynamic> json) {
    final hero = (json['hero'] as Map?)?.cast<String, dynamic>() ?? const {};
    final svcs = (json['services_summary'] as List?) ?? const [];
    return FortuneDashboardData(
      monthlyRevenueThb: ((hero['monthly_revenue_thb'] as num?) ?? 0).toDouble(),
      sessionsCount: ((hero['sessions_count'] as num?) ?? 0).toInt(),
      avgRating: ((hero['avg_rating'] as num?) ?? 0).toDouble(),
      activeNow: ((hero['active_now'] as num?) ?? 0).toInt(),
      services: svcs
          .whereType<Map>()
          .map((m) => FortuneService.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class FortuneService {
  FortuneService({
    required this.id,
    required this.name,
    required this.slug,
    required this.color,
    this.icon,
    required this.sessions,
    required this.revenueThb,
    required this.isActive,
  });

  final int id;
  final String name;
  final String slug;
  final String color;
  final String? icon;
  final int sessions;
  final double revenueThb;
  final bool isActive;

  factory FortuneService.fromJson(Map<String, dynamic> json) => FortuneService(
        id: ((json['id'] as num?) ?? 0).toInt(),
        name: (json['name'] as String?) ?? '',
        slug: (json['slug'] as String?) ?? '',
        color: (json['color'] as String?) ?? '#a855f7',
        icon: json['icon'] as String?,
        sessions: ((json['sessions'] as num?) ?? 0).toInt(),
        revenueThb: ((json['revenue_thb'] as num?) ?? 0).toDouble(),
        isActive: (json['is_active'] as bool?) ?? false,
      );

  /// hex color → int (สำหรับ Color)
  int get colorHex {
    final c = color.replaceAll('#', '');
    if (c.length == 6) return int.parse('FF$c', radix: 16);
    if (c.length == 8) return int.parse(c, radix: 16);
    return 0xFFA855F7;
  }
}

/// Fortune Reading record
class FortuneReading {
  FortuneReading({
    required this.id,
    this.userName,
    required this.facebookUserName,
    required this.questions,
    this.aiResponse,
    required this.isPaid,
    required this.amountPaid,
    required this.responseType,
    required this.readingType,
    this.aiProvider,
    this.aiModel,
    this.rating,
    required this.viewCount,
    this.createdAt,
  });

  final int id;
  final String? userName;
  final String facebookUserName;
  final List<dynamic> questions;
  final String? aiResponse;
  final bool isPaid;
  final double amountPaid;
  final String responseType;
  final String readingType;
  final String? aiProvider;
  final String? aiModel;
  final int? rating;
  final int viewCount;
  final DateTime? createdAt;

  factory FortuneReading.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ai = (json['ai'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FortuneReading(
      id: ((json['id'] as num?) ?? 0).toInt(),
      userName: user['name'] as String?,
      facebookUserName: (json['facebook_user_name'] as String?) ?? '—',
      questions: (json['questions'] as List?) ?? const [],
      aiResponse: json['ai_response'] as String?,
      isPaid: (json['is_paid'] as bool?) ?? false,
      amountPaid: ((json['amount_paid'] as num?) ?? 0).toDouble(),
      responseType: (json['response_type'] as String?) ?? 'pending',
      readingType: (json['reading_type'] as String?) ?? 'basic',
      aiProvider: ai['provider'] as String?,
      aiModel: ai['model'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      viewCount: ((json['view_count'] as num?) ?? 0).toInt(),
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }

  String get questionPreview {
    if (questions.isEmpty) return '(ไม่มีคำถาม)';
    final first = questions.first.toString();
    return first.length > 80 ? '${first.substring(0, 80)}...' : first;
  }
}

/// Bill record from /api/admin/fortune/bills
///
/// Backend format อิงจาก brain notes (FTU-260517-R3092):
/// - tier: 'celtic' (99฿) | 'deep' (39฿) | 'tarot_chat'
/// - status: pending_payment → paid → confirmed → reading_started → reading_done
///   หรือ rejected / refunded
class FortuneBill {
  FortuneBill({
    required this.id,
    required this.billNumber,
    required this.tier,
    required this.status,
    required this.customerName,
    required this.platform,
    this.platformUserId,
    required this.amountThb,
    required this.feeThb,
    required this.netThb,
    this.paymentMethod,
    this.slipImageUrl,
    this.questionPreview,
    this.readingId,
    this.createdAt,
    this.paidAt,
    this.confirmedAt,
    this.rejectReason,
  });

  final int id;
  final String billNumber;
  final String tier;
  final String status;
  final String customerName;
  final String platform; // 'line' | 'facebook' | 'fb_messenger'
  final String? platformUserId;
  final double amountThb;
  final double feeThb;
  final double netThb;
  final String? paymentMethod;
  final String? slipImageUrl;
  final String? questionPreview;
  final int? readingId;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final DateTime? confirmedAt;
  final String? rejectReason;

  factory FortuneBill.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FortuneBill(
      id: ((json['id'] as num?) ?? 0).toInt(),
      billNumber: (json['bill_number'] as String?) ?? '',
      tier: (json['tier'] as String?) ?? 'deep',
      status: (json['status'] as String?) ?? 'pending_payment',
      customerName: (user['name'] as String?) ?? (json['customer_name'] as String?) ?? '—',
      platform: (json['platform'] as String?) ?? 'line',
      platformUserId: json['platform_user_id'] as String?,
      amountThb: ((json['amount_thb'] as num?) ?? 0).toDouble(),
      feeThb: ((json['fee_thb'] as num?) ?? 0).toDouble(),
      netThb: ((json['net_thb'] as num?) ?? 0).toDouble(),
      paymentMethod: json['payment_method'] as String?,
      slipImageUrl: json['slip_image_url'] as String?,
      questionPreview: json['question_preview'] as String?,
      readingId: (json['reading_id'] as num?)?.toInt(),
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      paidAt: DateTime.tryParse((json['paid_at'] as String?) ?? ''),
      confirmedAt: DateTime.tryParse((json['confirmed_at'] as String?) ?? ''),
      rejectReason: json['reject_reason'] as String?,
    );
  }

  String get tierLabel => switch (tier) {
        'celtic' => 'Celtic 99฿',
        'deep' => 'Deep 39฿',
        'tarot_chat' => 'Tarot Chat',
        _ => tier,
      };

  /// hue for tier theming
  double get tierHue => switch (tier) {
        'celtic' => 320, // pink/magenta (premium)
        'deep' => 270, // purple
        'tarot_chat' => 200, // cyan
        _ => 220,
      };

  bool get isPending => status == 'pending_payment';
  bool get isPaid => status == 'paid';
  bool get isConfirmed =>
      status == 'confirmed' || status == 'reading_started' || status == 'reading_done';
  bool get isRejected => status == 'rejected';
  bool get isRefunded => status == 'refunded';

  /// elapsed time since createdAt (for "X mins ago" display)
  Duration get elapsed =>
      createdAt == null ? Duration.zero : DateTime.now().difference(createdAt!);
}

/// Stats for bills hero (รออนุมัติ N · approved วันนี้ N · revenue ฿N)
class FortuneBillStats {
  FortuneBillStats({
    required this.pendingCount,
    required this.paidUnconfirmedCount,
    required this.confirmedTodayCount,
    required this.todayRevenueThb,
    required this.rejectedTodayCount,
  });

  final int pendingCount;
  final int paidUnconfirmedCount;
  final int confirmedTodayCount;
  final double todayRevenueThb;
  final int rejectedTodayCount;

  factory FortuneBillStats.fromJson(Map<String, dynamic> json) => FortuneBillStats(
        pendingCount: ((json['pending_count'] as num?) ?? 0).toInt(),
        paidUnconfirmedCount:
            ((json['paid_unconfirmed_count'] as num?) ?? 0).toInt(),
        confirmedTodayCount:
            ((json['confirmed_today_count'] as num?) ?? 0).toInt(),
        todayRevenueThb: ((json['today_revenue_thb'] as num?) ?? 0).toDouble(),
        rejectedTodayCount:
            ((json['rejected_today_count'] as num?) ?? 0).toInt(),
      );
}
