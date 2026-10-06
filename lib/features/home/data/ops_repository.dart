import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/ui/tp_format.dart';

/// งานหนึ่งประเภทในคิว "ต้องจัดการตอนนี้"
class QueueItem {
  const QueueItem(
      {this.count = 0,
      this.amount = 0,
      this.oldestMinutes,
      this.preview,
      this.unavailable = false});

  /// backend อ่านส่วนนี้ไม่สำเร็จ (ส่ง null มา) — ต้องแสดงว่า "ไม่ทราบ" ห้ามตีเป็น 0 งาน
  final bool unavailable;
  final int count;
  final double amount;
  final int? oldestMinutes;
  final String? preview;

  factory QueueItem.fromJson(dynamic j) {
    if (j is num) return QueueItem(count: j.toInt());
    if (j is! Map) return const QueueItem(unavailable: true);
    final m = j.cast<String, dynamic>();
    // preview เป็นรายการย่อ (เก่าสุดก่อน) — ทำเป็นข้อความบรรทัดเดียวจากรายการแรก
    String? preview;
    final pv = m['preview'];
    if (pv is List && pv.isNotEmpty && pv.first is Map) {
      final f = (pv.first as Map).cast<String, dynamic>();
      final name =
          (f['customer_name'] ?? f['user_name'] ?? f['sender'])?.toString();
      final stage =
          f['stage'] is Map ? (f['stage'] as Map)['label']?.toString() : null;
      final extra = (f['keyword'] ?? stage ?? f['package_label'])?.toString();
      preview = [name, if (extra != null && extra.isNotEmpty) '“$extra”']
          .whereType<String>()
          .join(' · ');
      if (pv.length > 1) preview = '$preview และอีก ${pv.length - 1}';
    } else if (pv is String) {
      preview = pv;
    }
    return QueueItem(
      count: TpFmt.toInt(m['count']),
      amount: TpFmt.toDouble(m['amount_thb'] ?? m['amount'] ?? m['sum_thb']),
      oldestMinutes:
          m['oldest_minutes'] == null ? null : TpFmt.toInt(m['oldest_minutes']),
      preview: (preview == null || preview.isEmpty) ? null : preview,
    );
  }
}

/// สรุปงาน + สุขภาพระบบ + รายได้วันนี้ (GET /ops/summary)
class OpsSummary {
  const OpsSummary({
    required this.customerRequests,
    required this.billsAwaiting,
    required this.withdrawalsPending,
    this.withdrawalsApproved = const QueueItem(),
    required this.smsUnmatched,
    required this.stuckReadings,
    required this.aiHealthy,
    required this.aiTotal,
    this.linePushUsed,
    this.linePushLimit = 300,
    this.queueBacklog = 0,
    this.queueFailed24h = 0,
    this.linePushExhausted = false,
    required this.revenueToday,
    required this.revenueFortune,
    required this.revenueMarketplace,
    required this.revenueOther,
    required this.hourly,
    this.revenueYesterdaySameTime,
    this.latencyMs,
    this.fetchedAt,
    this.degraded = const [],
  });

  final QueueItem customerRequests;
  final QueueItem billsAwaiting;
  final QueueItem withdrawalsPending;

  /// อนุมัติแล้ว รอแอดมินโอน + แนบสลิป (backend v3 — ไม่มีคีย์ = 0)
  final QueueItem withdrawalsApproved;
  final QueueItem smsUnmatched;
  final QueueItem stuckReadings;
  final int aiHealthy;
  final int aiTotal;
  final int? linePushUsed;
  final int linePushLimit;
  final int queueBacklog;
  final int queueFailed24h;
  final bool linePushExhausted;
  final double revenueToday;
  final double revenueFortune;
  final double revenueMarketplace;
  final double revenueOther;

  /// รายได้รายชั่วโมงของวันนี้ (index = ชั่วโมง 0–23)
  final List<double> hourly;
  final double? revenueYesterdaySameTime;
  final int? latencyMs;
  final DateTime? fetchedAt;

  /// ส่วนที่ backend อ่านไม่สำเร็จรอบนี้ (เช่น ["bills_awaiting"])
  final List<String> degraded;

  bool get anyUnavailable =>
      degraded.isNotEmpty ||
      [
        customerRequests,
        billsAwaiting,
        withdrawalsPending,
        smsUnmatched,
        stuckReadings
      ].any((q) => q.unavailable);

  int get totalTasks =>
      customerRequests.count +
      billsAwaiting.count +
      withdrawalsPending.count +
      withdrawalsApproved.count +
      smsUnmatched.count +
      stuckReadings.count;

  /// เปอร์เซ็นต์เทียบเมื่อวานช่วงเวลาเดียวกัน (null = เทียบไม่ได้)
  double? get growthPct {
    final y = revenueYesterdaySameTime;
    if (y == null || y <= 0) return null;
    return (revenueToday - y) / y * 100;
  }

  /// งานที่แท็บ "งานรอทำ" ต้องแสดง (ไม่รวมแชท — แชทมีแท็บของตัวเอง)
  int get workBadge =>
      billsAwaiting.count +
      withdrawalsPending.count +
      withdrawalsApproved.count +
      smsUnmatched.count +
      stuckReadings.count;

  OpsSummary withLatency(int ms) => OpsSummary(
        customerRequests: customerRequests,
        billsAwaiting: billsAwaiting,
        withdrawalsPending: withdrawalsPending,
        withdrawalsApproved: withdrawalsApproved,
        smsUnmatched: smsUnmatched,
        stuckReadings: stuckReadings,
        aiHealthy: aiHealthy,
        aiTotal: aiTotal,
        linePushUsed: linePushUsed,
        linePushLimit: linePushLimit,
        queueBacklog: queueBacklog,
        queueFailed24h: queueFailed24h,
        linePushExhausted: linePushExhausted,
        revenueToday: revenueToday,
        revenueFortune: revenueFortune,
        revenueMarketplace: revenueMarketplace,
        revenueOther: revenueOther,
        hourly: hourly,
        revenueYesterdaySameTime: revenueYesterdaySameTime,
        latencyMs: ms,
        fetchedAt: DateTime.now(),
        degraded: degraded,
      );

  factory OpsSummary.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(dynamic v) =>
        v is Map ? v.cast<String, dynamic>() : const {};
    final q = m(j['queue']);
    final h = m(j['health']);
    final rev = m(j['revenue_today']);
    final split = rev['split'] is Map ? m(rev['split']) : rev;
    final ai = m(h['ai_pool']);
    final lp = h['line_push'] is Map ? m(h['line_push']) : null;

    final hourly = List<double>.filled(24, 0);
    final rawHourly = rev['hourly'];
    if (rawHourly is List) {
      for (var i = 0; i < rawHourly.length; i++) {
        final e = rawHourly[i];
        if (e is Map) {
          final hr = TpFmt.toInt(e['hour']);
          if (hr >= 0 && hr < 24) hourly[hr] = TpFmt.toDouble(e['amount']);
        } else if (i < 24) {
          hourly[i] = TpFmt.toDouble(e);
        }
      }
    }

    return OpsSummary(
      customerRequests: QueueItem.fromJson(q['customer_requests']),
      billsAwaiting: QueueItem.fromJson(q['bills_awaiting']),
      withdrawalsPending: QueueItem.fromJson(q['withdrawals_pending']),
      withdrawalsApproved: q.containsKey('withdrawals_approved')
          ? QueueItem.fromJson(q['withdrawals_approved'])
          : const QueueItem(),
      smsUnmatched: QueueItem.fromJson(q['sms_unmatched']),
      stuckReadings: QueueItem.fromJson(q['stuck_readings']),
      aiHealthy: TpFmt.toInt(ai['healthy']),
      aiTotal: TpFmt.toInt(ai['total']),
      linePushUsed:
          lp == null ? null : TpFmt.toInt(lp['used_this_month'] ?? lp['used']),
      linePushLimit: lp == null
          ? 300
          : (TpFmt.toInt(lp['limit']) > 0 ? TpFmt.toInt(lp['limit']) : 300),
      queueBacklog: h['queue_backlog'] is Map
          ? TpFmt.toInt((h['queue_backlog'] as Map)['pending'])
          : TpFmt.toInt(h['queue_backlog']),
      queueFailed24h: h['queue_backlog'] is Map
          ? TpFmt.toInt((h['queue_backlog'] as Map)['failed_24h'])
          : 0,
      linePushExhausted: lp?['exhausted'] == true,
      revenueToday: TpFmt.toDouble(rev['total']),
      revenueFortune: TpFmt.toDouble(split['fortune']),
      revenueMarketplace: TpFmt.toDouble(split['marketplace']),
      revenueOther: TpFmt.toDouble(split['other']),
      hourly: hourly,
      revenueYesterdaySameTime: j['revenue_yesterday_same_time'] == null
          ? null
          : TpFmt.toDouble(j['revenue_yesterday_same_time']),
      degraded: (j['degraded'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

class OpsRepository {
  OpsRepository(this._api);
  final ApiClient _api;

  Future<OpsSummary> summary() async {
    final sw = Stopwatch()..start();
    final data = await _api.get<Map<String, dynamic>>(
      '/ops/summary',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    sw.stop();
    return OpsSummary.fromJson(data).withLatency(sw.elapsedMilliseconds);
  }
}

final opsRepositoryProvider = Provider<OpsRepository>(
    (ref) => OpsRepository(ref.watch(apiClientProvider)));

/// สรุปงาน — AppShell สั่งรีเฟรชทุก 30 วินาทีขณะแอปเปิดอยู่ (แท็บ badge ใช้ตัวเดียวกัน)
final opsSummaryProvider = FutureProvider<OpsSummary>(
    (ref) => ref.watch(opsRepositoryProvider).summary());
