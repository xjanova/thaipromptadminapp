import '../../features/ai/data/ai_repository.dart' show TimeseriesPoint;
import '../../features/ai/data/models/ai_models.dart';
import '../../features/analytics/data/analytics_repository.dart';
import '../../features/auth/data/models/admin_user.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/finance/data/finance_repository.dart';
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

  static FortuneDashboardData fortuneDashboard() => FortuneDashboardData.fromJson({
        'hero': {
          'monthly_revenue_thb': 882000,
          'sessions_count': 6720,
          'avg_rating': 4.86,
          'active_now': 142,
        },
        'services_summary': [
          {
            'id': 1,
            'name': 'ไพ่ทาโรต์ AI',
            'slug': 'tarot',
            'color': '#a855f7',
            'icon': null,
            'sessions': 2840,
            'revenue_thb': 384000,
            'is_active': true,
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
          },
        ],
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
