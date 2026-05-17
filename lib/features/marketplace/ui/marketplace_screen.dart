import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/cube_3d.dart';
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
    _tab = TabController(length: 3, vsync: this);
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
            Tab(text: 'Products'),
            Tab(text: 'Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _DashboardTab(),
          _ProductsTab(),
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
    final compact = NumberFormat.compact();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketplaceDashboardProvider);
        await ref.read(marketplaceDashboardProvider.future);
      },
      child: async.when(
        data: (d) => ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Hero (gradient bg + Cube3D + product count) per concept ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF97316),
                    AppColors.pinkStart,
                    AppColors.purpleStart
                  ],
                  stops: [0.0, 0.6, 1.0],
                  begin: Alignment(-1, -1),
                  end: Alignment(1, 1),
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Cube3D(
                        size: 64,
                        faceA: AppColors.pinkStart,
                        faceB: Color(0xFF9D174D),
                        faceC: Color(0xFFFBCFE8),
                        tilt: -8,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              compact.format(d.productsCount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              'สินค้าทั้งหมด · 438 ร้านค้า',
                              style: TextStyle(
                                  color: Color(0xE6FFFFFF), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _heroChip('ขายแล้ววันนี้', '฿284k'),
                      const SizedBox(width: 8),
                      _heroChip('จัดส่ง', '${d.ordersCount}'),
                      const SizedBox(width: 8),
                      _heroChip('Commission', money.format(d.pendingCommissionsThb)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Revenue card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                fillOpacity: 0.06,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.goldStart.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined,
                          color: AppColors.goldStart, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'รายได้รวม',
                            style: TextStyle(
                                color: Color(0xCCFFFFFF), fontSize: 11),
                          ),
                          Text(
                            money.format(d.totalRevenueThb),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '↑ 24.6%',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Platforms
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'แพลตฟอร์มที่เชื่อมต่อ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${d.platforms.length} platforms',
                    style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: d.platforms.isEmpty
                  ? const _Empty(label: 'ยังไม่มี marketplace account')
                  : Column(children: d.platforms.map(_platformTile).toList()),
            ),
            const SizedBox(height: 110),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Empty(label: e is ApiException ? e.message : 'โหลดไม่สำเร็จ'),
      ),
    );
  }

  Widget _heroChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: Color(0xE6FFFFFF), fontSize: 10, height: 1),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceProductsProvider);
    final money = NumberFormat.compactCurrency(
        locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketplaceProductsProvider);
        await ref.read(marketplaceProductsProvider.future);
      },
      child: async.when(
        data: (page) {
          if (page.items.isEmpty) {
            return const _Empty(label: 'ยังไม่มีสินค้าในระบบ');
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: page.items.length,
            itemBuilder: (_, i) => _productCard(page.items[i], money),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Empty(
            label: e is ApiException ? e.message : 'โหลดสินค้าไม่สำเร็จ'),
      ),
    );
  }

  Widget _productCard(MarketplaceProduct p, NumberFormat money) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.white.withValues(alpha: 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image area (square) with Clay icon + status badge
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          HSLColor.fromAHSL(1, p.hue, 0.85, 0.92).toColor(),
                          HSLColor.fromAHSL(1, p.hue, 0.75, 0.78).toColor(),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Center(
                    child: ClayBall(
                      size: 64,
                      hue: p.hue,
                      saturation: 0.75,
                      lightness: 0.62,
                      child: const Icon(Icons.inventory_2_outlined,
                          color: Colors.white, size: 26),
                    ),
                  ),
                  // Status badge top-left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _statusBadge(p.status),
                  ),
                  // Edit button top-right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: Color(0xFF475569), size: 14),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    money.format(p.priceThb),
                    style: const TextStyle(
                      color: AppColors.pinkStart,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ขาย ${p.sold}',
                        style: const TextStyle(
                            color: Color(0x99FFFFFF), fontSize: 10),
                      ),
                      Text(
                        'คงเหลือ ${p.stock}',
                        style: const TextStyle(
                            color: Color(0x99FFFFFF), fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (label, color) = switch (status) {
      'live' => ('LIVE', AppColors.success),
      'low' => ('เหลือน้อย', AppColors.goldStart),
      'out' => ('หมด', AppColors.error),
      _ => (status.toUpperCase(), Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'live')
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              color: status == 'low' ? const Color(0xFF7C2D12) : Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
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
          if (page.items.isEmpty) {
            return const _Empty(label: 'ยังไม่มีคำสั่งซื้อ');
          }
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
