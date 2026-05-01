import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../finance/data/finance_repository.dart' show PagedResult;

class MarketplaceDashboard {
  MarketplaceDashboard({
    required this.totalRevenueThb,
    required this.ordersCount,
    required this.productsCount,
    required this.pendingCommissionsThb,
    required this.platforms,
  });

  final double totalRevenueThb;
  final int ordersCount;
  final int productsCount;
  final double pendingCommissionsThb;
  final List<MarketplacePlatform> platforms;

  factory MarketplaceDashboard.fromJson(Map<String, dynamic> json) {
    final hero = (json['hero'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ps = (json['platforms'] as List?) ?? const [];
    return MarketplaceDashboard(
      totalRevenueThb: ((hero['total_revenue_thb'] as num?) ?? 0).toDouble(),
      ordersCount: ((hero['orders_count'] as num?) ?? 0).toInt(),
      productsCount: ((hero['products_count'] as num?) ?? 0).toInt(),
      pendingCommissionsThb: ((hero['pending_commissions_thb'] as num?) ?? 0).toDouble(),
      platforms: ps
          .whereType<Map>()
          .map((m) => MarketplacePlatform.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class MarketplacePlatform {
  MarketplacePlatform({
    required this.id,
    required this.name,
    this.platform,
    required this.isActive,
    this.lastSyncAt,
  });
  final int id;
  final String name;
  final String? platform;
  final bool isActive;
  final DateTime? lastSyncAt;

  factory MarketplacePlatform.fromJson(Map<String, dynamic> json) => MarketplacePlatform(
        id: ((json['id'] as num?) ?? 0).toInt(),
        name: (json['name'] as String?) ?? '—',
        platform: json['platform'] as String?,
        isActive: (json['is_active'] as bool?) ?? false,
        lastSyncAt: DateTime.tryParse((json['last_sync_at'] as String?) ?? ''),
      );
}

class MarketplaceOrder {
  MarketplaceOrder({
    required this.id,
    required this.orderNumber,
    this.platform,
    this.customerName,
    required this.totalAmount,
    required this.commissionAmount,
    required this.orderStatus,
    required this.paymentStatus,
    this.orderedAt,
  });

  final int id;
  final String orderNumber;
  final String? platform;
  final String? customerName;
  final double totalAmount;
  final double commissionAmount;
  final String orderStatus;
  final String paymentStatus;
  final DateTime? orderedAt;

  factory MarketplaceOrder.fromJson(Map<String, dynamic> json) => MarketplaceOrder(
        id: ((json['id'] as num?) ?? 0).toInt(),
        orderNumber: (json['order_number'] as String?) ?? '',
        platform: json['platform'] as String?,
        customerName: json['customer_name'] as String?,
        totalAmount: ((json['total_amount'] as num?) ?? 0).toDouble(),
        commissionAmount: ((json['commission_amount'] as num?) ?? 0).toDouble(),
        orderStatus: (json['order_status'] as String?) ?? 'unknown',
        paymentStatus: (json['payment_status'] as String?) ?? 'unknown',
        orderedAt: DateTime.tryParse((json['ordered_at'] as String?) ?? ''),
      );
}

class MarketplaceRepository {
  MarketplaceRepository(this._api);
  final ApiClient _api;

  Future<MarketplaceDashboard> dashboard({String period = 'month'}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/marketplace/dashboard',
      query: {'period': period},
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return MarketplaceDashboard.fromJson(json);
  }

  Future<PagedResult<MarketplaceOrder>> orders({int page = 1, String? status}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/marketplace/orders',
      query: {
        'page': page,
        if (status != null) 'status': status,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return PagedResult.fromJson<MarketplaceOrder>(json, MarketplaceOrder.fromJson);
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(ref.watch(apiClientProvider));
});

final marketplaceDashboardProvider = FutureProvider<MarketplaceDashboard>((ref) {
  return ref.watch(marketplaceRepositoryProvider).dashboard();
});

final marketplaceOrdersProvider = FutureProvider<PagedResult<MarketplaceOrder>>((ref) {
  return ref.watch(marketplaceRepositoryProvider).orders();
});
