import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/approvals_repository.dart';
import 'approval_widgets.dart';

/// หน้า "ตรวจ eKYC" (`/approvals/ekyc`) — คำขอยืนยันตัวตนที่ AI ไม่มั่นใจ
///
/// แตะรายการ → แผ่นรายละเอียด: รูปบัตร/ใบหน้า (แนบ token · ทุกการเปิดดูถูกบันทึก PDPA) · คะแนน AI · เหตุผล
/// อนุมัติ = เลื่อนยืนยัน · ปฏิเสธ / ขอถ่ายใหม่ = ต้องใส่เหตุผล
class EkycReviewScreen extends ConsumerStatefulWidget {
  const EkycReviewScreen({super.key});

  @override
  ConsumerState<EkycReviewScreen> createState() => _EkycReviewScreenState();
}

class _EkycReviewScreenState extends ConsumerState<EkycReviewScreen> {
  EkycFilter _filter = EkycFilter.pending;
  String _query = '';
  int _reload = 0;
  int? _found;

  Future<void> _refresh() async {
    setState(() => _reload++);
    try {
      ref.invalidate(approvalsSummaryProvider);
      await ref.read(approvalsSummaryProvider.future);
    } catch (_) {
      // ตัวนับบนชิปไม่ขึ้นเฉย ๆ — รายการยังโหลดได้
    }
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
    final pendingCount = s?.box(ApprovalQueue.ekyc)?.count;
    return TpPage(
      title: 'ตรวจ eKYC',
      subtitle: _found == null
          ? 'คำขอยืนยันตัวตนที่ AI ไม่มั่นใจ'
          : 'พบ ${TpFmt.count(_found)} รายการ',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ApprovalSearchBar(
          hint: 'ชื่อหรืออีเมลผู้ใช้',
          onQuery: (q) => setState(() {
            _query = q;
            _found = null;
          }),
        ),
        const SizedBox(height: 10),
        TpChips<EkycFilter>(
          onHeader: true,
          padding: EdgeInsets.zero,
          value: _filter,
          onChanged: (f) => setState(() {
            _filter = f;
            _found = null;
          }),
          items: [
            for (final f in EkycFilter.values)
              TpChipItem(f, f.label,
                  count: f == EkycFilter.pending ? pendingCount : null),
          ],
        ),
      ]),
      slivers: [
        if (_filter == EkycFilter.pending)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                  'คำขอที่ AI มั่นใจระบบอนุมัติให้อัตโนมัติแล้ว — ที่เหลือคือกรณีก้ำกึ่ง เทียบรูปบัตรกับใบหน้าก่อนตัดสิน (ทุกการเปิดดูรูปถูกบันทึกตาม PDPA)',
                  style: TpType.body(12.5, p.muted)),
            ),
          ),
        TpPagedSliver<EkycItem>(
          reloadKey: '${_filter.key}|$_query|$_reload',
          fetch: (page) => ref
              .read(approvalsRepositoryProvider)
              .ekycList(filter: _filter, search: _query, page: page),
          onLoaded: (pg) {
            if (mounted) setState(() => _found = pg.total);
          },
          empty: TpEmpty(
            art: _filter == EkycFilter.pending
                ? TpArt.emptyDone
                : TpArt.emptyInbox,
            title: _query.isNotEmpty
                ? 'ไม่พบผู้ใช้ที่ค้นหา'
                : (_filter == EkycFilter.pending
                    ? 'ไม่มี eKYC รอตรวจ'
                    : 'ไม่มีรายการในกลุ่มนี้'),
            message: _filter == EkycFilter.pending && _query.isEmpty
                ? 'คำขอใหม่ที่ AI ไม่มั่นใจจะขึ้นที่นี่'
                : null,
            compact: true,
          ),
          itemBuilder: (context, item, _) => _EkycCard(
            item: item,
            onTap: () async {
              if (await showEkycSheet(context, item)) _changed();
            },
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── ป้าย / สี ─────────────────────────

const _flagMeta = <String, (String, TpTone)>{
  'duplicate_id': ('เลขบัตรซ้ำกับบัญชีอื่น', TpTone.danger),
  'replay_suspected': ('สงสัยใช้ภาพ/วิดีโอซ้ำ', TpTone.danger),
  'card_not_real': ('บัตรอาจไม่ใช่ของจริง', TpTone.danger),
  'prior_rejected': ('เคยถูกปฏิเสธ', TpTone.warning),
  'attempts_exhausted': ('ลองครบจำนวนครั้งแล้ว', TpTone.warning),
  'user_corrected': ('ผู้ใช้แก้ข้อมูลบัตรเอง', TpTone.warning),
  'ai_unavailable': ('AI ตรวจไม่ได้', TpTone.info),
  'lifelong_card': ('บัตรตลอดชีพ', TpTone.neutral),
};

(String, TpTone) _status(EkycItem it) => switch (it.status) {
      'pending' => (it.statusLabel ?? 'รอตรวจ', TpTone.info),
      'approved' => (it.statusLabel ?? 'อนุมัติแล้ว', TpTone.success),
      'rejected' => (it.statusLabel ?? 'ปฏิเสธแล้ว', TpTone.danger),
      'retake' => (it.statusLabel ?? 'ขอถ่ายใหม่', TpTone.warning),
      _ => (it.statusLabel ?? it.status, TpTone.neutral),
    };

/// สีของคะแนน: ใบหน้าใช้ 2 เกณฑ์ (อนุมัติเองได้ / ส่งคนตรวจ) · ข้ออื่นผ่าน/ไม่ผ่านเกณฑ์ขั้นต่ำ
TpTone _scoreTone(double v, double pass, [double? review]) {
  if (v >= pass) return TpTone.success;
  if (review != null && v >= review) return TpTone.warning;
  return TpTone.danger;
}

String _pct(double v) => '${(v * 100).round()}%';

String _decisionLabel(String? d) => switch (d) {
      'review' => 'ส่งให้คนตรวจ',
      'approve' || 'auto_approve' || 'approved' => 'AI ให้ผ่าน',
      'retake' => 'AI แนะนำให้ถ่ายใหม่',
      'reject' || 'rejected' => 'AI ให้ไม่ผ่าน',
      _ => 'ไม่ระบุ',
    };

/// "ผู้ใช้แก้ชื่อ (ไทย): AI อ่านได้ "ก" → "ข""
String _correctionText(EkycCorrection c) {
  final date = c.field == 'birth_date';
  final field = switch (c.field) {
    'name_th' => 'ชื่อ (ไทย)',
    'birth_date' => 'วันเกิด',
    _ => c.field,
  };
  final from = date ? approvalDate(c.ocr) : (c.ocr ?? '-');
  final to = date ? approvalDate(c.user) : (c.user ?? '-');
  return 'ผู้ใช้แก้$field: AI อ่านได้ "$from" → "$to"';
}

class _EkycCard extends StatelessWidget {
  const _EkycCard({required this.item, required this.onTap});
  final EkycItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final it = item;
    final (label, tone) = _status(it);
    final danger = it.flags.any((f) => _flagMeta[f]?.$2 == TpTone.danger);
    final face = it.ai.faceMatch;
    final live = it.ai.liveness;
    return TpCard(
      accent: danger ? p.danger : p.fg(tone),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TpAvatar(name: it.user?.display),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.user?.display ?? 'ผู้ใช้',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(
                [it.user?.memberNumber, it.documentTypeLabel, it.idLast4]
                    .whereType<String>()
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(12.5, p.muted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (it.isPending && it.waitingMinutes != null)
            WaitPill(it.waitingMinutes)
          else
            TpPill(pillText(label), tone: tone, dense: true),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (face != null)
            TpPill('ใบหน้า ${_pct(face)}',
                tone: _scoreTone(face, 0.5, 0.3),
                icon: PhosphorIconsBold.userFocus,
                dense: true),
          if (live != null)
            TpPill('คนจริง ${_pct(live)}',
                tone: _scoreTone(live, 0.8),
                icon: PhosphorIconsBold.eye,
                dense: true),
          for (final f in it.flags)
            if (_flagMeta[f] != null)
              TpPill(_flagMeta[f]!.$1, tone: _flagMeta[f]!.$2, dense: true),
        ]),
        if (it.reasonTexts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(it.reasonTexts.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TpType.body(12.5, p.text)),
        ],
      ]),
    );
  }
}

// ───────────────────────── แผ่นรายละเอียด ─────────────────────────

/// เปิดแผ่นรายละเอียด eKYC — คืน true ถ้าตัดสินแล้ว (ให้หน้ารายการโหลดใหม่)
Future<bool> showEkycSheet(BuildContext context, EkycItem item) async {
  final r = await tpShowSheet<bool>(context,
      initial: 0.92,
      builder: (ctx, scroll) => _EkycSheet(item: item, scroll: scroll));
  return r ?? false;
}

class _EkycSheet extends ConsumerStatefulWidget {
  const _EkycSheet({required this.item, required this.scroll});
  final EkycItem item;
  final ScrollController scroll;

  @override
  ConsumerState<_EkycSheet> createState() => _EkycSheetState();
}

class _EkycSheetState extends ConsumerState<_EkycSheet> {
  bool _busy = false;
  bool _sliding = false;

  /// รูปที่แผ่นนี้แสดง — ล้างออกจากแคชหน่วยความจำตอนปิด (รูปบัตรไม่ค้างในเครื่อง)
  final _photos = <String>{};

  int get _id => widget.item.id;

  @override
  void dispose() {
    evictPrivatePhotos(_photos);
    super.dispose();
  }

  Future<bool> _approve() async {
    setState(() => _sliding = true);
    final ok = await runApprovalAction(
        context, () => ref.read(approvalsRepositoryProvider).approveEkyc(_id));
    if (mounted) setState(() => _sliding = false);
    return ok;
  }

  Future<void> _reject() async {
    final reason = await askReason(
      context,
      title: 'ปฏิเสธการยืนยันตัวตน?',
      message:
          'ผู้ใช้จะได้รับแจ้งผล และต้องเริ่มยืนยันตัวตนใหม่ — ใช้เมื่อมั่นใจว่าไม่ใช่เจ้าของบัตร',
      hint: 'เหตุผล เช่น ใบหน้าไม่ตรงกับรูปบนบัตร',
      confirmLabel: 'ปฏิเสธ',
      max: 1000,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    await runApprovalAction(context,
        () => ref.read(approvalsRepositoryProvider).rejectEkyc(_id, reason));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _retake() async {
    final reason = await askReason(
      context,
      title: 'ขอให้ถ่ายใหม่',
      message:
          'ผู้ใช้จะเห็นข้อความนี้ แล้วกลับไปถ่ายบัตร/ใบหน้าใหม่ได้ — เขียนให้เข้าใจง่ายว่าต้องแก้อะไร',
      hint: 'เช่น รูปบัตรเบลอ ถ่ายใหม่ในที่สว่าง',
      confirmLabel: 'ส่งคำขอ',
      danger: false,
      max: 500,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    await runApprovalAction(
        context,
        () => ref
            .read(approvalsRepositoryProvider)
            .requestEkycRetake(_id, reason));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final detail = ref.watch(ekycDetailProvider(_id));
    final d = detail.valueOrNull;
    if (d != null) {
      _photos.addAll([
        for (final i in d.images)
          if (i.available) i.url!
      ]);
    }
    final it = d?.item ?? widget.item;
    final (label, tone) = _status(it);
    final locked = _busy || _sliding;

    return Column(children: [
      Expanded(
        child: ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          children: [
            SheetHeader(
              leading: TpAvatar(name: it.user?.display, size: 48),
              title: it.user?.display ?? 'ผู้ใช้',
              subtitle: [it.user?.memberNumber, it.documentTypeLabel]
                  .whereType<String>()
                  .join(' · '),
              pill: Wrap(spacing: 6, runSpacing: 6, children: [
                TpPill(pillText(label), tone: tone, dense: true),
                if (it.isPending) WaitPill(it.waitingMinutes),
              ]),
            ),
            const SizedBox(height: 14),
            TpAsync<EkycDetail>(
              value: detail,
              compactError: true,
              onRetry: () => ref.invalidate(ekycDetailProvider(_id)),
              loading: const SheetSkeleton(),
              data: (d) => _EkycBody(d: d),
            ),
          ],
        ),
      ),
      if (d != null && (d.canApprove || d.canReject || d.canRequestRetake))
        TpBottomBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (d.canApprove && d.duplicateNow)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('อนุมัติไม่ได้ — บัตรนี้ยืนยันกับบัญชีอื่นไปแล้ว',
                    textAlign: TextAlign.center,
                    style: TpType.body(12.5, p.warning, w: FontWeight.w500)),
              ),
            if (d.canApprove) ...[
              TpSlideToConfirm(
                label: 'เลื่อนเพื่ออนุมัติตัวตน',
                enabled: !_busy && !d.duplicateNow,
                onConfirmed: _approve,
              ),
              const SizedBox(height: 10),
            ],
            Row(children: [
              if (d.canRequestRetake)
                Expanded(
                  child: TpButton.outline('ขอถ่ายใหม่',
                      icon: PhosphorIconsRegular.camera,
                      height: 44,
                      fontSize: 14,
                      onPressed: locked ? null : _retake),
                ),
              if (d.canRequestRetake && d.canReject) const SizedBox(width: 10),
              if (d.canReject)
                Expanded(
                  child: TpButton.danger('ปฏิเสธ',
                      icon: PhosphorIconsRegular.xCircle,
                      height: 44,
                      fontSize: 14,
                      loading: _busy,
                      onPressed: locked ? null : _reject),
                ),
            ]),
          ]),
        ),
    ]);
  }
}

class _EkycBody extends StatelessWidget {
  const _EkycBody({required this.d});
  final EkycDetail d;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final it = d.item;
    final face = it.ai.faceMatch ?? d.matchScore;
    final scores = <(String, double?, double, double?)>[
      (
        'ใบหน้าตรงกับบัตร',
        face,
        d.threshold('auto_approve_match', 0.5),
        d.threshold('review_match', 0.3)
      ),
      ('ยืนยันคนจริง', it.ai.liveness, d.threshold('min_liveness', 0.8), null),
      ('ภาพใบหน้าจริง', it.ai.real, d.threshold('min_real', 0.7), null),
      ('บัตรของจริง', it.ai.cardReal, d.threshold('min_card_real', 0.6), null),
      ('อ่านข้อมูลบัตร', it.ai.ocr, d.threshold('min_ocr', 0.8), null),
    ].where((s) => s.$2 != null).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.duplicateNow) ...[
        const ApprovalNotice(
          text:
              'บัตรนี้ยืนยันกับบัญชีอื่นไปแล้ว (เช็คสด ณ ตอนเปิด) — อนุมัติไม่ได้ ปฏิเสธหรือขอถ่ายใหม่แทน',
          tone: TpTone.danger,
        ),
        const SizedBox(height: 12),
      ],
      // ── รูป ──
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < d.images.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: PrivatePhoto(
              url: d.images[i].available ? d.images[i].url : null,
              label: d.images[i].label,
              requiresAuth: d.imageRequiresAuth,
              missingText: 'ไม่มีรูป / ลบตามรอบแล้ว',
            ),
          ),
        ],
      ]),
      if (d.images.isEmpty)
        Text('ไม่มีรูปในคำขอนี้', style: TpType.body(13, p.muted)),
      const SizedBox(height: 6),
      Row(children: [
        Icon(PhosphorIconsRegular.lock, size: 13, color: p.faint),
        const SizedBox(width: 4),
        Expanded(
          child: Text('ทุกการเปิดดูรูปถูกบันทึกตาม PDPA · แตะรูปเพื่อขยาย',
              style: TpType.body(11.5, p.faint)),
        ),
      ]),

      // ── คะแนน AI ──
      DetailSection(
        'ผลตรวจของ AI',
        trailing: TpPill(_decisionLabel(it.ai.decision),
            tone: TpTone.navy, icon: PhosphorIconsFill.sparkle, dense: true),
        children: [
          if (scores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('AI ไม่ได้ให้คะแนนสำหรับคำขอนี้',
                  style: TpType.body(13, p.muted)),
            ),
          for (final s in scores)
            _ScoreBar(label: s.$1, value: s.$2!, pass: s.$3, review: s.$4),
          if (d.challenges.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in d.challenges.entries)
                TpPill(
                  switch (c.key) {
                    'blink' => 'กะพริบตา',
                    'turn_left' => 'หันซ้าย',
                    'turn_right' => 'หันขวา',
                    'smile' => 'ยิ้ม',
                    'nod' => 'พยักหน้า',
                    _ => c.key,
                  },
                  tone: c.value ? TpTone.success : TpTone.danger,
                  icon: c.value ? PhosphorIconsBold.check : PhosphorIconsBold.x,
                  dense: true,
                ),
            ]),
            const SizedBox(height: 6),
          ],
          if (d.modelVersion != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text('รุ่นโมเดล ${d.modelVersion}',
                  style: TpType.body(11, p.faint)),
            ),
        ],
      ),

      // ── เหตุผล + ธงเตือน ──
      if (it.reasonTexts.isNotEmpty || it.flags.isNotEmpty)
        DetailSection('ทำไมต้องให้คนตรวจ', children: [
          for (final r in it.reasonTexts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(PhosphorIconsFill.warningCircle,
                      size: 14, color: p.warning),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(r, style: TpType.body(13.5, p.text))),
              ]),
            ),
          if (it.flags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in it.flags)
                  if (_flagMeta[f] != null)
                    TpPill(_flagMeta[f]!.$1,
                        tone: _flagMeta[f]!.$2, dense: true),
              ]),
            ),
        ]),

      // ── ข้อมูลบนบัตร ──
      DetailSection('ข้อมูลบนบัตร', children: [
        TpKv('ชื่อ (ไทย)', d.cardNameTh ?? '-'),
        if (d.cardNameEn != null) TpKv('ชื่อ (อังกฤษ)', d.cardNameEn!),
        TpKv('วันเกิด', approvalDate(d.birthDate)),
        TpKv('หมดอายุ', d.lifelong ? 'ตลอดชีพ' : approvalDate(d.expiryDate)),
        TpKv('เลขบัตร', d.idMasked ?? it.idLast4 ?? '-', mono: true),
        if (d.checksumOk != null)
          TpKv('ตรวจเลขบัตร', d.checksumOk! ? 'ถูกต้อง' : 'ไม่ผ่าน',
              valueColor: d.checksumOk! ? p.success : p.danger),
      ]),
      if (d.corrections.isNotEmpty) ...[
        const SizedBox(height: 10),
        ApprovalNotice(
          icon: PhosphorIconsFill.pencilSimple,
          text: d.corrections.map(_correctionText).join('\n'),
        ),
      ],

      // ── บัญชีผู้ใช้ ──
      DetailSection('บัญชีผู้ใช้', children: [
        TpKv('ชื่อในบัญชี', d.accountName ?? it.user?.display ?? '-'),
        if (d.nameMatchesCard != null)
          TpKv('ชื่อตรงกับบัตร', d.nameMatchesCard! ? 'ตรงกัน' : 'ไม่ตรง',
              valueColor: d.nameMatchesCard! ? p.success : p.danger),
        TpKv('สถานะ KYC', kycStatusLabel(d.accountKycStatus)),
        TpKv('สมัครเมื่อ', approvalWhen(d.accountCreatedAt)),
        TpKv('ยื่นคำขอเมื่อ', approvalWhen(it.submittedAt)),
      ]),

      // ── ผลการตรวจ (ถ้าตัดสินแล้ว) ──
      if (d.reviewedAt != null || d.reviewedBy != null)
        DetailSection('ผลการตรวจ', children: [
          TpKv('ตรวจโดย', d.reviewedBy ?? '-'),
          TpKv('เมื่อ', approvalWhen(d.reviewedAt)),
          if (d.reviewNote != null) TpKv('หมายเหตุ', d.reviewNote!),
        ]),

      // ── ประวัติการเปิดดูรูป ──
      if (d.recentViews.isNotEmpty)
        DetailSection('เปิดดูรูปล่าสุด', children: [
          for (final v in d.recentViews.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(PhosphorIconsRegular.eye, size: 15, color: p.faint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      v.viewer ?? 'แอดมิน',
                      switch (v.kind) {
                        'card' => 'รูปบัตร',
                        'card_face' => 'หน้าบนบัตร',
                        'best_frame' => 'ใบหน้าจากกล้อง',
                        _ => v.kind ?? '',
                      },
                    ].where((e) => e.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TpType.body(12.5, p.text),
                  ),
                ),
                Text(TpFmt.ago(v.at), style: TpType.body(11.5, p.faint)),
              ]),
            ),
        ]),
    ]);
  }
}

/// แถบคะแนน AI เทียบเกณฑ์
class _ScoreBar extends StatelessWidget {
  const _ScoreBar(
      {required this.label,
      required this.value,
      required this.pass,
      this.review});
  final String label;
  final double value;
  final double pass;
  final double? review;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final tone = _scoreTone(value, pass, review);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style: TpType.body(13, p.text, w: FontWeight.w500))),
          Text('เกณฑ์ ${_pct(pass)}', style: TpType.body(11.5, p.faint)),
          const SizedBox(width: 8),
          Text(_pct(value), style: TpType.money(14, p.fg(tone))),
        ]),
        const SizedBox(height: 5),
        TpMeter(value: value.clamp(0, 1).toDouble(), color: p.fg(tone)),
      ]),
    );
  }
}
