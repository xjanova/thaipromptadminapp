import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/approvals_repository.dart';
import 'approval_widgets.dart';

/// หน้า "ไรเดอร์" (`/approvals/riders?status=`) — ใบสมัครใหม่ + ไรเดอร์ที่เปลี่ยนเอกสารสำคัญ (ตรวจซ้ำ)
///
/// เอกสารเป็นรูปส่วนตัว (แนบ token) · อนุมัติ = เลื่อนยืนยัน (เอกสารบังคับต้องครบ)
/// · ตรวจเอกสารซ้ำแล้ว = ไรเดอร์รับงานต่อได้ · ปฏิเสธ = เหตุผล 3–500 ตัวอักษร
class RiderApplicationsScreen extends ConsumerStatefulWidget {
  const RiderApplicationsScreen({super.key, this.initialStatus});
  final String? initialStatus;

  @override
  ConsumerState<RiderApplicationsScreen> createState() =>
      _RiderApplicationsScreenState();
}

class _RiderApplicationsScreenState
    extends ConsumerState<RiderApplicationsScreen> {
  late RiderFilter _filter = RiderFilter.parse(widget.initialStatus);
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
    final p = context.tp;
    final s = ref.watch(approvalsSummaryProvider).valueOrNull;
    return TpPage(
      title: 'ไรเดอร์',
      subtitle: _found == null
          ? 'ใบสมัครใหม่และเอกสารที่ต้องตรวจซ้ำ'
          : 'พบ ${TpFmt.count(_found)} คน',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ApprovalSearchBar(
          hint: 'ชื่อ เบอร์โทร หรือทะเบียนรถ',
          onQuery: (q) => setState(() {
            _query = q;
            _found = null;
          }),
        ),
        const SizedBox(height: 10),
        TpChips<RiderFilter>(
          onHeader: true,
          padding: EdgeInsets.zero,
          value: _filter,
          onChanged: (f) => setState(() {
            _filter = f;
            _found = null;
          }),
          items: [
            for (final f in RiderFilter.values)
              TpChipItem(f, f.label,
                  count: switch (f) {
                    RiderFilter.pending =>
                      s?.box(ApprovalQueue.riderApplications)?.count,
                    RiderFilter.documentsChanged =>
                      s?.box(ApprovalQueue.riderDocuments)?.count,
                    _ => null,
                  }),
          ],
        ),
      ]),
      slivers: [
        if (_filter == RiderFilter.documentsChanged)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                  'ไรเดอร์ที่อนุมัติแล้วแต่เปลี่ยนบัตร/ใบขับขี่/ทะเบียนรถ — รับงานไม่ได้จนกว่าจะตรวจเอกสารใหม่',
                  style: TpType.body(12.5, p.muted)),
            ),
          ),
        TpPagedSliver<RiderApplication>(
          reloadKey: '${_filter.key}|$_query|$_reload',
          fetch: (page) => ref
              .read(approvalsRepositoryProvider)
              .riderList(filter: _filter, search: _query, page: page),
          onLoaded: (pg) {
            if (mounted) setState(() => _found = pg.total);
          },
          empty: TpEmpty(
            art: (_filter == RiderFilter.pending ||
                    _filter == RiderFilter.documentsChanged)
                ? TpArt.emptyDone
                : TpArt.emptyInbox,
            title: _query.isNotEmpty
                ? 'ไม่พบไรเดอร์ที่ค้นหา'
                : switch (_filter) {
                    RiderFilter.pending => 'ไม่มีใบสมัครรอตรวจ',
                    RiderFilter.documentsChanged => 'ไม่มีเอกสารรอตรวจซ้ำ',
                    _ => 'ไม่มีไรเดอร์ในกลุ่มนี้',
                  },
            compact: true,
          ),
          itemBuilder: (context, r, _) => _RiderCard(
            r: r,
            onTap: () async {
              if (await showRiderSheet(context, r)) _changed();
            },
          ),
        ),
      ],
    );
  }
}

(String, TpTone) _status(RiderApplication r) {
  if (r.documentsChangedAt != null && r.status == 'approved') {
    return ('เปลี่ยนเอกสาร', TpTone.warning);
  }
  final tone = switch (r.status) {
    'pending' => TpTone.info,
    'approved' => TpTone.success,
    'rejected' || 'suspended' => TpTone.danger,
    _ => TpTone.neutral,
  };
  return (r.statusText ?? r.status, tone);
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.r, required this.onTap});
  final RiderApplication r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final (label, tone) = _status(r);
    return TpCard(
      accent: p.fg(tone),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TpAvatar(name: r.fullName),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(
                [r.vehicleTypeText, r.vehiclePlate, r.province]
                    .whereType<String>()
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(12.5, p.muted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (r.status == 'pending' && r.waitingMinutes != null)
            WaitPill(r.waitingMinutes)
          else
            TpPill(pillText(label), tone: tone, dense: true),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TpPill(r.kycVerified ? 'ยืนยันตัวตนแล้ว' : 'ยังไม่ยืนยันตัวตน',
              tone: r.kycVerified ? TpTone.success : TpTone.warning,
              icon: r.kycVerified
                  ? PhosphorIconsBold.sealCheck
                  : PhosphorIconsBold.warning,
              dense: true),
          if (r.documentsComplete)
            const TpPill('เอกสารครบ',
                tone: TpTone.success,
                icon: PhosphorIconsBold.check,
                dense: true)
          else
            TpPill(
                pillText(r.documentsMissingText ??
                    'ขาดเอกสาร ${r.documentsMissing.length} อย่าง'),
                tone: TpTone.danger,
                dense: true),
          if (r.documentsChangedAt != null)
            TpPill('เปลี่ยนเอกสาร ${TpFmt.ago(r.documentsChangedAt)}',
                tone: TpTone.warning,
                icon: PhosphorIconsBold.clockCountdown,
                dense: true),
        ]),
      ]),
    );
  }
}

/// เปิดแผ่นรายละเอียดไรเดอร์ — คืน true ถ้ามีการเปลี่ยนสถานะ
Future<bool> showRiderSheet(BuildContext context, RiderApplication r) async {
  final res = await tpShowSheet<bool>(context,
      initial: 0.92,
      builder: (ctx, scroll) => _RiderSheet(rider: r, scroll: scroll));
  return res ?? false;
}

class _RiderSheet extends ConsumerStatefulWidget {
  const _RiderSheet({required this.rider, required this.scroll});
  final RiderApplication rider;
  final ScrollController scroll;

  @override
  ConsumerState<_RiderSheet> createState() => _RiderSheetState();
}

class _RiderSheetState extends ConsumerState<_RiderSheet> {
  bool _sliding = false;

  /// ปุ่มที่กำลังทำงาน ('reject' / 'docs') — null = ว่าง
  String? _running;

  bool get _busy => _running != null;

  /// เอกสารที่แผ่นนี้แสดง — ล้างออกจากแคชหน่วยความจำตอนปิด
  final _photos = <String>{};

  int get _id => widget.rider.id;

  @override
  void dispose() {
    evictPrivatePhotos(_photos);
    super.dispose();
  }

  Future<bool> _approve() async {
    setState(() => _sliding = true);
    final ok = await runApprovalAction(
        context, () => ref.read(approvalsRepositoryProvider).approveRider(_id));
    if (mounted) setState(() => _sliding = false);
    return ok;
  }

  Future<void> _reject() async {
    final reason = await askReason(
      context,
      title: 'ปฏิเสธใบสมัครไรเดอร์?',
      message: 'ผู้สมัครจะเห็นเหตุผลนี้',
      hint: 'เช่น รูปใบขับขี่ไม่ชัด',
      confirmLabel: 'ปฏิเสธ',
      min: 3,
      max: 500,
    );
    if (reason == null || !mounted) return;
    setState(() => _running = 'reject');
    await runApprovalAction(context,
        () => ref.read(approvalsRepositoryProvider).rejectRider(_id, reason));
    if (mounted) setState(() => _running = null);
  }

  Future<void> _documentsReviewed() async {
    final yes = await tpConfirm(
      context,
      title: 'ตรวจเอกสารใหม่แล้ว?',
      message:
          'ยืนยันว่าเอกสารที่ไรเดอร์เปลี่ยนถูกต้อง — ไรเดอร์จะกลับมารับงานได้ทันที',
      confirmLabel: 'ยืนยัน',
    );
    if (!yes || !mounted) return;
    setState(() => _running = 'docs');
    await runApprovalAction(
        context,
        () =>
            ref.read(approvalsRepositoryProvider).riderDocumentsReviewed(_id));
    if (mounted) setState(() => _running = null);
  }

  void _openUser(int userId) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/users/$userId');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final detail = ref.watch(riderDetailProvider(_id));
    final d = detail.valueOrNull;
    if (d != null) {
      _photos.addAll([
        for (final doc in d.documents)
          if (doc.uploaded) doc.url!
      ]);
    }
    final r = d?.rider ?? widget.rider;
    final (label, tone) = _status(r);
    final locked = _busy || _sliding;
    final pendingBlocked = d != null && !d.canApprove && r.status == 'pending';

    return Column(children: [
      Expanded(
        child: ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          children: [
            SheetHeader(
              leading: TpAvatar(name: r.fullName, size: 48),
              title: r.fullName,
              subtitle: [r.phoneMasked, r.vehicleTypeText]
                  .whereType<String>()
                  .join(' · '),
              pill: Wrap(spacing: 6, runSpacing: 6, children: [
                TpPill(pillText(label), tone: tone, dense: true),
                if (r.status == 'pending') WaitPill(r.waitingMinutes),
              ]),
            ),
            const SizedBox(height: 6),
            TpAsync<RiderDetail>(
              value: detail,
              compactError: true,
              onRetry: () => ref.invalidate(riderDetailProvider(_id)),
              loading: const SheetSkeleton(),
              data: (d) => _RiderBody(d: d, onOpenUser: _openUser),
            ),
          ],
        ),
      ),
      if (d != null &&
          (d.canApprove || d.canReject || d.canMarkDocumentsReviewed))
        TpBottomBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (pendingBlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('อนุมัติไม่ได้ — เอกสารบังคับยังไม่ครบ',
                    textAlign: TextAlign.center,
                    style: TpType.body(12.5, p.warning, w: FontWeight.w500)),
              ),
            if (d.canMarkDocumentsReviewed) ...[
              TpButton('ตรวจเอกสารใหม่แล้ว · ให้รับงานต่อ',
                  icon: PhosphorIconsBold.sealCheck,
                  height: 48,
                  fontSize: 14.5,
                  loading: _running == 'docs',
                  onPressed: locked ? null : _documentsReviewed),
              if (d.canApprove || d.canReject) const SizedBox(height: 10),
            ],
            if (d.canApprove) ...[
              TpSlideToConfirm(
                label: 'เลื่อนเพื่ออนุมัติไรเดอร์',
                enabled: !_busy,
                onConfirmed: _approve,
              ),
              if (d.canReject) const SizedBox(height: 10),
            ],
            if (d.canReject)
              TpButton.danger('ปฏิเสธใบสมัคร',
                  icon: PhosphorIconsRegular.xCircle,
                  height: 44,
                  fontSize: 14,
                  loading: _running == 'reject',
                  onPressed: locked ? null : _reject),
          ]),
        ),
    ]);
  }
}

class _RiderBody extends StatelessWidget {
  const _RiderBody({required this.d, required this.onOpenUser});
  final RiderDetail d;
  final ValueChanged<int> onOpenUser;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final r = d.rider;
    final user = r.user;
    final docs = d.documents;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (r.documentsChangedAt != null) ...[
        const SizedBox(height: 8),
        ApprovalNotice(
          text:
              'ไรเดอร์เปลี่ยนเอกสารสำคัญเมื่อ ${approvalWhen(r.documentsChangedAt)} — รับงานไม่ได้จนกว่าจะตรวจซ้ำ',
        ),
      ],
      if (!r.documentsComplete) ...[
        const SizedBox(height: 8),
        ApprovalNotice(
          tone: TpTone.danger,
          text: r.documentsMissingText ??
              'ยังขาดเอกสารบังคับ ${r.documentsMissing.length} อย่าง',
        ),
      ],
      if (d.rejectionReason != null) ...[
        const SizedBox(height: 8),
        ApprovalNotice(
            tone: TpTone.danger,
            icon: PhosphorIconsFill.xCircle,
            text: 'ปฏิเสธไปแล้ว: ${d.rejectionReason}'),
      ],
      if (d.suspensionReason != null) ...[
        const SizedBox(height: 8),
        ApprovalNotice(
            tone: TpTone.danger,
            icon: PhosphorIconsFill.prohibit,
            text: 'ถูกระงับ: ${d.suspensionReason}'),
      ],

      // ── เอกสาร ──
      TpSection('เอกสาร',
          trailing: Text('แตะเพื่อขยาย', style: TpType.body(12, p.faint)),
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8)),
      if (docs.isEmpty)
        TpCard(
            child: Text('ไม่มีข้อมูลเอกสาร', style: TpType.body(13, p.muted)))
      else
        for (var i = 0; i < docs.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _DocTile(doc: docs[i])),
              const SizedBox(width: 10),
              Expanded(
                  child: i + 1 < docs.length
                      ? _DocTile(doc: docs[i + 1])
                      : const SizedBox.shrink()),
            ]),
          ),

      // ── ผู้สมัคร ──
      DetailSection(
        'ข้อมูลผู้สมัคร',
        trailing: user == null
            ? null
            : TpButton.ghost('เปิดหน้าสมาชิก',
                height: 32, fontSize: 13, onPressed: () => onOpenUser(user.id)),
        children: [
          TpKv('ชื่อ-นามสกุล', r.fullName),
          TpKv('โทรศัพท์', d.phone ?? r.phoneMasked ?? '-', mono: true),
          if (r.idCardMasked != null)
            TpKv('เลขบัตรประชาชน', r.idCardMasked!, mono: true),
          if (d.birthDate != null) TpKv('วันเกิด', approvalDate(d.birthDate)),
          TpKv('ที่อยู่', d.address.isEmpty ? (r.province ?? '-') : d.address),
          TpKv('ยืนยันตัวตน (KYC)',
              r.kycVerified ? 'ยืนยันแล้ว' : 'ยังไม่ยืนยัน',
              valueColor: r.kycVerified ? p.success : p.warning),
          if (user != null)
            TpKv(
                'บัญชีสมาชิก',
                [user.display, user.memberNumber]
                    .whereType<String>()
                    .join(' · ')),
          TpKv('สมัครเมื่อ', approvalWhen(r.submittedAt)),
          if (d.approvedAt != null)
            TpKv('อนุมัติเมื่อ', approvalWhen(d.approvedAt)),
        ],
      ),

      // ── ยานพาหนะ ──
      DetailSection('ยานพาหนะ', children: [
        TpKv('ประเภท', d.vehicle.isEmpty ? '-' : d.vehicle),
        TpKv('ทะเบียน', d.vehiclePlate ?? '-', mono: true),
        if (d.riderType != null) TpKv('รูปแบบไรเดอร์', d.riderType!),
      ]),
    ]);
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc});
  final RiderDocument doc;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Stack(children: [
      PrivatePhoto(
        url: doc.uploaded ? doc.url : null,
        label: doc.required ? '${doc.label} · จำเป็น' : doc.label,
        requiresAuth: doc.requiresAuth,
        height: 110,
        missingText: doc.required ? 'ยังไม่อัปโหลด (จำเป็น)' : 'ยังไม่อัปโหลด',
      ),
      if (!doc.uploaded && doc.required)
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: p.dangerSoft, borderRadius: BorderRadius.circular(8)),
            child: Text('ขาด',
                style: TpType.body(11, p.danger, w: FontWeight.w700)),
          ),
        ),
    ]);
  }
}
