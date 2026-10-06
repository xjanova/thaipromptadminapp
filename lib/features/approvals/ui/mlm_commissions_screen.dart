import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/api/paged.dart';
import '../../../shared/ui/tp.dart';
import '../data/approvals_repository.dart';
import 'approval_widgets.dart';

/// หน้า "คอมมิชชัน MLM" (`/approvals/mlm`) — 💸 เคลื่อนเงิน
///
/// อนุมัติ (รออนุมัติ → รอจ่าย) = ยืนยันก่อน · จ่าย = ฝากเข้ากระเป๋าผู้รับทันที (หักกองทุน MLM) → เลื่อนยืนยันเท่านั้น
class MlmCommissionsScreen extends ConsumerStatefulWidget {
  const MlmCommissionsScreen({super.key});

  @override
  ConsumerState<MlmCommissionsScreen> createState() =>
      _MlmCommissionsScreenState();
}

class _MlmCommissionsScreenState extends ConsumerState<MlmCommissionsScreen> {
  MlmFilter _filter = MlmFilter.pending;
  int _reload = 0;
  MlmTotals? _totals;

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

  Future<Paged<MlmCommission>> _fetch(int page) async {
    final (list, totals) = await ref
        .read(approvalsRepositoryProvider)
        .mlmCommissions(filter: _filter, page: page);
    if (page == 1 && mounted && totals != null) {
      setState(() => _totals = totals);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final box = ref
        .watch(approvalsSummaryProvider)
        .valueOrNull
        ?.box(ApprovalQueue.mlmCommissions);
    final t = _totals;
    return TpPage(
      title: 'คอมมิชชัน MLM',
      subtitle: t == null
          ? 'อนุมัติและจ่ายค่าคอมเข้ากระเป๋าสมาชิก'
          : 'รออนุมัติ ${TpFmt.count(t.pendingCount)} · รอจ่าย ${TpFmt.count(t.approvedCount)}',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom: TpChips<MlmFilter>(
        onHeader: true,
        padding: EdgeInsets.zero,
        value: _filter,
        onChanged: (f) => setState(() => _filter = f),
        items: [
          for (final f in MlmFilter.values)
            TpChipItem(f, f.label,
                count: switch (f) {
                  MlmFilter.pending => t?.pendingCount ?? box?.count,
                  MlmFilter.approved => t?.approvedCount ?? box?.approvedUnpaid,
                  _ => null,
                }),
        ],
      ),
      slivers: [
        if (t != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TpCard(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Row(children: [
                  Expanded(
                    child: TpStat(
                      label: 'รออนุมัติ ${TpFmt.count(t.pendingCount)} รายการ',
                      value: TpFmt.baht(t.pendingAmount),
                      align: CrossAxisAlignment.center,
                    ),
                  ),
                  Container(width: 1, height: 32, color: p.divider),
                  Expanded(
                    child: TpStat(
                      label: 'รอจ่าย ${TpFmt.count(t.approvedCount)} รายการ',
                      value: TpFmt.baht(t.approvedAmount),
                      color: p.goldText,
                      align: CrossAxisAlignment.center,
                    ),
                  ),
                ]),
              ),
            ),
          ),
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
                    'จ่าย = ฝากเงินเข้ากระเป๋าผู้รับทันที หักจากกองทุน MLM — ย้อนกลับไม่ได้',
                    style: TpType.body(12.5, p.muted)),
              ),
            ]),
          ),
        ),
        TpPagedSliver<MlmCommission>(
          reloadKey: '${_filter.key}|$_reload',
          fetch: _fetch,
          empty: TpEmpty(
            art: (_filter == MlmFilter.pending || _filter == MlmFilter.approved)
                ? TpArt.emptyDone
                : TpArt.emptyInbox,
            title: switch (_filter) {
              MlmFilter.pending => 'ไม่มีค่าคอมรออนุมัติ',
              MlmFilter.approved => 'ไม่มีค่าคอมรอจ่าย',
              _ => 'ไม่มีรายการในกลุ่มนี้',
            },
            compact: true,
          ),
          itemBuilder: (context, c, _) => _MlmCard(c: c, onChanged: _changed),
        ),
      ],
    );
  }
}

(String, TpTone) _status(MlmCommission c) => switch (c.status) {
      'pending' => (c.statusLabel ?? 'รออนุมัติ', TpTone.info),
      'approved' => (c.statusLabel ?? 'อนุมัติแล้ว รอจ่าย', TpTone.gold),
      'paid' => (c.statusLabel ?? 'จ่ายแล้ว', TpTone.success),
      'rejected' => (c.statusLabel ?? 'ปฏิเสธแล้ว', TpTone.danger),
      _ => (c.statusLabel ?? c.status, TpTone.neutral),
    };

String _typeLine(MlmCommission c) =>
    c.level == null ? c.typeLabel : '${c.typeLabel} · ชั้น ${c.level}';

class _MlmCard extends ConsumerStatefulWidget {
  const _MlmCard({required this.c, required this.onChanged});
  final MlmCommission c;
  final VoidCallback onChanged;

  @override
  ConsumerState<_MlmCard> createState() => _MlmCardState();
}

class _MlmCardState extends ConsumerState<_MlmCard> {
  bool _busy = false;

  Future<void> _approve() async {
    final c = widget.c;
    final yes = await tpConfirm(
      context,
      title: 'อนุมัติค่าคอม ${TpFmt.baht(c.amount, decimals: true)}?',
      message:
          '${c.recipient?.display ?? 'สมาชิก'} · ${_typeLine(c)}\nอนุมัติแล้วรายการจะไปอยู่กอง "รอจ่าย" (ยังไม่ฝากเงิน)',
      confirmLabel: 'อนุมัติ',
    );
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    final ok = await runApprovalAction(
        context, () => ref.read(approvalsRepositoryProvider).approveMlm(c.id),
        closeSheet: false);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onChanged();
  }

  Future<void> _open() async {
    if (await showMlmSheet(context, widget.c)) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final c = widget.c;
    final (label, tone) = _status(c);
    return TpCard(
      accent: p.fg(tone),
      onTap: _open,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TpAvatar(name: c.recipient?.display),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.recipient?.display ?? 'สมาชิก',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(_typeLine(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12.5, p.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(TpFmt.baht(c.amount), style: TpType.money(17, p.goldText)),
            if (c.salesAmount != null && c.salesAmount! > 0)
              Text('จากยอด ${TpFmt.bahtCompact(c.salesAmount)}',
                  style: TpType.body(11, p.faint)),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TpPill(pillText(label), tone: tone, dense: true),
          if (c.status == 'pending' || c.status == 'approved')
            WaitPill(c.waitingMinutes),
          if (c.fromMember != null)
            TpPill(pillText('จาก ${c.fromMember}'),
                tone: TpTone.navy, dense: true),
          if (c.plan != null) TpPill(pillText(c.plan!), dense: true),
        ]),
        if (c.canApprove || c.canPay) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TpButton.outline('รายละเอียด',
                  icon: PhosphorIconsRegular.fileText,
                  height: 40,
                  fontSize: 13.5,
                  onPressed: _busy ? null : _open),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: c.canApprove
                  ? TpButton('อนุมัติ',
                      icon: PhosphorIconsBold.checkCircle,
                      height: 40,
                      fontSize: 13.5,
                      loading: _busy,
                      onPressed: _busy ? null : _approve)
                  // จ่ายเงินจริง → เปิดแผ่นแล้วเลื่อนยืนยันเท่านั้น
                  : TpButton('จ่ายเข้ากระเป๋า',
                      icon: PhosphorIconsBold.wallet,
                      height: 40,
                      fontSize: 13.5,
                      onPressed: _busy ? null : _open),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// เปิดแผ่นรายละเอียดค่าคอม — คืน true ถ้าอนุมัติ/จ่ายแล้ว
Future<bool> showMlmSheet(BuildContext context, MlmCommission c) async {
  final r = await tpShowSheet<bool>(context,
      initial: 0.8, builder: (ctx, scroll) => _MlmSheet(c: c, scroll: scroll));
  return r ?? false;
}

class _MlmSheet extends ConsumerStatefulWidget {
  const _MlmSheet({required this.c, required this.scroll});
  final MlmCommission c;
  final ScrollController scroll;

  @override
  ConsumerState<_MlmSheet> createState() => _MlmSheetState();
}

class _MlmSheetState extends ConsumerState<_MlmSheet> {
  Future<bool> _approve() => runApprovalAction(context,
      () => ref.read(approvalsRepositoryProvider).approveMlm(widget.c.id));

  Future<bool> _pay() => runApprovalAction(
      context, () => ref.read(approvalsRepositoryProvider).payMlm(widget.c.id));

  void _openUser(int id) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/users/$id');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final c = widget.c;
    final (label, tone) = _status(c);
    final money = TpFmt.baht(c.amount, decimals: true);
    final recipient = c.recipient;
    return Column(children: [
      Expanded(
        child: ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          children: [
            SheetHeader(
              leading: TpAvatar(name: recipient?.display, size: 48),
              title: recipient?.display ?? 'สมาชิก',
              subtitle: [recipient?.memberNumber, 'ผู้รับค่าคอม']
                  .whereType<String>()
                  .join(' · '),
              pill: Wrap(spacing: 6, runSpacing: 6, children: [
                TpPill(pillText(label), tone: tone, dense: true),
                if (c.status == 'pending' || c.status == 'approved')
                  WaitPill(c.waitingMinutes),
              ]),
            ),
            const SizedBox(height: 16),
            Center(
                child: Text('ค่าคอม · ${_typeLine(c)}',
                    textAlign: TextAlign.center,
                    style: TpType.body(12.5, p.muted))),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(money, style: TpType.money(38, p.goldText)),
              ),
            ),
            if (c.salesAmount != null && c.salesAmount! > 0)
              Center(
                child: Text(
                    'คิดจากยอดขาย ${TpFmt.baht(c.salesAmount, decimals: true)}',
                    style: TpType.body(12.5, p.faint)),
              ),
            DetailSection(
              'รายละเอียด',
              trailing: recipient == null
                  ? null
                  : TpButton.ghost('เปิดหน้าผู้รับ',
                      height: 32,
                      fontSize: 13,
                      onPressed: () => _openUser(recipient.id)),
              children: [
                TpKv('ประเภท', c.typeLabel),
                if (c.level != null) TpKv('ชั้น', '${c.level}'),
                if (c.plan != null) TpKv('แผน', c.plan!),
                if (c.fromMember != null) TpKv('จากสมาชิก', c.fromMember!),
                if (c.pvAmount != null && c.pvAmount! > 0)
                  TpKv('PV', TpFmt.count(c.pvAmount), mono: true),
                if (c.sourceType != null || c.sourceId != null)
                  TpKv(
                      'ที่มา',
                      [
                        c.sourceType == 'Order'
                            ? 'ออเดอร์'
                            : (c.sourceType ?? 'รายการ'),
                        if (c.sourceId != null) '#${c.sourceId}',
                      ].join(' ')),
                TpKv('เกิดเมื่อ', approvalWhen(c.createdAt)),
                if (c.approvedAt != null)
                  TpKv('อนุมัติเมื่อ', approvalWhen(c.approvedAt)),
                if (c.paidAt != null)
                  TpKv('จ่ายเมื่อ', approvalWhen(c.paidAt),
                      valueColor: p.success),
              ],
            ),
          ],
        ),
      ),
      if (c.canApprove)
        TpBottomBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('อนุมัติแล้วไปอยู่กอง "รอจ่าย" — ยังไม่ฝากเงิน',
                  textAlign: TextAlign.center,
                  style: TpType.body(12, p.muted, w: FontWeight.w500)),
            ),
            TpSlideToConfirm(
                label: 'เลื่อนเพื่ออนุมัติค่าคอม', onConfirmed: _approve),
          ]),
        )
      else if (c.canPay)
        TpBottomBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  'ฝาก $money เข้ากระเป๋าผู้รับทันที หักจากกองทุน MLM — ย้อนกลับไม่ได้',
                  textAlign: TextAlign.center,
                  style: TpType.body(12, p.warning, w: FontWeight.w500)),
            ),
            TpSlideToConfirm(
                label: 'เลื่อนเพื่อจ่าย $money', onConfirmed: _pay),
          ]),
        ),
    ]);
  }
}
