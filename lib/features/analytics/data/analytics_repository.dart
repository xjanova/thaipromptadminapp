import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../shared/ui/tp_format.dart';

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

/// ช่วงเวลาที่ `GET /analytics/overview?period=` รองรับ
///
/// ⚠️ backend นับสองแบบไม่เหมือนกัน (AnalyticsController):
/// - ตัวเลขออเดอร์ (`top_metrics`) นับตามปฏิทิน: วันนี้ / ตั้งแต่วันจันทร์ / ตั้งแต่วันที่ 1 ของเดือน
/// - กราฟรายวัน (`revenue_trend`, `user_growth`) นับย้อนหลังแบบเลื่อน 1 / 7 / 30 วัน
enum AnalyticsPeriod {
  today('today', 'วันนี้', 'ตั้งแต่ 00:00 วันนี้'),
  week('week', 'สัปดาห์นี้', 'ตั้งแต่วันจันทร์'),
  month('month', 'เดือนนี้', 'ตั้งแต่วันที่ 1');

  const AnalyticsPeriod(this.key, this.label, this.since);
  final String key;
  final String label;

  /// คำอธิบายจุดเริ่มนับของตัวเลขออเดอร์
  final String since;

  /// จำนวนวันของกราฟแนวโน้มที่ใช้คู่กับช่วงนี้ (วันนี้ใช้ 7 วันให้เห็นแนวโน้ม)
  int get trendDays => this == AnalyticsPeriod.month ? 30 : 7;
}

/// ค่าหนึ่งวันในกราฟ
class DayPoint {
  const DayPoint(this.day, this.value);
  final DateTime day;
  final double value;
}

/// ผลจาก `GET /analytics/overview`
class AnalyticsOverview {
  const AnalyticsOverview({
    required this.period,
    required this.commissionsPaid,
    required this.newMembers,
    required this.ordersCount,
    required this.ordersPaidThb,
    required this.avgOrderThb,
    required this.uniqueBuyers,
    required this.fetchedAt,
  });

  final AnalyticsPeriod period;

  /// `revenue_trend` — ⚠️ ชื่อใน API คือ "revenue" แต่จริง ๆ คือ **ค่าคอมมิชชั่น MLM ที่จ่ายแล้ว**
  /// (SUM mlm_commissions.commission_amount WHERE status = paid) ไม่ใช่รายได้เข้าบริษัท
  final List<DayPoint> commissionsPaid;

  /// `user_growth` — สมาชิกสมัครใหม่รายวัน
  final List<DayPoint> newMembers;

  /// ออเดอร์ร้านค้าทุกสถานะในช่วงนี้ (รวมที่ยังไม่จ่าย)
  final int ordersCount;

  /// ยอดออเดอร์ที่ชำระแล้ว (payment_status = paid) — รายได้จริงของหน้านี้
  final double ordersPaidThb;

  /// backend คิด = ยอดชำระแล้ว ÷ จำนวนออเดอร์ทั้งหมด (รวมที่ยังไม่จ่าย)
  final double avgOrderThb;

  /// ผู้ซื้อไม่ซ้ำ (นับจากออเดอร์ทุกสถานะ)
  final int uniqueBuyers;
  final DateTime fetchedAt;

  factory AnalyticsOverview.fromJson(
      Map<String, dynamic> j, AnalyticsPeriod period) {
    final tm = _m(j['top_metrics']);
    return AnalyticsOverview(
      period: period,
      commissionsPaid: _points(j['revenue_trend']),
      newMembers: _points(j['user_growth']),
      ordersCount: TpFmt.toInt(tm['orders_count']),
      ordersPaidThb: TpFmt.toDouble(tm['orders_revenue_thb']),
      avgOrderThb: TpFmt.toDouble(tm['avg_order_value_thb']),
      uniqueBuyers: TpFmt.toInt(tm['unique_buyers']),
      fetchedAt: DateTime.now(),
    );
  }

  static List<DayPoint> _points(dynamic raw) {
    if (raw is! List) return const [];
    final out = <DayPoint>[];
    for (final e in raw.whereType<Map>()) {
      final d = DateTime.tryParse((e['date'] ?? '').toString());
      if (d == null) continue;
      out.add(DayPoint(
          DateTime(d.year, d.month, d.day), TpFmt.toDouble(e['value'])));
    }
    return out;
  }

  /// ค่าคอมฯ ที่จ่ายรายวันย้อนหลัง [days] วัน (วันที่ไม่มีข้อมูล = 0) — ตัวสุดท้ายคือวันนี้
  List<DayPoint> commissionsDaily(int days) => _fill(commissionsPaid, days);

  /// สมาชิกใหม่รายวันย้อนหลัง [days] วัน — ตัวสุดท้ายคือวันนี้
  List<DayPoint> membersDaily(int days) => _fill(newMembers, days);

  static List<DayPoint> _fill(List<DayPoint> src, int days) {
    final byDay = <int, double>{};
    for (final p in src) {
      final k = _key(p.day);
      byDay[k] = (byDay[k] ?? 0) + p.value;
    }
    final now = DateTime.now();
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final d = DateTime(now.year, now.month, now.day - i);
          return DayPoint(d, byDay[_key(d)] ?? 0);
        }(),
    ];
  }

  static int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
}

// ───────────────────────── Repository ─────────────────────────

class AnalyticsRepository {
  AnalyticsRepository(this._api);
  final ApiClient _api;

  Future<AnalyticsOverview> overview(AnalyticsPeriod period) => _safe(() async {
        final data = await _api
            .get<dynamic>('/analytics/overview', query: {'period': period.key});
        return AnalyticsOverview.fromJson(_m(data), period);
      });
}

bool _hasThai(String s) => RegExp(r'[฀-๿]').hasMatch(s);

/// กัน error ดิบจากเซิร์ฟเวอร์ (5xx / ข้อความอังกฤษ) หลุดถึงหน้าจอ — แปลงเป็นข้อความไทย
Future<T> _safe<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    final code = e.response?.statusCode ?? 0;
    if (code >= 500) {
      throw ActionError('เซิร์ฟเวอร์ขัดข้องชั่วคราว ($code) ลองใหม่อีกครั้ง');
    }
    rethrow;
  } on ApiException catch (e) {
    if (const {401, 403, 404, 429}.contains(e.statusCode)) rethrow;
    if (_hasThai(e.message)) throw ActionError(e.message);
    throw ActionError('โหลดรายงานไม่สำเร็จ (${e.statusCode})');
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
    (ref) => AnalyticsRepository(ref.watch(apiClientProvider)));

/// สรุปตามช่วงที่เลือก (ตัวเลขออเดอร์)
final analyticsOverviewProvider = FutureProvider.autoDispose
    .family<AnalyticsOverview, AnalyticsPeriod>((ref, period) =>
        ref.watch(analyticsRepositoryProvider).overview(period));
