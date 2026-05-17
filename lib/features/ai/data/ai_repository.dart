import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/mock/mock_config.dart';
import '../../../core/mock/mock_data.dart';
import '../../finance/data/finance_repository.dart' show PagedResult;
import 'models/ai_models.dart';

/// Repository สำหรับ /api/admin/ai/*
class AiRepository {
  AiRepository(this._api);
  final ApiClient _api;

  // ── Dashboard ──
  Future<AiDashboardData> dashboard({String period = 'month'}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/ai/dashboard',
      query: {'period': period},
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return AiDashboardData.fromJson(json);
  }

  Future<List<TimeseriesPoint>> timeseries({int hours = 24}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/ai/dashboard/timeseries',
      query: {'hours': hours},
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    final raw = (json['series'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((m) => TimeseriesPoint.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  // ── Providers ──
  Future<List<AiProvider>> providers() async {
    final list = await _api.get<List<dynamic>>(
      '/ai/providers',
      parser: (d) => (d as List).toList(),
    );
    return list
        .whereType<Map>()
        .map((m) => AiProvider.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<AiProvider> toggleProvider(int providerId) async {
    if (kMockMode) {
      Mock.flipProvider(providerId);
      final list = Mock.aiProviders();
      return mockDelay(list.firstWhere((p) => p.id == providerId,
          orElse: () => list.first));
    }
    final json = await _api.post<Map<String, dynamic>>(
      '/ai/providers/$providerId/toggle',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return AiProvider.fromJson(json);
  }

  // ── Bots ──
  Future<PagedResult<AiBot>> bots({int page = 1, String? search, bool? active}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/ai/bots',
      query: {
        'page': page,
        if (search != null && search.isNotEmpty) 'search': search,
        if (active != null) 'active': active ? 1 : 0,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return PagedResult.fromJson<AiBot>(json, AiBot.fromJson);
  }

  Future<AiBot> toggleBot(int botId) async {
    if (kMockMode) {
      Mock.flipBot(botId);
      final page = Mock.aiBots();
      return mockDelay(page.items.firstWhere((b) => b.id == botId,
          orElse: () => page.items.first));
    }
    final json = await _api.post<Map<String, dynamic>>(
      '/ai/bots/$botId/toggle',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return AiBot.fromJson(json);
  }
}

class TimeseriesPoint {
  TimeseriesPoint({required this.time, required this.requests, required this.avgLatencyMs});
  final String time;
  final int requests;
  final int avgLatencyMs;

  factory TimeseriesPoint.fromJson(Map<String, dynamic> json) => TimeseriesPoint(
        time: (json['time'] ?? '').toString(),
        requests: ((json['requests'] as num?) ?? 0).toInt(),
        avgLatencyMs: ((json['avg_latency_ms'] as num?) ?? 0).toInt(),
      );
}

// ── Providers (Riverpod) ──

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AiRepository(api);
});

final aiDashboardProvider = FutureProvider<AiDashboardData>((ref) async {
  if (kMockMode) return mockDelay(Mock.aiDashboard());
  return ref.watch(aiRepositoryProvider).dashboard();
});

final aiProvidersListProvider = FutureProvider<List<AiProvider>>((ref) async {
  if (kMockMode) return mockDelay(Mock.aiProviders());
  return ref.watch(aiRepositoryProvider).providers();
});

final aiBotsListProvider = FutureProvider<PagedResult<AiBot>>((ref) async {
  if (kMockMode) return mockDelay(Mock.aiBots());
  return ref.watch(aiRepositoryProvider).bots();
});

final aiTimeseriesProvider = FutureProvider<List<TimeseriesPoint>>((ref) async {
  if (kMockMode) return mockDelay(Mock.aiTimeseries());
  return ref.watch(aiRepositoryProvider).timeseries();
});
