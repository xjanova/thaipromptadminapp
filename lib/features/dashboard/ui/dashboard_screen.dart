import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/coin_3d.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_controller.dart';
import '../data/dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final admin = ref.watch(authControllerProvider).admin;
    final dataAsync = ref.watch(dashboardDataProvider);
    final money =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return Scaffold(
      body: Stack(
        children: [
          // Hero gradient bg
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardDataProvider);
                await ref.read(dashboardDataProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                children: [
                  // Top bar
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.goldStart, Color(0xFFF97316)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (admin?.name.isNotEmpty == true
                                  ? admin!.name[0]
                                  : 'A')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF7C2D12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.dashboardWelcome,
                            style: const TextStyle(
                                color: Color(0xD9FFFFFF), fontSize: 11),
                          ),
                          Text(
                            '${admin?.name ?? '-'} · ${admin?.isSuperAdmin == true ? "Super Admin" : (admin?.role ?? 'Admin')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _circleAction(Icons.notifications_none, badge: true),
                      const SizedBox(width: 10),
                      _circleAction(Icons.search),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Hero balance card
                  dataAsync.when(
                    data: (d) => GlassCard(
                      fillOpacity: 0.16,
                      borderOpacity: 0.25,
                      borderRadius: 26,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.dashboardMonthlyRevenue,
                                style: const TextStyle(
                                    color: Color(0xD9FFFFFF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                money.format(d.heroRevenue),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (d.heroGrowthPct >= 0
                                              ? AppColors.success
                                              : AppColors.error)
                                          .withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          d.heroGrowthPct >= 0
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${d.heroGrowthPct.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.dashboardComparedLastMonth,
                                    style: const TextStyle(
                                        color: Color(0xD9FFFFFF), fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (d.sparkline.isNotEmpty)
                                SizedBox(
                                  height: 50,
                                  child: LineChart(LineChartData(
                                    gridData: const FlGridData(show: false),
                                    titlesData: const FlTitlesData(show: false),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: [
                                          for (int i = 0;
                                              i < d.sparkline.length;
                                              i++)
                                            FlSpot(i.toDouble(),
                                                d.sparkline[i].total)
                                        ],
                                        isCurved: true,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFBBF24),
                                            Color(0xFFF97316)
                                          ],
                                        ),
                                        barWidth: 2.5,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFFFBBF24)
                                                  .withValues(alpha: 0.5),
                                              const Color(0xFFFBBF24)
                                                  .withValues(alpha: 0),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )),
                                ),
                            ],
                          ),
                          const Positioned(
                            right: -10,
                            top: -10,
                            child: Coin3D(size: 80),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const _HeroSkeleton(),
                    error: (e, _) => GlassCard(
                      fillOpacity: 0.12,
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 40),
                          const SizedBox(height: 8),
                          Text('โหลดข้อมูลไม่สำเร็จ\n$e',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Stat tiles
                  dataAsync.maybeWhen(
                    data: (d) => GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _statTile(
                            l10n.dashboardStatNewUsers,
                            NumberFormat.compact().format(d.totalUsers),
                            '+${d.newUsersToday} วันนี้',
                            200,
                            Icons.people_outline),
                        _statTile(
                            l10n.dashboardStatOrders,
                            NumberFormat.compact().format(d.ordersTotal),
                            'รอจัดส่ง ${d.ordersPending}',
                            25,
                            Icons.shopping_bag_outlined),
                        _statTile(
                            'ถอนเงินรอ',
                            d.pendingWithdrawals.toString(),
                            'รออนุมัติ',
                            35,
                            Icons.account_balance_wallet_outlined),
                        _statTile('KYC', d.quickActionKyc.toString(), 'รอตรวจ',
                            280, Icons.verified_user_outlined),
                      ],
                    ),
                    orElse: () => const SizedBox(),
                  ),

                  const SizedBox(height: 18),

                  // Quick actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.dashboardQuickActions,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/modules'),
                        child: Text(
                          l10n.dashboardSeeAll,
                          style: const TextStyle(
                            color: AppColors.purpleStart,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  dataAsync.maybeWhen(
                    data: (d) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _quickAction(d.quickActionApprovals.toString(),
                            'อนุมัติ', 130, () => context.go('/finance')),
                        _quickAction(d.quickActionWithdrawals.toString(),
                            'ถอนเงิน', 35, () => context.go('/finance')),
                        _quickAction(
                            d.quickActionKyc.toString(), 'KYC', 200, () {}),
                        _quickAction('5', 'รายงาน', 280, () {}),
                      ],
                    ),
                    orElse: () => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleAction(IconData icon, {bool badge = false}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          if (badge)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.goldStart,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6D28D9), width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statTile(
      String label, String value, String sub, double hue, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClayBall(
            size: 38,
            hue: hue,
            saturation: 0.85,
            lightness: 0.6,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: HSLColor.fromAHSL(1, hue, 0.7, 0.45).toColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(
      String value, String label, double hue, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          ClayBall(
            size: 50,
            hue: hue,
            saturation: 0.75,
            lightness: 0.62,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      fillOpacity: 0.16,
      borderRadius: 26,
      child: SizedBox(
        height: 130,
        child: Center(
          child: CircularProgressIndicator(
              color: Colors.white.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}
