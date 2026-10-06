import '../../../../shared/ui/tp_format.dart';

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{2300}-\u{23FF}\u{FE0E}\u{FE0F}\u{200D}\u{20E3}\u{E0020}-\u{E007F}]',
  unicode: true,
);

/// ตัดอีโมจิออกจากข้อความที่มาจากเซิร์ฟเวอร์ (แอปห้ามใช้อีโมจิเป็นไอคอน) + ยุบช่องว่างซ้ำ
String aiClean(String? s) =>
    (s ?? '').replaceAll(_emoji, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

String? _str(dynamic v) {
  final s = aiClean(v?.toString());
  return s.isEmpty ? null : s;
}

/// สรุปจาก `GET ai/dashboard?period=month`
///
/// ⚠️ ตัวเลขการใช้งานทั้งหมดอ่านจาก `ai_api_key_usage_logs` = คีย์ใน **AI Pool ของบอทดูดวง**
/// ส่วน `bots_summary` มาจากตาราง `ai_bot_profiles` (ระบบบอท AI ทั่วไป)
class AiOverview {
  const AiOverview({
    required this.tokensMonth,
    required this.costThb,
    required this.botsTotal,
    required this.botsActive,
    required this.botsRentable,
    required this.p95LatencyMs,
    required this.requestsPerMin,
    required this.errorsPct,
    this.generatedAt,
  });

  /// โทเคนรวมตั้งแต่วันที่ 1 ของเดือน
  final int tokensMonth;

  /// ค่าใช้จ่าย — backend ยังไม่คำนวณ (ส่ง 0 เสมอ) แสดงเฉพาะเมื่อ > 0
  final double costThb;
  final int botsTotal;
  final int botsActive;
  final int botsRentable;

  /// ค่าเหล่านี้คิดจาก 15 นาทีล่าสุด
  final int p95LatencyMs;
  final int requestsPerMin;
  final double errorsPct;
  final DateTime? generatedAt;

  factory AiOverview.fromJson(Map<String, dynamic> j) {
    final hero = _m(j['hero']);
    final bots = _m(j['bots_summary']);
    final inf = _m(j['inference']);
    return AiOverview(
      tokensMonth: TpFmt.toInt(hero['total_tokens']),
      costThb: TpFmt.toDouble(hero['total_cost_thb']),
      botsTotal: TpFmt.toInt(bots['total']),
      botsActive: TpFmt.toInt(bots['active']),
      botsRentable: TpFmt.toInt(bots['rentable']),
      p95LatencyMs: TpFmt.toInt(inf['p95_latency_ms']),
      requestsPerMin: TpFmt.toInt(inf['requests_per_min']),
      errorsPct: TpFmt.toDouble(inf['errors_pct']),
      generatedAt: TpFmt.parse(j['generated_at']),
    );
  }
}

/// หนึ่งชั่วโมงในกราฟการใช้งาน
class AiHourPoint {
  const AiHourPoint(
      {required this.hour, required this.requests, required this.avgLatencyMs});
  final DateTime hour;
  final int requests;
  final int avgLatencyMs;
}

/// การใช้งานรายชั่วโมงย้อนหลัง (`GET ai/dashboard/timeseries?hours=24`) — เติมชั่วโมงที่ไม่มีข้อมูลเป็น 0
class AiUsageSeries {
  const AiUsageSeries({required this.points, required this.fetchedAt});

  /// เรียงเก่า → ใหม่ ตัวสุดท้าย = ชั่วโมงปัจจุบัน
  final List<AiHourPoint> points;
  final DateTime fetchedAt;

  int get totalRequests => points.fold(0, (a, b) => a + b.requests);

  /// เวลาตอบเฉลี่ยถ่วงน้ำหนักตามจำนวนคำขอ (0 = ไม่มีข้อมูล)
  int get avgLatencyMs {
    var w = 0, sum = 0;
    for (final p in points) {
      if (p.requests <= 0 || p.avgLatencyMs <= 0) continue;
      w += p.requests;
      sum += p.requests * p.avgLatencyMs;
    }
    return w == 0 ? 0 : (sum / w).round();
  }

  /// ชั่วโมงที่คำขอมากสุด
  AiHourPoint? get peak {
    AiHourPoint? best;
    for (final p in points) {
      if (p.requests > 0 && (best == null || p.requests > best.requests)) {
        best = p;
      }
    }
    return best;
  }

  factory AiUsageSeries.fromJson(Map<String, dynamic> j, {int hours = 24}) {
    final byHour = <String, Map<String, dynamic>>{};
    final raw = j['series'];
    if (raw is List) {
      for (final e in raw.whereType<Map>()) {
        final t = (e['time'] ?? '').toString();
        if (t.length >= 13) {
          byHour[t.substring(0, 13)] = e.cast<String, dynamic>();
        }
      }
    }
    final now = DateTime.now();
    final cur = DateTime(now.year, now.month, now.day, now.hour);
    String key(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}';
    return AiUsageSeries(
      fetchedAt: now,
      points: [
        for (var i = hours - 1; i >= 0; i--)
          () {
            final h = DateTime(cur.year, cur.month, cur.day, cur.hour - i);
            final row = byHour[key(h)];
            return AiHourPoint(
              hour: h,
              requests: TpFmt.toInt(row?['requests']),
              avgLatencyMs: TpFmt.toInt(row?['avg_latency_ms']),
            );
          }(),
      ],
    );
  }
}

/// การใช้งานแยกตามผู้ให้บริการ (`GET ai/usage/per-provider`) — จัดกลุ่มตาม `ai_api_keys.provider`
class AiProviderUsage {
  const AiProviderUsage({
    required this.name,
    required this.displayName,
    this.color,
    required this.isActive,
    required this.totalKeys,
    required this.activeKeys,
    required this.requests,
    required this.tokens,
    required this.tokensToday,
    required this.tokensMonth,
    required this.avgLatencyMs,
    required this.p95LatencyMs,
    required this.errorRatePct,
  });

  final String name;
  final String displayName;

  /// สีจากเซิร์ฟเวอร์ ("#10b981" หรือ "hsl(120, 70%, 55%)")
  final String? color;
  final bool isActive;
  final int totalKeys;
  final int activeKeys;
  final int requests;
  final int tokens;
  final int tokensToday;
  final int tokensMonth;
  final int avgLatencyMs;
  final int p95LatencyMs;
  final double errorRatePct;

  factory AiProviderUsage.fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString();
    return AiProviderUsage(
      name: name,
      displayName: _str(j['display_name']) ?? (name.isEmpty ? 'ไม่ระบุ' : name),
      color: j['color']?.toString(),
      isActive: j['is_active'] == true,
      totalKeys: TpFmt.toInt(j['total_keys']),
      activeKeys: TpFmt.toInt(j['active_keys']),
      requests: TpFmt.toInt(j['requests']),
      tokens: TpFmt.toInt(j['tokens']),
      tokensToday: TpFmt.toInt(j['tokens_today']),
      tokensMonth: TpFmt.toInt(j['tokens_month']),
      avgLatencyMs: TpFmt.toInt(j['avg_latency_ms']),
      p95LatencyMs: TpFmt.toInt(j['p95_latency_ms']),
      errorRatePct: TpFmt.toDouble(j['error_rate_pct']),
    );
  }
}

/// ผู้ให้บริการ AI ของระบบบอท (ตาราง `ai_providers`) — คนละชุดกับคีย์ AI Pool ของบอทดูดวง
class AiProviderItem {
  const AiProviderItem({
    required this.id,
    required this.name,
    required this.displayName,
    this.type,
    required this.isActive,
    required this.isAvailable,
    this.endpoint,
    this.apiVersion,
    this.createdAt,
  });

  final int id;
  final String name;
  final String displayName;
  final String? type;
  final bool isActive;
  final bool isAvailable;
  final String? endpoint;
  final String? apiVersion;
  final DateTime? createdAt;

  /// ชนิดผู้ให้บริการ (enum ใน DB: cloud / self-hosted / gateway)
  String get typeLabel => switch ((type ?? '').toLowerCase()) {
        'cloud' => 'คลาวด์',
        'self-hosted' => 'ติดตั้งเอง',
        'gateway' => 'เกตเวย์',
        '' => 'ไม่ระบุชนิด',
        _ => type!,
      };

  /// โดเมนของ endpoint (ตัด https:// และ path ออก)
  String? get host {
    final e = endpoint;
    if (e == null || e.isEmpty) return null;
    final u = Uri.tryParse(e);
    return (u != null && u.host.isNotEmpty) ? u.host : e;
  }

  AiProviderItem copyWith({bool? isActive}) => AiProviderItem(
        id: id,
        name: name,
        displayName: displayName,
        type: type,
        isActive: isActive ?? this.isActive,
        isAvailable: isAvailable,
        endpoint: endpoint,
        apiVersion: apiVersion,
        createdAt: createdAt,
      );

  factory AiProviderItem.fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString();
    return AiProviderItem(
      id: TpFmt.toInt(j['id']),
      name: name,
      displayName:
          _str(j['display_name']) ?? _str(name) ?? 'ผู้ให้บริการ #${j['id']}',
      type: j['type']?.toString(),
      isActive: j['is_active'] == true,
      isAvailable: j['is_available'] == true,
      endpoint: _str(j['api_endpoint']),
      apiVersion: _str(j['api_version']),
      createdAt: TpFmt.parse(j['created_at']),
    );
  }
}

/// โปรไฟล์บอท AI (ตาราง `ai_bot_profiles`)
class AiBotItem {
  const AiBotItem({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.providerName,
    this.modelName,
    required this.isActive,
    required this.isPublic,
    required this.isRentable,
    required this.lineConnected,
    required this.rentalPerMonth,
    required this.rentalPerMessage,
    this.ownerId,
    this.createdAt,
  });

  final int id;
  final String name;
  final String displayName;
  final String? description;
  final String? providerName;
  final String? modelName;
  final bool isActive;
  final bool isPublic;
  final bool isRentable;
  final bool lineConnected;
  final double rentalPerMonth;
  final double rentalPerMessage;
  final int? ownerId;
  final DateTime? createdAt;

  factory AiBotItem.fromJson(Map<String, dynamic> j) {
    final provider = _m(j['provider']);
    final model = _m(j['model']);
    final rental = _m(j['rental']);
    final line = _m(j['line_oa']);
    final name = (j['name'] ?? '').toString();
    return AiBotItem(
      id: TpFmt.toInt(j['id']),
      name: name,
      displayName: _str(j['display_name']) ?? _str(name) ?? 'บอท #${j['id']}',
      description: _str(j['description']),
      providerName: _str(provider['name']),
      modelName: _str(model['name']),
      isActive: j['is_active'] == true,
      isPublic: j['is_public'] == true,
      isRentable: j['is_rentable'] == true,
      lineConnected: line['is_connected'] == true,
      rentalPerMonth: TpFmt.toDouble(rental['price_per_month']),
      rentalPerMessage: TpFmt.toDouble(rental['price_per_message']),
      ownerId: j['owner_id'] == null ? null : TpFmt.toInt(j['owner_id']),
      createdAt: TpFmt.parse(j['created_at']),
    );
  }
}

/// ผล `POST ai/providers/{id}/test-connection`
///
/// ⚠️ ปัจจุบัน backend ยังไม่ทดสอบจริง — คืน `reachable` = ค่า `is_available` ที่บันทึกไว้
/// พร้อมข้อความ "Connection test feature in progress" → แอปบอกตรง ๆ ว่ายังไม่ใช่ผลทดสอบจริง
class AiConnectionTest {
  const AiConnectionTest(
      {required this.reachable, required this.isStub, required this.at});
  final bool reachable;
  final bool isStub;
  final DateTime at;

  factory AiConnectionTest.fromJson(Map<String, dynamic> j) {
    final msg = (j['message'] ?? '').toString().toLowerCase();
    return AiConnectionTest(
      reachable: j['reachable'] == true,
      isStub: msg.contains('in progress') ||
          msg.contains('stub') ||
          msg.contains('mock'),
      at: TpFmt.parse(j['test_at']) ?? DateTime.now(),
    );
  }
}
