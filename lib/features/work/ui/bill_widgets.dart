import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/storage/secure_storage.dart';
import '../../../shared/ui/tp.dart';
import '../../home/data/ops_repository.dart';
import '../data/work_repository.dart';

/// การ์ดบิลในคิว (แถบสีซ้าย: เขียว = SMS ตรงยอด · ส้ม = ยังไม่พบ SMS)
class BillCard extends StatelessWidget {
  const BillCard({super.key, required this.bill, required this.onTap, this.onQuickConfirm});
  final FortuneBill bill;
  final VoidCallback onTap;

  /// แสดงปุ่มลัด "ยืนยันยอด" เมื่อ SMS ตรงแล้ว (ยังต้องเลื่อนยืนยันในแผ่นรายละเอียด)
  final VoidCallback? onQuickConfirm;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final matched = bill.sms.matched;
    final accent = bill.isPaid ? p.success : (matched ? p.success : p.warning);
    return TpCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      accent: bill.status == 'cancelled' || bill.status == 'refunded' ? p.faint : accent,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TpAvatar(name: bill.customerName, platform: bill.platform),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bill.customerName ?? 'ลูกค้า', style: TpType.h(14.5, p.textStrong, w: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(bill.billNumber, style: TpType.money(12, p.muted, w: FontWeight.w500)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(TpFmt.baht(bill.amount), style: TpType.money(18, p.goldText)),
            Text(TpFmt.ago(bill.paidAt ?? bill.createdAt), style: TpType.body(11.5, p.faint)),
          ]),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 56),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            TpPill(bill.packageLabel, tone: TpTone.gold),
            if (bill.isPaid)
              const TpPill('จ่ายแล้ว', tone: TpTone.success, icon: PhosphorIconsBold.check)
            else if (matched)
              const TpPill('SMS ตรงยอด', tone: TpTone.success, icon: PhosphorIconsBold.check)
            else if (bill.isFloating)
              const TpPill('บิลลอย', tone: TpTone.warning, icon: PhosphorIconsBold.question)
            else if (bill.status == 'awaiting')
              TpPill(bill.statusReason == 'transfer_reported' ? 'แจ้งโอนแล้ว' : 'ยังไม่พบ SMS', tone: TpTone.warning, icon: PhosphorIconsBold.clock)
            else if (bill.status == 'unpaid')
              const TpPill('รอลูกค้าโอน', tone: TpTone.info, icon: PhosphorIconsBold.hourglassMedium)
            else if (bill.isClosed)
              TpPill(bill.statusLabel ?? 'ปิดแล้ว', tone: TpTone.neutral),
            if (bill.slipUrl != null) const TpPill('มีสลิป', tone: TpTone.info, icon: PhosphorIconsBold.image),
            if (bill.priorPaid > 0) TpPill('ลูกค้าเก่า ${bill.priorPaid} ครั้ง', tone: TpTone.navy),
          ]),
        ),
        if (onQuickConfirm != null && bill.mayMarkPaid) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Row(children: [
              Expanded(
                child: TpButton.outline('ดูหลักฐาน',
                    icon: PhosphorIconsRegular.magnifyingGlass, height: 40, fontSize: 13.5, onPressed: onTap),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TpButton('ยืนยันยอด',
                    icon: PhosphorIconsBold.checkCircle, height: 40, fontSize: 13.5, onPressed: onQuickConfirm),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// เปิดแผ่นรายละเอียดบิล — คืน true ถ้ามีการเปลี่ยนสถานะ (ให้หน้ารายการรีเฟรช)
Future<bool> showBillSheet(BuildContext context, FortuneBill bill) async {
  final changed = await tpShowSheet<bool>(
    context,
    initial: 0.9,
    builder: (ctx, scroll) => _BillSheet(bill: bill, scroll: scroll),
  );
  return changed ?? false;
}

class _BillSheet extends ConsumerStatefulWidget {
  const _BillSheet({required this.bill, required this.scroll});
  final FortuneBill bill;
  final ScrollController scroll;

  @override
  ConsumerState<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends ConsumerState<_BillSheet> {
  bool _busy = false;

  FortuneBill get b => widget.bill;

  void _done(String msg) {
    ref.invalidate(opsSummaryProvider);
    ref.invalidate(billStatsProvider);
    tpToast(context, msg, kind: TpToastKind.success);
    Navigator.pop(context, true);
  }

  Future<bool> _markPaid() async {
    try {
      final msg = await ref.read(workRepositoryProvider).markPaid(b.id, note: 'ยืนยันจากแอปแอดมิน');
      if (!mounted) return true;
      _done(msg ?? 'ยืนยันยอดแล้ว — ส่งคำทำนายให้ลูกค้า');
      return true;
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
      return false;
    }
  }

  Future<void> _cancel() async {
    final reason = await tpPrompt(
      context,
      title: 'ยกเลิกบิลนี้?',
      message: 'บิลจะถูกยกเลิกและหายจากทุกรายการ — ใช้เมื่อตรวจแล้วไม่พบยอดโอน หรือลูกค้าขอยกเลิก',
      hint: 'เหตุผล เช่น ไม่พบยอดโอน',
      confirmLabel: 'ยกเลิกบิล',
      danger: true,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final msg = await ref.read(workRepositoryProvider).cancelBill(b.id, reason: reason);
      if (mounted) _done(msg ?? 'ยกเลิกบิลแล้ว');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        tpToast(context, tpErrorText(e), kind: TpToastKind.error);
      }
    }
  }

  Future<void> _refund() async {
    final reason = await tpPrompt(
      context,
      title: 'คืนเงินบิลนี้?',
      message: 'บิลจะเข้าคิวคืนเงิน ${TpFmt.baht(b.amount)} — ตรวจให้แน่ใจก่อนยืนยัน',
      hint: 'เหตุผลการคืนเงิน',
      confirmLabel: 'คืนเงิน',
      danger: true,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final msg = await ref.read(workRepositoryProvider).refundBill(b.id, reason: reason);
      if (mounted) _done(msg ?? 'ส่งเข้าคิวคืนเงินแล้ว');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        tpToast(context, tpErrorText(e), kind: TpToastKind.error);
      }
    }
  }

  void _openChat() {
    Navigator.pop(context);
    context.push('/chat/${b.id}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final paid = b.isPaid;
    final closed = b.isClosed;
    final (statusLabel, statusTone) = paid
        ? ('จ่ายแล้ว', TpTone.success)
        : closed
            ? (b.status == 'refunded' ? 'คืนเงินแล้ว' : 'ยกเลิกแล้ว', TpTone.neutral)
            : ((b.statusLabel ?? (b.status == 'unpaid' ? 'รอลูกค้าโอน' : 'รอแอดมินตรวจ')).split(' · ').first, TpTone.warning);

    return Column(children: [
      Expanded(
        child: ListView(controller: widget.scroll, padding: const EdgeInsets.fromLTRB(18, 6, 18, 18), children: [
          Row(children: [
            TpAvatar(name: b.customerName, platform: b.platform, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.customerName ?? 'ลูกค้า', style: TpType.h(16, p.textStrong)),
                Text(
                  [
                    TpAvatar.platformStyle(b.platform)?.$3 ?? (b.platform ?? ''),
                    if (b.priorPaid > 0) 'ลูกค้าเก่า ${b.priorPaid} ครั้ง' else 'ลูกค้าใหม่',
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: TpType.body(12.5, p.muted),
                ),
              ]),
            ),
            TpPill(statusLabel, tone: statusTone),
          ]),
          const SizedBox(height: 18),
          Center(child: Text('ยอดบิล · ${b.packageLabel}', style: TpType.body(12.5, p.muted))),
          Center(child: Text(TpFmt.baht(b.amount, decimals: true), style: TpType.money(40, p.goldText))),
          Center(child: Text(b.billNumber, style: TpType.money(12, p.faint, w: FontWeight.w500))),
          const SizedBox(height: 16),
          _Evidence(bill: b),
          if (b.slipUrl != null) ...[const SizedBox(height: 12), _Slip(url: b.slipUrl!, needsAuth: b.slipNeedsAuth, at: b.slipAt)],
          const SizedBox(height: 16),
          _Timeline(steps: [
            ('ออกบิล', b.createdAt, true),
            if (b.sms.matched) ('เงินเข้า (SMS ${b.sms.bank ?? ''})'.replaceAll(' )', ')'), b.sms.at, true),
            if (paid) ('ยืนยันแล้ว · เริ่มทำนาย', b.paidAt, true),
            if (!paid && !closed) ('รอแอดมินยืนยัน', null, false),
          ]),
          if ((b.question ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: p.inset,
                borderRadius: BorderRadius.circular(16),
                border: Border(left: BorderSide(color: p.gold, width: 3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('คำถามของลูกค้า', style: TpType.body(12, p.muted)),
                const SizedBox(height: 2),
                Text('“${b.question}”', style: TpType.body(14, p.text, height: 1.55)),
              ]),
            ),
          ],
        ]),
      ),
      TpBottomBar(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!paid && !closed && !b.mayMarkPaid)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                b.isFloating
                    ? 'บิลลอย (เงินเข้าแต่ไม่รู้เจ้าของ) — จับคู่ผ่านหน้าเว็บแอดมิน'
                    : 'ยืนยันบิลนี้ไม่ได้ — ลูกค้าอาจจ่ายบิลอื่นแทนแล้ว (อนุมัติซ้ำ = เก็บเงินซ้ำ)',
                textAlign: TextAlign.center,
                style: TpType.body(12.5, context.tp.warning, w: FontWeight.w500),
              ),
            ),
          if (b.mayMarkPaid) ...[
            TpSlideToConfirm(
              label: 'เลื่อนเพื่อยืนยันยอดและเริ่มทำนาย',
              enabled: !_busy,
              onConfirmed: _markPaid,
            ),
            const SizedBox(height: 10),
          ],
          Row(children: [
            if (b.mayCancel)
              Expanded(
                child: TpButton.danger('ยกเลิกบิล',
                    icon: PhosphorIconsRegular.xCircle, height: 44, fontSize: 14, loading: _busy, onPressed: _cancel),
              ),
            if (b.mayRefund)
              Expanded(
                child: TpButton.danger('คืนเงิน',
                    icon: PhosphorIconsRegular.arrowCounterClockwise,
                    height: 44,
                    fontSize: 14,
                    loading: _busy,
                    onPressed: _refund),
              ),
            if (b.mayCancel || b.mayRefund) const SizedBox(width: 10),
            Expanded(
              child: TpButton.outline('เปิดแชท',
                  icon: PhosphorIconsRegular.chatsCircle, height: 44, fontSize: 14, onPressed: _busy ? null : _openChat),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.bill});
  final FortuneBill bill;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final s = bill.sms;
    if (!s.matched) {
      return TpCard(
        child: Row(children: [
          const Tp3D(TpArt.sms, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ยังไม่พบ SMS เงินเข้าที่ตรงยอด', style: TpType.h(14, p.textStrong, w: FontWeight.w600)),
              Text('ตรวจยอดในแอปธนาคารหรือดูสลิปก่อนยืนยัน', style: TpType.body(12.5, p.muted)),
            ]),
          ),
          const TpPill('ไม่พบ', tone: TpTone.warning),
        ]),
      );
    }
    final amountOk = s.amount == null || (s.amount! - bill.amount).abs() < 0.01;
    final afterBill = s.at == null || bill.createdAt == null || !s.at!.isBefore(bill.createdAt!);
    final checks = [('ยอดตรง', amountOk), ('เข้าหลังออกบิล', afterBill)];
    final passed = checks.where((c) => c.$2).length;
    return TpCard(
      goldBorder: passed == checks.length,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Tp3D(TpArt.sms, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SMS ${s.bank ?? 'ธนาคาร'} · รับโอน ${TpFmt.baht(s.amount ?? bill.amount, decimals: true)}',
                  style: TpType.h(14, p.textStrong, w: FontWeight.w600)),
              Text(s.at == null ? 'เวลาไม่ระบุ' : TpFmt.dateTime(s.at!), style: TpType.body(12.5, p.muted)),
            ]),
          ),
          TpPill('ตรง $passed/${checks.length}', tone: passed == checks.length ? TpTone.success : TpTone.warning),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in checks)
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(c.$2 ? PhosphorIconsBold.check : PhosphorIconsBold.x, size: 13, color: c.$2 ? p.success : p.danger),
                const SizedBox(width: 4),
                Text(c.$1, style: TpType.body(12, p.text, w: FontWeight.w500, height: 1.1)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

class _Slip extends ConsumerWidget {
  const _Slip({required this.url, this.needsAuth = false, this.at});
  final String url;
  final bool needsAuth;
  final DateTime? at;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.tp;
    final token = needsAuth ? ref.watch(authTokenProvider).valueOrNull : null;
    if (needsAuth && token == null) return const TpSkeleton(height: 104, radius: 22);
    final headers = token == null ? null : {'Authorization': 'Bearer $token'};
    return TpCard(
      padding: const EdgeInsets.all(10),
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(child: Center(child: Image.network(url, headers: headers))),
        ),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            headers: headers,
            width: 64,
            height: 84,
            fit: BoxFit.cover,
            cacheWidth: 192,
            errorBuilder: (_, __, ___) => Container(
              width: 64,
              height: 84,
              color: p.inset,
              child: Icon(PhosphorIconsRegular.imageBroken, color: p.faint),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('สลิปที่ลูกค้าส่งมา', style: TpType.h(14, p.textStrong, w: FontWeight.w600)),
            Text(at == null ? 'แตะเพื่อดูภาพเต็ม · ตรวจชื่อบัญชีปลายทางและเวลาโอน' : 'ส่งมาเมื่อ ${TpFmt.dateTime(at!)} · แตะเพื่อดูภาพเต็ม', style: TpType.body(12.5, p.muted)),
          ]),
        ),
        Icon(PhosphorIconsRegular.arrowsOut, color: p.faint, size: 18),
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});
  final List<(String, DateTime?, bool)> steps;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 22,
                child: Column(children: [
                  const SizedBox(height: 3),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: steps[i].$3 ? p.success : Colors.transparent,
                      border: steps[i].$3 ? null : Border.all(color: p.gold, width: 2),
                      boxShadow: [BoxShadow(color: (steps[i].$3 ? p.success : p.gold).withValues(alpha: 0.25), spreadRadius: 3)],
                    ),
                  ),
                  if (i < steps.length - 1) Expanded(child: Container(width: 2, color: p.divider)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 14 : 0),
                  child: Row(children: [
                    Expanded(child: Text(steps[i].$1, style: TpType.body(13.5, p.text, w: FontWeight.w500))),
                    Text(steps[i].$2 == null ? 'ตอนนี้' : TpFmt.dateTime(steps[i].$2!), style: TpType.money(12.5, p.muted, w: FontWeight.w500)),
                  ]),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
