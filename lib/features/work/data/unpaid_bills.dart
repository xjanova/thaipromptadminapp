import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import 'work_repository.dart';

/// กองที่นับว่า "สร้างบิลแล้วยังไม่จ่าย" (ตาม backend FortuneBillBuckets — บิลหนึ่งใบอยู่ได้กองเดียว)
///
/// - awaiting  ลูกค้าส่งสลิป/แจ้งโอนแล้ว หรือบิลลอย — รอแอดมินตรวจ
/// - unpaid    บิลเปิดอยู่ (pending_payment / celtic_pending_payment /
///             awaiting_payment_method / pending_stripe_payment) อายุไม่เกิน 7 วัน
/// - closed    ยังไม่จ่ายแต่หลุดจากสองกองบน (เก่าเกิน 7 วัน / ปิดเงียบ)
///
/// ไม่นับ paid · refunded (เคยจ่ายแล้วถูกพลิก) · cancelled (ตัดสินใจยกเลิกแล้ว)
const kUnpaidBuckets = [
  BillBucket.awaiting,
  BillBucket.unpaid,
  BillBucket.closed
];

/// ตัวกรองในหน้า "อนุมัติบิลด่วน"
enum UnpaidFilter {
  all('ทั้งหมด', kUnpaidBuckets),
  awaiting('รอตรวจ', [BillBucket.awaiting]),
  unpaid('รอโอน', [BillBucket.unpaid]),
  stale('เก่าเกิน 7 วัน', [BillBucket.closed]);

  const UnpaidFilter(this.label, this.buckets);
  final String label;
  final List<BillBucket> buckets;

  int count(BillStats s) => buckets.fold(0, (sum, b) => sum + s.count(b));
}

/// จำนวนบิลที่ยังไม่จ่ายทั้งหมด (ทุกกองใน [kUnpaidBuckets])
int unpaidTotal(BillStats s) => UnpaidFilter.all.count(s);

/// รวมรายการ: ตัดซ้ำตาม id (ตัวที่มาทีหลังชนะ — ข้อมูลใหม่กว่า) แล้วเรียงบิลใหม่สุดก่อน
List<FortuneBill> mergeNewestFirst(
    Iterable<FortuneBill> current, Iterable<FortuneBill> incoming) {
  final byId = <int, FortuneBill>{};
  for (final b in current) {
    byId[b.id] = b;
  }
  for (final b in incoming) {
    byId[b.id] = b;
  }
  final list = byId.values.toList()
    ..sort((a, b) {
      final ta = a.createdAt, tb = b.createdAt;
      if (ta != null && tb != null) {
        final c = tb.compareTo(ta);
        if (c != 0) return c;
      } else if (ta != null) {
        return -1;
      } else if (tb != null) {
        return 1;
      }
      return b.id.compareTo(a.id);
    });
  return list;
}

/// backend ตอบว่าบิลนี้ถูกมาร์คจ่ายไปแล้ว (อีกเครื่อง/กดซ้ำ) — ถือว่างานเสร็จ
bool isAlreadyPaidError(Object e) =>
    e is ActionError && e.message.contains('ถูกมาร์คจ่ายแล้ว');

enum ApproveOutcome {
  /// อนุมัติสำเร็จ
  approved,

  /// เซิร์ฟเวอร์บอกว่าจ่ายแล้ว (มีคนอนุมัติก่อน) — เอาออกจากรายการเหมือนกัน
  alreadyPaid,

  /// กำลังอนุมัติบิลนี้อยู่ — คำขอซ้ำถูกเมิน ไม่ยิง API
  ignored,

  /// ไม่สำเร็จ — ดู [ApproveResult.error]
  failed,
}

class ApproveResult {
  const ApproveResult(this.outcome, {this.message, this.error});
  final ApproveOutcome outcome;
  final String? message;
  final Object? error;
  bool get removed =>
      outcome == ApproveOutcome.approved ||
      outcome == ApproveOutcome.alreadyPaid;
}

typedef BillPageFetcher = Future<Paged<FortuneBill>> Function(
    BillBucket bucket, int page);
typedef BillMarkPaid = Future<String?> Function(FortuneBill bill);

class _Cursor {
  int page = 0;
  int lastPage = 1;
  int perPage = 0;
  int total = 0;

  /// จำนวนบิลกองนี้ที่หายจากเซิร์ฟเวอร์หลังโหลด (อนุมัติไป) — แถวที่เหลือบนเซิร์ฟเวอร์เลื่อนขึ้นเท่านี้
  int removed = 0;

  bool get hasMore => page < lastPage;

  /// หน้าที่ต้องโหลดต่อ: หน้าที่มีแถวลำดับ (ที่โหลดแล้ว − ที่หายไป) — ไม่ข้ามบิลที่เลื่อนขึ้นมา
  int get nextPage {
    if (removed <= 0 || perPage <= 0) return page + 1;
    final consumed = math.max(0, page * perPage - removed);
    return consumed ~/ perPage + 1;
  }

  /// รับผลหน้าใหม่ — [removedBefore] = จำนวนที่หายไปก่อนยิงคำขอนี้ (คำขอคิดรวมไว้แล้ว)
  /// ที่หายไประหว่างรอคำตอบยังต้องนับต่อ (ตัดซ้ำได้ แต่ห้ามข้าม)
  void apply(Paged<FortuneBill> p, {int removedBefore = 0}) {
    page = p.page;
    lastPage = p.lastPage;
    total = p.total;
    if (p.perPage > 0) perPage = p.perPage;
    removed = math.max(0, removed - removedBefore);
  }
}

/// รายการบิลค้างจ่ายรวมหลายกอง — โหลดทีละหน้าต่อกองจนหมด, รวมแล้วเรียงใหม่สุดก่อน
///
/// - รีเฟรช = คงรายการเดิมไว้จนข้อมูลใหม่มา (ไม่กระพริบ)
/// - อนุมัติ = เอาออกจากรายการทันที + กันยิงซ้ำบิลเดียวกัน
/// - หลังอนุมัติ หน้าถัดไปบนเซิร์ฟเวอร์จะเลื่อนขึ้น → โหลดหน้าเดิมซ้ำแล้วตัดซ้ำ ไม่ให้บิลหลุด
class UnpaidBillsPager extends ChangeNotifier {
  UnpaidBillsPager({
    required this.fetch,
    required this.markPaid,
    List<BillBucket> buckets = kUnpaidBuckets,
  }) : _buckets = List.of(buckets);

  final BillPageFetcher fetch;
  final BillMarkPaid markPaid;

  List<BillBucket> _buckets;
  final Map<BillBucket, _Cursor> _cursors = {};
  List<FortuneBill> _items = const [];
  final Set<int> _inFlight = {};
  final Set<int> _approved = {};

  /// ตัวนับบิลที่หายไปต่อกอง (ทั้งชีวิตหน้า) — ใช้ชดเชยตำแหน่งที่เลื่อนระหว่างรอรีเฟรช
  final Map<String, int> _removedCount = {};
  int _generation = 0;
  bool _loadingFirst = false;
  bool _loadingMore = false;
  bool _loadedOnce = false;
  Object? _error;
  Object? _moreError;
  bool _disposed = false;

  List<FortuneBill> get items => _items;
  List<BillBucket> get buckets => List.unmodifiable(_buckets);
  bool get loadedOnce => _loadedOnce;
  bool get loadingFirst => _loadingFirst;
  bool get loadingMore => _loadingMore;

  /// error ตอนโหลดครั้งแรก (ยังไม่มีรายการให้โชว์)
  Object? get error => _error;

  /// error ตอนโหลดหน้าถัดไป (รายการเดิมยังอยู่)
  Object? get moreError => _moreError;
  bool get hasMore => _cursors.values.any((c) => c.hasMore);
  bool isApproving(int id) => _inFlight.contains(id);

  /// จำนวนบิลทั้งหมดในกองที่เลือก (ตามเซิร์ฟเวอร์ หักที่อนุมัติไปแล้ว)
  int get total =>
      math.max(_items.length, _cursors.values.fold(0, (s, c) => s + c.total));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// เปลี่ยนกองที่แสดง → ล้างแล้วโหลดใหม่
  Future<void> setBuckets(List<BillBucket> buckets) {
    _buckets = List.of(buckets);
    _items = const [];
    _cursors.clear();
    _loadedOnce = false;
    return refresh();
  }

  /// โหลดหน้าแรกของทุกกองใหม่ — คืน error (ถ้ามี) ให้หน้าจอแจ้ง แต่คงรายการเดิมไว้
  Future<Object?> refresh() async {
    final gen = ++_generation;
    _loadingFirst = true;
    _loadingMore = false;
    _error = null;
    _moreError = null;
    _notify();
    final buckets = List.of(_buckets);
    final removedSnap = [for (final b in buckets) _removedCount[b.key] ?? 0];
    try {
      final pages = await Future.wait([for (final b in buckets) fetch(b, 1)]);
      if (_disposed || gen != _generation) return null;
      _cursors.clear();
      final fresh = <FortuneBill>[];
      for (var i = 0; i < buckets.length; i++) {
        final p = pages[i];
        _cursors[buckets[i]] = _Cursor()
          ..apply(p)
          ..removed = (_removedCount[buckets[i].key] ?? 0) - removedSnap[i];
        fresh.addAll(p.items);
      }
      _items = mergeNewestFirst(const [], _visible(fresh));
      _loadedOnce = true;
      _loadingFirst = false;
      _notify();
      return null;
    } catch (e) {
      if (_disposed || gen != _generation) return null;
      _loadingFirst = false;
      if (!_loadedOnce) _error = e;
      _notify();
      return e;
    }
  }

  /// โหลดหน้าถัดไปของทุกกองที่ยังเหลือ
  Future<void> loadMore() async {
    if (_loadingFirst || _loadingMore || !hasMore) return;
    final gen = _generation;
    _loadingMore = true;
    _moreError = null;
    _notify();
    try {
      final pending = [
        for (final e in _cursors.entries)
          if (e.value.hasMore) e.key
      ];
      final removedBefore = [for (final b in pending) _cursors[b]!.removed];
      final pages = await Future.wait(
          [for (final b in pending) fetch(b, _cursors[b]!.nextPage)]);
      if (_disposed || gen != _generation) return;
      final incoming = <FortuneBill>[];
      for (var i = 0; i < pending.length; i++) {
        final p = pages[i];
        _cursors[pending[i]]!.apply(p, removedBefore: removedBefore[i]);
        incoming.addAll(p.items);
      }
      _items = mergeNewestFirst(_items, _visible(incoming));
      _loadingMore = false;
      _notify();
    } catch (e) {
      if (_disposed || gen != _generation) return;
      _loadingMore = false;
      _moreError = e;
      _notify();
    }
  }

  /// อนุมัติบิล (มาร์คจ่าย) — บิลเดียวกันยิงได้ครั้งเดียวจนกว่าจะได้ผล
  Future<ApproveResult> approve(FortuneBill bill) async {
    if (_inFlight.contains(bill.id) || _approved.contains(bill.id)) {
      return const ApproveResult(ApproveOutcome.ignored);
    }
    if (!bill.mayMarkPaid) {
      return ApproveResult(ApproveOutcome.failed,
          error:
              ActionError(bill.markPaidBlockReason ?? 'อนุมัติบิลนี้ไม่ได้'));
    }
    _inFlight.add(bill.id);
    _notify();
    try {
      final msg = await markPaid(bill);
      _remove(bill);
      return ApproveResult(ApproveOutcome.approved, message: msg);
    } catch (e) {
      if (isAlreadyPaidError(e)) {
        _remove(bill);
        return ApproveResult(ApproveOutcome.alreadyPaid,
            message: (e as ActionError).message);
      }
      return ApproveResult(ApproveOutcome.failed, error: e);
    } finally {
      _inFlight.remove(bill.id);
      _notify();
    }
  }

  /// เอาบิลออกจากรายการ (เช่น ยกเลิก/อนุมัติจากแผ่นรายละเอียด)
  void removeLocally(FortuneBill bill) {
    _remove(bill);
    _notify();
  }

  void _remove(FortuneBill bill) {
    _approved.add(bill.id);
    final before = _items.length;
    _items = [
      for (final b in _items)
        if (b.id != bill.id) b
    ];
    if (_items.length == before) return;
    _removedCount[bill.status] = (_removedCount[bill.status] ?? 0) + 1;
    final c = _cursorOf(bill);
    if (c != null) {
      c.removed++;
      if (c.total > 0) c.total--;
    }
  }

  _Cursor? _cursorOf(FortuneBill bill) {
    for (final e in _cursors.entries) {
      if (e.key.key == bill.status) return e.value;
    }
    return _cursors.length == 1 ? _cursors.values.first : null;
  }

  /// ตัดบิลที่อนุมัติไปแล้วในหน้านี้ (คำตอบจากเซิร์ฟเวอร์ที่ยิงไปก่อนอนุมัติอาจยังมีอยู่)
  Iterable<FortuneBill> _visible(Iterable<FortuneBill> list) =>
      list.where((b) => !_approved.contains(b.id));

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
