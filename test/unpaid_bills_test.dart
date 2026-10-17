import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thaipromptadmin/core/api/api_envelope.dart';
import 'package:thaipromptadmin/core/api/paged.dart';
import 'package:thaipromptadmin/features/work/data/unpaid_bills.dart';
import 'package:thaipromptadmin/features/work/data/work_repository.dart';
import 'package:thaipromptadmin/shared/ui/tp_feedback.dart';

FortuneBill _bill(int id, String status,
        {int minutesAgo = 0, Map<String, dynamic>? extra}) =>
    FortuneBill.fromJson({
      'id': id,
      'status': status,
      'amount_thb': 39,
      'created_at': DateTime.utc(2026, 10, 17, 12)
          .subtract(Duration(minutes: minutesAgo))
          .toIso8601String(),
      'actions': {'can_mark_paid': true},
      ...?extra,
    });

/// เซิร์ฟเวอร์จำลอง: แบ่งหน้าแบบ offset เหมือน Laravel paginate และบิลที่อนุมัติแล้วหายจากกอง
class _FakeServer {
  _FakeServer(this.perPage, this.data);
  final int perPage;
  final Map<BillBucket, List<FortuneBill>> data;
  final calls = <String>[];
  int markPaidCalls = 0;
  Object? failMarkPaid;
  Object? failFetch;
  Completer<void>? gate;

  Future<Paged<FortuneBill>> fetch(BillBucket b, int page) async {
    calls.add('${b.key}:$page');
    if (failFetch != null) throw failFetch!;
    final all = data[b] ?? const [];
    final last = all.isEmpty ? 1 : (all.length / perPage).ceil();
    final start = (page - 1) * perPage;
    final items = start >= all.length
        ? <FortuneBill>[]
        : all.sublist(start, (start + perPage).clamp(0, all.length));
    return Paged(
        items: items,
        page: page,
        lastPage: last,
        total: all.length,
        perPage: perPage);
  }

  Future<String?> markPaid(FortuneBill bill) async {
    markPaidCalls++;
    if (gate != null) await gate!.future;
    if (failMarkPaid != null) throw failMarkPaid!;
    for (final list in data.values) {
      list.removeWhere((b) => b.id == bill.id);
    }
    return 'มาร์คจ่ายเรียบร้อย';
  }

  UnpaidBillsPager pager([List<BillBucket> buckets = kUnpaidBuckets]) =>
      UnpaidBillsPager(fetch: fetch, markPaid: markPaid, buckets: buckets);
}

Future<void> _loadAll(UnpaidBillsPager p) async {
  var guard = 0;
  while (p.hasMore && guard++ < 100) {
    await p.loadMore();
  }
}

void main() {
  group('กองบิลที่ยังไม่จ่าย', () {
    test(
        'นับ awaiting + unpaid + closed เท่านั้น (ไม่นับ paid/refunded/cancelled)',
        () {
      expect(kUnpaidBuckets,
          [BillBucket.awaiting, BillBucket.unpaid, BillBucket.closed]);
      final s = BillStats.fromJson({
        'counts': {
          'awaiting': 3,
          'unpaid': 5,
          'closed': 12,
          'paid': 100,
          'refunded': 2,
          'cancelled': 9,
          'all': 131,
        }
      });
      expect(unpaidTotal(s), 20);
      expect(UnpaidFilter.awaiting.count(s), 3);
      expect(UnpaidFilter.unpaid.count(s), 5);
      expect(UnpaidFilter.stale.count(s), 12);
    });

    test('stats ไม่มีบางกอง → นับเป็น 0 ไม่ล้ม', () {
      expect(unpaidTotal(BillStats.fromJson({'awaiting': '4'})), 4);
      expect(unpaidTotal(BillStats.fromJson(const {})), 0);
    });

    test(
        'mergeNewestFirst: ตัดซ้ำตาม id (ข้อมูลใหม่ชนะ) + ใหม่สุดก่อน + ไม่มีเวลาไว้ท้าย',
        () {
      final old = _bill(1, 'unpaid', minutesAgo: 30);
      final updated = _bill(1, 'awaiting', minutesAgo: 30);
      final newer = _bill(2, 'unpaid', minutesAgo: 5);
      final noTime = FortuneBill.fromJson({'id': 3, 'status': 'closed'});
      final merged = mergeNewestFirst([old, noTime], [newer, updated]);
      expect(merged.map((b) => b.id), [2, 1, 3]);
      expect(merged[1].status, 'awaiting');
    });
  });

  group('FortuneBill — สิทธิ์อนุมัติ', () {
    test('อนุมัติได้ → ไม่มีเหตุผลห้าม', () {
      expect(_bill(1, 'unpaid').markPaidBlockReason, isNull);
    });

    test('บิลลอย / จันทรา / จ่ายบิลอื่นแทน → มีเหตุผลภาษาไทย', () {
      final floating = _bill(1, 'awaiting', extra: {
        'status_reason': 'floating',
        'actions': {'can_mark_paid': false},
      });
      expect(floating.markPaidBlockReason, contains('บิลลอย'));

      final juntra = _bill(2, 'unpaid', extra: {
        'is_juntra': true,
        'actions': {'can_mark_paid': false},
      });
      expect(juntra.isJuntra, isTrue);
      expect(juntra.markPaidBlockReason, contains('จันทรา'));

      final superseded = _bill(3, 'cancelled', extra: {
        'status_reason': 'superseded_by_paid',
        'actions': {'can_mark_paid': false},
      });
      expect(superseded.markPaidBlockReason, contains('จ่ายบิลอื่นแทน'));
    });
  });

  group('UnpaidBillsPager', () {
    _FakeServer server() => _FakeServer(3, {
          BillBucket.awaiting: [
            for (var i = 0; i < 4; i++)
              _bill(100 + i, 'awaiting', minutesAgo: i * 7)
          ],
          BillBucket.unpaid: [
            for (var i = 0; i < 7; i++)
              _bill(200 + i, 'unpaid', minutesAgo: i * 5 + 1)
          ],
          BillBucket.closed: [
            for (var i = 0; i < 5; i++)
              _bill(300 + i, 'closed', minutesAgo: 20000 + i)
          ],
        });

    test('โหลดทุกกองทีละหน้าจนครบ ไม่ตัดที่หน้าแรก + เรียงใหม่สุดก่อน',
        () async {
      final s = server();
      final p = s.pager();
      await p.refresh();
      expect(p.items.length, 9); // หน้าแรกของ 3 กอง กองละ 3
      expect(p.hasMore, isTrue);
      expect(p.total, 16);
      await _loadAll(p);
      expect(p.hasMore, isFalse);
      expect(p.items.length, 16);
      expect(p.items.map((b) => b.id).toSet().length, 16);
      for (var i = 1; i < p.items.length; i++) {
        expect(
            p.items[i - 1].createdAt!.isBefore(p.items[i].createdAt!), isFalse,
            reason: 'ต้องเรียงใหม่สุดก่อน');
      }
      p.dispose();
    });

    test('อนุมัติเกินหนึ่งหน้าก่อนเลื่อนต่อ → บิลที่เหลือไม่หลุดสักใบ',
        () async {
      final s = _FakeServer(3, {
        BillBucket.unpaid: [
          for (var i = 0; i < 10; i++) _bill(i + 1, 'unpaid', minutesAgo: i)
        ],
      });
      final p = s.pager([BillBucket.unpaid]);
      await p.refresh();
      expect(p.items.map((b) => b.id), [1, 2, 3]);
      for (final b in List.of(p.items)) {
        expect((await p.approve(b)).outcome, ApproveOutcome.approved);
      }
      expect(p.items, isEmpty);
      expect(p.hasMore, isTrue);
      await p.loadMore(); // 3 ใบหายไป → ต้องโหลดหน้า 1 ใหม่ ไม่ใช่หน้า 2
      expect(s.calls.last, 'unpaid:1');
      await _loadAll(p);
      expect(p.items.map((b) => b.id).toList(), [4, 5, 6, 7, 8, 9, 10]);
      expect(p.total, 7);
      p.dispose();
    });

    test('กดอนุมัติซ้ำเร็ว ๆ → ยิง mark-paid ครั้งเดียว', () async {
      final s = server();
      final p = s.pager();
      await p.refresh();
      final bill = p.items.first;
      s.gate = Completer<void>();
      final first = p.approve(bill);
      final second = await p.approve(bill);
      expect(second.outcome, ApproveOutcome.ignored);
      expect(p.isApproving(bill.id), isTrue);
      s.gate!.complete();
      expect((await first).outcome, ApproveOutcome.approved);
      final third = await p.approve(bill);
      expect(third.outcome, ApproveOutcome.ignored);
      expect(s.markPaidCalls, 1);
      expect(p.items.any((b) => b.id == bill.id), isFalse);
      p.dispose();
    });

    test('เซิร์ฟเวอร์บอกว่าจ่ายแล้ว → เอาออกจากรายการเหมือนอนุมัติสำเร็จ',
        () async {
      final s = server();
      final p = s.pager();
      await p.refresh();
      final bill = p.items.first;
      s.failMarkPaid = ActionError('บิลนี้ถูกมาร์คจ่ายแล้ว');
      final r = await p.approve(bill);
      expect(r.outcome, ApproveOutcome.alreadyPaid);
      expect(r.removed, isTrue);
      expect(p.items.any((b) => b.id == bill.id), isFalse);
      p.dispose();
    });

    test('อนุมัติล้มเหลว → บิลยังอยู่ กดใหม่ได้', () async {
      final s = server();
      final p = s.pager();
      await p.refresh();
      final bill = p.items.first;
      s.failMarkPaid = DioException.connectionError(
          requestOptions: RequestOptions(path: '/x'), reason: 'offline');
      final r = await p.approve(bill);
      expect(r.outcome, ApproveOutcome.failed);
      expect(p.items.any((b) => b.id == bill.id), isTrue);
      expect(p.isApproving(bill.id), isFalse);
      s.failMarkPaid = null;
      expect((await p.approve(bill)).outcome, ApproveOutcome.approved);
      p.dispose();
    });

    test('บิลที่ backend ห้ามอนุมัติ → ไม่ยิง API', () async {
      final s = server();
      final p = s.pager();
      final r = await p.approve(_bill(999, 'awaiting', extra: {
        'status_reason': 'floating',
        'actions': {'can_mark_paid': false},
      }));
      expect(r.outcome, ApproveOutcome.failed);
      expect(s.markPaidCalls, 0);
      p.dispose();
    });

    test('โหลดครั้งแรกล้ม → มี error · รีเฟรชล้มทีหลัง → คงรายการเดิม',
        () async {
      final s = server();
      final p = s.pager();
      s.failFetch = DioException.connectionError(
          requestOptions: RequestOptions(path: '/x'), reason: 'offline');
      await p.refresh();
      expect(p.loadedOnce, isFalse);
      expect(p.error, isNotNull);

      s.failFetch = null;
      await p.refresh();
      expect(p.error, isNull);
      final before = p.items.length;

      s.failFetch = Exception('boom');
      final err = await p.refresh();
      expect(err, isNotNull);
      expect(p.error, isNull, reason: 'มีรายการแล้ว ไม่ต้องโชว์หน้า error');
      expect(p.items.length, before);
      p.dispose();
    });

    test('ไม่มีบิลค้าง → รายการว่าง ไม่มีหน้าถัดไป', () async {
      final p = _FakeServer(3, {}).pager();
      await p.refresh();
      expect(p.loadedOnce, isTrue);
      expect(p.items, isEmpty);
      expect(p.hasMore, isFalse);
      expect(p.total, 0);
      p.dispose();
    });
  });

  group('tpErrorText', () {
    test('500 ข้อความอังกฤษจากเฟรมเวิร์ก → ข้อความไทย', () {
      final opts = RequestOptions(path: '/x');
      final e = DioException.badResponse(
        statusCode: 500,
        requestOptions: opts,
        response: Response(
            requestOptions: opts,
            statusCode: 500,
            data: {'message': 'Server Error'}),
      );
      expect(tpErrorText(e), 'เซิร์ฟเวอร์ขัดข้องชั่วคราว (500)');
    });

    test('409 ข้อความไทยจาก backend → ใช้ตามนั้น', () {
      final opts = RequestOptions(path: '/x');
      final e = DioException.badResponse(
        statusCode: 409,
        requestOptions: opts,
        response: Response(
            requestOptions: opts,
            statusCode: 409,
            data: {'message': 'บิลนี้กำลังถูกมาร์คจ่ายจากอีกเครื่อง'}),
      );
      expect(tpErrorText(e), 'บิลนี้กำลังถูกมาร์คจ่ายจากอีกเครื่อง');
    });

    test('เน็ตหลุด → ข้อความไทย', () {
      final e = DioException.connectionError(
          requestOptions: RequestOptions(path: '/x'), reason: 'offline');
      expect(tpErrorText(e), 'เชื่อมต่ออินเทอร์เน็ตไม่ได้');
    });
  });
}
