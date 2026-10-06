import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../home/data/ops_repository.dart';
import '../data/work_repository.dart';
import 'bill_widgets.dart';
import 'triage_widgets.dart';

enum WorkTab {
  bills('bills', 'บิลดูดวง'),
  withdrawals('withdrawals', 'ถอนเงิน'),
  sms('sms', 'SMS ธนาคาร'),
  stuck('stuck', 'คำทำนายค้าง'),
  triage('triage', 'ลูกค้าต้องดูแล');

  const WorkTab(this.key, this.label);
  final String key;
  final String label;

  static WorkTab parse(String? v) => WorkTab.values.firstWhere((t) => t.key == v, orElse: () => WorkTab.bills);
}

/// แท็บ "งานรอทำ" — รวมทุกเรื่องที่ต้องให้แอดมินตัดสินใจ
class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key, this.initialTab, this.initialSub});
  final String? initialTab;

  /// แท็บย่อย เช่น ถอนเงิน `approved` = รอโอน
  final String? initialSub;

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  late WorkTab _tab = WorkTab.parse(widget.initialTab);
  BillBucket _bucket = BillBucket.awaiting;
  late String _wdStatus = widget.initialSub == 'approved' ? 'approved' : 'pending';
  int _reload = 0;

  @override
  void didUpdateWidget(covariant WorkScreen old) {
    super.didUpdateWidget(old);
    // มาจากลิงก์ /work?tab=... ขณะแท็บนี้เปิดค้างอยู่
    if ((old.initialTab != widget.initialTab || old.initialSub != widget.initialSub) && widget.initialTab != null) {
      setState(() {
        _tab = WorkTab.parse(widget.initialTab);
        if (widget.initialSub == 'approved') _wdStatus = 'approved';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _reload++);
    ref.invalidate(billStatsProvider);
    try {
      ref.invalidate(opsSummaryProvider);
        await ref.read(opsSummaryProvider.future);
    } catch (_) {}
  }

  void _changed() {
    setState(() => _reload++);
    ref.invalidate(billStatsProvider);
    ref.invalidate(opsSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(opsSummaryProvider).valueOrNull;
    final counts = {
      WorkTab.bills: s?.billsAwaiting.count,
      WorkTab.withdrawals: s == null ? null : s.withdrawalsPending.count + s.withdrawalsApproved.count,
      WorkTab.sms: s?.smsUnmatched.count,
      WorkTab.stuck: s?.stuckReadings.count,
    };
    return TpPage(
      title: 'งานรอทำ',
      subtitle: s == null ? 'เรื่องที่รอแอดมินตัดสินใจ' : (s.workBadge == 0 ? 'ไม่มีงานค้าง' : 'ค้างอยู่ ${s.workBadge} เรื่อง'),
      showMark: true,
      onRefresh: _refresh,
      headerBottom: TpChips<WorkTab>(
        onHeader: true,
        padding: EdgeInsets.zero,
        value: _tab,
        onChanged: (t) => setState(() => _tab = t),
        items: [for (final t in WorkTab.values) TpChipItem(t, t.label, count: counts[t])],
      ),
      slivers: switch (_tab) {
        WorkTab.bills => _billSlivers(),
        WorkTab.withdrawals => _withdrawalSlivers(),
        WorkTab.sms => _smsSlivers(),
        WorkTab.stuck => [_StuckSliver(reloadKey: _reload, onChanged: _changed)],
        WorkTab.triage => [TriageSliver(reloadKey: _reload)],
      },
    );
  }

  // ───────────── บิล ─────────────
  List<Widget> _billSlivers() {
    final stats = ref.watch(billStatsProvider).valueOrNull;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TpChips<BillBucket>(
            padding: EdgeInsets.zero,
            value: _bucket,
            onChanged: (b) => setState(() => _bucket = b),
            items: [
              for (final b in BillBucket.values)
                TpChipItem(b, b.label, count: (b == BillBucket.awaiting || b == BillBucket.unpaid) ? stats?.count(b) : null),
            ],
          ),
        ),
      ),
      if (stats != null && _bucket == BillBucket.awaiting)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TpCard(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(children: [
                Expanded(
                    child: TpStat(
                        label: 'รอตรวจ', value: '${stats.count(BillBucket.awaiting)} บิล', align: CrossAxisAlignment.center)),
                _VLine(),
                Expanded(
                    child: TpStat(
                        label: 'รอลูกค้าโอน', value: '${stats.count(BillBucket.unpaid)}', align: CrossAxisAlignment.center)),
                _VLine(),
                Expanded(
                    child: TpStat(
                        label: 'รับวันนี้',
                        value: TpFmt.bahtCompact(stats.paidTodayAmount),
                        color: context.tp.goldText,
                        align: CrossAxisAlignment.center)),
              ]),
            ),
          ),
        ),
      TpPagedSliver<FortuneBill>(
        reloadKey: '${_bucket.key}-$_reload',
        fetch: (page) => ref.read(workRepositoryProvider).bills(_bucket, page: page),
        empty: TpEmpty(
          art: _bucket == BillBucket.awaiting ? TpArt.emptyDone : TpArt.emptyInbox,
          title: _bucket == BillBucket.awaiting ? 'ไม่มีบิลรอตรวจ' : 'ไม่มีบิลในกลุ่มนี้',
          message: _bucket == BillBucket.awaiting ? 'บิลที่ SMS ตรงยอดระบบตัดให้อัตโนมัติแล้ว' : null,
          compact: true,
        ),
        itemBuilder: (context, bill, _) => BillCard(
          bill: bill,
          onTap: () async {
            if (await showBillSheet(context, bill)) _changed();
          },
          onQuickConfirm: bill.sms.matched && _bucket == BillBucket.awaiting
              ? () async {
                  if (await showBillSheet(context, bill)) _changed();
                }
              : null,
        ),
      ),
    ];
  }

  // ───────────── ถอนเงิน ─────────────
  List<Widget> _withdrawalSlivers() {
    final s = ref.watch(opsSummaryProvider).valueOrNull;
    return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TpChips<String>(
              padding: EdgeInsets.zero,
              value: _wdStatus,
              onChanged: (v) => setState(() => _wdStatus = v),
              items: [
                TpChipItem('pending', 'รออนุมัติ', count: s?.withdrawalsPending.count),
                TpChipItem('approved', 'อนุมัติแล้ว · รอโอน', count: s?.withdrawalsApproved.count),
                const TpChipItem('completed', 'โอนแล้ว'),
              ],
            ),
          ),
        ),
        TpPagedSliver<Withdrawal>(
          reloadKey: 'wd-$_wdStatus-$_reload',
          fetch: (page) => ref.read(workRepositoryProvider).withdrawals(status: _wdStatus, page: page),
          empty: TpEmpty(
            art: TpArt.emptyDone,
            title: switch (_wdStatus) {
              'approved' => 'ไม่มีรายการรอโอน',
              'completed' => 'ยังไม่มีรายการที่โอนแล้ว',
              _ => 'ไม่มีคำขอถอนเงินค้าง',
            },
            compact: true,
          ),
          itemBuilder: (context, w, _) => _WithdrawalCard(
            w: w,
            onTap: () async {
              if (await _showWithdrawalSheet(context, w)) _changed();
            },
          ),
        ),
      ];
  }

  // ───────────── SMS ─────────────
  List<Widget> _smsSlivers() => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('SMS เงินเข้าที่ระบบยังจับคู่กับบิลไม่ได้ — ลองจับคู่ใหม่ หรือปัดตกถ้าไม่ใช่ยอดจากลูกค้า',
                style: TpType.body(12.5, context.tp.muted)),
          ),
        ),
        TpPagedSliver<BankSms>(
          reloadKey: 'sms-$_reload',
          fetch: (page) => ref.read(workRepositoryProvider).sms(page: page),
          empty: const TpEmpty(art: TpArt.emptyDone, title: 'SMS จับคู่ครบทุกรายการ', compact: true),
          itemBuilder: (context, sms, _) => _SmsCard(sms: sms, onChanged: _changed),
        ),
      ];
}

class _VLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 32, color: context.tp.divider);
}

// ═════════════════════ ถอนเงิน ═════════════════════

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({required this.w, required this.onTap});
  final Withdrawal w;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return TpCard(
      accent: w.status == 'approved' ? p.gold : (w.status == 'pending' ? p.info : p.success),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(children: [
        TpAvatar(name: w.userName),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.userName ?? 'สมาชิก', style: TpType.h(14.5, p.textStrong, w: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              [w.bankName ?? w.method, w.accountNumber].whereType<String>().join(' · '),
              style: TpType.body(12.5, p.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(TpFmt.baht(w.net), style: TpType.money(18, p.goldText)),
          if (w.status == 'approved')
            const TpPill('รอโอน', tone: TpTone.gold, dense: true)
          else
            Text(TpFmt.ago(w.createdAt), style: TpType.body(11.5, p.faint)),
        ]),
      ]),
    );
  }
}

Future<bool> _showWithdrawalSheet(BuildContext context, Withdrawal w) async {
  final r = await tpShowSheet<bool>(context, initial: 0.82, builder: (ctx, scroll) => _WithdrawalSheet(w: w, scroll: scroll));
  return r ?? false;
}

class _WithdrawalSheet extends ConsumerStatefulWidget {
  const _WithdrawalSheet({required this.w, required this.scroll});
  final Withdrawal w;
  final ScrollController scroll;

  @override
  ConsumerState<_WithdrawalSheet> createState() => _WithdrawalSheetState();
}

class _WithdrawalSheetState extends ConsumerState<_WithdrawalSheet> {
  bool _busy = false;
  XFile? _slip;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickSlip(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(source: src, imageQuality: 82, maxWidth: 1600);
      if (f != null && mounted) setState(() => _slip = f);
    } catch (_) {
      if (mounted) {
        tpToast(context, src == ImageSource.camera ? 'เปิดกล้องไม่ได้ — อนุญาตสิทธิ์กล้องหรือเลือกจากคลังภาพ' : 'เลือกรูปไม่สำเร็จ',
            kind: TpToastKind.error);
      }
    }
  }

  /// ปิดงาน: บันทึกว่าโอนให้สมาชิกแล้ว (แนบสลิป) — คืน false ให้ปุ่มเลื่อนเด้งกลับถ้าล้ม
  Future<bool> _complete() async {
    try {
      final msg = await ref
          .read(workRepositoryProvider)
          .completeWithdrawal(widget.w.id, slipPath: _slip?.path, note: _note.text.trim());
      if (!mounted) return true;
      tpToast(context, msg ?? 'บันทึกการโอนเงินแล้ว', kind: TpToastKind.success);
      Navigator.pop(context, true);
      return true;
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
      return false;
    }
  }

  Future<bool> _approve() async {
    try {
      final msg = await ref.read(workRepositoryProvider).approveWithdrawal(widget.w.id);
      if (!mounted) return true;
      tpToast(context, msg ?? 'อนุมัติแล้ว — โอนเงินให้สมาชิกตามบัญชีด้านบน', kind: TpToastKind.success);
      Navigator.pop(context, true);
      return true;
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
      return false;
    }
  }

  Future<void> _reject() async {
    final reason = await tpPrompt(
      context,
      title: 'ปฏิเสธคำขอถอนเงิน?',
      message: 'เงิน ${TpFmt.baht(widget.w.amount)} จะคืนเข้ากระเป๋าของสมาชิก',
      hint: 'เหตุผล (สมาชิกจะเห็นข้อความนี้)',
      confirmLabel: 'ปฏิเสธ',
      danger: true,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final msg = await ref.read(workRepositoryProvider).rejectWithdrawal(widget.w.id, reason);
      if (!mounted) return;
      tpToast(context, msg ?? 'ปฏิเสธแล้ว', kind: TpToastKind.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        tpToast(context, tpErrorText(e), kind: TpToastKind.error);
      }
    }
  }

  void _copy(String label, String? v) {
    if (v == null || v.isEmpty) return;
    Clipboard.setData(ClipboardData(text: v));
    tpToast(context, 'คัดลอก$labelแล้ว');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final w = widget.w;
    final pending = w.status == 'pending';
    return Column(children: [
      Expanded(
        child: ListView(controller: widget.scroll, padding: const EdgeInsets.fromLTRB(18, 6, 18, 18), children: [
          Row(children: [
            TpAvatar(name: w.userName, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.userName ?? 'สมาชิก', style: TpType.h(16, p.textStrong)),
                Text([w.userPhone, w.userEmail].whereType<String>().join(' · '), style: TpType.body(12.5, p.muted)),
              ]),
            ),
            TpPill(
              switch (w.status) {
                'pending' => 'รออนุมัติ',
                'approved' => 'อนุมัติแล้ว · รอโอน',
                'completed' => 'โอนแล้ว',
                'rejected' => 'ปฏิเสธแล้ว',
                _ => w.status,
              },
              tone: switch (w.status) {
                'pending' => TpTone.info,
                'approved' => TpTone.gold,
                'completed' => TpTone.success,
                _ => TpTone.neutral,
              },
            ),
          ]),
          const SizedBox(height: 18),
          Center(child: Text('ยอดที่ต้องโอน', style: TpType.body(12.5, p.muted))),
          Center(child: Text(TpFmt.baht(w.net, decimals: true), style: TpType.money(40, p.goldText))),
          Center(
            child: Text('ขอถอน ${TpFmt.baht(w.amount)} · หักค่าธรรมเนียม/ภาษี ${TpFmt.baht(w.fee)}',
                style: TpType.body(12.5, p.faint)),
          ),
          const SizedBox(height: 16),
          TpCard(
            goldBorder: true,
            child: Column(children: [
              Row(children: [
                const Tp3D(TpArt.wallet, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('บัญชีรับเงิน', style: TpType.h(14.5, p.textStrong)),
                ),
                if (w.method != null) TpPill(w.method!, tone: TpTone.navy, dense: true),
              ]),
              const SizedBox(height: 8),
              _CopyRow(label: 'ธนาคาร', value: w.bankName, onCopy: null),
              _CopyRow(label: 'ชื่อบัญชี', value: w.accountName, onCopy: () => _copy('ชื่อบัญชี', w.accountName)),
              _CopyRow(label: 'เลขบัญชี', value: w.accountNumber, mono: true, onCopy: () => _copy('เลขบัญชี', w.accountNumber)),
              _CopyRow(label: 'ยอดโอน', value: TpFmt.baht(w.net, decimals: true), mono: true, onCopy: () => _copy('ยอดโอน', w.net.toStringAsFixed(2))),
            ]),
          ),
          if ((w.userNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            TpCard(child: TpKv('หมายเหตุสมาชิก', w.userNote!)),
          ],
          const SizedBox(height: 12),
          TpKv('เลขที่คำขอ', w.requestId, mono: true),
          TpKv('ส่งคำขอเมื่อ', w.createdAt == null ? '-' : TpFmt.dateTime(w.createdAt!)),
          if (w.status == 'approved') ...[
            const SizedBox(height: 14),
            Text('หลังโอนเงินแล้ว แนบสลิปเพื่อปิดงาน', style: TpType.h(14.5, p.textStrong)),
            const SizedBox(height: 8),
            if (_slip != null)
              TpCard(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(_slip!.path), width: 56, height: 74, fit: BoxFit.cover, cacheWidth: 168),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('แนบสลิปแล้ว', style: TpType.h(14, p.textStrong, w: FontWeight.w600))),
                  TpButton.ghost('เปลี่ยน', onPressed: () => _pickSlip(ImageSource.gallery)),
                ]),
              )
            else
              Row(children: [
                Expanded(
                  child: TpButton.outline('ถ่ายรูปสลิป',
                      icon: PhosphorIconsRegular.camera, height: 44, fontSize: 14, onPressed: () => _pickSlip(ImageSource.camera)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TpButton.outline('เลือกจากคลังภาพ',
                      icon: PhosphorIconsRegular.image, height: 44, fontSize: 14, onPressed: () => _pickSlip(ImageSource.gallery)),
                ),
              ]),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: 500,
              decoration: const InputDecoration(hintText: 'หมายเหตุ (ไม่บังคับ) เช่น เลขอ้างอิงการโอน', counterText: ''),
            ),
          ],
        ]),
      ),
      if (w.status == 'approved')
        TpBottomBar(
          child: TpSlideToConfirm(
            label: _slip == null ? 'เลื่อนเพื่อยืนยันว่าโอนแล้ว (ไม่มีสลิป)' : 'เลื่อนเพื่อยืนยันว่าโอนแล้ว',
            onConfirmed: _complete,
          ),
        ),
      if (pending)
        TpBottomBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TpSlideToConfirm(label: 'เลื่อนเพื่ออนุมัติการถอนเงิน', enabled: !_busy, onConfirmed: _approve),
            const SizedBox(height: 10),
            TpButton.danger('ปฏิเสธคำขอ', icon: PhosphorIconsRegular.xCircle, height: 44, fontSize: 14, loading: _busy, onPressed: _reject),
          ]),
        ),
    ]);
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, this.onCopy, this.mono = false});
  final String label;
  final String? value;
  final VoidCallback? onCopy;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(width: 82, child: Text(label, style: TpType.body(13, p.muted))),
          Expanded(
            child: Text(value ?? '-',
                textAlign: TextAlign.right,
                style: mono ? TpType.money(14.5, p.textStrong) : TpType.body(14, p.textStrong, w: FontWeight.w600)),
          ),
          if (onCopy != null) ...[const SizedBox(width: 8), Icon(PhosphorIconsRegular.copy, size: 16, color: p.goldText)],
        ]),
      ),
    );
  }
}

// ═════════════════════ SMS ═════════════════════

class _SmsCard extends ConsumerStatefulWidget {
  const _SmsCard({required this.sms, required this.onChanged});
  final BankSms sms;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SmsCard> createState() => _SmsCardState();
}

class _SmsCardState extends ConsumerState<_SmsCard> {
  bool _busy = false;

  Future<void> _rematch() async {
    setState(() => _busy = true);
    try {
      final (ok, msg) = await ref.read(workRepositoryProvider).rematchSms(widget.sms.id);
      if (!mounted) return;
      tpToast(context, msg, kind: ok ? TpToastKind.success : TpToastKind.info);
      if (ok) widget.onChanged();
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await tpPrompt(
      context,
      title: 'ปัดตก SMS นี้?',
      message: 'ใช้เมื่อเป็นเงินเข้าที่ไม่ใช่ยอดจากลูกค้า (เช่น โอนระหว่างบัญชี) — ปัดตกแล้วจับคู่ใหม่ไม่ได้',
      hint: 'เหตุผล',
      confirmLabel: 'ปัดตก',
      danger: true,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(workRepositoryProvider).rejectSms(widget.sms.id, reason);
      if (!mounted) return;
      tpToast(context, 'ปัดตก SMS แล้ว', kind: TpToastKind.success);
      widget.onChanged();
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final s = widget.sms;
    return TpCard(
      accent: p.warning,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Tp3D(TpArt.sms, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.bank.toUpperCase()} · ${s.type == 'expense' ? 'เงินออก' : 'เงินเข้า'}',
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text([s.from, s.account].whereType<String>().where((e) => e.isNotEmpty).join(' · ').ifEmpty('ไม่ระบุผู้โอน'),
                  style: TpType.body(12.5, p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(TpFmt.baht(s.amount, decimals: true), style: TpType.money(17, p.goldText)),
            Text(s.at == null ? '' : TpFmt.dateTime(s.at!), style: TpType.body(11.5, p.faint)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TpButton.outline('ลองจับคู่อีกครั้ง',
                icon: PhosphorIconsRegular.arrowsClockwise, height: 40, fontSize: 13.5, loading: _busy, onPressed: _rematch),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TpButton.danger('ไม่ใช่ยอดลูกค้า',
                icon: PhosphorIconsRegular.prohibit, height: 40, fontSize: 13.5, onPressed: _busy ? null : _reject),
          ),
        ]),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

// ═════════════════════ คำทำนายค้าง ═════════════════════

class _StuckSliver extends ConsumerStatefulWidget {
  const _StuckSliver({required this.reloadKey, required this.onChanged});
  final int reloadKey;
  final VoidCallback onChanged;

  @override
  ConsumerState<_StuckSliver> createState() => _StuckSliverState();
}

class _StuckSliverState extends ConsumerState<_StuckSliver> {
  @override
  void didUpdateWidget(covariant _StuckSliver old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) ref.invalidate(activeReadingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(activeReadingsProvider);
    return SliverToBoxAdapter(
      child: TpAsync<List<ActiveReading>>(
        value: list,
        onRetry: () => ref.invalidate(activeReadingsProvider),
        compactError: true,
        data: (items) {
          if (items.isEmpty) {
            return const TpEmpty(art: TpArt.emptyDone, title: 'ไม่มีคำทำนายที่กำลังทำ', compact: true);
          }
          // ค้างขึ้นก่อน แล้วเรียงตามเวลาที่เงียบนานสุด
          final sorted = [...items]
            ..sort((a, b) {
              final s = (b.stuck ? 1 : 0).compareTo(a.stuck ? 1 : 0);
              return s != 0 ? s : b.idleMinutes.compareTo(a.idleMinutes);
            });
          return Column(children: [
            for (final r in sorted)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: _ActiveCard(r: r)),
          ]);
        },
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.r});
  final ActiveReading r;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return TpCard(
      accent: r.stuck ? p.danger : p.success,
      onTap: () => context.push('/chat/${r.id}'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(children: [
        TpAvatar(name: r.customerName, platform: r.platform),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.customerName ?? 'ลูกค้า', style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
            Text('${r.billNumber} · ${r.stage ?? r.packageLabel}', style: TpType.body(12.5, p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          TpPill(r.stuck ? 'ค้าง ${TpFmt.duration(r.idleMinutes)}' : 'กำลังทำ', tone: r.stuck ? TpTone.danger : TpTone.success, dense: true),
          if (r.takenOver) ...[const SizedBox(height: 4), const TpPill('แอดมินคุยอยู่', tone: TpTone.gold, dense: true)],
        ]),
      ]),
    );
  }
}
