import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/approvals_repository.dart';
import 'approval_widgets.dart';

/// หน้า "งานอนุมัติ" (`/approvals`) — รวมทุกคิวที่ต้องให้คนตัดสิน พร้อมจำนวน + เวลารอนานสุด
///
/// คิวที่เซิร์ฟเวอร์อ่านไม่ได้ (null / อยู่ใน degraded) แสดง "ไม่ทราบ" — ห้ามตีเป็น 0 งาน
class ApprovalsHubScreen extends ConsumerWidget {
  const ApprovalsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sum = ref.watch(approvalsSummaryProvider);
    final s = sum.valueOrNull;

    Future<void> refresh() async {
      ref.invalidate(approvalsSummaryProvider);
      try {
        await ref.read(approvalsSummaryProvider.future);
      } catch (_) {
        // error แสดงผ่าน TpAsync อยู่แล้ว
      }
    }

    return TpPage(
      title: 'งานอนุมัติ',
      subtitle: s == null
          ? 'คิวที่ต้องให้แอดมินตัดสิน'
          : s.total > 0
              ? 'ค้างอยู่ ${TpFmt.count(s.total)} เรื่อง'
              : (s.anyUnknown ? 'บางคิวโหลดตัวเลขไม่ได้' : 'ไม่มีงานค้าง'),
      back: true,
      bottomSpace: 32,
      onRefresh: refresh,
      slivers: [
        SliverToBoxAdapter(
          child: TpAsync<ApprovalsSummary>(
            value: sum,
            onRetry: () => ref.invalidate(approvalsSummaryProvider),
            loading: const _HubSkeleton(),
            data: (s) => _HubBody(s: s),
          ),
        ),
      ],
    );
  }
}

class _HubBody extends StatelessWidget {
  const _HubBody({required this.s});
  final ApprovalsSummary s;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final jobs = s.box(ApprovalQueue.riderJobs);
    final mlm = s.box(ApprovalQueue.mlmCommissions);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _HubHero(s: s),
      if (s.anyUnknown) ...[
        const SizedBox(height: 12),
        const ApprovalNotice(
          text:
              'บางคิวโหลดตัวเลขไม่ได้รอบนี้ (ขึ้น "ไม่ทราบ") — ไม่ได้แปลว่าไม่มีงาน แตะเข้าไปดูรายการเองได้',
        ),
      ],
      const TpSection('ตรวจตัวตนและใบสมัคร'),
      TpGroup(children: [
        _QueueRow(
          box: s.box(ApprovalQueue.ekyc),
          art: TpArt.shield,
          title: 'ยืนยันตัวตน (eKYC)',
          idle: 'ไม่มีคำขอที่ AI ไม่มั่นใจ',
          detail: (_) => 'AI ไม่มั่นใจ รอเจ้าหน้าที่ตรวจ',
          tone: TpTone.info,
          route: '/approvals/ekyc',
        ),
        _QueueRow(
          box: s.box(ApprovalQueue.sellerApplications),
          art: TpArt.store,
          title: 'คำขอเปิดร้านค้า',
          idle: 'ไม่มีร้านรออนุมัติ',
          route: '/approvals/sellers',
        ),
        _QueueRow(
          box: s.box(ApprovalQueue.riderApplications),
          art: TpArt.scooter,
          title: 'ใบสมัครไรเดอร์',
          idle: 'ไม่มีใบสมัครรอตรวจ',
          route: '/approvals/riders',
        ),
        _QueueRow(
          box: s.box(ApprovalQueue.riderDocuments),
          art: TpArt.scooter,
          title: 'ไรเดอร์เปลี่ยนเอกสาร',
          idle: 'ไม่มีเอกสารรอตรวจซ้ำ',
          detail: (_) => 'รับงานไม่ได้จนกว่าจะตรวจ',
          tone: TpTone.warning,
          route: '/approvals/riders?status=documents_changed',
        ),
      ]),
      TpSection(
        'เงินและบริการลูกค้า',
        trailing: const TpPill('เคลื่อนเงิน',
            tone: TpTone.warning, icon: PhosphorIconsBold.coins, dense: true),
      ),
      TpGroup(children: [
        _QueueRow(
          box: jobs,
          art: TpArt.payout,
          title: 'งานไรเดอร์รอตัดสิน',
          idle: 'ไม่มีงานที่ต้องตัดสิน',
          detail: (b) => [
            if ((b.disputed ?? 0) > 0) 'ร้องเรียน ${b.disputed}',
            if ((b.awaitingRelease ?? 0) > 0) 'เงินพัก ${b.awaitingRelease}',
            if ((b.manualNeeded ?? 0) > 0) 'ต้องมอบหมาย ${b.manualNeeded}',
          ].join(' · '),
          tone: TpTone.danger,
          route: '/approvals/rider-jobs',
        ),
        _QueueRow(
          box: mlm,
          art: TpArt.members,
          title: 'คอมมิชชัน MLM',
          idle: (mlm?.approvedUnpaid ?? 0) > 0
              ? 'อนุมัติแล้วรอจ่าย ${mlm!.approvedUnpaid} รายการ'
              : 'ไม่มีคอมรออนุมัติ',
          detail: (b) => [
            if (b.amountThb != null) 'รวม ${TpFmt.baht(b.amountThb)}',
            if ((b.approvedUnpaid ?? 0) > 0) 'รอจ่าย ${b.approvedUnpaid}',
          ].join(' · '),
          idleTrailing: (mlm?.approvedUnpaid ?? 0) > 0
              ? TpPill('รอจ่าย ${mlm!.approvedUnpaid}',
                  tone: TpTone.gold, dense: true)
              : null,
          route: '/approvals/mlm',
        ),
        _QueueRow(
          box: s.box(ApprovalQueue.tickets),
          art: TpArt.headset,
          title: 'ตั๋วซัพพอร์ต',
          idle: 'ไม่มีตั๋วรอทีมงาน',
          detail: (_) => 'รอทีมงานตอบ',
          tone: TpTone.info,
          route: '/approvals/tickets',
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
        child: Text(
          [
            'ตัวเลขใช้ร่วมกันทุกแอดมิน (อัปเดตทุก 20 วินาที)',
            if (s.computedAt != null) 'คำนวณเมื่อ ${TpFmt.time(s.computedAt!)}',
          ].join(' · '),
          textAlign: TextAlign.center,
          style: TpType.body(11.5, p.faint),
        ),
      ),
    ]);
  }
}

/// แถวคิวหนึ่งคิว — ภาพ 3D + ชื่อ + รายละเอียด/เวลารอ + ตัวนับ (null = "ไม่ทราบ")
class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.box,
    required this.art,
    required this.title,
    required this.idle,
    required this.route,
    this.detail,
    this.tone = TpTone.gold,
    this.idleTrailing,
  });

  final ApprovalBox? box;
  final TpArt art;
  final String title;
  final String idle;
  final String route;
  final String Function(ApprovalBox b)? detail;
  final TpTone tone;
  final Widget? idleTrailing;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final b = box;
    final String subtitle;
    final Widget trailing;
    if (b == null) {
      subtitle = 'โหลดตัวเลขส่วนนี้ไม่ได้ — แตะเพื่อเปิดดูเอง';
      trailing = const TpPill('ไม่ทราบ',
          tone: TpTone.warning, icon: PhosphorIconsBold.warning, dense: true);
    } else if (b.count == 0) {
      subtitle = idle;
      trailing = idleTrailing ??
          Icon(PhosphorIconsFill.checkCircle, size: 20, color: p.success);
    } else {
      final d = detail?.call(b) ?? '';
      subtitle = [
        if (d.isNotEmpty) d,
        if (b.oldestMinutes != null)
          'รอนานสุด ${approvalDuration(b.oldestMinutes!)}',
      ].join(' · ');
      trailing = TpCount(b.count, tone: tone);
    }
    return TpRow(
      art: art,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: () => context.push(route),
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero({required this.s});
  final ApprovalsSummary s;

  @override
  Widget build(BuildContext context) {
    final jobs = s.box(ApprovalQueue.riderJobs);
    final mlm = s.box(ApprovalQueue.mlmCommissions);
    final tickets = s.box(ApprovalQueue.tickets);
    final oldest = s.oldestMinutes;
    final money = (jobs == null || mlm == null)
        ? 'ไม่ทราบ'
        : '${TpFmt.count(jobs.count + mlm.count)} รายการ';
    return TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('งานรออนุมัติทั้งหมด',
                style:
                    TpType.body(13.5, TpPalette.heroMuted, w: FontWeight.w500)),
          ),
          if (s.computedAt != null)
            Text('อัปเดต ${TpFmt.time(s.computedAt!)}',
                style: TpType.body(11.5, TpPalette.heroMuted)),
        ]),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          TpFoilText(TpFmt.count(s.total),
              style: TpType.money(40, Colors.white)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('เรื่อง',
                style: TpType.body(15, TpPalette.heroText, w: FontWeight.w500)),
          ),
          if (s.anyUnknown)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 8),
                child: Text('+ คิวที่โหลดไม่ได้',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TpType.body(11.5, TpPalette.heroMuted)),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Container(height: 1, color: TpPalette.heroText.withValues(alpha: 0.08)),
        const SizedBox(height: 10),
        Row(children: [
          _HeroStat(
              'รอนานสุด', oldest == null ? '-' : approvalDuration(oldest)),
          _HeroStat('เคลื่อนเงิน', money),
          _HeroStat('ตั๋วลูกค้า',
              tickets == null ? 'ไม่ทราบ' : '${TpFmt.count(tickets.count)} ใบ'),
        ]),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style:
                    TpType.body(11.5, TpPalette.heroMuted, w: FontWeight.w500)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TpType.money(15, TpPalette.heroText)),
            ),
          ]),
        ),
      );
}

class _HubSkeleton extends StatelessWidget {
  const _HubSkeleton();

  @override
  Widget build(BuildContext context) =>
      const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TpHeroCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TpSkeleton(width: 120, height: 12),
            SizedBox(height: 10),
            TpSkeleton(width: 110, height: 34),
            SizedBox(height: 16),
            TpSkeleton(height: 30),
          ]),
        ),
        SizedBox(height: 22),
        TpSkeletonList(count: 4, itemHeight: 70),
      ]);
}
