/// AI Dashboard summary — from /api/admin/ai/dashboard
class AiDashboardData {
  AiDashboardData({
    required this.totalTokens,
    required this.totalCostThb,
    required this.cacheHitPct,
    required this.providersSummary,
    required this.botsTotal,
    required this.botsActive,
    required this.p95LatencyMs,
    required this.requestsPerMin,
    required this.errorsPct,
  });

  final int totalTokens;
  final double totalCostThb;
  final double cacheHitPct;
  final List<AiProviderBrief> providersSummary;
  final int botsTotal;
  final int botsActive;
  final int p95LatencyMs;
  final int requestsPerMin;
  final double errorsPct;

  factory AiDashboardData.fromJson(Map<String, dynamic> json) {
    final hero = (json['hero'] as Map?)?.cast<String, dynamic>() ?? const {};
    final bots = (json['bots_summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    final inference = (json['inference'] as Map?)?.cast<String, dynamic>() ?? const {};
    final providersRaw = (json['providers_summary'] as List?) ?? const [];

    return AiDashboardData(
      totalTokens: ((hero['total_tokens'] as num?) ?? 0).toInt(),
      totalCostThb: ((hero['total_cost_thb'] as num?) ?? 0).toDouble(),
      cacheHitPct: ((hero['cache_hit_pct'] as num?) ?? 0).toDouble(),
      providersSummary: providersRaw
          .whereType<Map>()
          .map((m) => AiProviderBrief.fromJson(m.cast<String, dynamic>()))
          .toList(),
      botsTotal: ((bots['total'] as num?) ?? 0).toInt(),
      botsActive: ((bots['active'] as num?) ?? 0).toInt(),
      p95LatencyMs: ((inference['p95_latency_ms'] as num?) ?? 0).toInt(),
      requestsPerMin: ((inference['requests_per_min'] as num?) ?? 0).toInt(),
      errorsPct: ((inference['errors_pct'] as num?) ?? 0).toDouble(),
    );
  }
}

class AiProviderBrief {
  AiProviderBrief({
    required this.id,
    required this.name,
    required this.type,
    required this.isAvailable,
    required this.quotaPct,
    required this.costThb,
  });

  final int id;
  final String name;
  final String type;
  final bool isAvailable;
  final double quotaPct;
  final double costThb;

  factory AiProviderBrief.fromJson(Map<String, dynamic> json) => AiProviderBrief(
        id: ((json['id'] as num?) ?? 0).toInt(),
        name: (json['name'] as String?) ?? '',
        type: (json['type'] as String?) ?? '',
        isAvailable: (json['is_available'] as bool?) ?? false,
        quotaPct: ((json['quota_pct'] as num?) ?? 0).toDouble(),
        costThb: ((json['cost_thb'] as num?) ?? 0).toDouble(),
      );
}

/// Full AI Provider — from /api/admin/ai/providers
class AiProvider {
  AiProvider({
    required this.id,
    required this.name,
    required this.displayName,
    required this.type,
    required this.isActive,
    required this.isAvailable,
    this.apiEndpoint,
  });

  final int id;
  final String name;
  final String displayName;
  final String type;
  final bool isActive;
  final bool isAvailable;
  final String? apiEndpoint;

  factory AiProvider.fromJson(Map<String, dynamic> json) => AiProvider(
        id: ((json['id'] as num?) ?? 0).toInt(),
        name: (json['name'] as String?) ?? '',
        displayName: (json['display_name'] as String?) ?? (json['name'] as String?) ?? '',
        type: (json['type'] as String?) ?? '',
        isActive: (json['is_active'] as bool?) ?? false,
        isAvailable: (json['is_available'] as bool?) ?? false,
        apiEndpoint: json['api_endpoint'] as String?,
      );

  /// Brand color hint per provider type (สำหรับ UI)
  /// อ้างอิง design handoff
  int get brandColorHex {
    final t = type.toLowerCase();
    if (t.contains('openai')) return 0xFF10A37F;
    if (t.contains('anthropic') || t.contains('claude')) return 0xFFD97706;
    if (t.contains('google') || t.contains('gemini')) return 0xFF4285F4;
    if (t.contains('llama') || t.contains('local')) return 0xFF7C3AED;
    if (t.contains('huggingface') || t.contains('hf')) return 0xFFFFD21E;
    return 0xFF6366F1; // default indigo
  }
}

/// AI Bot — from /api/admin/ai/bots
class AiBot {
  AiBot({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.avatarUrl,
    required this.providerName,
    this.modelName,
    required this.isActive,
    required this.isPublic,
    required this.isRentable,
    required this.lineConnected,
  });

  final int id;
  final String name;
  final String displayName;
  final String? description;
  final String? avatarUrl;
  final String providerName;
  final String? modelName;
  final bool isActive;
  final bool isPublic;
  final bool isRentable;
  final bool lineConnected;

  factory AiBot.fromJson(Map<String, dynamic> json) {
    final provider = (json['provider'] as Map?)?.cast<String, dynamic>() ?? const {};
    final model = (json['model'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lineOa = (json['line_oa'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AiBot(
      id: ((json['id'] as num?) ?? 0).toInt(),
      name: (json['name'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      providerName: (provider['name'] as String?) ?? 'Unknown',
      modelName: model['name'] as String?,
      isActive: (json['is_active'] as bool?) ?? false,
      isPublic: (json['is_public'] as bool?) ?? false,
      isRentable: (json['is_rentable'] as bool?) ?? false,
      lineConnected: (lineOa['is_connected'] as bool?) ?? false,
    );
  }
}
