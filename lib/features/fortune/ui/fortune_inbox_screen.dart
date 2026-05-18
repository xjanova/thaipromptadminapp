import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/fortune_repository.dart';
import '../data/models/chat_models.dart';

/// Inbox screen — list of conversations grouped by need-admin priority
///
/// Per brain ([[Thaiprompt Fortune Bot - Admin Takeover & FB Handover Limitations]]):
/// - customer_handoff_keywords trigger "ลูกค้าขอแอดมิน" state
/// - admin sees waiting requests in red, expiring takeovers in yellow
/// - tap → open chat thread → takeover + reply
class FortuneInboxScreen extends ConsumerStatefulWidget {
  const FortuneInboxScreen({super.key});

  @override
  ConsumerState<FortuneInboxScreen> createState() =>
      _FortuneInboxScreenState();
}

class _FortuneInboxScreenState extends ConsumerState<FortuneInboxScreen> {
  Timer? _refreshTimer;
  String _filter = 'all'; // all | needs_admin | takeover | bot | closed

  @override
  void initState() {
    super.initState();
    // Poll every 12s
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      ref.invalidate(fortuneConversationsProvider);
      ref.invalidate(takeoverStatsProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(fortuneConversationsProvider);
    final statsAsync = ref.watch(takeoverStatsProvider);

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
              ref.invalidate(fortuneConversationsProvider);
              ref.invalidate(takeoverStatsProvider);
              await ref.read(fortuneConversationsProvider.future);
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
                        'Inbox',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      statsAsync.maybeWhen(
                        data: (s) => s.customerRequests > 0
                            ? _alertDot()
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      ),
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

                // Stats hero
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: _StatsHero(async: statsAsync),
                  ),
                ),

                // Filter chips
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _filterChip('all', 'ทั้งหมด', null),
                        _filterChip(
                            'needs_admin', 'ขอแอดมิน', Icons.priority_high,
                            urgent: true),
                        _filterChip('takeover', 'Takeover',
                            Icons.support_agent),
                        _filterChip('bot', 'Bot', Icons.smart_toy_outlined),
                        _filterChip(
                            'closed', 'ปิดแล้ว', Icons.check_circle_outline),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                conversationsAsync.when(
                  data: (list) {
                    final filtered = _applyFilter(list);
                    if (filtered.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Empty(),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ConversationTile(
                          c: filtered[i],
                          onTap: () => context.push(
                              '/fortune/chat/${filtered[i].readingId}'),
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
                        e is ApiException ? e.message : 'โหลดไม่สำเร็จ',
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

  List<FortuneConversation> _applyFilter(List<FortuneConversation> list) {
    return switch (_filter) {
      'needs_admin' => list.where((c) => c.needsAdmin).toList(),
      'takeover' => list
          .where((c) =>
              c.status == ConversationStatus.takeoverActive ||
              c.status == ConversationStatus.takeoverExpiring)
          .toList(),
      'bot' => list
          .where((c) => c.status == ConversationStatus.activeBot)
          .toList(),
      'closed' => list
          .where((c) => c.status == ConversationStatus.closed)
          .toList(),
      _ => list,
    };
  }

  Widget _filterChip(String key, String label, IconData? icon,
      {bool urgent = false}) {
    final active = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: urgent
                        ? [AppColors.error, const Color(0xFFB91C1C)]
                        : [AppColors.purpleStart, AppColors.pinkStart],
                  )
                : null,
            color: active ? null : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  Colors.white.withValues(alpha: active ? 0 : 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertDot() {
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
// Stats hero
// ────────────────────────────────────────────────────────────

class _StatsHero extends StatelessWidget {
  const _StatsHero({required this.async});
  final AsyncValue<TakeoverStats> async;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      fillOpacity: 0.1,
      borderOpacity: 0.22,
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: async.when(
        data: (s) => Column(
          children: [
            Row(
              children: [
                ClayBall(
                  size: 44,
                  hue: s.customerRequests > 0 ? 0 : 280,
                  saturation: 0.85,
                  lightness: 0.62,
                  child: const Icon(Icons.inbox,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ที่ต้องตอบ',
                        style: TextStyle(
                            color: Color(0xCCFFFFFF), fontSize: 11),
                      ),
                      Text(
                        '${s.totalNeedsAdmin} conversations',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.customerRequests > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.priority_high,
                            color: AppColors.error, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          '${s.customerRequests}',
                          style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _col('ขอแอดมิน', s.customerRequests, AppColors.error),
                _div(),
                _col('Takeover', s.takeoverActive, AppColors.cyanStart),
                _div(),
                _col('ใกล้หมด', s.takeoverExpiring, AppColors.warning),
                _div(),
                _col('ปิดแล้ว', s.closedToday, AppColors.success),
              ],
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 70,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          e is ApiException ? e.message : 'โหลดสถิติไม่สำเร็จ',
          style: const TextStyle(color: AppColors.error, fontSize: 12),
        ),
      ),
    );
  }

  Widget _col(String label, int value, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10),
            ),
          ],
        ),
      );

  Widget _div() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withValues(alpha: 0.14),
      );
}

// ────────────────────────────────────────────────────────────
// Conversation tile
// ────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.c, required this.onTap});
  final FortuneConversation c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = c.needsAdmin;
    final isCustomerRequest =
        c.status == ConversationStatus.customerRequestedAdmin;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: isCustomerRequest
                ? [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: GlassCard(
            fillOpacity: urgent ? 0.14 : 0.06,
            borderOpacity: urgent ? 0.4 : 0.14,
            tint: isCustomerRequest ? AppColors.error : null,
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClayBall(
                      size: 44,
                      hue: c.tierHue,
                      saturation: 0.85,
                      lightness: 0.6,
                      child: Icon(
                        c.platform == 'line'
                            ? Icons.chat_bubble_outline
                            : Icons.facebook,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    if (c.unreadAdminCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(
                              minWidth: 18, minHeight: 18),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: const Color(0xFF0F0A1F), width: 2),
                          ),
                          child: Text(
                            c.unreadAdminCount.toString(),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _statusChip(c.status, c.takeoverMinutesLeft),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (c.lastMessageSender == 'bot') ...[
                            const Icon(Icons.smart_toy,
                                color: AppColors.purpleStart, size: 11),
                            const SizedBox(width: 3),
                          ] else if (c.lastMessageSender == 'admin') ...[
                            const Icon(Icons.support_agent,
                                color: AppColors.cyanStart, size: 11),
                            const SizedBox(width: 3),
                          ],
                          Expanded(
                            child: Text(
                              c.lastMessagePreview ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCustomerRequest
                                    ? Colors.white
                                    : const Color(0xCCFFFFFF),
                                fontSize: 12,
                                fontWeight: isCustomerRequest
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isCustomerRequest && c.requestKeyword != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark,
                                  color: AppColors.error, size: 10),
                              const SizedBox(width: 3),
                              Text(
                                'keyword: "${c.requestKeyword}"',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(c.lastMessageAt),
                  style: TextStyle(
                    color: urgent
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: urgent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? at) {
    if (at == null) return '—';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _statusChip(ConversationStatus status, int? minutesLeft) {
    final c = status.color;
    final label = status == ConversationStatus.takeoverExpiring &&
            minutesLeft != null
        ? '${status.label} (${minutesLeft}m)'
        : status == ConversationStatus.takeoverActive && minutesLeft != null
            ? '${minutesLeft}m left'
            : status.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
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
            Icon(Icons.mark_chat_unread_outlined,
                color: Color(0x44FFFFFF), size: 56),
            SizedBox(height: 14),
            Text(
              'ไม่มี conversation ในหมวดนี้',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'ระบบ poll ทุก 12 วินาที',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
            ),
          ],
        ),
      );
}
