import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/mock/mock_config.dart';
import '../../../core/mock/mock_data.dart';

class AnalyticsOverview {
  AnalyticsOverview({
    required this.revenueTrend,
    required this.userGrowth,
    required this.ordersCount,
    required this.ordersRevenueThb,
    required this.avgOrderValueThb,
    required this.uniqueBuyers,
  });

  final List<TimePoint> revenueTrend;
  final List<TimePoint> userGrowth;
  final int ordersCount;
  final double ordersRevenueThb;
  final double avgOrderValueThb;
  final int uniqueBuyers;

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    final rt = (json['revenue_trend'] as List?) ?? const [];
    final ug = (json['user_growth'] as List?) ?? const [];
    final tm = (json['top_metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AnalyticsOverview(
      revenueTrend: rt
          .whereType<Map>()
          .map((m) => TimePoint.fromJson(m.cast<String, dynamic>()))
          .toList(),
      userGrowth: ug
          .whereType<Map>()
          .map((m) => TimePoint.fromJson(m.cast<String, dynamic>()))
          .toList(),
      ordersCount: ((tm['orders_count'] as num?) ?? 0).toInt(),
      ordersRevenueThb: ((tm['orders_revenue_thb'] as num?) ?? 0).toDouble(),
      avgOrderValueThb: ((tm['avg_order_value_thb'] as num?) ?? 0).toDouble(),
      uniqueBuyers: ((tm['unique_buyers'] as num?) ?? 0).toInt(),
    );
  }
}

class TimePoint {
  TimePoint({required this.date, required this.value});
  final String date;
  final double value;
  factory TimePoint.fromJson(Map<String, dynamic> json) => TimePoint(
        date: (json['date'] ?? '').toString(),
        value: ((json['value'] as num?) ?? 0).toDouble(),
      );
}

class AnalyticsRepository {
  AnalyticsRepository(this._api);
  final ApiClient _api;

  Future<AnalyticsOverview> overview({String period = 'month'}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/analytics/overview',
      query: {'period': period},
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return AnalyticsOverview.fromJson(json);
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(apiClientProvider));
});

final analyticsOverviewProvider =
    FutureProvider.family<AnalyticsOverview, String>((ref, period) async {
  if (kMockMode) return mockDelay(Mock.analytics(period));
  return ref.watch(analyticsRepositoryProvider).overview(period: period);
});
