import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Dashboard data class — mirror ของ /api/admin/dashboard response
class DashboardData {
  DashboardData({
    required this.heroRevenue,
    required this.heroLastMonthRevenue,
    required this.heroGrowthPct,
    required this.totalUsers,
    required this.newUsersToday,
    required this.ordersTotal,
    required this.ordersPending,
    required this.pendingWithdrawals,
    required this.sparkline,
    required this.quickActionApprovals,
    required this.quickActionWithdrawals,
    required this.quickActionKyc,
  });

  final double heroRevenue;
  final double heroLastMonthRevenue;
  final double heroGrowthPct;
  final int totalUsers;
  final int newUsersToday;
  final int ordersTotal;
  final int ordersPending;
  final int pendingWithdrawals;
  final List<SparklinePoint> sparkline;
  final int quickActionApprovals;
  final int quickActionWithdrawals;
  final int quickActionKyc;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final hero = (json['hero'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stats = (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final spark = (json['sparkline'] as List?) ?? const [];
    final quick =
        (json['quick_actions'] as Map?)?.cast<String, dynamic>() ?? const {};

    return DashboardData(
      heroRevenue: ((hero['monthly_revenue'] as num?) ?? 0).toDouble(),
      heroLastMonthRevenue:
          ((hero['last_month_revenue'] as num?) ?? 0).toDouble(),
      heroGrowthPct: ((hero['revenue_growth_pct'] as num?) ?? 0).toDouble(),
      totalUsers: ((stats['total_users'] as num?) ?? 0).toInt(),
      newUsersToday: ((stats['new_users_today'] as num?) ?? 0).toInt(),
      ordersTotal: ((stats['orders_total'] as num?) ?? 0).toInt(),
      ordersPending: ((stats['orders_pending'] as num?) ?? 0).toInt(),
      pendingWithdrawals: ((stats['pending_withdrawals'] as num?) ?? 0).toInt(),
      sparkline: spark
          .whereType<Map>()
          .map((m) => SparklinePoint.fromJson(m.cast<String, dynamic>()))
          .toList(),
      quickActionApprovals: ((quick['approvals'] as num?) ?? 0).toInt(),
      quickActionWithdrawals: ((quick['withdrawals'] as num?) ?? 0).toInt(),
      quickActionKyc: ((quick['kyc_pending'] as num?) ?? 0).toInt(),
    );
  }
}

class SparklinePoint {
  SparklinePoint(
      {required this.date, required this.count, required this.total});
  final String date;
  final int count;
  final double total;
  factory SparklinePoint.fromJson(Map<String, dynamic> json) => SparklinePoint(
        date: (json['date'] ?? '').toString(),
        count: ((json['count'] as num?) ?? 0).toInt(),
        total: ((json['total'] as num?) ?? 0).toDouble(),
      );
}

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<DashboardData> fetch() async {
    final json = await _api.get<Map<String, dynamic>>(
      '/dashboard',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return DashboardData.fromJson(json);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return DashboardRepository(api);
});

final dashboardDataProvider = FutureProvider<DashboardData>((ref) {
  return ref.watch(dashboardRepositoryProvider).fetch();
});
