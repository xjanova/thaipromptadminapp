import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/fortune_repository.dart';
import '../data/models/fortune_models.dart';
import 'widgets/active_reading_actions_sheet.dart';

/// Live Readings monitor — แสดงการทำนายที่กำลังทำงาน + stuck alerts
///
/// Backend patterns (per brain notes):
/// - Stuck levels: ok <60s · slow 60-120s · stuck >120s
///   ([[Session 2026-05-14 #2 — Fortune AI Loading Ping + Admin Stuck Alert]])
/// - Admin takeover: AJAX sync, admin waits 30-60s
///   ([[2026-05-17-fortune-celtic-admin-ai-debug-tools-bill-race-lock]])
/// - FB Handover: rate-limited; LINE: replyToken 60s window + push fallback
///   ([[Thaiprompt Fortune Bot - Admin Takeover & FB Handover Limitations]])
class FortuneLiveScreen extends ConsumerStatefulWidget {
  const FortuneLiveScreen({super.key});

  @override
  ConsumerState<FortuneLiveScreen> createState() => _FortuneLiveScreenState();
}

class _FortuneLiveScreenState extends ConsumerState<FortuneLiveScreen> {
  Timer? _refreshTimer;
  Timer? _tickTimer; // for elapsed time UI updates (every 1s)

  @override
  void initState() {
    super.initState();
    // Refresh from "backend" every 10s
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) ref.invalidate(fortuneActiveReadingsProvider);
    });
    // Repaint every 1s so elapsed labels tick
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fortuneActiveReadingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0A1F),
      body: Stack(
        children: [
          // Cosmic bg
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.8),
                  radius: 1.3,
                  colors: [
                    Color(0xFF4C1D95),
                    Color(0xFF1E1B4B),
                    Color(0xFF0F0A1F)
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            color: AppColors.purpleStart,
            onRefresh: () async {
              ref.invalidate(fortuneActiveReadingsProvider);
              await ref.read(fortuneActiveReadingsProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  floating: true,
                  centerTitle: false,
                  title: Row(
                    children: [
                      const Text(
                        'Live การทำนาย',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _liveDot(),
                    ],
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),

                // Stats header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: _StatsCard(async: async),
                  ),
                ),

                async.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Empty(),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ReadingTile(
                          reading: list[i],
                          onActions: () => _openActions(list[i]),
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        e is ApiException ? e.message : 'โหลดข้อมูลไม่สำเร็จ',
                        style: const TextStyle(color: Color(0xCCFFFFFF)),
                      ),
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

  Future<void> _openActions(FortuneActiveReading r) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActiveReadingActionsSheet(reading: r),
    );
    if (!mounted) return;
    ref.invalidate(fortuneActiveReadingsProvider);
  }

  Widget _liveDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.7),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
  }
}

// ────────────────────────────────────────────────────────────
// Stats card
// ────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.async});
  final AsyncValue<List<FortuneActiveReading>> async;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      fillOpacity: 0.1,
      borderOpacity: 0.22,
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      child: async.when(
        data: (list) {
          final total = list.length;
          final stuck = list.where((r) => r.isStuck).length;
          final slow = list.where((r) => r.isSlow).length;
          final ok = total - stuck - slow;
          final takenOver = list.where((r) => r.adminTakenOver).length;
          return Column(
            children: [
              Row(
                children: [
                  ClayBall(
                    size: 44,
                    hue: total == 0 ? 145 : (stuck > 0 ? 0 : 280),
                    saturation: 0.85,
                    lightness: 0.62,
                    child: const Icon(Icons.podcasts,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'กำลังทำนายตอนนี้',
                          style: TextStyle(
                              color: Color(0xCCFFFFFF), fontSize: 11),
                        ),
                        Text(
                          '$total readings',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (takenOver > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyanStart.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.admin_panel_settings,
                              color: AppColors.cyanStart, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '$takenOver takeover',
                            style: const TextStyle(
                              color: AppColors.cyanStart,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statCol('OK', ok, AppColors.success),
                  _divider(),
                  _statCol('Slow (60s+)', slow, AppColors.warning),
                  _divider(),
                  _statCol('Stuck (2m+)', stuck, AppColors.error),
                ],
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          e is ApiException ? e.message : 'โหลดสถิติไม่สำเร็จ',
          style: const TextStyle(color: AppColors.error, fontSize: 12),
        ),
      ),
    );
  }

  Widget _statCol(String label, int value, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              label,
              style:
                  const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withValues(alpha: 0.14),
      );
}

// ────────────────────────────────────────────────────────────
// Reading tile
// ────────────────────────────────────────────────────────────

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.reading, required this.onActions});
  final FortuneActiveReading reading;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final accent = switch (reading.alertLevel) {
      'stuck' => AppColors.error,
      'slow' => AppColors.warning,
      _ => AppColors.success,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onActions,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: reading.isStuck
                ? [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.4),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: GlassCard(
            fillOpacity: reading.isStuck ? 0.14 : 0.06,
            borderOpacity: reading.isStuck ? 0.4 : 0.14,
            tint: reading.isStuck ? AppColors.error : null,
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Pulsing clay icon
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClayBall(
                          size: 42,
                          hue: reading.tierHue,
                          saturation: 0.85,
                          lightness: 0.6,
                          child: Icon(
                            reading.platform == 'line'
                                ? Icons.chat_bubble_outline
                                : Icons.facebook,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF0F0A1F), width: 2),
                            ),
                          ).animate(
                            onPlay: (c) => c.repeat(reverse: true),
                          ).scale(
                            duration: const Duration(milliseconds: 800),
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.15, 1.15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  reading.billNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _tierBadge(reading.tier, reading.tierLabel),
                              if (reading.adminTakenOver) ...[
                                const SizedBox(width: 4),
                                _adminBadge(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            reading.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onActions,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.more_horiz,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // State / stage label
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 14,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reading.stageLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _formatElapsed(reading.elapsed),
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reading.questionPreview != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '“${reading.questionPreview}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ],
                if (reading.aiProvider != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.smart_toy_outlined,
                          color: Color(0x99FFFFFF), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${reading.aiProvider} · ${reading.aiModel ?? "—"}',
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (reading.hasAlerted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_active,
                                  size: 10, color: AppColors.warning),
                              SizedBox(width: 3),
                              Text(
                                'Alert ส่งแล้ว',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final m = d.inMinutes;
    final s = d.inSeconds - (m * 60);
    return '${m}m ${s}s';
  }

  Widget _tierBadge(String tier, String label) {
    final color = switch (tier) {
      'celtic' => AppColors.pinkStart,
      'deep' => AppColors.purpleStart,
      'tarot_chat' => AppColors.cyanStart,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _adminBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.cyanStart.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.admin_panel_settings,
              color: AppColors.cyanStart, size: 10),
          SizedBox(width: 2),
          Text(
            'TAKEOVER',
            style: TextStyle(
              color: AppColors.cyanStart,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.podcasts,
                color: Color(0x44FFFFFF), size: 60),
            SizedBox(height: 14),
            Text(
              'ไม่มีการทำนายที่กำลังทำงาน',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'ระบบจะอัพเดทอัตโนมัติทุก 10 วินาที',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
            ),
          ],
        ),
      );
}
