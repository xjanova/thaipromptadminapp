import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bar_3d.dart';
import '../../../shared/widgets/donut_chart.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/orb_3d.dart';
import '../data/analytics_repository.dart';

/// Analytics Screen — รายงาน & วิเคราะห์
///
/// Layout (per design handoff screens-3.jsx):
/// - Hero gradient bg (cyan → indigo) + Orb3D hue 195
/// - รายได้สุทธิ + growth chip
/// - 3D bar chart (รายวัน 8 แท่ง พร้อม highlight วันที่ peak)
/// - Donut chart (หมวดยอดนิยม) + 3 KPI cards
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
    final money =
        NumberFormat.compactCurrency(locale: 'th_TH', symbol: '฿', decimalDigits: 1);
    final fullMoney =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsOverviewProvider(_period));
          await ref.read(analyticsOverviewProvider(_period).future);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Hero gradient bg ──
            _heroSection(async, money),

            // ── Period chips (overlap hero like floating card) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: _periodChips(),
            ),

            // ── Body ──
            async.when(
              data: (d) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    _barChartCard(d, fullMoney),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 11, child: _donutCard(d, fullMoney)),
                        const SizedBox(width: 10),
                        Expanded(flex: 10, child: _kpiList(d, fullMoney)),
                      ],
                    ),
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(60),
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

  Widget _heroSection(AsyncValue<AnalyticsOverview> async, NumberFormat money) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0891B2), Color(0xFF4F46E5), Color(0xFF7C3AED)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment(-1, -1),
          end: Alignment(1, 1),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bar_chart_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'รายงาน & วิเคราะห์',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Orb3D(size: 70, hue: 195),
                const SizedBox(width: 14),
                Expanded(
                  child: async.when(
                    data: (d) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'รายได้สุทธิ · ${_periodLabel(_period)}',
                          style: const TextStyle(
                              color: Color(0xCCFFFFFF), fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          money.format(d.ordersRevenueThb),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_upward,
                                      size: 10, color: Colors.white),
                                  SizedBox(width: 2),
                                  Text(
                                    '24.6%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'vs ${_period == 'today' ? 'เมื่อวาน' : 'รอบก่อน'}',
                              style: const TextStyle(
                                  color: Color(0xCCFFFFFF), fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => const Text(
                      '—',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChips() {
    return Row(
      children: [
        for (final p in const ['today', 'week', 'month'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _period = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: _period == p
                      ? const LinearGradient(colors: [
                          AppColors.purpleStart,
                          AppColors.pinkStart,
                        ])
                      : null,
                  color: _period == p
                      ? null
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white
                        .withValues(alpha: _period == p ? 0.0 : 0.18),
                  ),
                ),
                child: Text(
                  _periodLabel(p),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _barChartCard(AnalyticsOverview d, NumberFormat money) {
    final points = d.revenueTrend;
    if (points.isEmpty) {
      return GlassCard(
        fillOpacity: 0.06,
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text(
            'ยังไม่มีข้อมูลในช่วงนี้',
            style: TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
          ),
        ),
      );
    }
    // Pick max 8 visible bars (sample evenly)
    final step = (points.length / 8).ceil().clamp(1, points.length);
    final visible = <int>[];
    for (int i = 0; i < points.length; i += step) {
      visible.add(i);
    }
    if (visible.last != points.length - 1) {
      visible.add(points.length - 1);
    }
    final maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    // Find peak index (within visible)
    int peakIdx = 0;
    double peakVal = 0;
    for (final i in visible) {
      if (points[i].value > peakVal) {
        peakVal = points[i].value;
        peakIdx = i;
      }
    }

    return GlassCard(
      fillOpacity: 0.06,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ยอดขายรายวัน',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _legendDot(const Color(0xFF818CF8), 'ปกติ'),
              const SizedBox(width: 8),
              _legendDot(AppColors.pinkStart, 'Peak'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < visible.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Expanded(
                            child: Bar3D(
                              heightFraction: (points[visible[i]].value / maxVal),
                              gradient: visible[i] == peakIdx
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFF472B6),
                                        AppColors.pinkStart,
                                        AppColors.pinkEnd,
                                      ],
                                      stops: [0.0, 0.7, 1.0],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : null,
                              highlight: visible[i] == peakIdx,
                              label: visible[i] == peakIdx
                                  ? money.format(peakVal).replaceAll(',', '')
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _shortDate(points[visible[i]].date, i == visible.length - 1),
                            style: const TextStyle(
                                color: Color(0x99FFFFFF),
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _donutCard(AnalyticsOverview d, NumberFormat money) {
    const segs = [
      DonutSegment(0.40, Color(0xFF6366F1), 'อิเล็กฯ'),
      DonutSegment(0.28, AppColors.pinkStart, 'แฟชั่น'),
      DonutSegment(0.20, AppColors.goldStart, 'อาหาร'),
      DonutSegment(0.12, AppColors.cyanStart, 'อื่นๆ'),
    ];
    final total = money.format(d.ordersRevenueThb * 0.4);
    return GlassCard(
      fillOpacity: 0.06,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'หมวดยอดนิยม',
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Center(
            child: DonutChart(
              segments: segs,
              centerLabel: total,
              centerSub: 'รวม',
              size: 124,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in segs) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.label,
                    style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${(s.fraction * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }

  Widget _kpiList(AnalyticsOverview d, NumberFormat money) {
    final kpis = [
      _KpiCard(
        label: 'Conversion',
        value: '4.82%',
        delta: '+0.4',
        color: AppColors.success,
        icon: Icons.local_fire_department_outlined,
      ),
      _KpiCard(
        label: 'AOV',
        value: money.format(d.avgOrderValueThb),
        delta: '+24',
        color: const Color(0xFF6366F1),
        icon: Icons.shopping_bag_outlined,
      ),
      _KpiCard(
        label: 'Refund',
        value: '0.8%',
        delta: '-0.2',
        color: AppColors.success,
        icon: Icons.replay_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < kpis.length; i++) ...[
          GlassCard(
            fillOpacity: 0.06,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: kpis[i].color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(kpis[i].icon, color: kpis[i].color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kpis[i].label,
                        style: const TextStyle(
                            color: Color(0x99FFFFFF), fontSize: 10),
                      ),
                      Text(
                        kpis[i].value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  kpis[i].delta,
                  style: TextStyle(
                    color: kpis[i].color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (i != kpis.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 9),
          ),
        ],
      );

  static String _periodLabel(String p) => switch (p) {
        'today' => 'วันนี้',
        'week' => '7 วัน',
        'month' => '30 วัน',
        _ => p,
      };

  static String _shortDate(String iso, bool isLast) {
    if (isLast) return 'วันนี้';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat.d().format(dt);
  }
}

class _KpiCard {
  _KpiCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final String delta;
  final Color color;
  final IconData icon;
}
