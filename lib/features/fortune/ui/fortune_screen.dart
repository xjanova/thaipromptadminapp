import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/crystal_ball.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_text.dart';
import '../../../shared/widgets/starfield.dart';
import '../data/fortune_repository.dart';
import '../data/models/fortune_models.dart';

/// Fortune Screen — ระบบดูดวง & ทาโรต์
///
/// Layout (per design handoff screens-4.jsx):
/// - Cosmic radial bg (#4c1d95 → #1e1b4b → #0f0a1f)
/// - Starfield 60 dots
/// - Crystal ball 110px hero
/// - Title gradient (gold → pink)
/// - 4-stat bar
/// - Service grid 2-col
/// - Recent readings list
class FortuneScreen extends ConsumerWidget {
  const FortuneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(fortuneDashboardProvider);
    final readingsAsync = ref.watch(fortuneReadingsProvider);
    final billStatsAsync = ref.watch(fortuneBillStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0A1F),
      appBar: AppBar(
        title: const Text('ดูดวง & ทาโรต์'),
        backgroundColor: Colors.transparent,
        actions: [
          // Bills shortcut with pending badge
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: billStatsAsync.maybeWhen(
              data: (s) {
                final pending = s.pendingCount + s.paidUnconfirmedCount;
                return _BillShortcutButton(
                  pendingCount: pending,
                  onTap: () => context.push('/fortune/bills'),
                );
              },
              orElse: () => _BillShortcutButton(
                pendingCount: 0,
                onTap: () => context.push('/fortune/bills'),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Cosmic radial bg
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.7),
                  radius: 1.4,
                  colors: [Color(0xFF4C1D95), Color(0xFF1E1B4B), Color(0xFF0F0A1F)],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Starfield
          const Positioned.fill(child: Starfield(starCount: 80)),

          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(fortuneDashboardProvider);
              ref.invalidate(fortuneReadingsProvider);
              await ref.read(fortuneDashboardProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                // ── Hero ──
                const SizedBox(height: 20),
                const Center(child: CrystalBall(size: 110)),
                const SizedBox(height: 22),
                Center(
                  child: GradientText(
                    'ดูดวง & ทาโรต์',
                    gradient: const LinearGradient(
                      colors: [AppColors.goldStart, Color(0xFFF0ABFC)],
                    ),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '✨ AI Fortune Reading System',
                    style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                  ),
                ),

                const SizedBox(height: 22),

                // ── 4-stat bar ──
                _statBar(dashAsync),

                const SizedBox(height: 14),

                // ── Bill approval CTA ──
                _BillApprovalCta(
                  async: billStatsAsync,
                  onTap: () => context.push('/fortune/bills'),
                ),

                const SizedBox(height: 22),

                // ── Services grid ──
                _sectionHeader('บริการดูดวง', subtitle: '6 หมวด'),
                const SizedBox(height: 10),
                _servicesGrid(dashAsync),

                const SizedBox(height: 22),

                // ── Recent readings ──
                _sectionHeader('คำทำนายล่าสุด', subtitle: 'การทำนายในช่วง 24 ชั่วโมง'),
                const SizedBox(height: 10),
                _recentReadings(context, readingsAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBar(AsyncValue<FortuneDashboardData> async) {
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    final num = NumberFormat.compact();
    return GlassCard(
      fillOpacity: 0.06,
      borderOpacity: 0.18,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: async.when(
        data: (d) => Row(
          children: [
            _statCol('รายได้/เดือน', money.format(d.monthlyRevenueThb), AppColors.goldStart),
            _divider(),
            _statCol('Sessions', num.format(d.sessionsCount), AppColors.purpleStart),
            _divider(),
            _statCol('Rating', d.avgRating.toStringAsFixed(2), AppColors.cyanStart),
            _divider(),
            _statCol('Active', d.activeNow.toString(), AppColors.success),
          ],
        ),
        loading: () => const SizedBox(
          height: 50,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          e is ApiException ? e.message : 'โหลดไม่สำเร็จ',
          style: const TextStyle(color: AppColors.error, fontSize: 12),
        ),
      ),
    );
  }

  Widget _servicesGrid(AsyncValue<FortuneDashboardData> async) {
    return async.when(
      data: (d) {
        if (d.services.isEmpty) {
          return _emptyHint('ยังไม่มีบริการที่เปิดใช้งาน');
        }
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: d.services.map(_serviceCard).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _emptyHint('โหลดบริการไม่สำเร็จ'),
    );
  }

  Widget _serviceCard(FortuneService s) {
    final color = Color(s.colorHex);
    final money = NumberFormat.compactCurrency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    // Map color → hue สำหรับ ClayBall
    final hsl = HSLColor.fromColor(color);

    return GlassCard(
      fillOpacity: 0.05,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayBall(size: 44, hue: hsl.hue, saturation: 0.85, lightness: 0.6),
              const Spacer(),
              if (!s.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PAUSED',
                    style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            s.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat.compact().format(s.sessions)} sessions',
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
          ),
          const Spacer(),
          Text(
            money.format(s.revenueThb),
            style: const TextStyle(
              color: AppColors.goldStart,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentReadings(BuildContext context, AsyncValue async) {
    return async.when(
      data: (page) {
        final readings = (page as dynamic).items as List<FortuneReading>;
        if (readings.isEmpty) return _emptyHint('ยังไม่มีการทำนาย');
        return Column(
          children: readings.take(5).map(_readingTile).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _emptyHint('โหลดไม่สำเร็จ'),
    );
  }

  Widget _readingTile(FortuneReading r) {
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    final hue = r.readingType == 'deep' ? 280.0 : 220.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        fillOpacity: 0.04,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClayBall(size: 38, hue: hue, saturation: 0.7, lightness: 0.6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.userName ?? r.facebookUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.questionPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _typeChip(r.readingType),
                      const SizedBox(width: 6),
                      if (r.rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: AppColors.goldStart, size: 11),
                            Text(
                              ' ${r.rating}/5',
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (r.isPaid)
                  Text(
                    money.format(r.amountPaid),
                    style: const TextStyle(
                      color: AppColors.goldStart,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  )
                else
                  const Text(
                    'FREE',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 2),
                _statusDot(r.responseType),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type) {
    final color = type == 'deep' ? AppColors.purpleStart : AppColors.cyanStart;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _statusDot(String responseType) {
    final color = switch (responseType) {
      'completed' => AppColors.success,
      'pending' => AppColors.warning,
      'error' => AppColors.error,
      _ => Colors.grey,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _sectionHeader(String title, {String? subtitle}) => Padding(
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

  Widget _statCol(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
        height: 28,
        width: 1,
        color: Colors.white.withValues(alpha: 0.15),
      );

  Widget _emptyHint(String label) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(label, style: const TextStyle(color: Color(0x88FFFFFF))),
        ),
      );
}

/// AppBar action button with pending badge
class _BillShortcutButton extends StatelessWidget {
  const _BillShortcutButton({required this.pendingCount, required this.onTap});
  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.receipt_long,
                color: Colors.white, size: 19),
          ),
          if (pendingCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.error, Color(0xFFB91C1C)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFF0F0A1F), width: 2),
                ),
                child: Text(
                  pendingCount > 99 ? '99+' : pendingCount.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// CTA card showing pending bills count — links to FortuneBillsScreen
class _BillApprovalCta extends StatelessWidget {
  const _BillApprovalCta({required this.async, required this.onTap});
  final AsyncValue<FortuneBillStats> async;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.compactCurrency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    return async.maybeWhen(
      data: (s) {
        final total = s.pendingCount + s.paidUnconfirmedCount;
        final hasPending = total > 0;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: hasPending
                  ? const LinearGradient(
                      colors: [
                        AppColors.warning,
                        Color(0xFFEA580C),
                        AppColors.pinkStart,
                      ],
                      begin: Alignment(-1, -1),
                      end: Alignment(1, 1),
                    )
                  : LinearGradient(
                      colors: [
                        AppColors.success.withValues(alpha: 0.4),
                        AppColors.success.withValues(alpha: 0.2),
                      ],
                    ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: hasPending
                  ? [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasPending ? Icons.priority_high : Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPending
                            ? 'มีบิลรออนุมัติ $total รายการ'
                            : 'ไม่มีบิลค้างอนุมัติ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasPending
                            ? '${s.pendingCount} รอจ่าย · ${s.paidUnconfirmedCount} จ่ายแล้วรอ confirm · วันนี้รายได้ ${money.format(s.todayRevenueThb)}'
                            : 'วันนี้รายได้ ${money.format(s.todayRevenueThb)} · ผ่านการอนุมัติ ${s.confirmedTodayCount} บิล',
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 14),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
