import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../finance/data/finance_repository.dart' show PagedResult;
import 'models/fortune_models.dart';

/// Repository สำหรับ /api/admin/fortune/*
class FortuneRepository {
  FortuneRepository(this._api);
  final ApiClient _api;

  Future<FortuneDashboardData> dashboard({String period = 'month'}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/fortune/dashboard',
      query: {'period': period},
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return FortuneDashboardData.fromJson(json);
  }

  Future<PagedResult<FortuneReading>> readings({
    int page = 1,
    String? search,
    bool? isPaid,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/fortune/readings',
      query: {
        'page': page,
        if (search != null && search.isNotEmpty) 'search': search,
        if (isPaid != null) 'is_paid': isPaid ? 1 : 0,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return PagedResult.fromJson<FortuneReading>(json, FortuneReading.fromJson);
  }

  Future<Map<String, dynamic>> readingStats() async {
    return _api.get<Map<String, dynamic>>(
      '/fortune/readings/stats',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
  }
}

final fortuneRepositoryProvider = Provider<FortuneRepository>((ref) {
  return FortuneRepository(ref.watch(apiClientProvider));
});

final fortuneDashboardProvider = FutureProvider<FortuneDashboardData>((ref) {
  return ref.watch(fortuneRepositoryProvider).dashboard();
});

final fortuneReadingsProvider = FutureProvider<PagedResult<FortuneReading>>((ref) {
  return ref.watch(fortuneRepositoryProvider).readings();
});
