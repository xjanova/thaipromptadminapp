import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../home/data/ops_repository.dart';
import '../data/unpaid_bills.dart';
import '../data/work_repository.dart';
import 'bill_widgets.dart';

/// หน้า "อนุมัติบิลด่วน" — ทุกบิลที่สร้างแล้วยังไม่จ่าย (รอตรวจ + รอโอน + เก่าเกิน 7 วัน)
/// เรียงใหม่สุดก่อน เลื่อนโหลดต่อจนหมด และเลื่อนอนุมัติได้ทันทีจากรายการ
class QuickBillsScreen extends ConsumerStatefulWidget {
  const QuickBillsScreen({super.key});

  @override
  ConsumerState<QuickBillsScreen> createState() => _QuickBillsScreenState();
}

class _QuickBillsScreenState extends ConsumerState<QuickBillsScreen> {
  UnpaidFilter _filter = UnpaidFilter.all;
  late final UnpaidBillsPager _pager;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(workRepositoryProvider);
    _pager = UnpaidBillsPager(
      buckets: _filter.buckets,
      fetch: (bucket, page) => repo.bills(bucket, page: page, perPage: 50),
      markPaid: (bill) => repo.markPaid(bill.id,
          amount: bill.amount, note: 'อนุมัติด่วนจากแอปแอดมิน'),
    )..addListener(_onPager);
    _pager.refresh();
  }

  @override
  void dispose() {
    _pager
      ..removeListener(_onPager)
      ..dispose();
    super.dispose();
  }

  void _onPager() {
    if (mounted) setState(() {});
  }

  /// ตัวเลขบนหน้าแรก/แท็บงาน — โหลดใหม่เงียบ ๆ (ค่าเดิมยังแสดงอยู่ระหว่างรอ)
  void _invalidateCounts() {
    ref.invalidate(billStatsProvider);
    ref.invalidate(opsSummaryProvider);
  }

  Future<void> _refresh() async {
    _invalidateCounts();
    final err = await _pager.refresh();
    if (!mounted) return;
    if (err != null && _pager.loadedOnce) {
      tpToast(context, 'รีเฟรชไม่สำเร็จ — ${tpErrorText(err)}',
          kind: TpToastKind.error);
    }
  }

  void _setFilter(UnpaidFilter f) {
    if (f == _filter) return;
    setState(() => _filter = f);
    _pager.setBuckets(f.buckets);
  }

  Future<bool> _approve(FortuneBill bill) async {
    final r = await _pager.approve(bill);
    if (!mounted) return r.removed;
    switch (r.outcome) {
      case ApproveOutcome.approved:
        _invalidateCounts();
        tpToast(context, r.message ?? 'อนุมัติแล้ว — ส่งคำทำนายให้ลูกค้า',
            kind: TpToastKind.success);
      case ApproveOutcome.alreadyPaid:
        _invalidateCounts();
        tpToast(context,
            'บิล ${bill.billNumber} ถูกอนุมัติไปแล้ว — เอาออกจากรายการ',
            kind: TpToastKind.info);
      case ApproveOutcome.ignored:
        break;
      case ApproveOutcome.failed:
        final uncertain = _isUncertain(r.error);
        tpToast(context, _approveErrorText(r.error), kind: TpToastKind.error);
        // ไม่รู้ว่าเซิร์ฟเวอร์ทำไปแล้วหรือยัง → ดึงรายการใหม่ ไม่ให้แอดมินกดซ้ำบนข้อมูลเก่า
        if (uncertain) {
          _invalidateCounts();
          _pager.refresh();
        }
    }
    return r.removed;
  }

  Future<void> _openSheet(FortuneBill bill) async {
    final changed = await showBillSheet(context, bill);
    if (!mounted || !changed) return;
    // แผ่นรายละเอียดอนุมัติ/ยกเลิกไปแล้ว — บิลไม่ค้างจ่ายอีก
    _pager.removeLocally(bill);
    _invalidateCounts();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(billStatsProvider).valueOrNull;
    final total = _pager.loadedOnce
        ? _pager.total
        : (stats == null ? null : _filter.count(stats));
    return TpPage(
      title: 'อนุมัติบิลด่วน',
      subtitle: total == null
          ? 'ทุกบิลที่ยังไม่จ่าย · ใหม่สุดก่อน'
          : (total == 0
              ? 'ไม่มีบิลค้างจ่าย'
              : 'ค้างจ่าย ${TpFmt.count(total)} บิล · ใหม่สุดก่อน'),
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom: TpChips<UnpaidFilter>(
        onHeader: true,
        padding: EdgeInsets.zero,
        value: _filter,
        onChanged: _setFilter,
        items: [
          for (final f in UnpaidFilter.values)
            TpChipItem(f, f.label,
                count: stats == null ? null : f.count(stats)),
        ],
      ),
      slivers: [_list()],
    );
  }

  Widget _list() {
    final p = _pager;
    if (!p.loadedOnce) {
      if (p.error != null) {
        return SliverToBoxAdapter(
            child: TpErrorView(error: p.error, onRetry: _refresh));
      }
      return const SliverToBoxAdapter(child: TpSkeletonList(count: 5));
    }
    final items = p.items;
    if (items.isEmpty && !p.hasMore && p.moreError == null) {
      return SliverToBoxAdapter(
        child: TpCard(
          padding: EdgeInsets.zero,
          child: TpEmpty(
            art: TpArt.emptyDone,
            title: _filter == UnpaidFilter.all
                ? 'ไม่มีบิลค้างจ่าย'
                : 'ไม่มีบิล${_filter.label}',
            message: _filter == UnpaidFilter.all
                ? 'ทุกบิลที่ออกไปชำระครบแล้ว — ดึงลงเพื่อเช็กอีกครั้ง'
                : 'ลองดูกลุ่มอื่น หรือดึงลงเพื่อรีเฟรช',
            actionLabel:
                _filter == UnpaidFilter.all ? null : 'ดูบิลค้างทั้งหมด',
            onAction: _filter == UnpaidFilter.all
                ? null
                : () => _setFilter(UnpaidFilter.all),
          ),
        ),
      );
    }
    final trailing = p.hasMore || p.moreError != null;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          if (i >= items.length) return _trailing();
          final bill = items[i];
          return Padding(
            key: ValueKey(bill.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _QuickBillCard(
              bill: bill,
              approving: p.isApproving(bill.id),
              onApprove: () => _approve(bill),
              onOpen: () => _openSheet(bill),
            ),
          );
        },
        childCount: items.length + (trailing ? 1 : 0),
        // คงสถานะการ์ด (ตัวเลื่อนยืนยัน) ตาม id เมื่อบิลด้านบนหายไป
        findChildIndexCallback: (key) {
          if (key is! ValueKey<int>) return null;
          final i = items.indexWhere((b) => b.id == key.value);
          return i < 0 ? null : i;
        },
      ),
    );
  }

  Widget _trailing() {
    if (_pager.moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Text(tpErrorText(_pager.moreError),
              textAlign: TextAlign.center,
              style: TpType.body(12.5, context.tp.muted)),
          const SizedBox(height: 4),
          TpButton.ghost('โหลดต่อไม่สำเร็จ · ลองใหม่',
              onPressed: _pager.loadMore),
        ]),
      );
    }
    // ถึงท้ายรายการ → โหลดหน้าถัดไปของทุกกองที่ยังเหลือ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pager.loadMore();
    });
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
          child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2))),
    );
  }
}

/// error ที่ไม่รู้ว่าเซิร์ฟเวอร์ทำรายการไปแล้วหรือยัง (คำขออาจไปถึงแล้ว)
bool _isUncertain(Object? e) {
  if (e is! DioException) return false;
  return switch (e.type) {
    DioExceptionType.sendTimeout || DioExceptionType.receiveTimeout => true,
    DioExceptionType.badResponse => (e.response?.statusCode ?? 0) >= 500,
    DioExceptionType.unknown => true,
    _ => false,
  };
}

String _approveErrorText(Object? e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'เชื่อมต่ออินเทอร์เน็ตไม่ได้ — บิลยังไม่ถูกอนุมัติ ลองใหม่เมื่อเน็ตกลับมา';
    }
    if (_isUncertain(e)) {
      return 'เซิร์ฟเวอร์ไม่ตอบ ไม่แน่ใจว่าอนุมัติสำเร็จหรือยัง — โหลดรายการใหม่ให้แล้ว ตรวจก่อนลองอีกครั้ง';
    }
  }
  return tpErrorText(e);
}

/// การ์ดบิลค้างจ่าย + หลักฐาน SMS + ตัวเลื่อนอนุมัติ
class _QuickBillCard extends StatelessWidget {
  const _QuickBillCard({
    required this.bill,
    required this.approving,
    required this.onApprove,
    required this.onOpen,
  });
  final FortuneBill bill;
  final bool approving;
  final Future<bool> Function() onApprove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final blocked = bill.markPaidBlockReason;
    final matched = bill.sms.matched;
    return TpCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      accent: blocked != null ? p.faint : (matched ? p.success : p.warning),
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TpAvatar(name: bill.customerName, platform: bill.platform),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bill.customerName ?? 'ลูกค้า',
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(bill.billNumber,
                  style: TpType.money(12, p.muted, w: FontWeight.w500)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
                bill.amount > 0
                    ? TpFmt.baht(bill.amount, decimals: true)
                    : 'ยอดตามแพคเกจ',
                style: TpType.money(bill.amount > 0 ? 18 : 13, p.goldText)),
            Text(
                bill.createdAt == null
                    ? 'ไม่ทราบเวลา'
                    : 'ออกบิล ${TpFmt.ago(bill.createdAt)}',
                style: TpType.body(11.5, p.faint)),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TpPill(bill.packageLabel, tone: TpTone.gold, dense: true),
          _statusPill(),
          if (bill.slipUrl != null)
            const TpPill('มีสลิป',
                tone: TpTone.info, icon: PhosphorIconsBold.image, dense: true),
          if (bill.priorPaid > 0)
            TpPill('ลูกค้าเก่า ${bill.priorPaid} ครั้ง',
                tone: TpTone.navy, dense: true),
        ]),
        const SizedBox(height: 10),
        _SmsLine(bill: bill),
        const SizedBox(height: 12),
        if (blocked != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
                color: p.soft(TpTone.warning),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(PhosphorIconsBold.lock, size: 16, color: p.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text('อนุมัติไม่ได้ · $blocked',
                    style: TpType.body(12.5, p.warning, w: FontWeight.w500)),
              ),
            ]),
          )
        else
          TpSlideToConfirm(
            label: bill.amount > 0
                ? 'เลื่อนอนุมัติ ${TpFmt.baht(bill.amount, decimals: true)}'
                : 'เลื่อนเพื่ออนุมัติบิลนี้',
            enabled: !approving,
            onConfirmed: onApprove,
          ),
      ]),
    );
  }

  Widget _statusPill() {
    if (bill.isFloating) {
      return const TpPill('บิลลอย',
          tone: TpTone.warning, icon: PhosphorIconsBold.question, dense: true);
    }
    return switch (bill.status) {
      'awaiting' => TpPill(
          bill.statusReason == 'transfer_reported'
              ? 'แจ้งโอนแล้ว'
              : 'ส่งสลิปแล้ว',
          tone: TpTone.warning,
          icon: PhosphorIconsBold.clock,
          dense: true),
      'unpaid' => const TpPill('รอลูกค้าโอน',
          tone: TpTone.info,
          icon: PhosphorIconsBold.hourglassMedium,
          dense: true),
      'closed' => const TpPill('เก่าเกิน 7 วัน',
          tone: TpTone.neutral, icon: PhosphorIconsBold.archive, dense: true),
      _ => TpPill(bill.statusLabel ?? 'ยังไม่จ่าย',
          tone: TpTone.neutral, dense: true),
    };
  }
}

/// หลักฐานเงินเข้าแบบย่อ — SMS ที่จับคู่กับบิลนี้ (ถ้ามี)
class _SmsLine extends StatelessWidget {
  const _SmsLine({required this.bill});
  final FortuneBill bill;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final s = bill.sms;
    if (!s.matched) {
      return Row(children: [
        Icon(PhosphorIconsRegular.chatCenteredSlash, size: 15, color: p.faint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
              'ยังไม่พบ SMS เงินเข้า — ตรวจยอดในแอปธนาคารหรือดูสลิปก่อนอนุมัติ',
              style: TpType.body(12, p.muted)),
        ),
      ]);
    }
    final amountOk = s.amount == null || (s.amount! - bill.amount).abs() < 0.01;
    final color = amountOk ? p.success : p.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
          color: p.soft(amountOk ? TpTone.success : TpTone.warning),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(
            amountOk
                ? PhosphorIconsBold.checkCircle
                : PhosphorIconsBold.warning,
            size: 16,
            color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            [
              'SMS ${s.bank ?? 'ธนาคาร'}',
              'รับโอน ${TpFmt.baht(s.amount ?? bill.amount, decimals: true)}',
              if (s.at != null) TpFmt.dateTime(s.at!),
              if (!amountOk) 'ยอดไม่ตรงบิล',
            ].join(' · '),
            style: TpType.body(12.5, color, w: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
