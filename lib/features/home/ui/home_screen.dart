import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../auth/providers/auth_controller.dart';
import '../../chat/data/chat_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/ops_repository.dart';

/// หน้า "ภาพรวม" — รายได้วันนี้แบบสด + คิวงานที่ต้องจัดการ + สุขภาพระบบ
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ops = ref.watch(opsSummaryProvider);
    final admin = ref.watch(authControllerProvider).admin;
    final now = DateTime.now();
    final offline = ops.hasError && tpIsOffline(ops.error);

    Future<void> refresh() async {
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(liveConversationsProvider);
      try {
        ref.invalidate(opsSummaryProvider);
        await ref.read(opsSummaryProvider.future);
      } catch (_) {
        // error แสดงผ่าน TpAsync อยู่แล้ว
      }
    }

    return TpPage(
      title: 'ภาพรวม',
      subtitle: TpFmt.longDate(now),
      showMark: true,
      onRefresh: refresh,
      actions: [
        TpGlassButton(
          icon: PhosphorIconsRegular.magnifyingGlass,
          tooltip: 'ค้นหาสมาชิก',
          onTap: () => context.push('/users'),
        ),
        TpGlassButton(
          icon: PhosphorIconsRegular.bell,
          tooltip: 'งานรอทำ',
          dot: (ops.valueOrNull?.totalTasks ?? 0) > 0,
          onTap: () => context.go('/work'),
        ),
      ],
      headerBottom: Wrap(spacing: 8, runSpacing: 6, children: [
        _StatusPill(
          ok: !ops.hasError || ops.hasValue,
          offline: offline,
          label: ops.isLoading && !ops.hasValue
              ? 'กำลังเชื่อมต่อ…'
              : offline
                  ? 'ออฟไลน์'
                  : ops.hasError && !ops.hasValue
                      ? 'เชื่อมต่อไม่ได้'
                      : 'ระบบปกติ',
        ),
        if (ops.valueOrNull?.fetchedAt != null)
          _GlassPill(
            icon: PhosphorIconsRegular.arrowsClockwise,
            label: 'อัปเดต ${TpFmt.time(ops.valueOrNull!.fetchedAt!)}',
          ),
        if (admin != null)
          _GlassPill(
              icon: PhosphorIconsRegular.userCircle, label: admin.roleLabel),
      ]),
      slivers: [
        SliverToBoxAdapter(
          child: TpAsync<OpsSummary>(
            value: ops,
            onRetry: () => ref.invalidate(opsSummaryProvider),
            loading: const _HomeSkeleton(),
            data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RevenueHero(s: s),
                  TpSection(
                    'ต้องจัดการตอนนี้',
                    trailing: s.totalTasks > 0
                        ? TpPill('${s.totalTasks} งาน', tone: TpTone.danger)
                        : s.anyUnavailable
                            ? const TpPill('ข้อมูลไม่ครบ',
                                tone: TpTone.warning,
                                icon: PhosphorIconsBold.warning)
                            : const TpPill('เรียบร้อย',
                                tone: TpTone.success,
                                icon: PhosphorIconsBold.check),
                  ),
                  _QueueCard(s: s),
                  TpSection('กำลังคุยอยู่ตอนนี้',
                      action: 'ทั้งหมด', onAction: () => context.go('/chat')),
                  const _LiveNow(),
                  const TpSection('สุขภาพระบบ'),
                  _HealthGrid(s: s),
                  const _MonthStats(),
                ]),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(
      {required this.ok, required this.offline, required this.label});
  final bool ok;
  final bool offline;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c =
        offline || !ok ? const Color(0xFFFF8A7A) : const Color(0xFF4BE08E);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: c, blurRadius: 8)]),
        ),
        const SizedBox(width: 6),
        Text(label, style: TpType.body(12, c, w: FontWeight.w600, height: 1.1)),
      ]),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: p.glass, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: p.onHeaderMuted),
        const SizedBox(width: 5),
        Text(label,
            style: TpType.body(12, p.onHeaderMuted,
                w: FontWeight.w500, height: 1.1)),
      ]),
    );
  }
}

/// การ์ดรายได้วันนี้ + กราฟรายชั่วโมงสะสม + แยกตามธุรกิจ
class _RevenueHero extends StatelessWidget {
  const _RevenueHero({required this.s});
  final OpsSummary s;

  @override
  Widget build(BuildContext context) {
    final hourNow = DateTime.now().hour;
    var acc = 0.0;
    final cumulative = <double>[
      for (var h = 0; h <= hourNow; h++) acc += s.hourly[h]
    ];
    final growth = s.growthPct;
    final total = s.revenueToday <= 0 ? 1.0 : s.revenueToday;

    return TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('รายได้วันนี้',
              style:
                  TpType.body(13.5, TpPalette.heroMuted, w: FontWeight.w500)),
          const Spacer(),
          if (growth != null)
            _HeroPill(
              icon: growth >= 0
                  ? PhosphorIconsBold.trendUp
                  : PhosphorIconsBold.trendDown,
              label: '${TpFmt.pct(growth)} จากเมื่อวาน',
              color: growth >= 0
                  ? const Color(0xFF4BE08E)
                  : const Color(0xFFFF8A7A),
            ),
        ]),
        const SizedBox(height: 2),
        TpFoilText(TpFmt.baht(s.revenueToday.roundToDouble()),
            style: TpType.money(40, Colors.white)),
        const SizedBox(height: 6),
        TpAreaChart(values: cumulative, slots: 24),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['00:00', '06:00', '12:00', '18:00', 'ตอนนี้']
              .map((t) => Text(t,
                  style: TpType.body(10.5, const Color(0x61FFFFFF),
                      w: FontWeight.w500)))
              .toList(),
        ),
        const SizedBox(height: 12),
        Container(height: 1, color: const Color(0x14FFFFFF)),
        const SizedBox(height: 11),
        Row(children: [
          _Split('ดูดวง', s.revenueFortune, s.revenueFortune / total,
              const Color(0xFFF0C96A)),
          _Split('ร้านค้า', s.revenueMarketplace, s.revenueMarketplace / total,
              const Color(0xFF6FA3FF),
              divider: true),
          _Split('อื่น ๆ', s.revenueOther, s.revenueOther / total,
              const Color(0xFF3DDC84),
              divider: true),
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

class _Split extends StatelessWidget {
  const _Split(this.label, this.amount, this.ratio, this.color,
      {this.divider = false});
  final String label;
  final double amount;
  final double ratio;
  final Color color;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.only(left: divider ? 12 : 0, right: 8),
        decoration: divider
            ? const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0x14FFFFFF))))
            : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 5),
            Text(label,
                style: TpType.body(11.5, const Color(0x8CFFFFFF),
                    w: FontWeight.w500)),
          ]),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(TpFmt.baht(amount.roundToDouble()),
                style: TpType.money(15.5, TpPalette.heroText)),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(children: [
              Container(height: 3, color: const Color(0x14FFFFFF)),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0, 1).toDouble(),
                child: Container(height: 3, color: color),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// แถว "โหลดไม่ได้" ของส่วนที่ backend อ่านไม่สำเร็จ — ห้ามซ่อน ไม่งั้นแอดมินเข้าใจว่าไม่มีงาน
List<Widget> _unavailableRows(BuildContext context, OpsSummary s) {
  final items = <(QueueItem, TpArt, String, String)>[
    (s.customerRequests, TpArt.headset, 'ลูกค้าขอคุยกับแอดมิน', '/chat'),
    (s.billsAwaiting, TpArt.bill, 'บิลรอแอดมินตรวจ', '/work?tab=bills'),
    (
      s.withdrawalsPending,
      TpArt.payout,
      'ถอนเงินรออนุมัติ',
      '/work?tab=withdrawals'
    ),
    (s.smsUnmatched, TpArt.sms, 'SMS ธนาคารยังไม่ตรงบิล', '/work?tab=sms'),
    (s.stuckReadings, TpArt.hourglass, 'คำทำนายค้าง', '/work?tab=stuck'),
  ];
  return [
    for (final it in items)
      if (it.$1.unavailable)
        TpRow(
          art: it.$2,
          title: it.$3,
          subtitle: 'โหลดตัวเลขส่วนนี้ไม่ได้ — แตะเพื่อเปิดดูเอง',
          trailing: const TpPill('ไม่ทราบ',
              tone: TpTone.warning, icon: PhosphorIconsBold.warning),
          onTap: () => context.go(it.$4),
        ),
  ];
}

/// คิวงานที่ต้องจัดการตอนนี้
class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.s});
  final OpsSummary s;

  @override
  Widget build(BuildContext context) {
    if (s.totalTasks == 0 && !s.anyUnavailable) {
      return const TpCard(
        padding: EdgeInsets.zero,
        child: TpEmpty(
          art: TpArt.emptyDone,
          title: 'ไม่มีงานค้าง',
          message: 'บิล แชท และคำขอถอนเงินถูกจัดการครบแล้ว',
          compact: true,
        ),
      );
    }
    String oldest(QueueItem q, String prefix) => q.oldestMinutes == null
        ? prefix
        : '$prefix · รอนานสุด ${TpFmt.duration(q.oldestMinutes!)}';
    final rows = <Widget>[
      for (final u in _unavailableRows(context, s)) u,
      if (s.customerRequests.count > 0)
        TpRow(
          art: TpArt.headset,
          title: 'ลูกค้าขอคุยกับแอดมิน',
          subtitle: oldest(s.customerRequests,
              s.customerRequests.preview ?? 'รอแอดมินรับเรื่อง'),
          trailing: TpCount(s.customerRequests.count, tone: TpTone.danger),
          onTap: () => context.go('/chat'),
        ),
      if (s.billsAwaiting.count > 0)
        TpRow(
          art: TpArt.bill,
          title: 'บิลรอแอดมินตรวจ',
          subtitle: oldest(
              s.billsAwaiting, 'รวม ${TpFmt.baht(s.billsAwaiting.amount)}'),
          trailing: TpCount(s.billsAwaiting.count),
          onTap: () => context.go('/work?tab=bills'),
        ),
      if (s.withdrawalsPending.count > 0)
        TpRow(
          art: TpArt.payout,
          title: 'ถอนเงินรออนุมัติ',
          subtitle:
              'รวม ${TpFmt.baht(s.withdrawalsPending.amount)} · ${s.withdrawalsPending.count} รายการ',
          trailing: TpCount(s.withdrawalsPending.count, tone: TpTone.info),
          onTap: () => context.go('/work?tab=withdrawals'),
        ),
      if (s.withdrawalsApproved.count > 0)
        TpRow(
          art: TpArt.wallet,
          title: 'อนุมัติแล้ว รอโอนเงิน',
          subtitle: oldest(s.withdrawalsApproved,
              'รวม ${TpFmt.baht(s.withdrawalsApproved.amount)} · โอนแล้วแนบสลิปปิดงาน'),
          trailing: TpCount(s.withdrawalsApproved.count),
          onTap: () => context.go('/work?tab=withdrawals&sub=approved'),
        ),
      if (s.smsUnmatched.count > 0)
        TpRow(
          art: TpArt.sms,
          title: 'SMS ธนาคารยังไม่ตรงบิล',
          subtitle: oldest(s.smsUnmatched, 'ต้องจับคู่ด้วยมือ'),
          trailing: TpCount(s.smsUnmatched.count, tone: TpTone.warning),
          onTap: () => context.go('/work?tab=sms'),
        ),
      if (s.stuckReadings.count > 0)
        TpRow(
          art: TpArt.hourglass,
          title: 'คำทำนายค้างเกิน 2 นาที',
          subtitle: s.stuckReadings.preview ?? 'ตรวจคิวงานบอทดูดวง',
          trailing: TpCount(s.stuckReadings.count, tone: TpTone.warning),
          onTap: () => context.go('/work?tab=stuck'),
        ),
    ];
    return TpGroup(children: rows);
  }
}

class _HealthGrid extends StatelessWidget {
  const _HealthGrid({required this.s});
  final OpsSummary s;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final aiOk = s.aiTotal > 0 && s.aiHealthy >= (s.aiTotal / 2).ceil();
    final push = s.linePushUsed;
    final pushRatio = push == null ? 0.0 : push / s.linePushLimit;
    final lat = s.latencyMs ?? 0;
    Widget tile({
      required TpArt art,
      required String title,
      required String value,
      required Color color,
      Widget? extra,
      VoidCallback? onTap,
    }) =>
        TpCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          onTap: onTap,
          child: Row(children: [
            Tp3D(art, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TpType.h(13, p.textStrong, w: FontWeight.w600)),
                    Text(value,
                        style: TpType.body(12, color, w: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (extra != null) ...[const SizedBox(height: 5), extra],
                  ]),
            ),
          ]),
        );

    return Column(children: [
      Row(children: [
        Expanded(
          child: tile(
            art: TpArt.ai,
            title: 'AI Pool',
            value: s.aiTotal == 0
                ? 'ยังไม่มีคีย์'
                : '${s.aiHealthy}/${s.aiTotal} คีย์พร้อม',
            color: aiOk ? p.success : p.warning,
            onTap: () => context.push('/fortune/ai-pool'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: tile(
            art: TpArt.broadcast,
            title: 'LINE push',
            value: push == null
                ? 'ไม่มีข้อมูล'
                : '$push/${s.linePushLimit} เดือนนี้',
            color: pushRatio >= 0.85
                ? p.danger
                : (pushRatio >= 0.6 ? p.warning : p.muted),
            extra: push == null
                ? null
                : TpMeter(
                    value: pushRatio,
                    color: pushRatio >= 0.85
                        ? p.danger
                        : (pushRatio >= 0.6 ? p.warning : p.gold)),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: tile(
            art: TpArt.hourglass,
            title: 'คิวงานเบื้องหลัง',
            value: s.queueBacklog == 0
                ? 'ว่าง'
                : '${TpFmt.count(s.queueBacklog)} งานรอ',
            color: s.queueBacklog > 50 ? p.warning : p.muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: tile(
            art: TpArt.server,
            title: 'เซิร์ฟเวอร์',
            value: '$lat ms',
            color: lat > 1500 ? p.danger : (lat > 700 ? p.warning : p.success),
          ),
        ),
      ]),
    ]);
  }
}

/// สถิติเดือนนี้ (จาก /dashboard เดิม) — แสดงเมื่อโหลดสำเร็จ ไม่บังหน้าถ้าล้ม
class _MonthStats extends ConsumerWidget {
  const _MonthStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(dashboardDataProvider).valueOrNull;
    if (d == null) return const SizedBox.shrink();
    final p = context.tp;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TpSection('สมาชิกและออเดอร์',
          action: 'สมาชิก', onAction: () => context.push('/users')),
      TpCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(children: [
          Expanded(
              child: TpStat(
                  label: 'สมาชิกทั้งหมด',
                  value: TpFmt.count(d.totalUsers),
                  align: CrossAxisAlignment.center)),
          Container(width: 1, height: 34, color: p.divider),
          Expanded(
              child: TpStat(
                  label: 'สมัครวันนี้',
                  value: '+${TpFmt.count(d.newUsersToday)}',
                  color: p.success,
                  align: CrossAxisAlignment.center)),
          Container(width: 1, height: 34, color: p.divider),
          Expanded(
              child: TpStat(
                  label: 'ออเดอร์รอส่ง',
                  value: TpFmt.count(d.ordersPending),
                  color: d.ordersPending > 0 ? p.warning : null,
                  align: CrossAxisAlignment.center)),
        ]),
      ),
    ]);
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TpHeroCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TpSkeleton(width: 90, height: 12),
              SizedBox(height: 10),
              TpSkeleton(width: 180, height: 34),
              SizedBox(height: 14),
              TpSkeleton(height: 92, radius: 12),
              SizedBox(height: 14),
              TpSkeleton(height: 30),
            ]),
          ),
          SizedBox(height: 22),
          TpSkeletonList(count: 4, itemHeight: 70),
        ]);
  }
}

/// ห้องแชท/บิลที่กำลังดำเนินการอยู่ — กด "รับช่วง" ครั้งเดียว = หยุดบอท 30 นาทีแล้วเข้าห้องแชททันที
class _LiveNow extends ConsumerWidget {
  const _LiveNow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveConversationsProvider);
    return TpAsync<List<Conversation>>(
      value: live,
      compactError: true,
      onRetry: () => ref.invalidate(liveConversationsProvider),
      loading: const TpSkeletonList(count: 3, itemHeight: 70),
      data: (items) {
        if (items.isEmpty) {
          return const TpCard(
            padding: EdgeInsets.zero,
            child: TpEmpty(
                art: TpArt.emptyInbox,
                title: 'ยังไม่มีบทสนทนาที่เปิดอยู่',
                compact: true),
          );
        }
        return TpGroup(
            children: [for (final c in items.take(6)) _LiveRow(c: c)]);
      },
    );
  }
}

class _LiveRow extends ConsumerStatefulWidget {
  const _LiveRow({required this.c});
  final Conversation c;

  @override
  ConsumerState<_LiveRow> createState() => _LiveRowState();
}

class _LiveRowState extends ConsumerState<_LiveRow> {
  bool _busy = false;

  Future<void> _takeOver() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .takeover(widget.c.readingId, minutes: 30);
      if (!mounted) return;
      ref.invalidate(liveConversationsProvider);
      ref.invalidate(opsSummaryProvider);
      tpToast(context, 'รับช่วงแล้ว · บอทหยุดตอบห้องนี้ 30 นาที',
          kind: TpToastKind.success);
      context.push('/chat/${widget.c.readingId}');
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final c = widget.c;
    final who = switch (c.lastSender) {
      'admin' => 'คุณ: ',
      'bot' => 'บอท: ',
      _ => '',
    };
    final preview = c.lastText == null
        ? (c.stageLabel ?? c.packageLabel ?? '')
        : '$who${c.lastText}';
    return InkWell(
      onTap: () => context.push('/chat/${c.readingId}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(children: [
          TpAvatar(name: c.customerName, platform: c.platform, size: 40),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(c.customerName ?? 'ลูกค้า',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                if (c.packageLabel != null)
                  TpPill(c.packageLabel!, tone: TpTone.gold, dense: true),
              ]),
              const SizedBox(height: 2),
              Text(preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12.5, c.unread ? p.text : p.muted,
                      w: c.unread ? FontWeight.w600 : FontWeight.w400)),
              const SizedBox(height: 2),
              Text(
                [c.stageLabel, TpFmt.ago(c.lastAt ?? c.updatedAt)]
                    .whereType<String>()
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(11.5, p.faint),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (c.isTakenOver)
            TpPill('คุมอยู่ ${TpFmt.duration(c.remainingMinutes)}',
                tone: TpTone.navy, icon: PhosphorIconsFill.headset, dense: true)
          else
            _TakeButton(busy: _busy, onTap: _takeOver),
        ]),
      ),
    );
  }
}

class _TakeButton extends StatelessWidget {
  const _TakeButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: TpPalette.goldButton),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: TpPalette.onGold))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(PhosphorIconsFill.headset,
                          size: 15, color: TpPalette.onGold),
                      const SizedBox(width: 5),
                      Text('รับช่วง',
                          style: TpType.body(12.5, TpPalette.onGold,
                              w: FontWeight.w700, height: 1.1)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}
