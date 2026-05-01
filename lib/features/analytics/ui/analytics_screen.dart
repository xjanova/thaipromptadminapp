import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/analytics_repository.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(analyticsOverviewProvider(_period));
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    final compact = NumberFormat.compact();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics 📊'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider(_period));
          await ref.read(analyticsOverviewProvider(_period).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Period selector
            Row(
              children: [
                for (final p in const ['today', 'week', 'month'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_periodLabel(p)),
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                      selectedColor: AppColors.purpleStart,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            async.when(
              data: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top metrics grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      _metricCard('คำสั่งซื้อ', compact.format(d.ordersCount), AppColors.cyanStart),
                      _metricCard('รายได้', money.format(d.ordersRevenueThb), AppColors.goldStart),
                      _metricCard('AOV', money.format(d.avgOrderValueThb), AppColors.success),
                      _metricCard('ผู้ซื้อ unique', compact.format(d.uniqueBuyers), AppColors.purpleStart),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Revenue trend
                  _chartCard(
                    title: 'รายได้ Commission ${_periodLabel(_period)}',
                    subtitle: 'รายวัน (THB)',
                    points: d.revenueTrend,
                    lineColor: AppColors.goldStart,
                  ),
                  const SizedBox(height: 14),

                  // User growth
                  _chartCard(
                    title: 'สมาชิกใหม่ ${_periodLabel(_period)}',
                    subtitle: 'รายวัน',
                    points: d.userGrowth,
                    lineColor: AppColors.purpleStart,
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  e is ApiException ? e.message : 'โหลดข้อมูลไม่สำเร็จ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0x99FFFFFF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(String p) => switch (p) {
        'today' => 'วันนี้',
        'week' => '7 วัน',
        'month' => '30 วัน',
        _ => p,
      };

  Widget _metricCard(String label, String value, Color color) {
    return GlassCard(
      fillOpacity: 0.06,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required List<TimePoint> points,
    required Color lineColor,
  }) {
    return GlassCard(
      fillOpacity: 0.06,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'ยังไม่มีข้อมูลในช่วงนี้',
                      style: TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
                    ),
                  )
                : LineChart(LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (int i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].value)
                        ],
                        isCurved: true,
                        color: lineColor,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              lineColor.withValues(alpha: 0.4),
                              lineColor.withValues(alpha: 0),
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
    );
  }
}
