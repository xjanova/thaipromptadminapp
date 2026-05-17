// AI Pool models — มาจาก backend table `ai_api_keys`
//
// อ้างอิงจาก brain:
// [[Session 2026-05-13 — Fortune AI Pool-first + Health Gate + Auto-Recovery]]
//
// Architecture:
// - แต่ละ key มี provider/model/key + priority + purposes (รองรับหลาย)
// - rotation_mode 6 แบบ: round_robin / least_used / smart / priority /
//   random / failover (อ้างอิงจาก `config/ai.php`)
// - Health gate: ต้อง `last_test_passed_at != null` ถึงจะอยู่ใน available pool
//   ([[Session 2026-05-13]] migration 2026_05_13_200000_add_test_passed_at)
// - Cross-provider tier: priority เดียวกัน → vote ตาม global mode

class AiApiKey {
  AiApiKey({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.model,
    required this.priority,
    required this.purposes,
    required this.isActive,
    this.lastTestPassedAt,
    this.lastTestErrorAt,
    this.costThbToday,
    this.quotaPct,
    this.usageCount,
    this.note,
  });

  final int id;
  final String provider; // 'openai' | 'anthropic' | 'google' | 'local' | 'huggingface'
  final String displayName;
  final String model;
  final int priority; // 1 = highest
  final List<String> purposes; // prediction_celtic / prediction_deep / vision / chat / banner
  final bool isActive;
  final DateTime? lastTestPassedAt;
  final DateTime? lastTestErrorAt;
  final double? costThbToday;
  final double? quotaPct; // 0..100
  final int? usageCount;
  final String? note;

  factory AiApiKey.fromJson(Map<String, dynamic> json) => AiApiKey(
        id: ((json['id'] as num?) ?? 0).toInt(),
        provider: (json['provider'] as String?) ?? '',
        displayName:
            (json['display_name'] as String?) ?? (json['provider'] as String?) ?? '',
        model: (json['model'] as String?) ?? '',
        priority: ((json['priority'] as num?) ?? 99).toInt(),
        purposes: ((json['purposes'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        isActive: (json['is_active'] as bool?) ?? true,
        lastTestPassedAt:
            DateTime.tryParse((json['last_test_passed_at'] as String?) ?? ''),
        lastTestErrorAt:
            DateTime.tryParse((json['last_test_error_at'] as String?) ?? ''),
        costThbToday: (json['cost_thb_today'] as num?)?.toDouble(),
        quotaPct: (json['quota_pct'] as num?)?.toDouble(),
        usageCount: (json['usage_count'] as num?)?.toInt(),
        note: json['note'] as String?,
      );

  /// Healthy ถ้ามี test ผ่านล่าสุด + ไม่ถูก disable
  bool get isHealthy => isActive && lastTestPassedAt != null;

  /// brand color per provider (สำหรับ UI)
  int get brandColorHex {
    final p = provider.toLowerCase();
    if (p.contains('openai')) return 0xFF10A37F;
    if (p.contains('anthropic') || p.contains('claude')) return 0xFFD97706;
    if (p.contains('google') || p.contains('gemini')) return 0xFF4285F4;
    if (p.contains('huggingface') || p.contains('hf')) return 0xFFFFD21E;
    if (p.contains('local') || p.contains('llama')) return 0xFF7C3AED;
    return 0xFF6366F1;
  }

  String get providerLabel {
    final p = provider.toLowerCase();
    if (p.contains('openai')) return 'OpenAI';
    if (p.contains('anthropic') || p.contains('claude')) return 'Anthropic';
    if (p.contains('google') || p.contains('gemini')) return 'Google';
    if (p.contains('huggingface') || p.contains('hf')) return 'HuggingFace';
    if (p.contains('local') || p.contains('llama')) return 'Local';
    return provider;
  }
}

/// Global pool settings — รวม cross_provider_rotation_mode
class AiPoolSettings {
  AiPoolSettings({
    required this.globalMode,
    required this.totalKeys,
    required this.healthyKeys,
  });

  /// 'round_robin' | 'least_used' | 'smart' | 'priority' | 'random' | 'failover'
  final String globalMode;
  final int totalKeys;
  final int healthyKeys;

  factory AiPoolSettings.fromJson(Map<String, dynamic> json) => AiPoolSettings(
        globalMode: (json['global_mode'] as String?) ?? 'priority',
        totalKeys: ((json['total_keys'] as num?) ?? 0).toInt(),
        healthyKeys: ((json['healthy_keys'] as num?) ?? 0).toInt(),
      );
}

class AiKeyPatch {
  AiKeyPatch({this.isActive, this.priority});
  final bool? isActive;
  final int? priority;
  Map<String, dynamic> toJson() => {
        if (isActive != null) 'is_active': isActive,
        if (priority != null) 'priority': priority,
      };
}

/// Rotation modes available (per `config/ai.php`)
const aiPoolRotationModes = [
  AiRotationMode(
    key: 'priority',
    label: 'Priority',
    description: 'ใช้ตาม priority ก่อนเสมอ (เสถียร)',
  ),
  AiRotationMode(
    key: 'round_robin',
    label: 'Round Robin',
    description: 'เวียนตามลำดับ — กระจายโหลด',
  ),
  AiRotationMode(
    key: 'least_used',
    label: 'Least Used',
    description: 'เลือกตัวที่ใช้น้อยที่สุดในช่วงเวลา',
  ),
  AiRotationMode(
    key: 'smart',
    label: 'Smart',
    description: 'พิจารณา priority + usage + health',
  ),
  AiRotationMode(
    key: 'random',
    label: 'Random',
    description: 'สุ่มจาก keys ที่ available',
  ),
  AiRotationMode(
    key: 'failover',
    label: 'Failover',
    description: 'ใช้ตัวแรก — ถ้าพังค่อยข้ามไปตัวถัดไป',
  ),
];

class AiRotationMode {
  const AiRotationMode({
    required this.key,
    required this.label,
    required this.description,
  });
  final String key;
  final String label;
  final String description;
}

/// Purposes — ใช้กรอง keys ที่ใช้ได้ตามวัตถุประสงค์
const aiPoolPurposes = [
  AiPurpose(
    key: 'prediction_celtic',
    label: 'Celtic 99฿',
    icon: 'celtic',
    description: 'Tarot 10-card spread (premium)',
  ),
  AiPurpose(
    key: 'prediction_deep',
    label: 'Deep 39฿',
    icon: 'deep',
    description: 'การทำนายเชิงลึก',
  ),
  AiPurpose(
    key: 'vision',
    label: 'Vision',
    icon: 'vision',
    description: 'อ่านรูปภาพ (Celtic + ลายมือ)',
  ),
  AiPurpose(
    key: 'chat',
    label: 'Chat',
    icon: 'chat',
    description: 'พูดคุยทั่วไป · ตอบสั้น',
  ),
  AiPurpose(
    key: 'banner',
    label: 'Banner/Misc',
    icon: 'banner',
    description: 'Banner generation · auxiliary tasks',
  ),
];

class AiPurpose {
  const AiPurpose({
    required this.key,
    required this.label,
    required this.icon,
    required this.description,
  });
  final String key;
  final String label;
  final String icon;
  final String description;
}
