import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/orb_3d.dart';
import '../data/ai_repository.dart';
import '../data/models/ai_models.dart';

/// AI Management Screen
///
/// Layout (per design handoff screens-4.jsx):
/// - Dark bg #020617
/// - Hero: "Central AI Brain" + glowing orb 130px + 3-stat (tokens, cost, cache hit)
/// - Providers list: 4 providers with progress bar (quota %) + cost
/// - Bots grid 2-col: name, model, toggle
/// - Live Inference graph at bottom
class AiManagementScreen extends ConsumerWidget {
  const AiManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(aiDashboardProvider);
    final providersAsync = ref.watch(aiProvidersListProvider);
    final botsAsync = ref.watch(aiBotsListProvider);
    final tsAsync = ref.watch(aiTimeseriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('AI Management 🧠'),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Radial bg gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.7),
                  radius: 1.2,
                  colors: [Color(0xFF1E1B4B), Color(0xFF020617)],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          // Neural network — simple decorative dots
          Positioned.fill(
            child: CustomPaint(painter: _NeuralNetworkPainter()),
          ),

          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(aiDashboardProvider);
              ref.invalidate(aiProvidersListProvider);
              ref.invalidate(aiBotsListProvider);
              ref.invalidate(aiTimeseriesProvider);
              await ref.read(aiDashboardProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                // ── Hero: Central AI Brain ──
                _heroBrain(context, dashAsync),

                const SizedBox(height: 20),

                // ── Providers ──
                _sectionHeader('AI Providers', subtitle: 'แหล่งโมเดลที่เปิดใช้งาน'),
                const SizedBox(height: 10),
                _providersSection(context, ref, providersAsync),

                const SizedBox(height: 20),

                // ── Bots grid ──
                _sectionHeader('AI Bots', subtitle: 'บอทที่ active ในระบบ'),
                const SizedBox(height: 10),
                _botsSection(context, ref, botsAsync),

                const SizedBox(height: 20),

                // ── Live Inference graph ──
                _sectionHeader('Live Inference', subtitle: 'การเรียกใช้ AI 24 ชั่วโมงล่าสุด'),
                const SizedBox(height: 10),
                _inferenceChart(tsAsync, dashAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Sections
  // ────────────────────────────────────────────────────────────

  Widget _heroBrain(BuildContext context, AsyncValue<AiDashboardData> dashAsync) {
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    final num = NumberFormat.compact();

    return GlassCard(
      fillOpacity: 0.06,
      borderOpacity: 0.18,
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const Center(child: Orb3D(size: 130, hue: 270)),
          const SizedBox(height: 18),
          const Text(
            'Central AI Brain',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dashAsync.maybeWhen(
              data: (d) => 'ระบบ AI ${d.botsActive}/${d.botsTotal} bots active',
              orElse: () => 'กำลังโหลด...',
            ),
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 22),

          // 3-stat row
          dashAsync.when(
            data: (d) => Row(
              children: [
                _statCol('Tokens', num.format(d.totalTokens), const Color(0xFF7C3AED)),
                _divider(),
                _statCol('ค่าใช้จ่าย', money.format(d.totalCostThb), AppColors.goldStart),
                _divider(),
                _statCol('Cache Hit', '${d.cacheHitPct.toStringAsFixed(0)}%', AppColors.cyanStart),
              ],
            ),
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              e is ApiException ? e.message : 'โหลดข้อมูลไม่สำเร็จ',
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providersSection(BuildContext context, WidgetRef ref, AsyncValue<List<AiProvider>> async) {
    return async.when(
      data: (providers) {
        if (providers.isEmpty) {
          return const _EmptyHint(label: 'ยังไม่มี AI provider เปิดใช้งาน');
        }
        return Column(
          children: providers.map((p) => _providerCard(context, ref, p)).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyHint(label: e is ApiException ? e.message : 'โหลดไม่สำเร็จ'),
    );
  }

  Widget _providerCard(BuildContext context, WidgetRef ref, AiProvider p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        fillOpacity: 0.05,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Color avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(p.brandColorHex),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(p.brandColorHex).withValues(alpha: 0.5),
                    blurRadius: 14,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    p.type,
                    style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
                  ),
                ],
              ),
            ),
            // Toggle
            Switch.adaptive(
              value: p.isActive,
              activeThumbColor: AppColors.goldStart,
              onChanged: (v) => _toggleProvider(context, ref, p),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleProvider(BuildContext context, WidgetRef ref, AiProvider p) async {
    try {
      await ref.read(aiRepositoryProvider).toggleProvider(p.id);
      ref.invalidate(aiProvidersListProvider);
      ref.invalidate(aiDashboardProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _botsSection(BuildContext context, WidgetRef ref, AsyncValue async) {
    return async.when(
      data: (page) {
        final bots = (page as dynamic).items as List<AiBot>;
        if (bots.isEmpty) return const _EmptyHint(label: 'ยังไม่มี AI bot');
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: bots.take(6).map((b) => _botCard(context, ref, b)).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyHint(label: e is ApiException ? e.message : 'โหลดไม่สำเร็จ'),
    );
  }

  Widget _botCard(BuildContext context, WidgetRef ref, AiBot b) {
    final accent = _hueForBot(b);
    return GlassCard(
      fillOpacity: 0.05,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayBall(size: 36, hue: accent, saturation: 0.75, lightness: 0.6),
              const Spacer(),
              Switch.adaptive(
                value: b.isActive,
                activeThumbColor: AppColors.success,
                onChanged: (v) => _toggleBot(context, ref, b),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            b.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            b.modelName ?? b.providerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10),
          ),
          const Spacer(),
          if (b.lineConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF06C755).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'LINE OA',
                style: TextStyle(color: Color(0xFF06C755), fontSize: 9, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleBot(BuildContext context, WidgetRef ref, AiBot b) async {
    try {
      await ref.read(aiRepositoryProvider).toggleBot(b.id);
      ref.invalidate(aiBotsListProvider);
      ref.invalidate(aiDashboardProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _inferenceChart(AsyncValue<List<TimeseriesPoint>> tsAsync, AsyncValue<AiDashboardData> dashAsync) {
    return GlassCard(
      fillOpacity: 0.06,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              dashAsync.maybeWhen(
                data: (d) => Text(
                  '${d.requestsPerMin} req/min · p95 ${(d.p95LatencyMs / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                orElse: () => const Text('—', style: TextStyle(color: Colors.white)),
              ),
              const Spacer(),
              dashAsync.maybeWhen(
                data: (d) => Text(
                  d.errorsPct > 0 ? 'errors ${d.errorsPct}%' : 'all OK',
                  style: TextStyle(
                    color: d.errorsPct > 1 ? AppColors.error : AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                orElse: () => const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: tsAsync.when(
              data: (series) {
                if (series.isEmpty) {
                  return const Center(
                    child: Text(
                      'ยังไม่มีข้อมูล (ai_request_logs ว่าง)',
                      style: TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
                    ),
                  );
                }
                final spots = [
                  for (int i = 0; i < series.length; i++)
                    FlSpot(i.toDouble(), series[i].requests.toDouble())
                ];
                return LineChart(LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [AppColors.purpleStart, AppColors.pinkStart],
                      ),
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.purpleStart.withValues(alpha: 0.4),
                            AppColors.purpleStart.withValues(alpha: 0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ));
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        height: 28,
        width: 1,
        color: Colors.white.withValues(alpha: 0.15),
      );

  double _hueForBot(AiBot b) {
    // hue ตามชื่อ provider
    final p = b.providerName.toLowerCase();
    if (p.contains('openai')) return 160;
    if (p.contains('anthropic') || p.contains('claude')) return 25;
    if (p.contains('google') || p.contains('gemini')) return 220;
    if (p.contains('llama') || p.contains('local')) return 270;
    return 300;
  }
}

/// Dot pattern for AI background
class _NeuralNetworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);

    final nodes = <Offset>[
      Offset(size.width * 0.15, 80),
      Offset(size.width * 0.5, 120),
      Offset(size.width * 0.85, 90),
      Offset(size.width * 0.25, 200),
      Offset(size.width * 0.75, 220),
      Offset(size.width * 0.5, 260),
    ];

    // dots
    for (final n in nodes) {
      canvas.drawCircle(n, 1.5, dotPaint);
    }

    // lines
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        if ((nodes[i] - nodes[j]).distance < size.width * 0.5) {
          canvas.drawLine(nodes[i], nodes[j], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x88FFFFFF)),
          ),
        ),
      );
}
