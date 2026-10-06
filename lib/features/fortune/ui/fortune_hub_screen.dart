import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../home/data/ops_repository.dart';
import '../../work/data/work_repository.dart';
import '../data/fortune_repository.dart';

/// ศูนย์รวมธุรกิจดูดวง — รายได้วันนี้ + ทางเข้าเครื่องมือทั้งหมดของบอทแม่หมอ + สถิติตามช่วงเวลา
class FortuneHubScreen extends ConsumerStatefulWidget {
  const FortuneHubScreen({super.key});

  @override
  ConsumerState<FortuneHubScreen> createState() => _FortuneHubScreenState();
}

class _FortuneHubScreenState extends ConsumerState<FortuneHubScreen> {
  FortunePeriod _period = FortunePeriod.month;

  Future<void> _refresh() async {
    ref.invalidate(liveSummaryProvider);
    ref.invalidate(fortuneDashboardProvider(_period));
    ref.invalidate(opsSummaryProvider);
    ref.invalidate(billStatsProvider);
    try {
      await ref.read(billStatsProvider.future);
    } catch (_) {
      // error แสดงผ่าน TpAsync อยู่แล้ว
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(billStatsProvider);
    final live = ref.watch(liveSummaryProvider).valueOrNull;
    final ops = ref.watch(opsSummaryProvider).valueOrNull;
    final dash = ref.watch(fortuneDashboardProvider(_period));
    final s = stats.valueOrNull;

    return TpPage(
      title: 'ระบบดูดวง',
      subtitle: 'บอทแม่หมอ · ${TpFmt.longDate(DateTime.now())}',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      actions: [
        TpGlassButton(
          icon: PhosphorIconsRegular.magnifyingGlass,
          tooltip: 'ค้นหาบิล',
          onTap: () => context.push('/fortune/bills'),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: TpAsync<BillStats>(
            value: stats,
            onRetry: () => ref.invalidate(billStatsProvider),
            compactError: true,
            loading: const _HeroSkeleton(),
            data: (b) => _RevenueHero(stats: b, live: live),
          ),
        ),
        const SliverToBoxAdapter(child: TpSection('เครื่องมือ')),
        SliverToBoxAdapter(child: _ToolsGroup(stats: s, live: live, ops: ops)),
        const SliverToBoxAdapter(child: TpSection('ภาพรวมบอทแม่หมอ')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TpChips<FortunePeriod>(
              padding: EdgeInsets.zero,
              value: _period,
              onChanged: (p) => setState(() => _period = p),
              items: [
                for (final p in FortunePeriod.values) TpChipItem(p, p.label)
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TpAsync<FortuneDashboard>(
            value: dash,
            compactError: true,
            onRetry: () => ref.invalidate(fortuneDashboardProvider(_period)),
            loading: const TpSkeletonList(count: 2, itemHeight: 76),
            data: (d) => _PeriodStats(d: d, period: _period),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════ การ์ดฮีโร่ ═════════════════════

class _RevenueHero extends StatelessWidget {
  const _RevenueHero({required this.stats, this.live});
  final BillStats stats;
  final LiveReadingsPage? live;

  @override
  Widget build(BuildContext context) {
    final awaiting = stats.count(BillBucket.awaiting);
    final unpaid = stats.count(BillBucket.unpaid);
    return TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('รายได้ดูดวงวันนี้',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TpType.body(13.5, TpPalette.heroMuted, w: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          _HeroPill(
            icon: PhosphorIconsBold.receipt,
            label: 'จ่ายแล้ว ${TpFmt.count(stats.paidTodayCount)} บิล',
            color: TpPalette.heroGold,
          ),
        ]),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: TpFoilText(TpFmt.baht(stats.paidTodayAmount),
              style: TpType.money(40, Colors.white)),
        ),
        Text(
          'นับบิลที่ยืนยันจ่ายวันนี้ · ไม่รวมเว็บจันทรา',
          style: TpType.body(11.5, TpPalette.heroText.withValues(alpha: 0.45)),
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: TpPalette.heroText.withValues(alpha: 0.08)),
        const SizedBox(height: 12),
        Row(children: [
          _HeroStat(
            label: 'รอตรวจ',
            value: '${TpFmt.count(awaiting)} บิล',
            highlight: awaiting > 0,
          ),
          _HeroStat(
              label: 'รอลูกค้าโอน', value: TpFmt.count(unpaid), divider: true),
          _HeroStat(
            label: 'กำลังทำนาย',
            value: live == null ? '–' : TpFmt.count(live!.summaryTotal),
            alert: (live?.summaryStuck ?? 0) > 0
                ? 'ค้าง ${live!.summaryStuck}'
                : null,
            divider: true,
          ),
        ]),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TpType.body(12, color, w: FontWeight.w600, height: 1.1)),
        ]),
      );
}

/// ตัวเลขย่อยในการ์ดฮีโร่ (พื้นน้ำเงินเข้มเสมอ — ใช้สีคงที่ของฮีโร่)
class _HeroStat extends StatelessWidget {
  const _HeroStat(
      {required this.label,
      required this.value,
      this.divider = false,
      this.highlight = false,
      this.alert});
  final String label;
  final String value;
  final bool divider;
  final bool highlight;
  final String? alert;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.only(left: divider ? 12 : 0, right: 6),
        decoration: divider
            ? BoxDecoration(
                border: Border(
                    left: BorderSide(
                        color: TpPalette.heroText.withValues(alpha: 0.08))))
            : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TpType.body(
                  11.5, TpPalette.heroText.withValues(alpha: 0.55),
                  w: FontWeight.w500)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TpType.money(
                    16, highlight ? TpPalette.heroGold : TpPalette.heroText)),
          ),
          if (alert != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(alert!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(11, TpPalette.midnight.danger,
                      w: FontWeight.w600, height: 1.2)),
            ),
        ]),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => const TpHeroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TpSkeleton(width: 110, height: 12),
          SizedBox(height: 10),
          TpSkeleton(width: 170, height: 34),
          SizedBox(height: 8),
          TpSkeleton(width: 200, height: 10),
          SizedBox(height: 18),
          TpSkeleton(height: 34),
        ]),
      );
}

// ═════════════════════ ทางเข้าเครื่องมือ ═════════════════════

class _ToolsGroup extends StatelessWidget {
  const _ToolsGroup({this.stats, this.live, this.ops});
  final BillStats? stats;
  final LiveReadingsPage? live;
  final OpsSummary? ops;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final awaiting = s?.count(BillBucket.awaiting) ?? 0;
    // แต่ละบิลอยู่ได้กองเดียว → ผลรวมทุกกอง = บิลทั้งหมด
    final allBills = s?.counts.values.fold<int>(0, (a, b) => a + b);
    final stuck = live?.summaryStuck ?? 0;
    final requests = ops?.customerRequests.count ?? 0;

    final aiTotal = ops?.aiTotal ?? 0;
    final aiHealthy = ops?.aiHealthy ?? 0;
    final (String aiLabel, TpTone aiTone) = aiHealthy == 0
        ? ('ไม่มีคีย์พร้อม', TpTone.danger)
        : aiHealthy < (aiTotal / 2).ceil()
            ? ('เหลือน้อย', TpTone.warning)
            : ('ปกติ', TpTone.success);

    return TpGroup(children: [
      TpRow(
        art: TpArt.bill,
        title: 'ตรวจบิล',
        subtitle: s == null
            ? 'บิลที่ลูกค้าส่งสลิปหรือแจ้งโอนแล้ว'
            : awaiting > 0
                ? 'รอตรวจ ${TpFmt.count(awaiting)} บิล · รวม ${TpFmt.baht(s.awaitingAmount)}'
                : 'ไม่มีบิลรอตรวจ — บิลที่ SMS ตรงยอดระบบตัดให้เอง',
        trailing: awaiting > 0 ? TpCount(awaiting) : null,
        onTap: () => context.go('/work?tab=bills'),
      ),
      TpRow(
        art: TpArt.analytics,
        title: 'ค้นหาบิลทั้งหมด',
        subtitle: allBills == null
            ? 'ทุกสถานะ · ค้นด้วยชื่อลูกค้า เลขบิล หรือ #รหัส'
            : 'บิล ${TpFmt.count(allBills)} ใบ · ค้นด้วยชื่อลูกค้า เลขบิล หรือ #รหัส',
        onTap: () => context.push('/fortune/bills'),
      ),
      TpRow(
        art: TpArt.tarot,
        title: 'คำทำนายสด',
        subtitle: live == null
            ? 'บิลจ่ายแล้วที่บอทกำลังทำนาย'
            : live!.summaryTotal == 0
                ? 'ตอนนี้ไม่มีคำทำนายที่กำลังทำ'
                : stuck > 0
                    ? 'กำลังทำ ${TpFmt.count(live!.summaryTotal)} รายการ · ค้าง $stuck รายการ'
                    : 'กำลังทำ ${TpFmt.count(live!.summaryTotal)} รายการ · เดินปกติ',
        trailing: stuck > 0 ? TpCount(stuck, tone: TpTone.danger) : null,
        onTap: () => context.push('/fortune/live'),
      ),
      TpRow(
        art: TpArt.headset,
        title: 'แชทลูกค้า',
        subtitle: ops == null
            ? 'บทสนทนาบอทดูดวงทุกช่องทาง'
            : requests > 0
                ? 'ลูกค้าขอคุยกับแอดมิน ${TpFmt.count(requests)} คน'
                : 'ไม่มีลูกค้ารอคุยกับแอดมิน',
        trailing: requests > 0 ? TpCount(requests, tone: TpTone.danger) : null,
        onTap: () => context.go('/chat'),
      ),
      TpRow(
        art: TpArt.ai,
        title: 'AI Pool',
        subtitle: ops == null
            ? 'คีย์ AI ที่บอทแม่หมอใช้ทำนาย'
            : aiTotal == 0
                ? 'ยังไม่มีคีย์ AI ในระบบ'
                : 'คีย์พร้อมใช้ $aiHealthy จาก $aiTotal คีย์',
        trailing: ops == null || aiTotal == 0
            ? null
            : TpPill(aiLabel, tone: aiTone, dense: true),
        onTap: () => context.push('/fortune/ai-pool'),
      ),
      TpRow(
        art: TpArt.settings,
        title: 'บริการและราคา',
        subtitle: 'แพคเกจ ราคา และหมวดคำถาม',
        onTap: () => context.push('/fortune/services'),
      ),
    ]);
  }
}

// ═════════════════════ สถิติตามช่วงเวลา ═════════════════════

class _PeriodStats extends StatelessWidget {
  const _PeriodStats({required this.d, required this.period});
  final FortuneDashboard d;
  final FortunePeriod period;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final cats = [...d.categories]
      ..sort((a, b) => b.sessions.compareTo(a.sessions));
    final top = cats.where((c) => c.sessions > 0).take(5).toList();
    final maxSessions = top.isEmpty ? 1 : math.max(1, top.first.sessions);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TpCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(children: [
          Expanded(
            child: TpStat(
              label: 'บิลที่จ่ายแล้ว',
              value: TpFmt.bahtCompact(d.revenue),
              color: p.goldText,
              align: CrossAxisAlignment.center,
            ),
          ),
          _VLine(),
          Expanded(
            child: TpStat(
                label: 'บทสนทนาใหม่',
                value: TpFmt.compact(d.sessions),
                align: CrossAxisAlignment.center),
          ),
          _VLine(),
          Expanded(
            child: TpStat(
              label: 'คะแนนรีวิว',
              value: d.avgRating > 0 ? d.avgRating.toStringAsFixed(1) : '–',
              align: CrossAxisAlignment.center,
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(
          'ยอดเงินนับจากบิลที่เปิดใน${period.label}และจ่ายแล้ว · บทสนทนานับทุกห้องที่เริ่มคุยกับบอท',
          style: TpType.body(11.5, p.faint),
        ),
      ),
      TpSection('หมวดคำถามยอดนิยม · ${period.label}'),
      if (top.isEmpty)
        const TpCard(
          padding: EdgeInsets.zero,
          child: TpEmpty(
            art: TpArt.emptyInbox,
            title: 'ยังไม่มีคำถามตามหมวดในช่วงนี้',
            message: 'เมื่อลูกค้าเลือกหมวดคำถาม สถิติจะขึ้นที่นี่',
            compact: true,
          ),
        )
      else
        TpCard(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(children: [
            for (var i = 0; i < top.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: p.divider),
              _CategoryBar(c: top[i], ratio: top[i].sessions / maxSessions),
            ],
          ]),
        ),
    ]);
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.c, required this.ratio});
  final FortuneCategoryStat c;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final color = fortuneHexColor(c.color) ?? p.gold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.h(13.5, p.textStrong, w: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text('${TpFmt.count(c.sessions)} ครั้ง',
              style: TpType.money(12.5, p.muted, w: FontWeight.w600)),
          if (c.revenue > 0) ...[
            const SizedBox(width: 8),
            Text(TpFmt.bahtCompact(c.revenue),
                style: TpType.money(13, p.goldText)),
          ],
        ]),
        const SizedBox(height: 7),
        TpMeter(value: ratio, color: color, height: 4),
      ]),
    );
  }
}

class _VLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: context.tp.divider);
}
