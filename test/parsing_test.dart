import 'package:flutter_test/flutter_test.dart';
import 'package:thaipromptadmin/core/api/paged.dart';
import 'package:thaipromptadmin/features/home/data/ops_repository.dart';
import 'package:thaipromptadmin/features/work/data/work_repository.dart';
import 'package:thaipromptadmin/shared/ui/tp_format.dart';

void main() {
  group('Paged.parse', () {
    test('แบบแบน {data:[...], current_page, last_page, total}', () {
      final p = Paged.parse<int>(
        {'data': [{'id': 1}, {'id': 2}], 'current_page': 2, 'last_page': 5, 'total': 90},
        (m) => m['id'] as int,
      );
      expect(p.items, [1, 2]);
      expect(p.page, 2);
      expect(p.lastPage, 5);
      expect(p.total, 90);
      expect(p.hasMore, isTrue);
    });

    test('แบบ Laravel resource {data:[...], meta:{...}}', () {
      final p = Paged.parse<int>(
        {'data': [{'id': 7}], 'links': {}, 'meta': {'current_page': 3, 'last_page': 3, 'total': 41}},
        (m) => m['id'] as int,
      );
      expect(p.items, [7]);
      expect(p.page, 3);
      expect(p.hasMore, isFalse);
      expect(p.total, 41);
    });

    test('รายการเปล่า ๆ (ไม่แบ่งหน้า)', () {
      final p = Paged.parse<int>([{'id': 1}, {'id': 2}, {'id': 3}], (m) => m['id'] as int);
      expect(p.items.length, 3);
      expect(p.total, 3);
      expect(p.hasMore, isFalse);
    });
  });

  group('OpsSummary.fromJson (ตามสัญญา ADMIN_APP_API.md)', () {
    final json = {
      'queue': {
        'customer_requests': {
          'count': 2,
          'oldest_minutes': 14,
          'preview': [
            {'reading_id': 1, 'customer_name': 'สมหญิง', 'keyword': 'ขอคุยกับแอดมิน'},
            {'reading_id': 2, 'customer_name': 'สมชาย'},
          ],
        },
        'bills_awaiting': {'count': 3, 'amount_thb': 237.84, 'oldest_minutes': 22, 'preview': []},
        'withdrawals_pending': {'count': 1, 'amount_thb': 500.0},
        'sms_unmatched': {'count': 4, 'amount_thb': 156.0},
        'stuck_readings': {'count': 1, 'preview': [{'customer_name': 'นายบี', 'stage': {'label': 'AI กำลังทำนาย'}}]},
      },
      'health': {
        'ai_pool': {'healthy': 5, 'total': 7},
        'line_push': {'used_this_month': 120, 'limit': 300, 'exhausted': false},
        'queue_backlog': {'driver': 'database', 'pending': 4, 'failed_24h': 1},
      },
      'revenue_today': {
        'total': 1234.0,
        'fortune': 1000.0,
        'marketplace': 234.0,
        'other': 0.0,
        'hourly': [for (var h = 0; h < 24; h++) {'hour': h, 'amount': h == 9 ? 100.0 : 0.0}],
      },
      'revenue_yesterday_same_time': 900.0,
    };

    test('คิวงาน + พรีวิวเป็นข้อความบรรทัดเดียว', () {
      final s = OpsSummary.fromJson(json);
      expect(s.customerRequests.count, 2);
      expect(s.customerRequests.preview, 'สมหญิง · “ขอคุยกับแอดมิน” และอีก 1');
      expect(s.stuckReadings.preview, 'นายบี · “AI กำลังทำนาย”');
      expect(s.billsAwaiting.amount, closeTo(237.84, 0.001));
      expect(s.totalTasks, 2 + 3 + 1 + 4 + 1);
      expect(s.workBadge, 3 + 1 + 4 + 1); // แชทไม่นับในแท็บงาน
    });

    test('สุขภาพระบบ + รายได้', () {
      final s = OpsSummary.fromJson(json);
      expect(s.aiHealthy, 5);
      expect(s.linePushUsed, 120);
      expect(s.queueBacklog, 4);
      expect(s.queueFailed24h, 1);
      expect(s.hourly[9], 100.0);
      expect(s.growthPct, closeTo((1234 - 900) / 900 * 100, 0.01));
    });

    test('ส่วนที่ backend อ่านไม่สำเร็จ (null + degraded) ต้องเป็น "ไม่ทราบ" ไม่ใช่ 0 งาน', () {
      final q = Map<String, dynamic>.from(json['queue'] as Map)..['bills_awaiting'] = null;
      final s = OpsSummary.fromJson({...json, 'queue': q, 'degraded': ['bills_awaiting']});
      expect(s.billsAwaiting.unavailable, isTrue);
      expect(s.anyUnavailable, isTrue);
      expect(s.degraded, ['bills_awaiting']);
    });

    test('line_push = null (ยังไม่เคยดึงโควตาได้) ไม่ล้ม', () {
      final s = OpsSummary.fromJson({
        ...json,
        'health': {'ai_pool': {'healthy': 0, 'total': 0}, 'line_push': null, 'queue_backlog': null},
      });
      expect(s.linePushUsed, isNull);
      expect(s.queueBacklog, 0);
    });
  });

  group('FortuneBill', () {
    test('backend ห้ามอนุมัติ (บิลลอย / จ่ายบิลอื่นแทนแล้ว) → แอปต้องไม่ให้ยืนยันยอด', () {
      final b = FortuneBill.fromJson({
        'id': 1,
        'status': 'awaiting',
        'status_reason': 'floating',
        'amount_thb': '39.42',
        'actions': {'can_mark_paid': false, 'can_refund': false, 'can_cancel': true},
      });
      expect(b.mayMarkPaid, isFalse);
      expect(b.mayCancel, isTrue);
      expect(b.isFloating, isTrue);
      expect(b.amount, closeTo(39.42, 0.001));
    });

    test('ไม่มี actions → เดาจากสถานะ', () {
      final paid = FortuneBill.fromJson({'id': 2, 'status': 'paid', 'paid_at': '2026-10-06T10:00:00+07:00'});
      expect(paid.isPaid, isTrue);
      expect(paid.mayMarkPaid, isFalse);
      expect(paid.mayRefund, isTrue);
      final cancelled = FortuneBill.fromJson({'id': 3, 'status': 'cancelled'});
      expect(cancelled.mayMarkPaid, isFalse);
      expect(cancelled.mayCancel, isFalse);
    });
  });

  group('TpFmt', () {
    test('เงินบาท', () {
      expect(TpFmt.baht(48920), '฿48,920');
      expect(TpFmt.baht(39.42), '฿39.42');
      expect(TpFmt.baht(99, decimals: true), '฿99.00');
      expect(TpFmt.bahtCompact(31240), '฿31.2K');
    });

    test('อักษรต้นของชื่อไทย ข้ามคำนำหน้าและสระหน้า', () {
      expect(TpFmt.initial('คุณน้ำฝน'), 'น');
      expect(TpFmt.initial('เกศินี'), 'ก');
      expect(TpFmt.initial(''), '?');
    });

    test('อ่านตัวเลขจาก JSON ที่เป็นสตริง', () {
      expect(TpFmt.toDouble('99.17'), closeTo(99.17, 0.001));
      expect(TpFmt.toInt('12'), 12);
      expect(TpFmt.toInt(null), 0);
    });
  });
}
