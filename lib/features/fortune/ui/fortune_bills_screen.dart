import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/fortune_repository.dart';
import '../data/models/fortune_models.dart';
import 'widgets/bill_detail_sheet.dart';

/// Fortune Bills Approval Screen — อนุมัติบิลดูดวง
///
/// Backend pattern (per brain notes):
/// - Bill number format: FTU-YYMMDD-R{readingId}
/// - Tiers: Celtic 99฿ (premium + Vision AI) · Deep 39฿ · Tarot Chat 59฿
/// - Status flow: pending_payment → paid → confirmed → reading_done
///   (or rejected / refunded)
/// - Race condition: rapid-click protected by Cache::add atomic lock
///   ([[2026-05-17-fortune-celtic-admin-ai-debug-tools-bill-race-lock]])
class FortuneBillsScreen extends ConsumerStatefulWidget {
  const FortuneBillsScreen({super.key});

  @override
  ConsumerState<FortuneBillsScreen> createState() => _FortuneBillsScreenState();
}

class _FortuneBillsScreenState extends ConsumerState<FortuneBillsScreen> {
  String? _filter; // null = all, 'pending_payment' | 'paid' | 'reading_done' | 'rejected'

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(fortuneBillsProvider(_filter));
    final statsAsync = ref.watch(fortuneBillStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0A1F),
      body: Stack(
        children: [
          // Cosmic gradient bg
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.8),
                  radius: 1.3,
                  colors: [Color(0xFF4C1D95), Color(0xFF1E1B4B), Color(0xFF0F0A1F)],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            color: AppColors.purpleStart,
            onRefresh: () async {
              ref.invalidate(fortuneBillsProvider);
              ref.invalidate(fortuneBillStatsProvider);
              await ref.read(fortuneBillsProvider(_filter).future);
            },
            child: CustomScrollView(
              slivers: [
                // ── App bar ──
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: false,
                  floating: true,
                  centerTitle: false,
                  title: const Text(
                    'อนุมัติบิลดูดวง',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
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

                // ── Stats hero ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: _StatsHero(async: statsAsync),
                  ),
                ),

                // ── Filter chips ──
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _filterChip(null, 'ทั้งหมด', null),
                        _filterChip(
                            'pending_payment', 'รอจ่าย', Icons.schedule),
                        _filterChip('paid', 'รอ Confirm', Icons.payments_outlined),
                        _filterChip('reading_done', 'เสร็จแล้ว',
                            Icons.check_circle_outline),
                        _filterChip(
                            'rejected', 'ปฏิเสธ', Icons.cancel_outlined),
                        _filterChip('refunded', 'Refund', Icons.replay),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // ── Bills list ──
                billsAsync.when(
                  data: (page) {
                    if (page.items.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Empty(),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _BillTile(
                          bill: page.items[i],
                          onTap: () => _openDetail(page.items[i]),
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
                        e is ApiException ? e.message : 'โหลดบิลไม่สำเร็จ',
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

  // ────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────

  Future<void> _openDetail(FortuneBill bill) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BillDetailSheet(bill: bill),
    );
    // refresh after sheet closes (in case actions were taken)
    ref.invalidate(fortuneBillsProvider);
    ref.invalidate(fortuneBillStatsProvider);
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  Widget _filterChip(String? key, String label, IconData? icon) {
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
                ? const LinearGradient(
                    colors: [AppColors.purpleStart, AppColors.pinkStart])
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
}

// ────────────────────────────────────────────────────────────
// Stats hero card (รออนุมัติ N · paid N · confirmed today N · revenue ฿)
// ────────────────────────────────────────────────────────────

class _StatsHero extends StatelessWidget {
  const _StatsHero({required this.async});
  final AsyncValue<FortuneBillStats> async;

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.compactCurrency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    return GlassCard(
      fillOpacity: 0.1,
      borderOpacity: 0.22,
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: async.when(
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClayBall(
                  size: 46,
                  hue: 280,
                  saturation: 0.85,
                  lightness: 0.62,
                  child: const Icon(Icons.receipt_long,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'รายได้บิลวันนี้',
                        style: TextStyle(
                            color: Color(0xCCFFFFFF), fontSize: 11),
                      ),
                      Text(
                        money.format(s.todayRevenueThb),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.pendingCount + s.paidUnconfirmedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.priority_high,
                            color: AppColors.warning, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${s.pendingCount + s.paidUnconfirmedCount}',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statCol('รอจ่าย', s.pendingCount.toString(),
                    AppColors.cyanStart),
                _divider(),
                _statCol('รอ Confirm', s.paidUnconfirmedCount.toString(),
                    AppColors.warning),
                _divider(),
                _statCol('เสร็จแล้ว', s.confirmedTodayCount.toString(),
                    AppColors.success),
                _divider(),
                _statCol('Reject', s.rejectedTodayCount.toString(),
                    AppColors.error),
              ],
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          e is ApiException ? e.message : 'โหลดสถิติไม่สำเร็จ',
          style: const TextStyle(color: AppColors.error, fontSize: 12),
        ),
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10),
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
// Bill list tile
// ────────────────────────────────────────────────────────────

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill, required this.onTap});
  final FortuneBill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: GlassCard(
          fillOpacity: bill.isPending ? 0.1 : 0.06,
          borderOpacity: bill.isPending ? 0.3 : 0.14,
          borderRadius: 18,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClayBall(
                    size: 38,
                    hue: bill.tierHue,
                    saturation: 0.85,
                    lightness: 0.6,
                    child: Icon(
                      bill.platform == 'line'
                          ? Icons.chat_bubble_outline
                          : Icons.facebook,
                      color: Colors.white,
                      size: 16,
                    ),
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
                                bill.billNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _tierBadge(bill.tier, bill.tierLabel),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          bill.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money.format(bill.amountThb),
                        style: const TextStyle(
                          color: AppColors.goldStart,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _statusChip(bill.status),
                    ],
                  ),
                ],
              ),
              if (bill.questionPreview != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 50),
                  child: Text(
                    '“${bill.questionPreview}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 10, color: Color(0x88FFFFFF)),
                    const SizedBox(width: 4),
                    Text(
                      _formatElapsed(bill.elapsed),
                      style: const TextStyle(
                          color: Color(0x99FFFFFF), fontSize: 10),
                    ),
                    const Spacer(),
                    if (bill.slipImageUrl != null && bill.isPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.cyanStart.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_outlined,
                                size: 10, color: AppColors.cyanStart),
                            SizedBox(width: 3),
                            Text(
                              'มีสลิป',
                              style: TextStyle(
                                color: AppColors.cyanStart,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    if (d.inMinutes < 1) return 'พึ่งสร้าง';
    if (d.inMinutes < 60) return '${d.inMinutes} นาทีก่อน';
    if (d.inHours < 24) return '${d.inHours} ชั่วโมงก่อน';
    return '${d.inDays} วันก่อน';
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

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'pending_payment' => ('รอจ่าย', AppColors.cyanStart),
      'paid' => ('รอ Confirm', AppColors.warning),
      'confirmed' => ('Confirmed', AppColors.success),
      'reading_started' => ('กำลังอ่าน', AppColors.success),
      'reading_done' => ('เสร็จแล้ว', AppColors.success),
      'rejected' => ('Reject', AppColors.error),
      'refunded' => ('Refund', Colors.grey),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_outlined, color: Color(0x44FFFFFF), size: 56),
          SizedBox(height: 14),
          Text(
            'ไม่มีบิลในหมวดนี้',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'ลองเลือกหมวดอื่น หรือดึงลงเพื่อรีเฟรช',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
