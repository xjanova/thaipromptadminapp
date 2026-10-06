import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/approvals_repository.dart';
import 'approval_widgets.dart';

/// หน้า "คำขอเปิดร้านค้า" (`/approvals/sellers`)
///
/// อนุมัติ = ร้านเปิดใช้งาน + แพ็กเกจฟรี + เจ้าของเป็นผู้ขาย (เลื่อนยืนยัน) · ปฏิเสธ = ต้องใส่เหตุผล (ผู้สมัครเห็น)
class SellerApplicationsScreen extends ConsumerStatefulWidget {
  const SellerApplicationsScreen({super.key});

  @override
  ConsumerState<SellerApplicationsScreen> createState() =>
      _SellerApplicationsScreenState();
}

class _SellerApplicationsScreenState
    extends ConsumerState<SellerApplicationsScreen> {
  SellerFilter _filter = SellerFilter.pending;
  String _query = '';
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
    final s = ref.watch(approvalsSummaryProvider).valueOrNull;
    return TpPage(
      title: 'คำขอเปิดร้านค้า',
      subtitle: _found == null
          ? 'ตรวจข้อมูลร้านและเจ้าของก่อนอนุมัติ'
          : 'พบ ${TpFmt.count(_found)} ร้าน',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ApprovalSearchBar(
          hint: 'ชื่อร้าน บริษัท หรือเจ้าของ',
          onQuery: (q) => setState(() {
            _query = q;
            _found = null;
          }),
        ),
        const SizedBox(height: 10),
        TpChips<SellerFilter>(
          onHeader: true,
          padding: EdgeInsets.zero,
          value: _filter,
          onChanged: (f) => setState(() {
            _filter = f;
            _found = null;
          }),
          items: [
            for (final f in SellerFilter.values)
              TpChipItem(f, f.label,
                  count: f == SellerFilter.pending
                      ? s?.box(ApprovalQueue.sellerApplications)?.count
                      : null),
          ],
        ),
      ]),
      slivers: [
        TpPagedSliver<SellerApplication>(
          reloadKey: '${_filter.key}|$_query|$_reload',
          fetch: (page) => ref
              .read(approvalsRepositoryProvider)
              .sellerList(filter: _filter, search: _query, page: page),
          onLoaded: (pg) {
            if (mounted) setState(() => _found = pg.total);
          },
          empty: TpEmpty(
            art: _filter == SellerFilter.pending
                ? TpArt.emptyDone
                : TpArt.emptyInbox,
            title: _query.isNotEmpty
                ? 'ไม่พบร้านที่ค้นหา'
                : (_filter == SellerFilter.pending
                    ? 'ไม่มีร้านรออนุมัติ'
                    : 'ไม่มีร้านในกลุ่มนี้'),
            compact: true,
          ),
          itemBuilder: (context, app, _) => _SellerCard(
            app: app,
            onTap: () async {
              if (await showSellerSheet(context, app)) _changed();
            },
          ),
        ),
      ],
    );
  }
}

(String, TpTone) _status(SellerApplication a) => switch (a.status) {
      'pending' => (a.statusLabel ?? 'รออนุมัติ', TpTone.info),
      'active' => (a.statusLabel ?? 'เปิดใช้งาน', TpTone.success),
      'closed' => (a.statusLabel ?? 'ถูกปฏิเสธ', TpTone.danger),
      _ => (a.statusLabel ?? a.status, TpTone.neutral),
    };

String _roleLabel(String? r) => switch (r) {
      'user' || 'member' || 'customer' => 'สมาชิกทั่วไป',
      'seller' || 'vendor' => 'ผู้ขาย',
      'admin' => 'แอดมิน',
      'super_admin' => 'ผู้ดูแลสูงสุด',
      'provider' => 'ผู้ให้บริการ',
      'rider' => 'ไรเดอร์',
      null || '' => '-',
      final String other => other,
    };

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.app, required this.onTap});
  final SellerApplication app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final (label, tone) = _status(app);
    return TpCard(
      accent: p.fg(tone),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Tp3D(TpArt.store, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(
                [
                  app.owner?.display,
                  app.businessTypeLabel,
                  app.province,
                ].whereType<String>().join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(12.5, p.muted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (app.isPending && app.waitingMinutes != null)
            WaitPill(app.waitingMinutes)
          else
            TpPill(pillText(label), tone: tone, dense: true),
        ]),
        if (app.companyName != null ||
            (app.status == 'closed' && app.rejectionReason != null)) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Text(
              app.status == 'closed' && app.rejectionReason != null
                  ? 'เหตุผล: ${app.rejectionReason}'
                  : app.companyName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  TpType.body(12.5, app.status == 'closed' ? p.danger : p.text),
            ),
          ),
        ],
      ]),
    );
  }
}

/// เปิดแผ่นรายละเอียดร้าน — คืน true ถ้าตัดสินแล้ว
Future<bool> showSellerSheet(
    BuildContext context, SellerApplication app) async {
  final r = await tpShowSheet<bool>(context,
      initial: 0.88,
      builder: (ctx, scroll) => _SellerSheet(app: app, scroll: scroll));
  return r ?? false;
}

class _SellerSheet extends ConsumerStatefulWidget {
  const _SellerSheet({required this.app, required this.scroll});
  final SellerApplication app;
  final ScrollController scroll;

  @override
  ConsumerState<_SellerSheet> createState() => _SellerSheetState();
}

class _SellerSheetState extends ConsumerState<_SellerSheet> {
  bool _busy = false;
  bool _sliding = false;

  int get _id => widget.app.id;

  Future<bool> _approve() async {
    setState(() => _sliding = true);
    final ok = await runApprovalAction(context,
        () => ref.read(approvalsRepositoryProvider).approveSeller(_id));
    if (mounted) setState(() => _sliding = false);
    return ok;
  }

  Future<void> _reject() async {
    final reason = await askReason(
      context,
      title: 'ปฏิเสธคำขอเปิดร้าน?',
      message: 'ผู้สมัครจะเห็นเหตุผลนี้ และแก้ไขแล้วยื่นใหม่ได้',
      hint: 'เช่น เอกสารบริษัทไม่ครบ',
      confirmLabel: 'ปฏิเสธ',
      max: 500,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    await runApprovalAction(context,
        () => ref.read(approvalsRepositoryProvider).rejectSeller(_id, reason));
    if (mounted) setState(() => _busy = false);
  }

  void _openOwner(int userId) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/users/$userId');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final detail = ref.watch(sellerDetailProvider(_id));
    final d = detail.valueOrNull;
    final a = d?.app ?? widget.app;
    final (label, tone) = _status(a);
    final locked = _busy || _sliding;
    final blocked = d != null && (d.ownerSuspended || d.ownerDeleted);

    return Column(children: [
      Expanded(
        child: ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          children: [
            SheetHeader(
              leading: const Tp3D(TpArt.store, size: 50),
              title: a.storeName,
              subtitle: [a.businessTypeLabel, a.province]
                  .whereType<String>()
                  .join(' · '),
              pill: Wrap(spacing: 6, runSpacing: 6, children: [
                TpPill(pillText(label), tone: tone, dense: true),
                if (a.isPending) WaitPill(a.waitingMinutes),
              ]),
            ),
            const SizedBox(height: 6),
            TpAsync<SellerDetail>(
              value: detail,
              compactError: true,
              onRetry: () => ref.invalidate(sellerDetailProvider(_id)),
              loading: const SheetSkeleton(),
              data: (d) => _SellerBody(d: d, onOpenOwner: _openOwner),
            ),
          ],
        ),
      ),
      if (d != null && (d.canApprove || d.canReject))
        TpBottomBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (d.canApprove) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  blocked
                      ? 'อนุมัติไม่ได้ — บัญชีเจ้าของถูกระงับหรือถูกลบ'
                      : 'อนุมัติแล้วร้านเปิดทันที (แพ็กเกจฟรี) และบัญชีเจ้าของเปลี่ยนเป็นผู้ขาย',
                  textAlign: TextAlign.center,
                  style: TpType.body(12, blocked ? p.warning : p.muted,
                      w: FontWeight.w500),
                ),
              ),
              TpSlideToConfirm(
                label: 'เลื่อนเพื่ออนุมัติร้านค้า',
                enabled: !_busy && !blocked,
                onConfirmed: _approve,
              ),
              const SizedBox(height: 10),
            ],
            if (d.canReject)
              TpButton.danger('ปฏิเสธคำขอ',
                  icon: PhosphorIconsRegular.xCircle,
                  height: 44,
                  fontSize: 14,
                  loading: _busy,
                  onPressed: locked ? null : _reject),
          ]),
        ),
    ]);
  }
}

class _SellerBody extends StatelessWidget {
  const _SellerBody({required this.d, required this.onOpenOwner});
  final SellerDetail d;
  final ValueChanged<int> onOpenOwner;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final a = d.app;
    final owner = a.owner;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.ownerSuspended || d.ownerDeleted) ...[
        const SizedBox(height: 8),
        ApprovalNotice(
          tone: TpTone.danger,
          text: d.ownerDeleted
              ? 'บัญชีเจ้าของร้านถูกลบแล้ว — อนุมัติไม่ได้'
              : 'บัญชีเจ้าของร้านถูกระงับอยู่ — ยกเลิกการระงับก่อนจึงจะอนุมัติได้',
        ),
      ],
      if (a.status == 'closed' && a.rejectionReason != null) ...[
        const SizedBox(height: 8),
        ApprovalNotice(
            tone: TpTone.danger,
            icon: PhosphorIconsFill.xCircle,
            text: 'ปฏิเสธไปแล้ว: ${a.rejectionReason}'),
      ],
      DetailSection('ข้อมูลร้าน', children: [
        TpKv('ชื่อร้าน', a.storeName),
        TpKv('ประเภทธุรกิจ', a.businessTypeLabel ?? '-'),
        if (a.companyName != null) TpKv('ชื่อนิติบุคคล', a.companyName!),
        if (a.taxIdMasked != null)
          TpKv('เลขผู้เสียภาษี', a.taxIdMasked!, mono: true),
        TpKv('โทรศัพท์ร้าน', d.storePhone ?? a.phoneMasked ?? '-', mono: true),
        if (d.storeEmail != null) TpKv('อีเมลร้าน', d.storeEmail!),
        TpKv('ที่อยู่', d.address.isEmpty ? (a.province ?? '-') : d.address),
        TpKv('ยื่นคำขอเมื่อ', approvalWhen(a.submittedAt)),
      ]),
      if (d.description != null)
        DetailSection('รายละเอียดร้าน', children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(d.description!,
                style: TpType.body(13.5, p.text, height: 1.55)),
          ),
        ]),
      DetailSection(
        'เจ้าของร้าน',
        trailing: owner == null
            ? null
            : TpButton.ghost('เปิดหน้าสมาชิก',
                height: 32,
                fontSize: 13,
                onPressed: () => onOpenOwner(owner.id)),
        children: [
          TpKv('ชื่อ', owner?.display ?? '-'),
          if (owner?.memberNumber != null)
            TpKv('รหัสสมาชิก', owner!.memberNumber!, mono: true),
          if (d.hasOwnerDetail) ...[
            TpKv('บทบาทปัจจุบัน', _roleLabel(d.ownerRole)),
            TpKv(
                'ยืนยันตัวตน',
                d.ownerKycVerified
                    ? 'ยืนยันแล้ว'
                    : kycStatusLabel(d.ownerKycStatus),
                valueColor: d.ownerKycVerified ? p.success : p.warning),
            TpKv(
                'สถานะบัญชี',
                d.ownerDeleted
                    ? 'ถูกลบ'
                    : (d.ownerSuspended ? 'ถูกระงับ' : 'ใช้งานปกติ'),
                valueColor: (d.ownerDeleted || d.ownerSuspended)
                    ? p.danger
                    : p.success),
            TpKv('สมัครสมาชิกเมื่อ', approvalWhen(d.ownerJoinedAt)),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('ไม่พบบัญชีเจ้าของในระบบ',
                  style: TpType.body(13, p.danger)),
            ),
        ],
      ),
    ]);
  }
}
