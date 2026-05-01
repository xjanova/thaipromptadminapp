import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/marketplace_repository.dart';

/// Marketplace Screen (Shopee/Lazada aggregator)
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace 🛍'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0x99FFFFFF),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.pinkStart, width: 3),
          ),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _DashboardTab(),
          _OrdersTab(),
        ],
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceDashboardProvider);
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketplaceDashboardProvider);
        await ref.read(marketplaceDashboardProvider.future);
      },
      child: async.when(
        data: (d) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Hero stats
            GlassCard(
              fillOpacity: 0.06,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รายได้รวม',
                    style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                  ),
                  Text(
                    money.format(d.totalRevenueThb),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _miniStat('คำสั่งซื้อ', d.ordersCount.toString(), AppColors.pinkStart),
                      _miniStat('สินค้า', d.productsCount.toString(), AppColors.cyanStart),
                      _miniStat('Commission Pending', money.format(d.pendingCommissionsThb), AppColors.goldStart),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Platforms
            const Text(
              'แพลตฟอร์มที่เชื่อมต่อ',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (d.platforms.isEmpty)
              const _Empty(label: 'ยังไม่มี marketplace account ที่เปิดใช้งาน')
            else
              ...d.platforms.map(_platformTile),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Empty(label: e is ApiException ? e.message : 'โหลดไม่สำเร็จ'),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10),
            ),
          ],
        ),
      );

  Widget _platformTile(MarketplacePlatform p) {
    final hue = switch (p.platform) {
      'shopee' => 25.0,
      'lazada' => 280.0,
      'tiktokshop' => 0.0,
      _ => 220.0,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        fillOpacity: 0.05,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClayBall(size: 36, hue: hue, saturation: 0.8, lightness: 0.6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    p.platform ?? 'unknown',
                    style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10),
                  ),
                ],
              ),
            ),
            if (p.lastSyncAt != null)
              Text(
                'sync ${_relativeTime(p.lastSyncAt!)}',
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceOrdersProvider);
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketplaceOrdersProvider);
        await ref.read(marketplaceOrdersProvider.future);
      },
      child: async.when(
        data: (page) {
          if (page.items.isEmpty) return const _Empty(label: 'ยังไม่มีคำสั่งซื้อ');
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: page.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final o = page.items[i];
              return GlassCard(
                fillOpacity: 0.05,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.orderNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${o.customerName ?? '—'} · ${o.platform ?? 'unknown'}',
                            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _statusChip(o.orderStatus),
                              const SizedBox(width: 4),
                              _paymentChip(o.paymentStatus),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money.format(o.totalAmount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '+${money.format(o.commissionAmount)}',
                          style: const TextStyle(
                            color: AppColors.goldStart,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Empty(label: e is ApiException ? e.message : 'โหลดไม่สำเร็จ'),
      ),
    );
  }

  Widget _statusChip(String s) {
    final color = switch (s) {
      'paid' || 'completed' || 'delivered' => AppColors.success,
      'pending' || 'processing' => AppColors.warning,
      'cancelled' || 'rejected' => AppColors.error,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        s,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _paymentChip(String s) {
    final color = s == 'paid' ? AppColors.goldStart : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        s,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(label, style: const TextStyle(color: Color(0x88FFFFFF))),
        ),
      );
}
