import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import '../../../shared/ui/tp_format.dart';
import '../../work/data/work_repository.dart' show FortuneBill;

// ═════════════════════════ ตัวช่วยอ่าน JSON ═════════════════════════

Map<String, dynamic> _m(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];

/// อีโมจิ/สัญลักษณ์ภาพที่เซิร์ฟเวอร์ใส่มาในป้าย (🔮 ⭐ ✅ ❌ ⏳ ฯลฯ) — ตัวอักษรไทย ฿ • — → ไม่โดน
final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{2300}-\u{23FF}\u{FE00}-\u{FE0F}\u{200D}\u{20E3}\u{E0020}-\u{E007F}]',
  unicode: true,
);
final _spaces = RegExp(r'\s{2,}');
final _parenOpen = RegExp(r'\(\s+');
final _parenClose = RegExp(r'\s+\)');
final _thai = RegExp(r'[฀-๿]');

/// ตัดอีโมจิออกจากข้อความที่มาจากเซิร์ฟเวอร์ (กติกาดีไซน์: ห้ามอีโมจิในหน้าจอ)
/// เช่น "Smart (⭐ กระจาย load)" → "Smart (กระจาย load)"
String fortuneCleanText(String? v) => (v ?? '')
    .replaceAll(_emoji, '')
    .replaceAll(_spaces, ' ')
    .replaceAll(_parenOpen, '(')
    .replaceAll(_parenClose, ')')
    .trim();

/// ข้อความที่ตัดอีโมจิแล้ว — ว่าง = null
String? _clean(dynamic v) {
  if (v == null) return null;
  final s = fortuneCleanText(v.toString());
  return s.isEmpty ? null : s;
}

/// สี hex จากเซิร์ฟเวอร์ (#ff6699 / #f69 / ff6699) → Color · อ่านไม่ได้ = null
Color? fortuneHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

// ═════════════════════════ ตัวกรองบิล ═════════════════════════

/// ช่องทางแชทที่กรองได้ใน `fortune/bills?platform=`
enum FortunePlatform {
  facebook('facebook', 'Messenger'),
  line('line', 'LINE'),
  telegram('telegram', 'Telegram'),
  other('other', 'อื่น ๆ');

  const FortunePlatform(this.key, this.label);
  final String key;
  final String label;
}

/// แพคเกจที่กรองได้ใน `fortune/bills?package=` (ป้ายตรงกับหน้าเว็บ FortuneBillsController::PACKAGES)
enum FortunePackage {
  deep('deep', 'ดูพื้นดวง 39฿'),
  celtic('celtic', 'Celtic 99฿'),
  freeCard('free_card', 'ไพ่ฟรี'),
  basic('basic', 'พื้นฐาน'),
  juntra('juntra', 'เว็บจันทรา');

  const FortunePackage(this.key, this.label);
  final String key;
  final String label;
}

// ═════════════════════════ สรุปธุรกิจดูดวง (fortune/dashboard) ═════════════════════════

enum FortunePeriod {
  today('today', 'วันนี้'),
  week('week', 'สัปดาห์นี้'),
  month('month', 'เดือนนี้');

  const FortunePeriod(this.key, this.label);
  final String key;
  final String label;
}

/// สถิติต่อหมวดคำถาม (เฉพาะหมวดที่เปิดอยู่)
class FortuneCategoryStat {
  const FortuneCategoryStat({required this.id, required this.name, this.color, this.sessions = 0, this.revenue = 0});
  final int id;
  final String name;
  final String? color;
  final int sessions;
  final double revenue;

  factory FortuneCategoryStat.fromJson(Map<String, dynamic> j) => FortuneCategoryStat(
        id: TpFmt.toInt(j['id']),
        name: _clean(j['name']) ?? 'ไม่มีชื่อหมวด',
        color: j['color']?.toString(),
        sessions: TpFmt.toInt(j['sessions']),
        revenue: TpFmt.toDouble(j['revenue_thb']),
      );
}

/// GET fortune/dashboard?period=
///
/// หมายเหตุนิยาม (ตามโค้ด backend):
/// - [revenue] = ผลรวม amount_paid ของบิลที่ "สร้างในช่วงนี้" และจ่ายแล้ว (ไม่รวมเว็บจันทรา)
/// - [sessions] = จำนวนแถว fortune_readings ที่สร้างในช่วงนี้ (นับทุกบทสนทนา รวมที่ไม่ได้ออกบิล)
class FortuneDashboard {
  const FortuneDashboard({
    this.revenue = 0,
    this.sessions = 0,
    this.avgRating = 0,
    this.activeNow = 0,
    this.categories = const [],
  });

  final double revenue;
  final int sessions;
  final double avgRating;
  final int activeNow;
  final List<FortuneCategoryStat> categories;

  factory FortuneDashboard.fromJson(Map<String, dynamic> j) {
    final h = _m(j['hero']);
    return FortuneDashboard(
      revenue: TpFmt.toDouble(h['monthly_revenue_thb']),
      sessions: TpFmt.toInt(h['sessions_count']),
      avgRating: TpFmt.toDouble(h['avg_rating']),
      activeNow: TpFmt.toInt(h['active_now']),
      categories: _list(j['services_summary']).map(FortuneCategoryStat.fromJson).toList(),
    );
  }
}

// ═════════════════════════ คำทำนายสด (fortune/active-readings) ═════════════════════════

class LiveReading {
  const LiveReading({
    required this.id,
    required this.billNumber,
    required this.packageLabel,
    required this.stuck,
    this.customerName,
    this.platform,
    this.stageLabel,
    this.stageDetail,
    this.paidAt,
    this.lastActivityAt,
    this.minutesSinceActivity,
    this.stuckReason,
    this.takenOver = false,
  });

  final int id;
  final String billNumber;
  final String packageLabel;
  final bool stuck;
  final String? customerName;
  final String? platform;
  final String? stageLabel;
  final String? stageDetail;
  final DateTime? paidAt;
  final DateTime? lastActivityAt;

  /// null = เซิร์ฟเวอร์ไม่รู้เวลาขยับล่าสุด
  final int? minutesSinceActivity;
  final String? stuckReason;
  final bool takenOver;

  /// เหตุผลที่ค้างเป็นภาษาไทย
  String? get stuckLabel => switch (stuckReason) {
        null => stuck ? 'ระบบไม่ขยับ' : null,
        'ai_generating_timeout' => 'AI ทำนายไม่เสร็จ',
        'deep_job_failed' => 'งานทำนายล้มเหลว',
        _ => 'ระบบไม่ขยับ',
      };

  factory LiveReading.fromJson(Map<String, dynamic> j) {
    final stage = _m(j['stage']);
    final id = TpFmt.toInt(j['reading_id'] ?? j['id']);
    return LiveReading(
      id: id,
      billNumber: (j['bill_number'] ?? 'R$id').toString(),
      packageLabel: _clean(j['package_label']) ?? 'ดูดวง',
      stuck: j['stuck'] == true,
      customerName: _clean(j['customer_name']),
      platform: j['platform']?.toString(),
      stageLabel: _clean(stage['label']),
      stageDetail: _clean(stage['detail']),
      paidAt: TpFmt.parse(j['paid_at']),
      lastActivityAt: TpFmt.parse(j['last_activity_at']),
      minutesSinceActivity: j['minutes_since_activity'] == null ? null : TpFmt.toInt(j['minutes_since_activity']),
      stuckReason: j['stuck_reason']?.toString(),
      takenOver: j['is_taken_over'] == true,
    );
  }
}

/// หน้าแบ่งของคำทำนายสด + ตัวนับรวม (`summary` นับจากทุกแถว ไม่ขึ้นกับตัวกรอง stuck)
class LiveReadingsPage extends Paged<LiveReading> {
  LiveReadingsPage({
    required super.items,
    super.page,
    super.lastPage,
    super.total,
    super.perPage,
    this.summaryTotal = 0,
    this.summaryStuck = 0,
  });

  final int summaryTotal;
  final int summaryStuck;

  factory LiveReadingsPage.parse(dynamic raw) {
    final base = Paged.parse(raw, LiveReading.fromJson);
    final s = _m(_m(raw)['summary']);
    return LiveReadingsPage(
      items: base.items,
      page: base.page,
      lastPage: base.lastPage,
      total: base.total,
      perPage: base.perPage,
      summaryTotal: s.isEmpty ? base.total : TpFmt.toInt(s['total']),
      summaryStuck: s.isEmpty ? base.items.where((e) => e.stuck).length : TpFmt.toInt(s['stuck']),
    );
  }
}

// ═════════════════════════ AI Pool (fortune/ai-pool) ═════════════════════════

/// โหมดวนคีย์ — ป้ายจากเซิร์ฟเวอร์ "Smart (⭐ กระจาย load อัจฉริยะ — แนะนำ)" แยกเป็นชื่อ + คำอธิบาย
class AiMode {
  const AiMode({required this.key, required this.title, this.description});
  final String key;
  final String title;
  final String? description;

  factory AiMode.fromJson(Map<String, dynamic> j) {
    final key = (j['key'] ?? '').toString();
    final label = _clean(j['label']) ?? key;
    final open = label.indexOf('(');
    if (open > 0 && label.endsWith(')')) {
      final desc = label.substring(open + 1, label.length - 1).trim();
      return AiMode(key: key, title: label.substring(0, open).trim(), description: desc.isEmpty ? null : desc);
    }
    return AiMode(key: key, title: label);
  }
}

class AiProviderInfo {
  const AiProviderInfo({
    required this.provider,
    required this.name,
    required this.rotationMode,
    this.keysTotal = 0,
    this.keysHealthy = 0,
  });

  final String provider;
  final String name;
  final String rotationMode;
  final int keysTotal;
  final int keysHealthy;

  AiProviderInfo copyWith({String? rotationMode, int? keysTotal, int? keysHealthy}) => AiProviderInfo(
        provider: provider,
        name: name,
        rotationMode: rotationMode ?? this.rotationMode,
        keysTotal: keysTotal ?? this.keysTotal,
        keysHealthy: keysHealthy ?? this.keysHealthy,
      );

  factory AiProviderInfo.fromJson(Map<String, dynamic> j) => AiProviderInfo(
        provider: (j['provider'] ?? '').toString(),
        name: _clean(j['name']) ?? (j['provider'] ?? 'ไม่ระบุ').toString(),
        rotationMode: (j['rotation_mode'] ?? 'round_robin').toString(),
        keysTotal: TpFmt.toInt(j['keys_total']),
        keysHealthy: TpFmt.toInt(j['keys_healthy']),
      );
}

/// คีย์ AI หนึ่งตัว — ไม่มีค่าคีย์จริง (เห็นแค่ 4 ตัวท้ายใน [keyMasked])
class AiKey {
  const AiKey({
    required this.id,
    required this.provider,
    required this.providerName,
    required this.label,
    required this.isActive,
    required this.healthy,
    this.model,
    this.priority = 0,
    this.purposeLabel,
    this.isCritical = false,
    this.disabledUntil,
    this.lastTestPassedAt,
    this.lastTestFailedAt,
    this.lastTestMessage,
    this.lastError,
    this.lastErrorAt,
    this.consecutiveErrors = 0,
    this.lastUsedAt,
    this.usageRequests = 0,
    this.usageTokens = 0,
    this.usageErrors = 0,
    this.keyMasked = '••••',
  });

  final int id;
  final String provider;
  final String providerName;
  final String label;
  final bool isActive;
  final bool healthy;
  final String? model;
  final int priority;

  /// ป้ายจุดประสงค์ (ตัดอีโมจิแล้ว)
  final String? purposeLabel;
  final bool isCritical;
  final DateTime? disabledUntil;
  final DateTime? lastTestPassedAt;
  final DateTime? lastTestFailedAt;
  final String? lastTestMessage;
  final String? lastError;
  final DateTime? lastErrorAt;
  final int consecutiveErrors;
  final DateTime? lastUsedAt;
  final int usageRequests;
  final int usageTokens;
  final int usageErrors;
  final String keyMasked;

  /// ป้ายจุดประสงค์แบบสั้น (ตัดวงเล็บอธิบายท้ายออก) สำหรับป้ายเม็ดยา
  String? get purposeShort {
    final p = purposeLabel;
    if (p == null) return null;
    final i = p.indexOf(' (');
    return i > 0 ? p.substring(0, i).trim() : p;
  }

  /// ถูกพักชั่วคราวอยู่ไหม (เทียบเวลาเครื่อง)
  bool get isSuspended => disabledUntil != null && disabledUntil!.isAfter(DateTime.now());

  /// ผลทดสอบล่าสุดคือไม่ผ่าน (ไม่ผ่านใหม่กว่าผ่าน)
  bool get lastTestFailed =>
      lastTestFailedAt != null && (lastTestPassedAt == null || lastTestFailedAt!.isAfter(lastTestPassedAt!));

  factory AiKey.fromJson(Map<String, dynamic> j) {
    final u = _m(j['usage_today']);
    final id = TpFmt.toInt(j['id']);
    return AiKey(
      id: id,
      provider: (j['provider'] ?? '').toString(),
      providerName: _clean(j['provider_name']) ?? (j['provider'] ?? 'ไม่ระบุ').toString(),
      label: _clean(j['label']) ?? 'คีย์ #$id',
      isActive: j['is_active'] == true,
      healthy: j['healthy'] == true,
      model: _clean(j['model']),
      priority: TpFmt.toInt(j['priority']),
      purposeLabel: _clean(j['purpose_label']),
      isCritical: j['is_critical'] == true,
      disabledUntil: TpFmt.parse(j['disabled_until']),
      lastTestPassedAt: TpFmt.parse(j['last_test_passed_at']),
      lastTestFailedAt: TpFmt.parse(j['last_test_failed_at']),
      lastTestMessage: _clean(j['last_test_message']),
      lastError: _clean(j['last_error']),
      lastErrorAt: TpFmt.parse(j['last_error_at']),
      consecutiveErrors: TpFmt.toInt(j['consecutive_errors']),
      lastUsedAt: TpFmt.parse(j['last_used_at']),
      usageRequests: TpFmt.toInt(u['requests']),
      usageTokens: TpFmt.toInt(u['tokens']),
      usageErrors: TpFmt.toInt(u['errors']),
      keyMasked: (j['key_masked'] ?? '••••').toString(),
    );
  }
}

class AiPool {
  const AiPool({
    required this.globalMode,
    required this.globalModeWritable,
    required this.modes,
    required this.providers,
    required this.keys,
    required this.total,
    required this.healthy,
    required this.active,
    required this.canManage,
  });

  final String globalMode;
  final bool globalModeWritable;
  final List<AiMode> modes;
  final List<AiProviderInfo> providers;
  final List<AiKey> keys;
  final int total;
  final int healthy;
  final int active;

  /// สิทธิ์เขียน (super admin หรือ manage_api_keys) — false = ดูได้อย่างเดียว
  final bool canManage;

  int get requestsToday => keys.fold(0, (s, k) => s + k.usageRequests);
  int get errorsToday => keys.fold(0, (s, k) => s + k.usageErrors);

  AiMode? mode(String key) {
    for (final m in modes) {
      if (m.key == key) return m;
    }
    return null;
  }

  String modeTitle(String key) => mode(key)?.title ?? key;

  List<AiKey> keysOf(String provider) => keys.where((k) => k.provider == provider).toList();

  /// แทนที่คีย์หนึ่งตัวแล้วคำนวณตัวนับใหม่ในเครื่อง (หลังเปิด/ปิด/ทดสอบ)
  AiPool withKey(AiKey key) => _rebuild(keys: [for (final k in keys) k.id == key.id ? key : k]);

  AiPool withProviderMode(String provider, String mode) => _rebuild(
        providers: [for (final p in providers) p.provider == provider ? p.copyWith(rotationMode: mode) : p],
      );

  AiPool _rebuild({List<AiKey>? keys, List<AiProviderInfo>? providers}) {
    final ks = keys ?? this.keys;
    final pv = [
      for (final p in providers ?? this.providers)
        p.copyWith(
          keysTotal: ks.where((k) => k.provider == p.provider).length,
          keysHealthy: ks.where((k) => k.provider == p.provider && k.healthy).length,
        ),
    ];
    return AiPool(
      globalMode: globalMode,
      globalModeWritable: globalModeWritable,
      modes: modes,
      providers: pv,
      keys: ks,
      total: ks.length,
      healthy: ks.where((k) => k.healthy).length,
      active: ks.where((k) => k.isActive).length,
      canManage: canManage,
    );
  }

  factory AiPool.fromJson(Map<String, dynamic> j) {
    final keys = _list(j['keys']).map(AiKey.fromJson).toList();
    var providers = _list(j['providers']).map(AiProviderInfo.fromJson).toList();
    // เซิร์ฟเวอร์ไม่ได้ส่งรายชื่อ provider มา → สร้างจากคีย์ (กันคีย์หายจากหน้าจอ)
    if (providers.isEmpty && keys.isNotEmpty) {
      final seen = <String>{};
      providers = [
        for (final k in keys)
          if (seen.add(k.provider)) AiProviderInfo(provider: k.provider, name: k.providerName, rotationMode: 'round_robin'),
      ];
    }
    final s = _m(j['summary']);
    return AiPool(
      globalMode: (j['global_mode'] ?? 'smart').toString(),
      globalModeWritable: j['global_mode_writable'] == true,
      modes: _list(j['modes']).map(AiMode.fromJson).toList(),
      providers: providers,
      keys: keys,
      total: s.isEmpty ? keys.length : TpFmt.toInt(s['total']),
      healthy: s.isEmpty ? keys.where((k) => k.healthy).length : TpFmt.toInt(s['healthy']),
      active: s.isEmpty ? keys.where((k) => k.isActive).length : TpFmt.toInt(s['active']),
      canManage: j['can_manage'] == true,
    )._rebuild();
  }
}

/// ผลการกด "ทดสอบ" คีย์
class AiKeyTestResult {
  const AiKeyTestResult({required this.passed, this.message, this.responseTimeMs, this.modelWarning, this.key});
  final bool passed;
  final String? message;
  final int? responseTimeMs;
  final String? modelWarning;
  final AiKey? key;
}

// ═════════════════════════ บริการ/แพคเกจ (fortune/services) ═════════════════════════

class FortuneServiceItem {
  const FortuneServiceItem({required this.id, required this.name, required this.price, required this.isActive});
  final String id;
  final String name;
  final double price;
  final bool isActive;

  factory FortuneServiceItem.fromJson(Map<String, dynamic> j) => FortuneServiceItem(
        id: (j['id'] ?? '').toString(),
        name: _clean(j['name']) ?? (j['id'] ?? 'แพคเกจ').toString(),
        price: TpFmt.toDouble(j['price_thb']),
        isActive: j['is_active'] == true,
      );
}

/// หมวดคำถาม — `icon` จากเซิร์ฟเวอร์เป็นอีโมจิ จึงไม่เก็บ (ห้ามแสดง)
class FortuneCategoryItem {
  const FortuneCategoryItem({required this.id, required this.name, this.color, required this.isActive});
  final int id;
  final String name;
  final String? color;
  final bool isActive;

  factory FortuneCategoryItem.fromJson(Map<String, dynamic> j) => FortuneCategoryItem(
        id: TpFmt.toInt(j['id']),
        name: _clean(j['name']) ?? 'ไม่มีชื่อหมวด',
        color: j['color']?.toString(),
        isActive: j['is_active'] == true,
      );
}

class FortuneServices {
  const FortuneServices({this.services = const [], this.categories = const [], this.writable = false});
  final List<FortuneServiceItem> services;
  final List<FortuneCategoryItem> categories;
  final bool writable;

  factory FortuneServices.fromJson(Map<String, dynamic> j) => FortuneServices(
        services: _list(j['services']).map(FortuneServiceItem.fromJson).toList(),
        categories: _list(j['categories']).map(FortuneCategoryItem.fromJson).toList(),
        writable: j['writable'] == true,
      );
}

// ═════════════════════════ Repository ═════════════════════════

class FortuneRepository {
  FortuneRepository(this._api);
  final ApiClient _api;

  Future<FortuneDashboard> dashboard(FortunePeriod period) async {
    final data = await _api.get<dynamic>('/fortune/dashboard', query: {'period': period.key});
    return FortuneDashboard.fromJson(_m(data));
  }

  /// ค้นบิลดูดวงทุกสถานะ (`status=all` = ทุกกอง)
  Future<Paged<FortuneBill>> searchBills({
    String status = 'all',
    String? search,
    FortunePlatform? platform,
    FortunePackage? package,
    int page = 1,
  }) async {
    final q = (search ?? '').trim();
    final data = await _api.get<dynamic>('/fortune/bills', query: {
      'status': status,
      'page': page,
      'per_page': 20,
      if (q.isNotEmpty) 'search': q.length > 100 ? q.substring(0, 100) : q,
      if (platform != null) 'platform': platform.key,
      if (package != null) 'package': package.key,
    });
    return Paged.parse(data, FortuneBill.fromJson);
  }

  /// บิลจ่ายแล้วที่กำลังใช้บริการ (ค้างขึ้นก่อน — เรียงจากเซิร์ฟเวอร์)
  Future<LiveReadingsPage> liveReadings({bool stuckOnly = false, int page = 1, int perPage = 20}) async {
    final data = await _api.get<dynamic>('/fortune/active-readings', query: {
      'page': page,
      'per_page': perPage,
      // Laravel boolean รับ 1/0 — ห้ามส่ง "true"
      if (stuckOnly) 'stuck': 1,
    });
    return LiveReadingsPage.parse(data);
  }

  Future<AiPool> aiPool() async {
    final data = await _api.get<dynamic>('/fortune/ai-pool');
    return AiPool.fromJson(_m(data));
  }

  /// สลับเปิด/ปิดคีย์ (endpoint เป็น toggle ไม่ใช่ set) — คืนคีย์สถานะล่าสุด + ข้อความ
  Future<(AiKey?, String?)> toggleKey(int id) async {
    final res = await _api.dio.post<Map<String, dynamic>>('/fortune/ai-pool/keys/$id/toggle');
    final body = _expectOk(res.data, res.statusCode);
    final k = _m(_m(body['data'])['key']);
    return (k.isEmpty ? null : AiKey.fromJson(k), _clean(body['message']));
  }

  /// ทดสอบคีย์ — ไม่ผ่านตอบ HTTP 200 + success:false + data.passed:false (เป็น "ผลทดสอบ" ไม่ใช่ error)
  Future<AiKeyTestResult> testKey(int id) async {
    final res = await _api.dio.post<Map<String, dynamic>>('/fortune/ai-pool/keys/$id/test');
    final body = res.data ?? const <String, dynamic>{};
    final code = res.statusCode ?? 500;
    final data = _m(body['data']);
    if (code >= 400 || (body['success'] != true && !data.containsKey('passed'))) {
      _expectOk(body, code == 200 ? 500 : code);
    }
    final k = _m(data['key']);
    final ms = data['response_time_ms'];
    return AiKeyTestResult(
      passed: data['passed'] == true || (body['success'] == true && !data.containsKey('passed')),
      message: _clean(body['message']),
      responseTimeMs: ms == null ? null : TpFmt.toInt(ms),
      modelWarning: _clean(data['model_warning']),
      key: k.isEmpty ? null : AiKey.fromJson(k),
    );
  }

  /// ตั้งโหมดวนคีย์ราย provider (โหมดรวมตั้งจาก env เท่านั้น)
  Future<String?> setProviderMode(String provider, String mode) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/fortune/ai-pool/mode',
      data: {'provider': provider, 'mode': mode},
    );
    return _clean(_expectOk(res.data, res.statusCode)['message']);
  }

  Future<FortuneServices> services() async {
    final data = await _api.get<dynamic>('/fortune/services');
    return FortuneServices.fromJson(_m(data));
  }

  /// ตรวจผลของคำขอที่ยิงผ่าน dio ตรง ๆ — คืน body ถ้าสำเร็จ ไม่งั้น throw ข้อความไทยที่อ่านได้
  Map<String, dynamic> _expectOk(Map<String, dynamic>? body, int? code) {
    final b = body ?? const <String, dynamic>{};
    final c = code ?? 500;
    if (c < 400 && b['success'] != false) return b;
    if (c == 401) {
      // ให้ AuthController พากลับหน้าเข้าสู่ระบบ (เหมือน ApiClient._unwrap)
      ApiClient.onUnauthorized?.call();
      throw ApiException(statusCode: 401, message: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    final msg = _clean(b['message']);
    // ข้อความไทยจาก backend แสดงได้เลย · ข้อความอังกฤษ (เช่น validation ค่าเริ่มต้นของ Laravel) แทนด้วยข้อความไทย
    if (msg != null && _thai.hasMatch(msg)) throw ActionError(msg);
    throw ActionError(switch (c) {
      403 => 'บัญชีนี้ไม่มีสิทธิ์ทำรายการนี้',
      404 => 'ไม่พบรายการนี้ในระบบ (อาจถูกลบไปแล้ว)',
      422 => 'ข้อมูลไม่ถูกต้อง',
      429 => 'ทำรายการถี่เกินไป รอสักครู่แล้วลองใหม่',
      _ => 'ทำรายการไม่สำเร็จ ($c)',
    });
  }
}

final fortuneRepositoryProvider = Provider<FortuneRepository>((ref) => FortuneRepository(ref.watch(apiClientProvider)));

/// สรุปธุรกิจดูดวงตามช่วงเวลา
final fortuneDashboardProvider = FutureProvider.autoDispose.family<FortuneDashboard, FortunePeriod>(
    (ref, period) => ref.watch(fortuneRepositoryProvider).dashboard(period));

/// ตัวนับคำทำนายสด (กำลังทำ / ค้าง) — ขอแค่ 1 แถว เอา summary
final liveSummaryProvider = FutureProvider.autoDispose<LiveReadingsPage>(
    (ref) => ref.watch(fortuneRepositoryProvider).liveReadings(perPage: 1));

final fortuneServicesProvider =
    FutureProvider.autoDispose<FortuneServices>((ref) => ref.watch(fortuneRepositoryProvider).services());

/// คลังคีย์ AI — แก้คีย์ทีละตัวในหน่วยความจำได้ (ไม่ต้องโหลดใหม่ทั้งหน้าหลังกดสวิตช์)
class AiPoolNotifier extends AutoDisposeAsyncNotifier<AiPool> {
  @override
  Future<AiPool> build() => ref.watch(fortuneRepositoryProvider).aiPool();

  void patchKey(AiKey key) {
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = AsyncData(cur.withKey(key));
  }

  void patchMode(String provider, String mode) {
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = AsyncData(cur.withProviderMode(provider, mode));
  }
}

final aiPoolProvider = AsyncNotifierProvider.autoDispose<AiPoolNotifier, AiPool>(AiPoolNotifier.new);
