import '../../features/ai/data/ai_repository.dart' show TimeseriesPoint;
import '../../features/ai/data/models/ai_models.dart';
import '../../features/analytics/data/analytics_repository.dart';
import '../../features/auth/data/models/admin_user.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/finance/data/finance_repository.dart';
import '../../features/fortune/data/models/ai_pool_models.dart';
import '../../features/fortune/data/models/chat_models.dart';
import '../../features/fortune/data/models/fortune_models.dart';
import '../../features/marketplace/data/marketplace_repository.dart';
import '../../features/users/data/models/user_models.dart';

/// Fixture data ตามคอนเซป design handoff — ใช้แทน backend response เมื่อ kMockMode = true
///
/// ค่าตัวเลขอ้างอิงจาก screens-*.jsx (รายได้ 882k, sessions 6.7k, tokens 28.6M ฯลฯ)
class Mock {
  Mock._();

  // ────────────────────────────────────────────────────────────
  // Stateful overrides — make toggles & mutations actually persist
  // visually across `ref.invalidate(...)` re-fetches in the same session.
  // ────────────────────────────────────────────────────────────

  /// providerId → isActive override (absent = ใช้ค่า default จาก fixture)
  static final Map<int, bool> _providerActiveOverride = {};

  /// botId → isActive override
  static final Map<int, bool> _botActiveOverride = {};

  /// withdrawalId → new status (ใช้ตอน approve/reject)
  static final Map<int, String> _withdrawalStatusOverride = {};

  /// billId → new fortune bill status (approve/reject/refund)
  static final Map<int, String> _billStatusOverride = {};
  static final Map<int, String> _billRejectReasonOverride = {};

  /// activeReadingId → true means admin took over (badge in UI)
  static final Set<int> _adminTakenOverReadings = {};

  /// activeReadingId → true means cancelled (removed from list)
  static final Set<int> _cancelledReadings = {};

  /// serviceId → patched fields (active/price/payFirst/persona/color/prompt)
  static final Map<int, Map<String, dynamic>> _servicePatches = {};

  /// keyId → patched AI Pool fields
  static final Map<int, Map<String, dynamic>> _aiKeyPatches = {};
  static String _aiPoolGlobalMode = 'priority';

  /// readingId → takeover until (sets `takeover_active` status)
  static final Map<int, DateTime> _takeoverUntil = {};

  /// readingId → list of appended admin messages
  static final Map<int, List<Map<String, dynamic>>> _adminMessages = {};

  /// readingId → resumed (admin sent /ai) — clears takeover state
  static final Set<int> _resumedReadings = {};

  // ────────────────────────────────────────────────────────────
  // Toggle helpers (called from mocked repository methods)
  // ────────────────────────────────────────────────────────────

  static bool _resolveProviderActive(int id, bool defaultValue) =>
      _providerActiveOverride[id] ?? defaultValue;
  static bool _resolveBotActive(int id, bool defaultValue) =>
      _botActiveOverride[id] ?? defaultValue;
  static String _resolveWithdrawalStatus(int id, String defaultValue) =>
      _withdrawalStatusOverride[id] ?? defaultValue;

  /// flip provider active state — เรียกจาก AiRepository.toggleProvider เมื่อ kMockMode
  static void flipProvider(int id) {
    final list = aiProviders();
    final cur = list.firstWhere((p) => p.id == id, orElse: () => list.first);
    _providerActiveOverride[id] = !cur.isActive;
  }

  /// flip bot active state
  static void flipBot(int id) {
    final page = aiBots();
    final cur =
        page.items.firstWhere((b) => b.id == id, orElse: () => page.items.first);
    _botActiveOverride[id] = !cur.isActive;
  }

  /// อัพเดทสถานะ withdrawal (approve/reject)
  static void setWithdrawalStatus(int id, String status) {
    _withdrawalStatusOverride[id] = status;
  }

  /// อัพเดทสถานะ fortune bill (approve/reject/refund)
  static void setBillStatus(int id, String status, {String? rejectReason}) {
    _billStatusOverride[id] = status;
    if (rejectReason != null && rejectReason.isNotEmpty) {
      _billRejectReasonOverride[id] = rejectReason;
    }
  }

  static void markAdminTakeover(int readingId) {
    _adminTakenOverReadings.add(readingId);
  }

  static void cancelActiveReading(int readingId) {
    _cancelledReadings.add(readingId);
  }

  static void toggleFortuneService(int id) {
    final cur = _servicePatches[id] ?? {};
    final base = _fortuneServicesBase().firstWhere(
      (m) => m['id'] == id,
      orElse: () => {'is_active': true},
    );
    final currentActive = cur['is_active'] ?? base['is_active'] ?? true;
    _servicePatches[id] = {...cur, 'is_active': !(currentActive as bool)};
  }

  static void patchFortuneService(int id, FortuneServicePatch patch) {
    final cur = _servicePatches[id] ?? {};
    _servicePatches[id] = {...cur, ...patch.toJson()};
  }

  // ── AI Pool mutators ──
  static void setAiPoolGlobalMode(String mode) {
    _aiPoolGlobalMode = mode;
  }

  static void toggleAiKey(int id) {
    final cur = _aiKeyPatches[id] ?? {};
    final base = _aiPoolKeysBase().firstWhere(
      (m) => m['id'] == id,
      orElse: () => {'is_active': true},
    );
    final curActive = cur['is_active'] ?? base['is_active'] ?? true;
    _aiKeyPatches[id] = {...cur, 'is_active': !(curActive as bool)};
  }

  static void patchAiKey(int id, AiKeyPatch patch) {
    final cur = _aiKeyPatches[id] ?? {};
    _aiKeyPatches[id] = {...cur, ...patch.toJson()};
  }

  // ── Takeover mutators ──
  static void startTakeover(int readingId, int minutes) {
    _takeoverUntil[readingId] =
        DateTime.now().add(Duration(minutes: minutes));
    _resumedReadings.remove(readingId);
  }

  static void extendTakeover(int readingId, int minutes) {
    final current = _takeoverUntil[readingId] ?? DateTime.now();
    final base =
        current.isAfter(DateTime.now()) ? current : DateTime.now();
    _takeoverUntil[readingId] = base.add(Duration(minutes: minutes));
  }

  static void resumeAi(int readingId) {
    _takeoverUntil.remove(readingId);
    _resumedReadings.add(readingId);
    // System message: takeover ended
    appendSystemMessage(readingId, 'Admin คืนการควบคุมให้ AI · /ai resumed',
        kind: 'takeover_ended');
  }

  static void appendAdminMessage(int readingId, String text) {
    final list = _adminMessages.putIfAbsent(readingId, () => []);
    list.add({
      'id': 9000 + (readingId * 100) + list.length,
      'reading_id': readingId,
      'sender': 'admin',
      'admin_name': 'แม่หมอ',
      'text': text,
      'at': DateTime.now().toIso8601String(),
    });
  }

  static void appendSystemMessage(int readingId, String text,
      {String kind = 'note'}) {
    final list = _adminMessages.putIfAbsent(readingId, () => []);
    list.add({
      'id': 9000 + (readingId * 100) + list.length,
      'reading_id': readingId,
      'sender': 'system',
      'text': text,
      'at': DateTime.now().toIso8601String(),
      'is_system': true,
      'system_kind': kind,
    });
  }

  /// Returns true on (simulated) test pass — sets last_test_passed_at to now
  static bool testAiKey(int id) {
    // pseudo-random success: even-id always passes, odd-id has 60% pass rate
    final success = id.isEven || (id * 7 % 10) >= 4;
    final cur = _aiKeyPatches[id] ?? {};
    if (success) {
      _aiKeyPatches[id] = {
        ...cur,
        'last_test_passed_at': DateTime.now().toIso8601String(),
      };
    } else {
      _aiKeyPatches[id] = {
        ...cur,
        'last_test_error_at': DateTime.now().toIso8601String(),
      };
    }
    return success;
  }

  // ────────────────────────────────────────────────────────────
  // Auth
  // ────────────────────────────────────────────────────────────

  static const String token = 'mock-admin-token-thaiprompt';

  static AdminUser admin() => AdminUser.fromJson({
        'id': 1,
        'name': 'กฤษณะ ภัทรกุล',
        'email': 'admin@thaiprompt.com',
        'phone': '+66 81 234 5678',
        'avatar_url': null,
        'role': 'super_admin',
        'is_super_admin': true,
        'permissions': ['*'],
        'two_factor': {'enabled': true},
        'rank': {'name': 'Super Admin'},
      });

  // ────────────────────────────────────────────────────────────
  // Dashboard
  // ────────────────────────────────────────────────────────────

  static DashboardData dashboard() => DashboardData.fromJson({
        'hero': {
          'monthly_revenue': 12840000,
          'last_month_revenue': 10300000,
          'revenue_growth_pct': 24.6,
        },
        'stats': {
          'total_users': 2847,
          'new_users_today': 28,
          'orders_total': 14230,
          'orders_pending': 86,
          'pending_withdrawals': 12,
        },
        'sparkline': [
          for (int i = 0; i < 14; i++)
            {
              'date': '2026-05-${(i + 4).toString().padLeft(2, '0')}',
              'count': 80 + (i * 6) + (i.isEven ? 12 : -8),
              'total': 380000.0 + (i * 14500) + (i.isEven ? 35000 : -22000),
            }
        ],
        'quick_actions': {
          'approvals': 24,
          'withdrawals': 12,
          'kyc_pending': 8,
        },
      });

  // ────────────────────────────────────────────────────────────
  // Users
  // ────────────────────────────────────────────────────────────

  static UsersStats userStats() => UsersStats.fromJson({
        'total': 2847,
        'active': 2710,
        'blocked': 38,
        'admins': 8,
        'new_today': 28,
        'new_this_week': 184,
      });

  static PagedResult<AdminListUser> users() {
    final names = [
      ['สมชาย ใจดี', 'somchai@gmail.com', 1, 'Gold', '#fbbf24', 24800.0],
      ['Lisa Anderson', 'lisa.a@thaiprompt.com', 3, 'Platinum', '#e0e7ff', 184200.0],
      ['ภาคิน ทรัพย์ทวี', 'pakin@line.me', 2, 'Silver', '#cbd5e1', 8420.0],
      ['Mei Wong', 'mei.wong@hk.com', 4, 'Diamond', '#22d3ee', 412800.0],
      ['ปนัดดา วงศ์สุข', 'panadda@thaiprompt.com', 1, 'Gold', '#fbbf24', 6280.0],
      ['Carlos Rivera', 'carlos.r@gmail.com', 2, 'Silver', '#cbd5e1', 14200.0],
      ['ธนพล อิ่มสุข', 'thanapol@gmail.com', 0, null, null, 0.0],
      ['Yuki Tanaka', 'yuki.t@jp.com', 3, 'Platinum', '#e0e7ff', 92400.0],
    ];
    return PagedResult.fromJson<AdminListUser>(
      {
        'data': [
          for (int i = 0; i < names.length; i++)
            {
              'id': 100 + i,
              'name': names[i][0],
              'email': names[i][1],
              'phone': '+66 8${(i + 1)} ${(1000 + i * 137) % 9000} ${(2000 + i * 91) % 9000}',
              'avatar_url': null,
              'role': i == 1 ? 'admin' : 'user',
              'is_super_admin': false,
              'is_blocked': i == 6,
              'phone_verified': i != 6,
              'line_verified': i.isEven,
              'facebook_verified': i % 3 == 0,
              'wallet': {'balance': names[i][5]},
              'rank': names[i][3] == null
                  ? null
                  : {
                      'name': names[i][3],
                      'color': names[i][4],
                      'level': names[i][2],
                    },
              'referral_code': 'TP${(10000 + i * 137)}',
              'city': i.isEven ? 'กรุงเทพ' : 'เชียงใหม่',
              'created_at': '2026-04-${(20 - i).toString().padLeft(2, '0')}T10:00:00Z',
            },
        ],
        'current_page': 1,
        'last_page': 12,
        'total': 2847,
      },
      AdminListUser.fromJson,
    );
  }

  static List<AdminRank> ranks() => [
        AdminRank.fromJson({
          'id': 1,
          'name': 'Starter',
          'name_th': 'สมาชิกเริ่มต้น',
          'level': 0,
          'color': '#94a3b8',
          'commission_rate': 0.03,
          'is_active': true,
          'is_top_tier': false,
        }),
        AdminRank.fromJson({
          'id': 2,
          'name': 'Silver',
          'name_th': 'ซิลเวอร์',
          'level': 2,
          'color': '#cbd5e1',
          'commission_rate': 0.06,
          'is_active': true,
          'is_top_tier': false,
        }),
        AdminRank.fromJson({
          'id': 3,
          'name': 'Gold',
          'name_th': 'โกลด์',
          'level': 1,
          'color': '#fbbf24',
          'commission_rate': 0.09,
          'is_active': true,
          'is_top_tier': false,
        }),
        AdminRank.fromJson({
          'id': 4,
          'name': 'Platinum',
          'name_th': 'แพลตินั่ม',
          'level': 3,
          'color': '#e0e7ff',
          'commission_rate': 0.12,
          'is_active': true,
          'is_top_tier': true,
        }),
        AdminRank.fromJson({
          'id': 5,
          'name': 'Diamond',
          'name_th': 'ไดมอนด์',
          'level': 4,
          'color': '#22d3ee',
          'commission_rate': 0.15,
          'is_active': true,
          'is_top_tier': true,
        }),
      ];

  // ────────────────────────────────────────────────────────────
  // Finance
  // ────────────────────────────────────────────────────────────

  static PagedResult<AdminWallet> wallets() {
    return PagedResult.fromJson<AdminWallet>(
      {
        'data': [
          for (int i = 0; i < 8; i++)
            {
              'id': 200 + i,
              'wallet_address': 'WL-${(70000 + i * 1313)}',
              'balance': 1200.0 + i * 8420 + (i.isEven ? 1820 : -540),
              'total_income': 22800.0 + i * 11200,
              'total_expense': 8400.0 + i * 6400,
              'status': i == 5 ? 'suspended' : 'active',
              'is_active': i != 5,
              'is_locked': i == 5,
              'user': {
                'name': [
                  'สมชาย ใจดี',
                  'Lisa Anderson',
                  'ภาคิน ทรัพย์ทวี',
                  'Mei Wong',
                  'ปนัดดา วงศ์สุข',
                  'Carlos Rivera',
                  'ธนพล อิ่มสุข',
                  'Yuki Tanaka',
                ][i],
                'email': 'user$i@thaiprompt.com',
                'avatar_url': null,
              },
            },
        ],
        'current_page': 1,
        'last_page': 8,
        'total': 438,
      },
      AdminWallet.fromJson,
    );
  }

  static PagedResult<AdminWithdrawal> withdrawals({String? status}) {
    final defaultStatuses = ['pending', 'pending', 'approved', 'completed', 'rejected', 'pending'];
    final all = [
      for (int i = 0; i < 6; i++)
        {
          'id': 300 + i,
          'request_id': 'WR-${(40000 + i * 1731)}',
          'amount': 2000.0 + i * 1400,
          'net_amount': 2000.0 + i * 1400 - 30,
          'fee': 30.0,
          'status': _resolveWithdrawalStatus(300 + i, defaultStatuses[i]),
          'payment_type': ['bank', 'promptpay', 'bank', 'bank', 'promptpay', 'bank'][i],
          'created_at': '2026-05-${(17 - i).toString().padLeft(2, '0')}T12:00:00Z',
          'user': {
            'name': [
              'สมชาย ใจดี',
              'Lisa Anderson',
              'ภาคิน ทรัพย์ทวี',
              'Mei Wong',
              'ปนัดดา วงศ์สุข',
              'ธนพล อิ่มสุข',
            ][i],
            'email': 'user$i@thaiprompt.com',
            'avatar_url': null,
          },
        }
    ];
    final filtered = status == null ? all : all.where((m) => m['status'] == status).toList();
    return PagedResult.fromJson<AdminWithdrawal>(
      {
        'data': filtered,
        'current_page': 1,
        'last_page': 1,
        'total': filtered.length,
      },
      AdminWithdrawal.fromJson,
    );
  }

  // ────────────────────────────────────────────────────────────
  // Fortune
  // ────────────────────────────────────────────────────────────

  /// Base service list (เปลี่ยน static เมื่อต้องเพิ่ม service)
  static List<Map<String, dynamic>> _fortuneServicesBase() => [
        {
          'id': 1,
          'name': 'ไพ่ทาโรต์ AI',
          'slug': 'tarot',
          'color': '#a855f7',
          'icon': null,
          'sessions': 2840,
          'revenue_thb': 384000,
          'is_active': true,
          'price_thb': 39.0,
          'pay_first': true,
          'persona_name': 'แม่หมอลัคกี้',
          'ai_purpose': 'prediction_deep',
          'tier': 'deep',
          'system_prompt':
              'คุณคือแม่หมอลัคกี้ ผู้มีประสบการณ์ดูไพ่ทาโรต์มากกว่า 20 ปี ใช้ภาษาไทยอบอุ่น เน้นให้กำลังใจ',
        },
        {
          'id': 2,
          'name': 'โหราศาสตร์ไทย',
          'slug': 'astrology',
          'color': '#0ea5e9',
          'icon': null,
          'sessions': 1820,
          'revenue_thb': 218000,
          'is_active': true,
          'price_thb': 59.0,
          'pay_first': true,
          'persona_name': 'อาจารย์ดวงดี',
          'ai_purpose': 'prediction_deep',
          'tier': 'deep',
          'system_prompt':
              'คุณคืออาจารย์ดวงดี โหรเก่าแก่ ใช้หลักโหราศาสตร์ไทยดั้งเดิม ตอบเป็นภาษาทางการ',
        },
        {
          'id': 3,
          'name': 'Celtic Cross VIP',
          'slug': 'celtic-cross',
          'color': '#ec4899',
          'icon': null,
          'sessions': 412,
          'revenue_thb': 184000,
          'is_active': true,
          'price_thb': 99.0,
          'pay_first': true,
          'persona_name': 'Madam Celeste',
          'ai_purpose': 'prediction_celtic',
          'tier': 'celtic',
          'system_prompt':
              'You are Madam Celeste, expert in Celtic Cross 10-card spread. Provide deep, structured analysis covering past/present/future/influences.',
        },
        {
          'id': 4,
          'name': 'ลายมือ AI',
          'slug': 'palm-reading',
          'color': '#f97316',
          'icon': null,
          'sessions': 920,
          'revenue_thb': 62000,
          'is_active': true,
          'price_thb': 19.0,
          'pay_first': false,
          'persona_name': 'หมอชะตา',
          'ai_purpose': 'vision',
          'tier': 'tarot_chat',
          'system_prompt':
              'คุณคือหมอชะตา ดูลายมือผ่านภาพถ่าย ใช้หลักกายภาพประกอบจิตวิทยา',
        },
        {
          'id': 5,
          'name': 'ราศี 12 ปี',
          'slug': 'zodiac',
          'color': '#ef4444',
          'icon': null,
          'sessions': 520,
          'revenue_thb': 0,
          'is_active': true,
          'price_thb': null,
          'pay_first': false,
          'persona_name': 'ครูดวง',
          'ai_purpose': 'chat',
          'tier': null,
          'system_prompt':
              'คุณคือครูดวง อธิบายดวงตามปีนักษัตร 12 ปี ตอบสั้นกระชับ ฟรีสำหรับลูกค้าใหม่',
        },
        {
          'id': 6,
          'name': 'I-Ching',
          'slug': 'iching',
          'color': '#22c55e',
          'icon': null,
          'sessions': 208,
          'revenue_thb': 34000,
          'is_active': false,
          'price_thb': 29.0,
          'pay_first': true,
          'persona_name': 'Master Wei',
          'ai_purpose': 'prediction_deep',
          'tier': 'deep',
          'system_prompt': 'You are Master Wei, expert in I-Ching divination.',
        },
      ];

  /// Apply overrides จาก _servicePatches แล้วคืน base list
  static List<Map<String, dynamic>> _fortuneServicesWithPatches() {
    return _fortuneServicesBase().map((m) {
      final id = m['id'] as int;
      final patch = _servicePatches[id];
      if (patch == null) return m;
      return {...m, ...patch};
    }).toList();
  }

  static FortuneDashboardData fortuneDashboard() => FortuneDashboardData.fromJson({
        'hero': {
          'monthly_revenue_thb': 882000,
          'sessions_count': 6720,
          'avg_rating': 4.86,
          'active_now': 142,
        },
        'services_summary': _fortuneServicesWithPatches(),
      });

  static PagedResult<FortuneReading> fortuneReadings() {
    final qs = [
      'จะเจอเนื้อคู่เมื่อไหร่คะ?',
      'ปีนี้จะได้เลื่อนตำแหน่งไหม',
      'การเงินช่วงนี้เป็นยังไง?',
      'จะย้ายงานดีไหม?',
      'ความสัมพันธ์กับแฟนจะดีขึ้นไหม',
      'ธุรกิจใหม่จะรอดไหม?',
    ];
    return PagedResult.fromJson<FortuneReading>(
      {
        'data': [
          for (int i = 0; i < qs.length; i++)
            {
              'id': 500 + i,
              'user': {'name': i.isEven ? 'สมหญิง ${i + 1}' : null},
              'facebook_user_name': 'Anonymous Seeker',
              'questions': [qs[i]],
              'ai_response': 'ดวงเดือนนี้กำลังเปิดทางด้านการเงิน...',
              'is_paid': i % 3 != 0,
              'amount_paid': i % 3 != 0 ? 99.0 + i * 50 : 0.0,
              'response_type': ['completed', 'completed', 'pending', 'completed', 'error', 'completed'][i],
              'reading_type': i.isEven ? 'deep' : 'basic',
              'ai': {'provider': 'OpenAI', 'model': 'gpt-4o'},
              'rating': i % 3 == 0 ? null : 4 + (i % 2),
              'view_count': 12 + i * 3,
              'created_at': '2026-05-17T${(8 + i).toString().padLeft(2, '0')}:30:00Z',
            }
        ],
        'current_page': 1,
        'last_page': 6,
        'total': 480,
      },
      FortuneReading.fromJson,
    );
  }

  // ────────────────────────────────────────────────────────────
  // Fortune Bills (อนุมัติบิล)
  // อ้างอิงรูปแบบจริง: FTU-YYMMDD-R{readingId} (Celtic 99 / Deep 39)
  // ────────────────────────────────────────────────────────────

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  static List<Map<String, dynamic>> _fortuneBillsRaw() {
    final now = DateTime.now();
    final dateTag = '${now.year.toString().substring(2)}${_pad2(now.month)}${_pad2(now.day)}';
    return [
      // 4 pending payment (รอลูกค้าจ่าย)
      {
        'id': 901,
        'bill_number': 'FTU-$dateTag-R3092',
        'tier': 'celtic',
        'status': 'pending_payment',
        'amount_thb': 99.0,
        'fee_thb': 0.0,
        'net_thb': 99.0,
        'payment_method': 'promptpay',
        'slip_image_url': null,
        'question_preview': 'จะเจอเนื้อคู่ปีนี้ไหมคะ? อยากรู้รายละเอียดด้วย',
        'reading_id': 3092,
        'created_at':
            now.subtract(const Duration(minutes: 3)).toIso8601String(),
        'user': {'name': 'พลอย จันทรา'},
        'platform': 'line',
        'platform_user_id': 'U44425abec76f4458ef731274a056212d',
      },
      {
        'id': 902,
        'bill_number': 'FTU-$dateTag-R3091',
        'tier': 'deep',
        'status': 'pending_payment',
        'amount_thb': 39.0,
        'fee_thb': 0.0,
        'net_thb': 39.0,
        'payment_method': 'promptpay',
        'slip_image_url': null,
        'question_preview': 'งานใหม่จะดีกว่าเดิมไหม?',
        'reading_id': 3091,
        'created_at':
            now.subtract(const Duration(minutes: 8)).toIso8601String(),
        'user': {'name': 'สมชาย ใจดี'},
        'platform': 'facebook',
      },
      {
        'id': 903,
        'bill_number': 'FTU-$dateTag-R3090',
        'tier': 'celtic',
        'status': 'pending_payment',
        'amount_thb': 99.0,
        'fee_thb': 0.0,
        'net_thb': 99.0,
        'payment_method': 'promptpay',
        'slip_image_url': null,
        'question_preview': 'ความรักกับแฟนคนเก่าจะกลับมาไหม',
        'reading_id': 3090,
        'created_at':
            now.subtract(const Duration(minutes: 14)).toIso8601String(),
        'user': {'name': 'Mei Wong'},
        'platform': 'line',
      },
      {
        'id': 904,
        'bill_number': 'FTU-$dateTag-R3089',
        'tier': 'tarot_chat',
        'status': 'pending_payment',
        'amount_thb': 59.0,
        'fee_thb': 0.0,
        'net_thb': 59.0,
        'payment_method': 'stripe',
        'slip_image_url': null,
        'question_preview': 'ปีนี้จะได้เลื่อนตำแหน่งไหม?',
        'reading_id': 3089,
        'created_at':
            now.subtract(const Duration(minutes: 22)).toIso8601String(),
        'user': {'name': 'ภาคิน ทรัพย์ทวี'},
        'platform': 'line',
      },

      // 3 paid (รอ admin confirm) — มี slip image แล้ว
      {
        'id': 905,
        'bill_number': 'FTU-$dateTag-R3088',
        'tier': 'celtic',
        'status': 'paid',
        'amount_thb': 99.0,
        'fee_thb': 0.0,
        'net_thb': 99.0,
        'payment_method': 'promptpay',
        'slip_image_url': 'https://placeholder.example/slip1.jpg',
        'question_preview': 'ดวงรายเดือนพฤษภาคม',
        'reading_id': 3088,
        'created_at':
            now.subtract(const Duration(minutes: 28)).toIso8601String(),
        'paid_at': now.subtract(const Duration(minutes: 4)).toIso8601String(),
        'user': {'name': 'Lisa Anderson'},
        'platform': 'line',
      },
      {
        'id': 906,
        'bill_number': 'FTU-$dateTag-R3087',
        'tier': 'deep',
        'status': 'paid',
        'amount_thb': 39.0,
        'fee_thb': 0.0,
        'net_thb': 39.0,
        'payment_method': 'promptpay',
        'slip_image_url': 'https://placeholder.example/slip2.jpg',
        'question_preview': 'การเงินช่วงนี้',
        'reading_id': 3087,
        'created_at':
            now.subtract(const Duration(hours: 1)).toIso8601String(),
        'paid_at': now.subtract(const Duration(minutes: 12)).toIso8601String(),
        'user': {'name': 'ปนัดดา วงศ์สุข'},
        'platform': 'facebook',
      },
      {
        'id': 907,
        'bill_number': 'FTU-$dateTag-R3086',
        'tier': 'celtic',
        'status': 'paid',
        'amount_thb': 99.0,
        'fee_thb': 0.0,
        'net_thb': 99.0,
        'payment_method': 'promptpay',
        'slip_image_url': 'https://placeholder.example/slip3.jpg',
        'question_preview': 'อยากรู้เรื่องการลงทุนปีนี้',
        'reading_id': 3086,
        'created_at':
            now.subtract(const Duration(hours: 1, minutes: 22))
                .toIso8601String(),
        'paid_at': now.subtract(const Duration(minutes: 18)).toIso8601String(),
        'user': {'name': 'Yuki Tanaka'},
        'platform': 'line',
      },

      // 3 confirmed (admin อนุมัติแล้ว — บิล healthy)
      {
        'id': 908,
        'bill_number': 'FTU-$dateTag-R3085',
        'tier': 'celtic',
        'status': 'reading_done',
        'amount_thb': 99.0,
        'fee_thb': 0.0,
        'net_thb': 99.0,
        'payment_method': 'promptpay',
        'slip_image_url': 'https://placeholder.example/slip4.jpg',
        'question_preview': 'คำถามเรื่องสุขภาพ',
        'reading_id': 3085,
        'created_at':
            now.subtract(const Duration(hours: 2)).toIso8601String(),
        'paid_at':
            now.subtract(const Duration(hours: 2, minutes: -10))
                .toIso8601String(),
        'confirmed_at':
            now.subtract(const Duration(hours: 1, minutes: 50))
                .toIso8601String(),
        'user': {'name': 'Carlos Rivera'},
        'platform': 'line',
      },
      {
        'id': 909,
        'bill_number': 'FTU-$dateTag-R3084',
        'tier': 'deep',
        'status': 'reading_done',
        'amount_thb': 39.0,
        'fee_thb': 0.0,
        'net_thb': 39.0,
        'payment_method': 'stripe',
        'slip_image_url': null,
        'question_preview': 'งานใหม่กับงานเก่า',
        'reading_id': 3084,
        'created_at':
            now.subtract(const Duration(hours: 3)).toIso8601String(),
        'confirmed_at':
            now.subtract(const Duration(hours: 2, minutes: 55))
                .toIso8601String(),
        'user': {'name': 'ธนพล อิ่มสุข'},
        'platform': 'facebook',
      },
      {
        'id': 910,
        'bill_number': 'FTU-$dateTag-R3083',
        'tier': 'celtic',
        'status': 'reading_done',
        'amount_thb': 99.0,
        'fee_thb': 0.0,
        'net_thb': 99.0,
        'payment_method': 'promptpay',
        'slip_image_url': 'https://placeholder.example/slip5.jpg',
        'question_preview': 'การเดินทางต่างประเทศ',
        'reading_id': 3083,
        'created_at':
            now.subtract(const Duration(hours: 5)).toIso8601String(),
        'confirmed_at':
            now.subtract(const Duration(hours: 4, minutes: 55))
                .toIso8601String(),
        'user': {'name': 'พิมพ์ใจ ศรีสุข'},
        'platform': 'line',
      },

      // 1 rejected
      {
        'id': 911,
        'bill_number': 'FTU-$dateTag-R3082',
        'tier': 'celtic',
        'status': 'rejected',
        'amount_thb': 99.0,
        'fee_thb': 0.0,
        'net_thb': 99.0,
        'payment_method': 'promptpay',
        'slip_image_url': 'https://placeholder.example/slip6.jpg',
        'question_preview': 'อยากรู้ดวงปีนี้',
        'reading_id': 3082,
        'created_at':
            now.subtract(const Duration(hours: 6)).toIso8601String(),
        'reject_reason': 'สลิปปลอม — ยอดเงินไม่ตรง',
        'user': {'name': 'นาง สมหญิง'},
        'platform': 'facebook',
      },

      // 1 refunded
      {
        'id': 912,
        'bill_number': 'FTU-$dateTag-R3081',
        'tier': 'celtic',
        'status': 'refunded',
        'amount_thb': 99.0,
        'fee_thb': 0.0,
        'net_thb': 99.0,
        'payment_method': 'promptpay',
        'slip_image_url': 'https://placeholder.example/slip7.jpg',
        'question_preview': 'ความรักจะดีไหมปีนี้',
        'reading_id': 3081,
        'created_at':
            now.subtract(const Duration(hours: 8)).toIso8601String(),
        'reject_reason': 'AI ตอบไม่ครบ — refund 99฿',
        'user': {'name': 'อรพรรณ สวัสดิ์'},
        'platform': 'line',
      },
    ];
  }

  static PagedResult<FortuneBill> fortuneBills({String? status, String? tier}) {
    final all = _fortuneBillsRaw().map((m) {
      final id = m['id'] as int;
      final patched = Map<String, dynamic>.from(m);
      // apply status override
      if (_billStatusOverride.containsKey(id)) {
        patched['status'] = _billStatusOverride[id];
      }
      if (_billRejectReasonOverride.containsKey(id)) {
        patched['reject_reason'] = _billRejectReasonOverride[id];
      }
      return patched;
    }).toList();

    final filtered = all.where((m) {
      if (status != null && m['status'] != status) return false;
      if (tier != null && m['tier'] != tier) return false;
      return true;
    }).toList();

    // sort: pending first, then by created_at desc
    filtered.sort((a, b) {
      final ap = a['status'] == 'pending_payment' ? 0 : (a['status'] == 'paid' ? 1 : 2);
      final bp = b['status'] == 'pending_payment' ? 0 : (b['status'] == 'paid' ? 1 : 2);
      if (ap != bp) return ap.compareTo(bp);
      return (b['created_at'] as String).compareTo(a['created_at'] as String);
    });

    return PagedResult.fromJson<FortuneBill>(
      {
        'data': filtered,
        'current_page': 1,
        'last_page': 1,
        'total': filtered.length,
      },
      FortuneBill.fromJson,
    );
  }

  static FortuneBillStats fortuneBillStats() {
    final all = _fortuneBillsRaw().map((m) {
      final id = m['id'] as int;
      final patched = Map<String, dynamic>.from(m);
      if (_billStatusOverride.containsKey(id)) {
        patched['status'] = _billStatusOverride[id];
      }
      return patched;
    }).toList();

    final pending =
        all.where((m) => m['status'] == 'pending_payment').length;
    final paidUnconfirmed = all.where((m) => m['status'] == 'paid').length;
    final confirmed = all.where((m) {
      final s = m['status'] as String;
      return s == 'confirmed' || s == 'reading_started' || s == 'reading_done';
    }).length;
    final rejected = all.where((m) => m['status'] == 'rejected').length;

    final todayRevenue = all.where((m) {
      final s = m['status'] as String;
      return s == 'confirmed' || s == 'reading_started' || s == 'reading_done';
    }).fold<double>(0, (sum, m) => sum + ((m['amount_thb'] as num).toDouble()));

    return FortuneBillStats(
      pendingCount: pending,
      paidUnconfirmedCount: paidUnconfirmed,
      confirmedTodayCount: confirmed,
      todayRevenueThb: todayRevenue,
      rejectedTodayCount: rejected,
    );
  }

  // ────────────────────────────────────────────────────────────
  // Fortune Active Readings (Live monitor)
  // อ้างอิง brain: stuck > 60s (slow) / > 120s (stuck) / alert_sent หลัง 60s
  // ────────────────────────────────────────────────────────────

  static List<FortuneActiveReading> fortuneActiveReadings() {
    final now = DateTime.now();
    final dateTag =
        '${now.year.toString().substring(2)}${_pad2(now.month)}${_pad2(now.day)}';
    // varied elapsed times to demo alert levels
    final raw = [
      {
        'id': 5001,
        'bill_number': 'FTU-$dateTag-R3092',
        'tier': 'celtic',
        'state': 'CELTIC_PICKING',
        'stage_label': 'กำลังเปิดไพ่ใบที่ 4/10',
        'started_at': now.subtract(const Duration(seconds: 28)).toIso8601String(),
        'last_activity_at':
            now.subtract(const Duration(seconds: 4)).toIso8601String(),
        'question_preview': 'อยากรู้เรื่องเนื้อคู่',
        'ai': {'provider': 'OpenAI', 'model': 'gpt-4o'},
        'user': {'name': 'พลอย จันทรา'},
        'platform': 'line',
        'platform_user_id': 'U44425abec76f4458ef731274a056212d',
      },
      {
        'id': 5002,
        'bill_number': 'FTU-$dateTag-R3091',
        'tier': 'deep',
        'state': 'DEEP_PROCESSING',
        'stage_label': 'AI กำลังประมวลผล (Deep 39฿)',
        'started_at': now.subtract(const Duration(seconds: 78)).toIso8601String(),
        'last_activity_at':
            now.subtract(const Duration(seconds: 22)).toIso8601String(),
        'question_preview': 'งานใหม่จะดีกว่าเดิมไหม?',
        'ai': {'provider': 'Anthropic', 'model': 'claude-sonnet-4-6'},
        'user': {'name': 'สมชาย ใจดี'},
        'platform': 'facebook',
      },
      {
        'id': 5003,
        'bill_number': 'FTU-$dateTag-R3090',
        'tier': 'celtic',
        'state': 'CELTIC_AWAITING_QUESTION',
        'stage_label': 'รอลูกค้าพิมพ์คำถาม',
        'started_at':
            now.subtract(const Duration(seconds: 145)).toIso8601String(),
        'last_activity_at':
            now.subtract(const Duration(seconds: 95)).toIso8601String(),
        'question_preview': null,
        'ai': null,
        'user': {'name': 'Mei Wong'},
        'platform': 'line',
        'alert_sent_at':
            now.subtract(const Duration(seconds: 85)).toIso8601String(),
      },
      {
        'id': 5004,
        'bill_number': 'FTU-$dateTag-R3089',
        'tier': 'tarot_chat',
        'state': 'CHAT_THINKING',
        'stage_label': 'AI ตอบคำถาม (Chat)',
        'started_at':
            now.subtract(const Duration(seconds: 192)).toIso8601String(),
        'last_activity_at':
            now.subtract(const Duration(seconds: 192)).toIso8601String(),
        'question_preview': 'ปีนี้จะได้เลื่อนตำแหน่งไหม?',
        'ai': {'provider': 'Google', 'model': 'gemini-2.0-flash'},
        'user': {'name': 'ภาคิน ทรัพย์ทวี'},
        'platform': 'line',
        'alert_sent_at':
            now.subtract(const Duration(seconds: 132)).toIso8601String(),
      },
      {
        'id': 5005,
        'bill_number': 'FTU-$dateTag-R3088',
        'tier': 'celtic',
        'state': 'CELTIC_PICKING',
        'stage_label': 'กำลังเปิดไพ่ใบที่ 9/10',
        'started_at': now.subtract(const Duration(seconds: 42)).toIso8601String(),
        'last_activity_at':
            now.subtract(const Duration(seconds: 6)).toIso8601String(),
        'question_preview': 'ดวงรายเดือนพฤษภาคม',
        'ai': null,
        'user': {'name': 'Lisa Anderson'},
        'platform': 'line',
      },
      {
        'id': 5006,
        'bill_number': 'FTU-$dateTag-R3086',
        'tier': 'celtic',
        'state': 'CELTIC_VISION_PROCESSING',
        'stage_label': 'AI Vision อ่านรูปภาพ',
        'started_at': now.subtract(const Duration(seconds: 52)).toIso8601String(),
        'last_activity_at':
            now.subtract(const Duration(seconds: 12)).toIso8601String(),
        'question_preview': 'อยากรู้เรื่องการลงทุนปีนี้',
        'ai': {'provider': 'OpenAI', 'model': 'gpt-4o (vision)'},
        'user': {'name': 'Yuki Tanaka'},
        'platform': 'line',
      },
    ];
    return raw
        .where((m) => !_cancelledReadings.contains(m['id']))
        .map((m) {
          final id = m['id'] as int;
          final patched = Map<String, dynamic>.from(m);
          if (_adminTakenOverReadings.contains(id)) {
            patched['admin_taken_over'] = true;
          }
          return FortuneActiveReading.fromJson(patched);
        })
        .toList()
        // sort: stuck first, then slow, then ok; within group by elapsed desc
        ..sort((a, b) {
          final order = {'stuck': 0, 'slow': 1, 'ok': 2};
          final ao = order[a.alertLevel] ?? 99;
          final bo = order[b.alertLevel] ?? 99;
          if (ao != bo) return ao.compareTo(bo);
          return b.elapsed.compareTo(a.elapsed);
        });
  }

  // ────────────────────────────────────────────────────────────
  // Takeover Inbox + Chat
  // Brain: customer_handoff_keywords (คุยกับคน/แอดมิน/แม่หมอ ฯลฯ),
  // takeover_default_minutes 30-60, HUMAN_AGENT tag for FB
  // ────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _fortuneConversationsBase() {
    final now = DateTime.now();
    final dateTag =
        '${now.year.toString().substring(2)}${_pad2(now.month)}${_pad2(now.day)}';
    return [
      // ❗ ลูกค้าขอแอดมิน 2 คน
      {
        'reading_id': 7001,
        'bill_number': 'FTU-$dateTag-R3092',
        'tier': 'celtic',
        'status': 'customer_requested_admin',
        'user': {'name': 'พลอย จันทรา', 'avatar_url': null},
        'platform': 'line',
        'platform_user_id': 'U44425abec76f4458ef731274a056212d',
        'last_message_at':
            now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'last_message_preview': 'คุยกับแม่หมอได้ไหมคะ ขอสอบถามเรื่องเปลี่ยนคำถาม',
        'last_message_sender': 'customer',
        'request_keyword': 'คุยกับแม่หมอ',
        'unread_admin_count': 3,
      },
      {
        'reading_id': 7002,
        'bill_number': 'FTU-$dateTag-R3088',
        'tier': 'deep',
        'status': 'customer_requested_admin',
        'user': {'name': 'สมชาย ใจดี', 'avatar_url': null},
        'platform': 'facebook',
        'last_message_at':
            now.subtract(const Duration(minutes: 4)).toIso8601String(),
        'last_message_preview': 'ขอแอดมินช่วยตอบหน่อยครับ AI ตอบไม่ตรง',
        'last_message_sender': 'customer',
        'request_keyword': 'ขอแอดมิน',
        'unread_admin_count': 1,
      },
      // ⏳ Takeover ใกล้หมดเวลา
      {
        'reading_id': 7003,
        'bill_number': 'FTU-$dateTag-R3081',
        'tier': 'celtic',
        'status': 'takeover_expiring',
        'user': {'name': 'Lisa Anderson', 'avatar_url': null},
        'platform': 'line',
        'last_message_at':
            now.subtract(const Duration(minutes: 2)).toIso8601String(),
        'last_message_preview':
            'ขอบคุณค่ะแม่หมอ แล้วเรื่องการเงินล่ะคะ',
        'last_message_sender': 'customer',
        'takeover_until':
            now.add(const Duration(minutes: 3)).toIso8601String(),
        'unread_admin_count': 1,
      },
      // 💬 Takeover active ปกติ
      {
        'reading_id': 7004,
        'bill_number': 'FTU-$dateTag-R3079',
        'tier': 'deep',
        'status': 'takeover_active',
        'user': {'name': 'Mei Wong', 'avatar_url': null},
        'platform': 'line',
        'last_message_at':
            now.subtract(const Duration(minutes: 12)).toIso8601String(),
        'last_message_preview': 'ค่ะ จะรอนะคะ',
        'last_message_sender': 'customer',
        'takeover_until':
            now.add(const Duration(minutes: 28)).toIso8601String(),
        'unread_admin_count': 0,
      },
      // 🤖 Bot คุยปกติ
      {
        'reading_id': 7005,
        'bill_number': 'FTU-$dateTag-R3076',
        'tier': 'celtic',
        'status': 'active_bot',
        'user': {'name': 'Yuki Tanaka', 'avatar_url': null},
        'platform': 'line',
        'last_message_at':
            now.subtract(const Duration(minutes: 18)).toIso8601String(),
        'last_message_preview': 'หมอจันทราจะทำนายเรื่องการงานของคุณ...',
        'last_message_sender': 'bot',
        'unread_admin_count': 0,
      },
      {
        'reading_id': 7006,
        'bill_number': 'FTU-$dateTag-R3074',
        'tier': 'tarot_chat',
        'status': 'active_bot',
        'user': {'name': 'Carlos Rivera', 'avatar_url': null},
        'platform': 'facebook',
        'last_message_at':
            now.subtract(const Duration(hours: 1)).toIso8601String(),
        'last_message_preview': 'OK got it, will think about it. Thanks!',
        'last_message_sender': 'customer',
        'unread_admin_count': 0,
      },
      // ✅ ปิดแล้ว
      {
        'reading_id': 7007,
        'bill_number': 'FTU-$dateTag-R3060',
        'tier': 'celtic',
        'status': 'closed',
        'user': {'name': 'ปนัดดา วงศ์สุข', 'avatar_url': null},
        'platform': 'line',
        'last_message_at':
            now.subtract(const Duration(hours: 5)).toIso8601String(),
        'last_message_preview': '🙏 ขอบคุณค่ะแม่หมอ',
        'last_message_sender': 'customer',
        'unread_admin_count': 0,
      },
    ];
  }

  static List<FortuneConversation> fortuneConversations() {
    final list = _fortuneConversationsBase().map((m) {
      final id = m['reading_id'] as int;
      final patched = Map<String, dynamic>.from(m);
      // Apply takeover overrides
      if (_takeoverUntil.containsKey(id)) {
        final until = _takeoverUntil[id]!;
        patched['takeover_until'] = until.toIso8601String();
        final minutesLeft = until.difference(DateTime.now()).inMinutes;
        patched['status'] = minutesLeft <= 5
            ? 'takeover_expiring'
            : 'takeover_active';
      } else if (_resumedReadings.contains(id)) {
        patched['status'] = 'active_bot';
        patched['takeover_until'] = null;
      }
      // If admin sent messages → bump last_message_*
      final admin = _adminMessages[id];
      if (admin != null && admin.isNotEmpty) {
        final lastAdmin = admin.last;
        patched['last_message_at'] = lastAdmin['at'];
        patched['last_message_preview'] = lastAdmin['text'];
        patched['last_message_sender'] = lastAdmin['sender'];
      }
      return FortuneConversation.fromJson(patched);
    }).toList()
      // sort by status priority → then last_message_at desc
      ..sort((a, b) {
        final cmp = a.status.sortRank.compareTo(b.status.sortRank);
        if (cmp != 0) return cmp;
        if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
        if (a.lastMessageAt == null) return 1;
        if (b.lastMessageAt == null) return -1;
        return b.lastMessageAt!.compareTo(a.lastMessageAt!);
      });
    return list;
  }

  static TakeoverStats takeoverStats() {
    final all = fortuneConversations();
    return TakeoverStats(
      customerRequests: all
          .where((c) => c.status == ConversationStatus.customerRequestedAdmin)
          .length,
      takeoverActive: all
          .where((c) => c.status == ConversationStatus.takeoverActive)
          .length,
      takeoverExpiring: all
          .where((c) => c.status == ConversationStatus.takeoverExpiring)
          .length,
      closedToday:
          all.where((c) => c.status == ConversationStatus.closed).length,
    );
  }

  static List<ChatMessage> chatMessages(int readingId) {
    final now = DateTime.now();
    // Base scripted thread per conversation (varies by readingId)
    final base = _baseChatMessages(readingId, now);
    // Append admin messages from override
    final admin = _adminMessages[readingId] ?? const [];
    final all = [...base, ...admin];
    // Sort ascending by at
    all.sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));
    return all.map((m) => ChatMessage.fromJson(m)).toList();
  }

  static List<Map<String, dynamic>> _baseChatMessages(
      int readingId, DateTime now) {
    // Different scripts per reading id
    switch (readingId) {
      case 7001:
        return [
          _msg(7001, 'customer', 'สวัสดีค่ะ',
              now.subtract(const Duration(minutes: 22))),
          _msg(7001, 'bot',
              '✨ หมอจันทราพร้อมรับใช้ค่ะ · เลือกบริการที่ต้องการได้เลย',
              now.subtract(const Duration(minutes: 22, seconds: -10))),
          _msg(7001, 'customer', 'ขอ Celtic Cross ค่ะ',
              now.subtract(const Duration(minutes: 21))),
          _msg(7001, 'bot',
              '🔮 Celtic Cross 99฿ · พิมพ์คำถาม + โอนเงินตามบิล FTU-...',
              now.subtract(const Duration(minutes: 20, seconds: 30))),
          _msg(7001, 'customer', 'อยากรู้เรื่องเนื้อคู่ค่ะ',
              now.subtract(const Duration(minutes: 18))),
          _msg(7001, 'bot',
              '🌸 หมอจะดูไพ่ Celtic Cross 10 ใบให้นะคะ · ขอเวลาสักครู่...',
              now.subtract(const Duration(minutes: 17, seconds: 50))),
          _msg(7001, 'bot',
              'ใบที่ 1: The Star — ความหวังและแรงบันดาลใจ ความรักที่บริสุทธิ์...',
              now.subtract(const Duration(minutes: 10))),
          _msg(7001, 'customer',
              'ขอเปลี่ยนคำถามได้ไหมคะ เพราะเพิ่งคิดออก',
              now.subtract(const Duration(minutes: 3))),
          _msg(7001, 'bot',
              'ขออภัยค่ะ · บิลนี้ได้ลงคำถามไปแล้ว ไม่สามารถเปลี่ยนได้',
              now.subtract(const Duration(minutes: 2, seconds: 30))),
          _msgKeyword(
              7001,
              'คุยกับแม่หมอได้ไหมคะ ขอสอบถามเรื่องเปลี่ยนคำถาม',
              now.subtract(const Duration(minutes: 1))),
        ];
      case 7002:
        return [
          _msg(7002, 'customer', 'จ่ายแล้วครับ',
              now.subtract(const Duration(minutes: 35))),
          _msg(7002, 'bot',
              'ขอบคุณค่ะ · ระบบกำลังตรวจสอบบิล...',
              now.subtract(const Duration(minutes: 34, seconds: 40))),
          _msg(7002, 'bot',
              '✅ ยืนยันการจ่ายแล้ว · กำลังทำนายเชิงลึก...',
              now.subtract(const Duration(minutes: 30))),
          _msg(7002, 'bot',
              'ดวงเดือนนี้กำลังเปิดทางด้านการเงิน...',
              now.subtract(const Duration(minutes: 28))),
          _msg(7002, 'customer',
              'ตอบไม่ตรงกับคำถามครับ ผมถามเรื่องงานไม่ใช่เงิน',
              now.subtract(const Duration(minutes: 10))),
          _msgKeyword(7002,
              'ขอแอดมินช่วยตอบหน่อยครับ AI ตอบไม่ตรง',
              now.subtract(const Duration(minutes: 4))),
        ];
      case 7003:
        return [
          _msg(7003, 'customer', 'อยากดูเรื่องความรักค่ะ',
              now.subtract(const Duration(minutes: 50))),
          _msg(7003, 'bot',
              'หมอจะดูไพ่ Celtic ให้นะคะ · ขอเวลาสักครู่',
              now.subtract(const Duration(minutes: 49))),
          _msg(7003, 'bot',
              'ใบ The Lovers ที่ตำแหน่งปัจจุบัน...',
              now.subtract(const Duration(minutes: 45))),
          _msgSystem(7003,
              'Admin เปิด takeover · เวลา 30 นาที',
              now.subtract(const Duration(minutes: 35)),
              kind: 'takeover_started'),
          _msg(7003, 'admin', 'แม่หมอเองนะคะ มีอะไรให้ช่วยเพิ่มไหม',
              now.subtract(const Duration(minutes: 34)),
              adminName: 'แม่หมอจันทรา'),
          _msg(7003, 'customer', 'อยากถามเรื่องเงินด้วยค่ะ',
              now.subtract(const Duration(minutes: 25))),
          _msg(7003, 'admin',
              'ดวงการเงินคุณช่วงนี้กำลังเข้ามาดีค่ะ มีโอกาสได้ลาภ',
              now.subtract(const Duration(minutes: 24)),
              adminName: 'แม่หมอจันทรา'),
          _msg(7003, 'customer',
              'ขอบคุณค่ะแม่หมอ แล้วเรื่องการเงินล่ะคะ',
              now.subtract(const Duration(minutes: 2))),
        ];
      case 7004:
        return [
          _msg(7004, 'customer', '请问什么时候可以开始?',
              now.subtract(const Duration(hours: 1))),
          _msg(7004, 'bot',
              '🌙 เริ่มได้เลยค่ะ · กรุณาพิมพ์คำถาม',
              now.subtract(const Duration(minutes: 58))),
          _msgSystem(7004, 'Admin เปิด takeover · เวลา 60 นาที',
              now.subtract(const Duration(minutes: 45)),
              kind: 'takeover_started'),
          _msg(7004, 'admin', 'ผมเข้ามาช่วยแม่หมอตอบเองครับ มีอะไรสงสัยไหม',
              now.subtract(const Duration(minutes: 44)),
              adminName: 'Admin Kris'),
          _msg(7004, 'customer', 'ค่ะ จะรอนะคะ',
              now.subtract(const Duration(minutes: 12))),
        ];
      case 7005:
        return [
          _msg(7005, 'customer', 'สวัสดีครับ',
              now.subtract(const Duration(minutes: 30))),
          _msg(7005, 'bot',
              '✨ หมอจันทราพร้อมรับใช้ค่ะ',
              now.subtract(const Duration(minutes: 29, seconds: 50))),
          _msg(7005, 'customer', 'ขอดูเรื่องการงาน',
              now.subtract(const Duration(minutes: 25))),
          _msg(7005, 'bot',
              'หมอจันทราจะทำนายเรื่องการงานของคุณ...',
              now.subtract(const Duration(minutes: 18))),
        ];
      case 7006:
        return [
          _msg(7006, 'customer', 'Hi can I ask about my career?',
              now.subtract(const Duration(hours: 2))),
          _msg(7006, 'bot',
              'Sure! Please share your birth date and the specific question.',
              now.subtract(const Duration(hours: 2, minutes: -1))),
          _msg(7006, 'customer', '1992-05-14, will I get promoted this year?',
              now.subtract(const Duration(hours: 1, minutes: 50))),
          _msg(7006, 'bot',
              'The cards suggest a strong period of growth between July-September...',
              now.subtract(const Duration(hours: 1, minutes: 30))),
          _msg(7006, 'customer', 'OK got it, will think about it. Thanks!',
              now.subtract(const Duration(hours: 1))),
        ];
      case 7007:
        return [
          _msg(7007, 'customer', 'อยากรู้ดวงปีนี้ค่ะ',
              now.subtract(const Duration(hours: 6))),
          _msg(7007, 'bot',
              'หมอจันทราจะทำนายให้นะคะ',
              now.subtract(const Duration(hours: 6, minutes: -1))),
          _msg(7007, 'bot',
              'ดวงปีนี้คุณมีโชคใหญ่ในเดือนตุลาคม...',
              now.subtract(const Duration(hours: 5, minutes: 30))),
          _msg(7007, 'customer', '🙏 ขอบคุณค่ะแม่หมอ',
              now.subtract(const Duration(hours: 5))),
          _msgSystem(7007, 'Reading ปิด · ผ่านการประเมิน 5 ดาว',
              now.subtract(const Duration(hours: 5, minutes: -2)),
              kind: 'closed'),
        ];
      default:
        return [];
    }
  }

  static Map<String, dynamic> _msg(
      int readingId, String sender, String text, DateTime at,
      {String? adminName}) {
    return {
      'id': readingId * 100 + at.millisecondsSinceEpoch % 100,
      'reading_id': readingId,
      'sender': sender,
      'text': text,
      'at': at.toIso8601String(),
      if (adminName != null) 'admin_name': adminName,
    };
  }

  static Map<String, dynamic> _msgKeyword(
      int readingId, String text, DateTime at) {
    return {
      'id': readingId * 100 + at.millisecondsSinceEpoch % 100,
      'reading_id': readingId,
      'sender': 'customer',
      'text': text,
      'at': at.toIso8601String(),
      'is_keyword_match': true,
    };
  }

  static Map<String, dynamic> _msgSystem(
      int readingId, String text, DateTime at,
      {String kind = 'note'}) {
    return {
      'id': readingId * 100 + at.millisecondsSinceEpoch % 100,
      'reading_id': readingId,
      'sender': 'system',
      'text': text,
      'at': at.toIso8601String(),
      'is_system': true,
      'system_kind': kind,
    };
  }

  // ────────────────────────────────────────────────────────────
  // AI Pool (per brain: Pool-first + Health Gate + Auto-Recovery)
  // ────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _aiPoolKeysBase() {
    final now = DateTime.now();
    final passOk = now.subtract(const Duration(minutes: 4)).toIso8601String();
    final passStale = now.subtract(const Duration(hours: 18)).toIso8601String();
    final passDay = now.subtract(const Duration(days: 2)).toIso8601String();
    final errRecent = now.subtract(const Duration(hours: 1)).toIso8601String();
    return [
      // ── OpenAI ──
      {
        'id': 1001,
        'provider': 'openai',
        'display_name': 'OpenAI · GPT-4o Primary',
        'model': 'gpt-4o',
        'priority': 1,
        'purposes': ['prediction_celtic', 'prediction_deep', 'chat', 'vision'],
        'is_active': true,
        'last_test_passed_at': passOk,
        'cost_thb_today': 14200.0,
        'quota_pct': 84.0,
        'usage_count': 2840,
        'note': 'Primary key — Tier 1',
      },
      {
        'id': 1002,
        'provider': 'openai',
        'display_name': 'OpenAI · GPT-4o Backup',
        'model': 'gpt-4o',
        'priority': 2,
        'purposes': ['prediction_celtic', 'prediction_deep', 'chat'],
        'is_active': true,
        'last_test_passed_at': passOk,
        'cost_thb_today': 8200.0,
        'quota_pct': 42.0,
        'usage_count': 1620,
        'note': 'Failover backup',
      },
      {
        'id': 1003,
        'provider': 'openai',
        'display_name': 'OpenAI · o1-preview',
        'model': 'o1-preview',
        'priority': 3,
        'purposes': ['prediction_celtic'],
        'is_active': true,
        'last_test_passed_at': passStale,
        'cost_thb_today': 6000.0,
        'quota_pct': 18.0,
        'usage_count': 320,
        'note': 'Reasoning — high cost',
      },
      // ── Anthropic ──
      {
        'id': 1004,
        'provider': 'anthropic',
        'display_name': 'Anthropic · Claude Sonnet 4.6',
        'model': 'claude-sonnet-4-6',
        'priority': 1,
        'purposes': ['prediction_celtic', 'prediction_deep', 'chat'],
        'is_active': true,
        'last_test_passed_at': passOk,
        'cost_thb_today': 12400.0,
        'quota_pct': 62.0,
        'usage_count': 1840,
        'note': null,
      },
      {
        'id': 1005,
        'provider': 'anthropic',
        'display_name': 'Anthropic · Claude Haiku 4.5',
        'model': 'claude-haiku-4-5',
        'priority': 2,
        'purposes': ['chat', 'banner'],
        'is_active': true,
        'last_test_passed_at': passOk,
        'cost_thb_today': 1200.0,
        'quota_pct': 28.0,
        'usage_count': 4200,
        'note': 'Cheap & fast',
      },
      // ── Google ──
      {
        'id': 1006,
        'provider': 'google',
        'display_name': 'Google · Gemini 2.0 Flash',
        'model': 'gemini-2.0-flash',
        'priority': 1,
        'purposes': ['prediction_deep', 'chat', 'banner'],
        'is_active': true,
        'last_test_passed_at': passOk,
        'cost_thb_today': 4800.0,
        'quota_pct': 38.0,
        'usage_count': 1920,
        'note': null,
      },
      {
        'id': 1007,
        'provider': 'google',
        'display_name': 'Google · Gemini 2.0 Pro',
        'model': 'gemini-2.0-pro',
        'priority': 2,
        'purposes': ['prediction_celtic', 'vision'],
        'is_active': true,
        'last_test_passed_at': passStale,
        'cost_thb_today': 2400.0,
        'quota_pct': 22.0,
        'usage_count': 340,
        'note': 'Vision-capable',
      },
      // ── Failing / unhealthy keys ──
      {
        'id': 1008,
        'provider': 'openai',
        'display_name': 'OpenAI · GPT-4o EU',
        'model': 'gpt-4o',
        'priority': 4,
        'purposes': ['chat'],
        'is_active': true,
        'last_test_passed_at': null, // unhealthy
        'last_test_error_at': errRecent,
        'cost_thb_today': 0.0,
        'quota_pct': 0.0,
        'usage_count': 0,
        'note': 'Rate limited — test failed',
      },
      {
        'id': 1009,
        'provider': 'huggingface',
        'display_name': 'HuggingFace · Llama-3.3-70B',
        'model': 'meta-llama/Llama-3.3-70B-Instruct',
        'priority': 5,
        'purposes': ['chat', 'banner'],
        'is_active': false,
        'last_test_passed_at': passDay,
        'cost_thb_today': 0.0,
        'quota_pct': 0.0,
        'usage_count': 0,
        'note': 'Disabled — too slow for primary',
      },
      {
        'id': 1010,
        'provider': 'local',
        'display_name': 'Local · Llama 3.1 70B (self-host)',
        'model': 'llama-3.1-70b-instruct',
        'priority': 3,
        'purposes': ['chat', 'banner'],
        'is_active': true,
        'last_test_passed_at': passOk,
        'cost_thb_today': 0.0,
        'quota_pct': 12.0,
        'usage_count': 820,
        'note': 'Self-hosted — free but limited',
      },
    ];
  }

  static List<Map<String, dynamic>> _aiPoolKeysWithPatches() {
    return _aiPoolKeysBase().map((m) {
      final id = m['id'] as int;
      final patch = _aiKeyPatches[id];
      if (patch == null) return m;
      return {...m, ...patch};
    }).toList();
  }

  static List<AiApiKey> aiPoolKeys({String? purpose}) {
    final filtered = _aiPoolKeysWithPatches().where((m) {
      if (purpose == null) return true;
      final purposes = (m['purposes'] as List).map((e) => e.toString()).toList();
      return purposes.contains(purpose);
    }).toList();
    // sort by priority asc (1 = highest)
    filtered.sort(
        (a, b) => (a['priority'] as num).compareTo(b['priority'] as num));
    return filtered.map((m) => AiApiKey.fromJson(m)).toList();
  }

  static AiPoolSettings aiPoolSettings() {
    final all = _aiPoolKeysWithPatches();
    final healthy = all.where((m) {
      final isActive = m['is_active'] as bool? ?? true;
      final passedAt = m['last_test_passed_at'] as String?;
      return isActive && passedAt != null && passedAt.isNotEmpty;
    }).length;
    return AiPoolSettings(
      globalMode: _aiPoolGlobalMode,
      totalKeys: all.length,
      healthyKeys: healthy,
    );
  }

  // ────────────────────────────────────────────────────────────
  // AI Management
  // ────────────────────────────────────────────────────────────

  static AiDashboardData aiDashboard() {
    final bots = aiBots().items;
    final activeBots = bots.where((b) => b.isActive).length;
    return AiDashboardData.fromJson({
        'hero': {
          'total_tokens': 28600000,
          'total_cost_thb': 55500,
          'cache_hit_pct': 68,
        },
        'providers_summary': [
          {
            'id': 1,
            'name': 'OpenAI',
            'type': 'openai',
            'is_available': true,
            'quota_pct': 84,
            'cost_thb': 28400,
          },
          {
            'id': 2,
            'name': 'Anthropic',
            'type': 'anthropic',
            'is_available': true,
            'quota_pct': 62,
            'cost_thb': 18200,
          },
          {
            'id': 3,
            'name': 'Google',
            'type': 'google',
            'is_available': true,
            'quota_pct': 38,
            'cost_thb': 8900,
          },
          {
            'id': 4,
            'name': 'Local Llama',
            'type': 'local',
            'is_available': true,
            'quota_pct': 24,
            'cost_thb': 0,
          },
        ],
        'bots_summary': {'total': bots.length, 'active': activeBots},
        'inference': {
          'p95_latency_ms': 2400,
          'requests_per_min': 284,
          'errors_pct': 0.4,
        },
      });
  }

  static List<AiProvider> aiProviders() {
    final base = [
      {
        'id': 1,
        'name': 'openai',
        'display_name': 'OpenAI · GPT-4o',
        'type': 'openai',
        'is_active': true,
        'is_available': true,
        'api_endpoint': 'https://api.openai.com',
      },
      {
        'id': 2,
        'name': 'anthropic',
        'display_name': 'Anthropic · Claude Sonnet 4.6',
        'type': 'anthropic',
        'is_active': true,
        'is_available': true,
        'api_endpoint': 'https://api.anthropic.com',
      },
      {
        'id': 3,
        'name': 'google',
        'display_name': 'Google · Gemini 2.0 Flash',
        'type': 'google',
        'is_active': true,
        'is_available': true,
        'api_endpoint': 'https://generativelanguage.googleapis.com',
      },
      {
        'id': 4,
        'name': 'local',
        'display_name': 'Local · Llama 3.1 70B',
        'type': 'local',
        'is_active': false,
        'is_available': true,
        'api_endpoint': 'http://localhost:11434',
      },
    ];
    return base.map((m) {
      final id = m['id'] as int;
      final patched = Map<String, dynamic>.from(m);
      patched['is_active'] =
          _resolveProviderActive(id, m['is_active'] as bool);
      return AiProvider.fromJson(patched);
    }).toList();
  }

  static PagedResult<AiBot> aiBots() {
    final raw = [
          {
            'id': 1,
            'name': 'tarot-reader',
            'display_name': 'Tarot Reader',
            'description': 'ทำนายไพ่ทาโรต์ผ่าน LINE OA',
            'avatar_url': null,
            'provider': {'name': 'OpenAI'},
            'model': {'name': 'gpt-4o'},
            'line_oa': {'is_connected': true},
            'is_active': true,
            'is_public': true,
            'is_rentable': false,
          },
          {
            'id': 2,
            'name': 'content-writer',
            'display_name': 'Content Writer',
            'description': 'เขียนเนื้อหา blog/social',
            'avatar_url': null,
            'provider': {'name': 'Anthropic'},
            'model': {'name': 'claude-sonnet-4-6'},
            'line_oa': {'is_connected': false},
            'is_active': true,
            'is_public': true,
            'is_rentable': true,
          },
          {
            'id': 3,
            'name': 'customer-support',
            'display_name': 'Customer Support',
            'description': 'ตอบคำถามลูกค้าผ่าน LINE',
            'avatar_url': null,
            'provider': {'name': 'Google'},
            'model': {'name': 'gemini-2.0-flash'},
            'line_oa': {'is_connected': true},
            'is_active': true,
            'is_public': false,
            'is_rentable': false,
          },
          {
            'id': 4,
            'name': 'image-generator',
            'display_name': 'Image Generator',
            'description': 'สร้างภาพจาก prompt',
            'avatar_url': null,
            'provider': {'name': 'OpenAI'},
            'model': {'name': 'dall-e-3'},
            'line_oa': {'is_connected': false},
            'is_active': false,
            'is_public': true,
            'is_rentable': true,
          },
        ];
    final patched = raw.map((m) {
      final id = m['id'] as int;
      final m2 = Map<String, dynamic>.from(m);
      m2['is_active'] = _resolveBotActive(id, m['is_active'] as bool);
      return m2;
    }).toList();
    return PagedResult.fromJson<AiBot>(
      {
        'data': patched,
        'current_page': 1,
        'last_page': 3,
        'total': 12,
      },
      AiBot.fromJson,
    );
  }

  static List<TimeseriesPoint> aiTimeseries() {
    // 24-hour shape: low overnight, peak ~14-18:00
    const shape = [12, 18, 22, 18, 14, 8, 6, 8, 22, 56, 84, 96, 122, 148, 180, 220, 246, 274, 268, 220, 184, 142, 96, 64];
    return [
      for (int i = 0; i < shape.length; i++)
        TimeseriesPoint.fromJson({
          'time': '${i.toString().padLeft(2, '0')}:00',
          'requests': shape[i],
          'avg_latency_ms': 1200 + (shape[i] * 4),
        }),
    ];
  }

  // ────────────────────────────────────────────────────────────
  // Marketplace
  // ────────────────────────────────────────────────────────────

  static MarketplaceDashboard marketplaceDashboard() => MarketplaceDashboard.fromJson({
        'hero': {
          'total_revenue_thb': 4823000,
          'orders_count': 14230,
          'products_count': 412,
          'pending_commissions_thb': 184200,
        },
        'platforms': [
          {
            'id': 1,
            'name': 'Shopee Mall · ThaiTech',
            'platform': 'shopee',
            'is_active': true,
            'last_sync_at': '2026-05-17T11:42:00Z',
          },
          {
            'id': 2,
            'name': 'Lazada · BeautyHouse',
            'platform': 'lazada',
            'is_active': true,
            'last_sync_at': '2026-05-17T11:30:00Z',
          },
          {
            'id': 3,
            'name': 'TikTok Shop · SportZone',
            'platform': 'tiktokshop',
            'is_active': true,
            'last_sync_at': '2026-05-17T10:58:00Z',
          },
        ],
      });

  static PagedResult<MarketplaceProduct> marketplaceProducts() {
    final items = [
      ['iPhone 15 Pro Max', 49900.0, 142, 24, 280.0, 'live', 'shopee'],
      ['AirPods Pro 2', 8990.0, 384, 156, 200.0, 'live', 'shopee'],
      ['MacBook Air M3', 39900.0, 86, 12, 25.0, 'low', 'lazada'],
      ['Samsung Watch6', 12900.0, 58, 0, 0.0, 'out', 'tiktokshop'],
      ['Sony WH-1000XM5', 11990.0, 218, 42, 145.0, 'live', 'lazada'],
      ['Logitech MX Master 3S', 4290.0, 412, 88, 320.0, 'live', 'shopee'],
      ['iPad Air M2', 24900.0, 96, 18, 220.0, 'low', 'shopee'],
      ['Galaxy Buds3 Pro', 8490.0, 184, 64, 40.0, 'live', 'tiktokshop'],
    ];
    return PagedResult.fromJson<MarketplaceProduct>(
      {
        'data': [
          for (int i = 0; i < items.length; i++)
            {
              'id': 800 + i,
              'name': items[i][0],
              'price_thb': items[i][1],
              'sold': items[i][2],
              'stock': items[i][3],
              'hue': items[i][4],
              'status': items[i][5],
              'platform': items[i][6],
            }
        ],
        'current_page': 1,
        'last_page': 32,
        'total': 412,
      },
      MarketplaceProduct.fromJson,
    );
  }

  static PagedResult<MarketplaceOrder> marketplaceOrders() {
    final items = [
      ['SP-148201', 'shopee', 'สมชาย ใจดี', 49900.0, 2495.0, 'processing', 'paid'],
      ['SP-148198', 'shopee', 'Lisa Anderson', 8990.0, 449.0, 'delivered', 'paid'],
      ['LZ-92041', 'lazada', 'ภาคิน ทรัพย์ทวี', 12900.0, 645.0, 'pending', 'pending'],
      ['TT-31204', 'tiktokshop', 'Mei Wong', 39900.0, 1995.0, 'processing', 'paid'],
      ['SP-148195', 'shopee', 'ปนัดดา วงศ์สุข', 1290.0, 64.0, 'cancelled', 'pending'],
      ['LZ-92038', 'lazada', 'Carlos Rivera', 5290.0, 264.0, 'delivered', 'paid'],
    ];
    return PagedResult.fromJson<MarketplaceOrder>(
      {
        'data': [
          for (int i = 0; i < items.length; i++)
            {
              'id': 700 + i,
              'order_number': items[i][0],
              'platform': items[i][1],
              'customer_name': items[i][2],
              'total_amount': items[i][3],
              'commission_amount': items[i][4],
              'order_status': items[i][5],
              'payment_status': items[i][6],
              'ordered_at': '2026-05-17T${(8 + i).toString().padLeft(2, '0')}:30:00Z',
            }
        ],
        'current_page': 1,
        'last_page': 24,
        'total': 14230,
      },
      MarketplaceOrder.fromJson,
    );
  }

  // ────────────────────────────────────────────────────────────
  // Analytics
  // ────────────────────────────────────────────────────────────

  static AnalyticsOverview analytics(String period) {
    final days = switch (period) {
      'today' => 1,
      'week' => 7,
      _ => 30,
    };
    // Realistic-looking trend (rising)
    final revenue = [
      for (int i = 0; i < days; i++)
        {
          'date': '2026-04-${(20 - i).toString().padLeft(2, '0')}',
          'value': 280000.0 + (i * 14000) + (i.isEven ? 28000 : -18000),
        }
    ].reversed.toList();
    final users = [
      for (int i = 0; i < days; i++)
        {
          'date': '2026-04-${(20 - i).toString().padLeft(2, '0')}',
          'value': 18.0 + (i * 1.4) + (i.isEven ? 4 : -2),
        }
    ].reversed.toList();
    return AnalyticsOverview.fromJson({
      'revenue_trend': revenue,
      'user_growth': users,
      'top_metrics': {
        'orders_count': period == 'today' ? 286 : (period == 'week' ? 2104 : 14230),
        'orders_revenue_thb': period == 'today' ? 284000 : (period == 'week' ? 1820000 : 12840000),
        'avg_order_value_thb': 1284,
        'unique_buyers': period == 'today' ? 238 : (period == 'week' ? 1620 : 9840),
      },
    });
  }
}
