import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/approvals_repository.dart';
import 'approval_widgets.dart';

/// หน้า "งานไรเดอร์รอตัดสิน" (`/approvals/rider-jobs?filter=`) — 💸 เคลื่อนเงินจริง
///
/// - ปล่อยเงิน = ปิดงานส่งสำเร็จ แบ่งเงินร้าน + จ่ายไรเดอร์ → เลื่อนยืนยัน
/// - คืนเงิน = งานส่งไม่สำเร็จ + ยกเลิกออเดอร์ คืนผู้ซื้อเต็มจำนวน → ปุ่มแดง + ต้องใส่เหตุผล
/// - มอบหมายใหม่ = เลือกจากรายชื่อที่รับได้ หรือใส่รหัสไรเดอร์ · เรียกไรเดอร์ใหม่ = ยืนยันก่อน
/// ทุกการตัดสินจริงอยู่ที่ service ฝั่งเซิร์ฟเวอร์ (กดซ้ำปลอดภัย — ได้ already_decided)
class RiderJobsScreen extends ConsumerStatefulWidget {
  const RiderJobsScreen({super.key, this.initialFilter});
  final String? initialFilter;

  @override
  ConsumerState<RiderJobsScreen> createState() => _RiderJobsScreenState();
}

class _RiderJobsScreenState extends ConsumerState<RiderJobsScreen> {
  late RiderJobFilter _filter = RiderJobFilter.parse(widget.initialFilter);
  int _reload = 0;
  int? _found;

  Future<void> _refresh() async {
    setState(() => _reload++);
    try {
      ref.invalidate(approvalsSummaryProvider);
      await ref.read(approvalsSummaryProvider.future);
    } catch (_) {}
  }

  void _changed() {
    if (!mounted) return;
    setState(() => _reload++);
    ref.invalidate(approvalsSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final b = ref.watch(approvalsSummaryProvider).valueOrNull?.box(
          ApprovalQueue.riderJobs,
        );
    return TpPage(
      title: 'งานไรเดอร์รอตัดสิน',
      subtitle: _found == null
          ? 'ร้องเรียน · เงินพัก · หาไรเดอร์ไม่ได้'
          : 'พบ ${TpFmt.count(_found)} งาน',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom: TpChips<RiderJobFilter>(
        onHeader: true,
        padding: EdgeInsets.zero,
        value: _filter,
        onChanged: (f) => setState(() {
          _filter = f;
          _found = null;
        }),
        items: [
          for (final f in RiderJobFilter.values)
            TpChipItem(f, f.label,
                count: switch (f) {
                  RiderJobFilter.needsDecision => b?.count,
                  RiderJobFilter.disputed => b?.disputed,
                  RiderJobFilter.awaitingRelease => b?.awaitingRelease,
                  RiderJobFilter.manualNeeded => b?.manualNeeded,
                  RiderJobFilter.handoverReview => null,
                }),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child:
                    Icon(PhosphorIconsFill.coins, size: 15, color: p.warning),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'รายการนี้ขยับเงินจริง — ปล่อยเงิน = ร้านและไรเดอร์ได้เงิน · คืนเงิน = ยกเลิกออเดอร์ คืนผู้ซื้อเต็มจำนวน',
                    style: TpType.body(12.5, p.muted)),
              ),
            ]),
          ),
        ),
        TpPagedSliver<RiderJob>(
          reloadKey: '${_filter.key}|$_reload',
          fetch: (page) => ref
              .read(approvalsRepositoryProvider)
              .riderJobs(filter: _filter, page: page),
          onLoaded: (pg) {
            if (mounted) setState(() => _found = pg.total);
          },
          empty: const TpEmpty(
            art: TpArt.emptyDone,
            title: 'ไม่มีงานที่ต้องตัดสิน',
            message: 'งานที่ผู้ซื้อร้องเรียนหรือเงินพักรอปลดจะขึ้นที่นี่',
            compact: true,
          ),
          itemBuilder: (context, job, _) => _JobCard(
            job: job,
            onTap: () async {
              if (await showRiderJobSheet(context, job)) _changed();
            },
          ),
        ),
      ],
    );
  }
}

(String, TpTone, IconData) _decision(RiderJob j) => switch (j.decisionType) {
      'dispute' => (
          'ผู้ซื้อร้องเรียน',
          TpTone.danger,
          PhosphorIconsBold.warning
        ),
      'awaiting_release' => (
          'เงินพักรอปลด',
          TpTone.gold,
          PhosphorIconsBold.hourglassMedium
        ),
      'manual_dispatch' => (
          'ไม่มีไรเดอร์รับ',
          TpTone.warning,
          PhosphorIconsBold.motorcycle
        ),
      'handover_review' => (
          'รอตัดสินส่งมอบ',
          TpTone.info,
          PhosphorIconsBold.scales
        ),
      _ => (j.statusText ?? 'รอตัดสิน', TpTone.neutral, PhosphorIconsBold.info),
    };

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});
  final RiderJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final (label, tone, icon) = _decision(job);
    final people = [
      if (job.customer != null) 'ผู้ซื้อ ${job.customer!.display}',
      if (job.rider != null) 'ไรเดอร์ ${job.rider!.display}',
    ].join(' · ');
    return TpCard(
      accent: p.fg(tone),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TpIconTile(icon, tone: tone, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(job.jobNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.money(14.5, p.textStrong, w: FontWeight.w700)),
              Text(job.statusText ?? label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12.5, p.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(TpFmt.baht(job.amounts.orderTotal),
                style: TpType.money(17, p.goldText)),
            Text('เงินพัก', style: TpType.body(11, p.faint)),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TpPill(pillText(label), tone: tone, dense: true),
          WaitPill(job.waitingMinutes),
          if (job.autoReleaseAt != null)
            TpPill('ปลดเอง ${TpFmt.dateTime(job.autoReleaseAt!)}',
                tone: TpTone.navy,
                icon: PhosphorIconsBold.clockCountdown,
                dense: true),
        ]),
        if (job.reasonText != null) ...[
          const SizedBox(height: 8),
          Text(
            job.reasonNote == null
                ? job.reasonText!
                : '${job.reasonText} — “${job.reasonNote}”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TpType.body(
                13, job.decisionType == 'dispute' ? p.danger : p.text,
                w: FontWeight.w500),
          ),
        ],
        if (people.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(people,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TpType.body(12, p.muted)),
        ],
      ]),
    );
  }
}

/// เปิดแผ่นรายละเอียดงาน — คืน true ถ้ามีการตัดสิน
Future<bool> showRiderJobSheet(BuildContext context, RiderJob job) async {
  final r = await tpShowSheet<bool>(context,
      initial: 0.92,
      builder: (ctx, scroll) => _JobSheet(job: job, scroll: scroll));
  return r ?? false;
}

class _JobSheet extends ConsumerStatefulWidget {
  const _JobSheet({required this.job, required this.scroll});
  final RiderJob job;
  final ScrollController scroll;

  @override
  ConsumerState<_JobSheet> createState() => _JobSheetState();
}

class _JobSheetState extends ConsumerState<_JobSheet> {
  bool _sliding = false;

  /// ปุ่มที่กำลังทำงาน ('refund' / 'reassign' / 'redispatch') — null = ว่าง
  String? _running;

  /// รูปหลักฐานที่แผ่นนี้แสดง — ล้างออกจากแคชหน่วยความจำตอนปิด
  final _photos = <String>{};

  int get _id => widget.job.id;
  bool get _locked => _running != null || _sliding;

  @override
  void dispose() {
    evictPrivatePhotos(_photos);
    super.dispose();
  }

  Future<bool> _release() async {
    setState(() => _sliding = true);
    final ok = await runApprovalAction(context,
        () => ref.read(approvalsRepositoryProvider).releaseRiderJob(_id));
    if (mounted) setState(() => _sliding = false);
    return ok;
  }

  Future<void> _refund(RiderJob j) async {
    final reason = await askReason(
      context,
      title:
          'คืนเงินผู้ซื้อ ${TpFmt.baht(j.amounts.orderTotal, decimals: true)}?',
      message:
          'งานจะปิดเป็น "ส่งไม่สำเร็จ" (ไรเดอร์ไม่ได้ค่าส่ง) และยกเลิกออเดอร์ คืนเงินผู้ซื้อเต็มจำนวน — ย้อนกลับไม่ได้',
      hint: 'เหตุผล เช่น ผู้ซื้อได้ของผิด',
      confirmLabel: 'คืนเงิน',
      min: 3,
      max: 1000,
    );
    if (reason == null || !mounted) return;
    setState(() => _running = 'refund');
    await runApprovalAction(
        context,
        () =>
            ref.read(approvalsRepositoryProvider).refundRiderJob(_id, reason));
    if (mounted) setState(() => _running = null);
  }

  Future<void> _reassignById() async {
    final v = await tpPrompt(
      context,
      title: 'มอบหมายให้ไรเดอร์',
      message:
          'ใส่รหัสไรเดอร์ (ตัวเลข) — ไรเดอร์ต้องอนุมัติแล้ว ไม่ถูกระงับ ไม่มีงานค้าง และไม่ใช่คู่กรณี',
      hint: 'เช่น 15',
      confirmLabel: 'มอบหมาย',
      maxLines: 1,
    );
    if (v == null || !mounted) return;
    final riderId = int.tryParse(v.replaceAll('#', '').trim());
    if (riderId == null || riderId <= 0) {
      tpToast(context, 'รหัสไรเดอร์ต้องเป็นตัวเลข', kind: TpToastKind.error);
      return;
    }
    await _reassign(riderId);
  }

  Future<void> _reassignTo(EligibleRider r) async {
    final yes = await tpConfirm(
      context,
      title: 'มอบหมายงานให้ ${r.fullName}?',
      message:
          'งาน ${widget.job.jobNumber} จะย้ายไปให้ไรเดอร์คนนี้ (รหัส ${r.id}) และแจ้งทุกฝ่าย',
      confirmLabel: 'มอบหมาย',
    );
    if (!yes || !mounted) return;
    await _reassign(r.id);
  }

  Future<void> _reassign(int riderId) async {
    setState(() => _running = 'reassign');
    await runApprovalAction(
        context,
        () => ref
            .read(approvalsRepositoryProvider)
            .reassignRiderJob(_id, riderId));
    if (mounted) setState(() => _running = null);
  }

  Future<void> _redispatch() async {
    final yes = await tpConfirm(
      context,
      title: 'เรียกไรเดอร์ใหม่?',
      message:
          'สร้างงานใหม่ให้ออเดอร์นี้ แล้วระบบจะหาไรเดอร์รับงานอีกรอบ (ใช้กับงานที่ยกเลิก/ส่งไม่สำเร็จ)',
      confirmLabel: 'เรียกไรเดอร์ใหม่',
    );
    if (!yes || !mounted) return;
    setState(() => _running = 'redispatch');
    await runApprovalAction(context,
        () => ref.read(approvalsRepositoryProvider).redispatchRiderJob(_id));
    if (mounted) setState(() => _running = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final detail = ref.watch(riderJobDetailProvider(_id));
    final d = detail.valueOrNull;
    if (d != null) {
      _photos.addAll([
        for (final ph in d.photos)
          if (ph.url != null) ph.url!
      ]);
    }
    final j = d?.job ?? widget.job;
    final (label, tone, _) = _decision(j);

    return Column(children: [
      Expanded(
        child: ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          children: [
            SheetHeader(
              leading: const Tp3D(TpArt.payout, size: 50),
              title: j.jobNumber,
              subtitle: [
                if (j.orderNumber != null) 'ออเดอร์ ${j.orderNumber}',
                j.statusText,
              ].whereType<String>().join(' · '),
              pill: Wrap(spacing: 6, runSpacing: 6, children: [
                TpPill(pillText(label), tone: tone, dense: true),
                WaitPill(j.waitingMinutes),
              ]),
            ),
            const SizedBox(height: 16),
            Center(
                child: Text('เงินพักของออเดอร์',
                    style: TpType.body(12.5, p.muted))),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(TpFmt.baht(j.amounts.orderTotal, decimals: true),
                    style: TpType.money(36, p.goldText)),
              ),
            ),
            if (j.amounts.riderEarnings > 0 || j.amounts.deliveryFee > 0)
              Center(
                child: Text(
                    'ค่าส่ง ${TpFmt.baht(j.amounts.deliveryFee)} · ไรเดอร์ได้ ${TpFmt.baht(j.amounts.riderEarnings)}',
                    style: TpType.body(12.5, p.faint)),
              ),
            const SizedBox(height: 12),
            if (j.reasonText != null) ...[
              ApprovalNotice(
                tone: j.decisionType == 'dispute'
                    ? TpTone.danger
                    : TpTone.warning,
                text: j.reasonNote == null
                    ? j.reasonText!
                    : '${j.reasonText}\nผู้ซื้อเขียนว่า: “${j.reasonNote}”',
              ),
              const SizedBox(height: 4),
            ],
            TpAsync<RiderJobDetail>(
              value: detail,
              compactError: true,
              onRetry: () => ref.invalidate(riderJobDetailProvider(_id)),
              loading: const SheetSkeleton(),
              data: (d) => _JobBody(
                d: d,
                busy: _locked,
                onPickRider: _reassignTo,
                onReassignById: _reassignById,
              ),
            ),
          ],
        ),
      ),
      if (d != null && d.job.hasAction) _actions(d.job),
    ]);
  }

  Widget _actions(RiderJob j) {
    final p = context.tp;
    final money = TpFmt.baht(j.amounts.orderTotal, decimals: true);
    return TpBottomBar(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (j.canRelease) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                'ปล่อยเงิน = ปิดงานเป็นส่งสำเร็จ แบ่งเงินให้ร้าน และจ่ายไรเดอร์ ${TpFmt.baht(j.amounts.riderEarnings)}',
                textAlign: TextAlign.center,
                style: TpType.body(12, p.muted, w: FontWeight.w500)),
          ),
          TpSlideToConfirm(
            label: 'เลื่อนเพื่อปล่อยเงิน $money',
            enabled: _running == null,
            onConfirmed: _release,
          ),
        ],
        if (j.canRefund || j.canReassign || j.canRedispatch) ...[
          if (j.canRelease) const SizedBox(height: 10),
          Row(children: [
            if (j.canRefund)
              Expanded(
                child: TpButton.danger('คืนเงินผู้ซื้อ',
                    icon: PhosphorIconsRegular.arrowCounterClockwise,
                    height: 44,
                    fontSize: 14,
                    loading: _running == 'refund',
                    onPressed: _locked ? null : () => _refund(j)),
              ),
            if (j.canRefund && (j.canReassign || j.canRedispatch))
              const SizedBox(width: 10),
            if (j.canReassign)
              Expanded(
                child: TpButton.outline('มอบหมายไรเดอร์',
                    icon: PhosphorIconsRegular.userSwitch,
                    height: 44,
                    fontSize: 14,
                    loading: _running == 'reassign',
                    onPressed: _locked ? null : _reassignById),
              )
            else if (j.canRedispatch)
              Expanded(
                child: TpButton.outline('เรียกไรเดอร์ใหม่',
                    icon: PhosphorIconsRegular.arrowsClockwise,
                    height: 44,
                    fontSize: 14,
                    loading: _running == 'redispatch',
                    onPressed: _locked ? null : _redispatch),
              ),
          ]),
          if (j.canReassign && j.canRedispatch) ...[
            const SizedBox(height: 10),
            TpButton.outline('เรียกไรเดอร์ใหม่',
                icon: PhosphorIconsRegular.arrowsClockwise,
                height: 44,
                fontSize: 14,
                loading: _running == 'redispatch',
                onPressed: _locked ? null : _redispatch),
          ],
        ],
      ]),
    );
  }
}

class _JobBody extends StatelessWidget {
  const _JobBody({
    required this.d,
    required this.busy,
    required this.onPickRider,
    required this.onReassignById,
  });
  final RiderJobDetail d;
  final bool busy;
  final ValueChanged<EligibleRider> onPickRider;
  final VoidCallback onReassignById;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final j = d.job;
    final a = j.amounts;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.cancellationReason != null) ...[
        const SizedBox(height: 8),
        ApprovalNotice(
            tone: TpTone.neutral,
            icon: PhosphorIconsFill.info,
            text: 'เหตุผลที่ยกเลิก: ${d.cancellationReason}'),
      ],
      if (d.failureReason != null) ...[
        const SizedBox(height: 8),
        ApprovalNotice(
            tone: TpTone.neutral,
            icon: PhosphorIconsFill.info,
            text: 'เหตุผลที่ส่งไม่สำเร็จ: ${d.failureReason}'),
      ],

      // ── การส่งมอบ + รูปหลักฐาน ──
      DetailSection('การส่งมอบ', children: [
        TpKv('สถานะ', j.handoverStatusText ?? j.statusText ?? '-'),
        if (j.disputedAt != null)
          TpKv('ร้องเรียนเมื่อ', approvalWhen(j.disputedAt),
              valueColor: p.danger),
        if (j.waitedPhotoAt != null)
          TpKv('ถ่ายรูปวางของ', approvalWhen(j.waitedPhotoAt)),
        if (j.buyerConfirmedAt != null)
          TpKv('ผู้ซื้อยืนยันรับ', approvalWhen(j.buyerConfirmedAt),
              valueColor: p.success),
        if (j.autoReleaseAt != null)
          TpKv('ปลดเงินอัตโนมัติ', approvalWhen(j.autoReleaseAt),
              valueColor: p.goldText),
      ]),
      if (d.photos.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < d.photos.length && i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: PrivatePhoto(
                url: d.photos[i].url,
                label: d.photos[i].takenAt == null
                    ? d.photos[i].label
                    : '${d.photos[i].label} · ${TpFmt.dateTime(d.photos[i].takenAt!)}',
                height: 130,
              ),
            ),
          ],
          if (d.photos.length == 1) ...[
            const SizedBox(width: 10),
            const Expanded(child: SizedBox.shrink()),
          ],
        ]),
      ],

      // ── ยอดเงิน ──
      DetailSection('ยอดเงิน', children: [
        TpKv('ยอดออเดอร์ (เงินพัก)', TpFmt.baht(a.orderTotal, decimals: true),
            mono: true, valueColor: p.goldText),
        TpKv('ค่าส่งรวม', TpFmt.baht(a.deliveryFee, decimals: true),
            mono: true),
        TpKv('ส่วนของไรเดอร์', TpFmt.baht(a.riderEarnings, decimals: true),
            mono: true),
        TpKv('ค่าบริการแพลตฟอร์ม', TpFmt.baht(a.platformFee, decimals: true),
            mono: true),
        if (a.shopBonus > 0)
          TpKv('โบนัสที่ร้านเติม', TpFmt.baht(a.shopBonus, decimals: true),
              mono: true),
        if (a.cod > 0)
          TpKv('เก็บเงินปลายทาง', TpFmt.baht(a.cod, decimals: true),
              mono: true),
      ]),

      // ── คู่กรณี + เส้นทาง ──
      DetailSection('คู่กรณีและเส้นทาง', children: [
        TpKv(
            'ผู้ซื้อ',
            j.customer == null
                ? '-'
                : [j.customer!.display, j.customer!.memberNumber]
                    .whereType<String>()
                    .join(' · ')),
        TpKv(
            'ไรเดอร์',
            j.rider == null
                ? 'ยังไม่มี'
                : '${j.rider!.display} (#${j.rider!.id})'),
        if (d.title != null) TpKv('งาน', d.title!),
        TpKv(
            'รับของที่',
            [d.pickupContact, d.pickupAddress]
                .whereType<String>()
                .join(' · ')
                .ifEmpty('-')),
        TpKv(
            'ส่งถึง',
            [d.deliveryContact, d.deliveryAddress]
                .whereType<String>()
                .join(' · ')
                .ifEmpty('-')),
        if (d.distanceKm != null)
          TpKv('ระยะทาง', '${d.distanceKm!.toStringAsFixed(1)} กม.',
              mono: true),
        if (d.dispatchRound != null)
          TpKv('รอบเรียกไรเดอร์', 'รอบที่ ${d.dispatchRound}'),
      ]),

      if (d.timeline.isNotEmpty)
        DetailSection('ลำดับเหตุการณ์', children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ApprovalTimeline(steps: d.timeline),
          ),
        ]),

      // ── ไรเดอร์ที่มอบหมายได้ ──
      if (j.canReassign)
        DetailSection(
          'ไรเดอร์ที่รับงานนี้ได้',
          trailing: TpButton.ghost('ใส่รหัสเอง',
              height: 32,
              fontSize: 13,
              onPressed: busy ? null : onReassignById),
          children: [
            if (d.eligibleRiders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('ตอนนี้ไม่มีไรเดอร์ว่างที่รับงานนี้ได้',
                    style: TpType.body(13, p.muted)),
              ),
            for (final r in d.eligibleRiders)
              InkWell(
                onTap: busy ? null : () => onPickRider(r),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    TpAvatar(name: r.fullName, size: 36, online: r.online),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TpType.h(14, p.textStrong,
                                    w: FontWeight.w600)),
                            Text(
                              [
                                '#${r.id}',
                                r.vehicleTypeText,
                                r.availabilityText,
                                if (r.distanceKm != null)
                                  '${r.distanceKm!.toStringAsFixed(1)} กม. ถึงจุดรับ',
                              ].whereType<String>().join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TpType.body(12, p.muted),
                            ),
                          ]),
                    ),
                    Icon(PhosphorIconsRegular.caretRight,
                        size: 16, color: p.faint),
                  ]),
                ),
              ),
          ],
        ),
    ]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
