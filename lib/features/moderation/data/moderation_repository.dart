import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import '../../../shared/ui/tp_format.dart';

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

bool _hasThai(String s) => RegExp(r'[฀-๿]').hasMatch(s);

final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{2300}-\u{23FF}\u{FE0E}\u{FE0F}\u{200D}\u{20E3}\u{E0020}-\u{E007F}]',
  unicode: true,
);

/// ตัดอีโมจิออกจากข้อความที่มาจากเซิร์ฟเวอร์ + ยุบช่องว่างซ้ำ
String modClean(String? s) =>
    (s ?? '').replaceAll(_emoji, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

String? _str(dynamic v) {
  final s = modClean(v?.toString());
  return s.isEmpty ? null : s;
}

/// ชื่อช่องทางแชทภาษาคน
String modPlatformLabel(String? platform) =>
    switch ((platform ?? '').toLowerCase()) {
      'facebook' => 'Messenger',
      'line' => 'LINE',
      'telegram' => 'Telegram',
      '' => 'ไม่ทราบช่องทาง',
      _ => platform!,
    };

/// ย่อ ID ยาว ๆ ให้เหลือท้าย 6 ตัว (…a1b2c3)
String modShortId(String? id) {
  final s = (id ?? '').trim();
  if (s.isEmpty) return '-';
  return s.length <= 8 ? s : '…${s.substring(s.length - 6)}';
}

// ───────────────────────── ผู้ต้องสงสัย ─────────────────────────

/// บทสนทนาที่เข้าข่าย (GET moderation/suspects) — คะแนน = จำนวนคำต้องสงสัยที่เจอ + 1 ถ้าให้ ≤ 2 ดาว
class Suspect {
  const Suspect({
    required this.readingId,
    this.userId,
    this.platformUserId,
    this.displayName,
    required this.isPaid,
    this.rating,
    this.createdAt,
    required this.keywords,
    required this.score,
    required this.lowRating,
    this.preview,
  });

  final int readingId;
  final int? userId;

  /// ⚠️ backend อ่านจากคอลัมน์ `facebook_user_id` อย่างเดียว — ลูกค้า LINE จะเป็น null
  /// (ต้องดึงบิลจริงก่อนแบนเพื่อเอา platform + platform_user_id ที่ถูกต้อง)
  final String? platformUserId;
  final String? displayName;
  final bool isPaid;
  final int? rating;
  final DateTime? createdAt;
  final List<String> keywords;
  final int score;
  final bool lowRating;
  final String? preview;

  factory Suspect.fromJson(Map<String, dynamic> j) {
    final kws = j['matched_keywords'];
    final flags = j['flags'];
    final flagList = flags is List
        ? flags.map((e) => '$e').toList()
        : (flags is Map ? flags.values.map((e) => '$e').toList() : <String>[]);
    return Suspect(
      readingId: TpFmt.toInt(j['reading_id']),
      userId: j['user_id'] == null ? null : TpFmt.toInt(j['user_id']),
      platformUserId: _str(j['platform_user_id']),
      displayName: _str(j['display_name']),
      isPaid: j['is_paid'] == true,
      rating: j['rating'] == null ? null : TpFmt.toInt(j['rating']),
      createdAt: TpFmt.parse(j['created_at']),
      keywords: kws is List
          ? kws.map((e) => '$e').where((e) => e.isNotEmpty).toList()
          : const [],
      score: TpFmt.toInt(j['score']),
      lowRating: flagList.contains('low_rating'),
      preview: _str(j['preview']),
    );
  }
}

class SuspectsResult {
  const SuspectsResult(
      {required this.items,
      required this.total,
      required this.windowHours,
      required this.keywordCount});
  final List<Suspect> items;

  /// จำนวนที่เข้าข่ายทั้งหมด (backend ตัดส่งมาแค่ตาม per_page)
  final int total;
  final int windowHours;
  final int keywordCount;
}

// ───────────────────────── รายการแบน ─────────────────────────

class BanEntry {
  const BanEntry({
    required this.id,
    required this.platform,
    required this.platformUserId,
    this.displayName,
    this.reason,
    this.bannedUntil,
    required this.isPermanent,
    required this.attemptCount,
    this.bannedByName,
    this.createdAt,
  });

  final int id;
  final String platform;
  final String platformUserId;
  final String? displayName;
  final String? reason;
  final DateTime? bannedUntil;
  final bool isPermanent;

  /// จำนวนครั้งที่ลูกค้าทักมาระหว่างถูกแบน
  final int attemptCount;
  final String? bannedByName;
  final DateTime? createdAt;

  /// แยกเหตุผลที่ระบบบันทึก ("bill_troll: สร้างบิลไม่ชำระ 3 ครั้ง…") เป็น (หมวดภาษาไทย, รายละเอียด)
  (String, String?) get reasonParts {
    final raw = (reason ?? '').trim();
    if (raw.isEmpty) {
      return (bannedByName != null ? 'แอดมินแบน' : 'ไม่ระบุเหตุผล', null);
    }
    if (raw == 'banned_by_admin') return ('แอดมินแบน', null);
    final m = RegExp(r'^([a-z_]+)(\[[^\]]*\])?\s*:\s*(.*)$', dotAll: true)
        .firstMatch(raw);
    if (m != null) {
      final code = m[1]!;
      final detail = _str(m[3]);
      final label = switch (code) {
        'bill_troll' => 'สร้างบิลแล้วไม่จ่าย',
        'consent_quiz' => 'รับกติกาแล้วไม่จ่าย',
        'gesture_flood' => 'ส่งสติกเกอร์/อีโมจิรัว',
        'nav_flood' => 'กดเมนูรัว',
        'auto' => 'ระบบแบนอัตโนมัติ',
        _ => 'ระบบแบนอัตโนมัติ',
      };
      return (label, detail);
    }
    return (bannedByName != null ? 'แอดมินแบน' : 'ระบบแบน', _str(raw));
  }

  factory BanEntry.fromJson(Map<String, dynamic> j) {
    final by = _m(j['banned_by']);
    final until = TpFmt.parse(j['banned_until']);
    return BanEntry(
      id: TpFmt.toInt(j['id']),
      platform: (j['platform'] ?? '').toString(),
      platformUserId: (j['platform_user_id'] ?? '').toString(),
      displayName: _str(j['display_name']),
      reason: j['reason']?.toString(),
      bannedUntil: until,
      isPermanent: j['is_permanent'] == true ||
          (j['is_permanent'] == null && until == null),
      attemptCount: TpFmt.toInt(j['attempt_count']),
      bannedByName: _str(by['name']),
      createdAt: TpFmt.parse(j['created_at']),
    );
  }
}

/// สรุปผู้ที่ถูกแบนอยู่ (หน้าแรก 100 รายการ) — ใช้ติดป้าย "แบนอยู่แล้ว" ในรายการผู้ต้องสงสัย
class BanIndex {
  const BanIndex({required this.userIds, required this.total});
  final Set<String> userIds;
  final int total;
}

/// ตัวตนบนช่องทางแชทที่ใช้แบน (อ่านจากบิลจริง)
class BanTarget {
  const BanTarget(
      {required this.platform,
      required this.platformUserId,
      this.displayName,
      required this.readingId});
  final String platform;
  final String platformUserId;
  final String? displayName;
  final int readingId;
}

/// กติกาคำต้องสงสัย (GET moderation/rules) — แก้ได้เฉพาะ extra_keywords
class ModerationRules {
  const ModerationRules({required this.defaults, required this.extra});
  final List<String> defaults;
  final List<String> extra;

  factory ModerationRules.fromJson(Map<String, dynamic> j) {
    List<String> list(dynamic v) => v is List
        ? v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return ModerationRules(
        defaults: list(j['default_keywords']),
        extra: list(j['extra_keywords']));
  }
}

// ───────────────────────── Repository ─────────────────────────

class ModerationRepository {
  ModerationRepository(this._api);
  final ApiClient _api;

  Future<SuspectsResult> suspects({required int hours}) => _safe(() async {
        final d = _m(await _api.get<dynamic>('/moderation/suspects',
            query: {'since_hours': hours, 'per_page': 100}));
        final raw = d['data'];
        final items = raw is List
            ? raw
                .whereType<Map>()
                .map((e) => Suspect.fromJson(e.cast<String, dynamic>()))
                .toList()
            : <Suspect>[];
        final kws = d['keywords_used'];
        return SuspectsResult(
          items: items,
          total: d['total'] == null ? items.length : TpFmt.toInt(d['total']),
          windowHours: d['window_hours'] == null
              ? hours
              : TpFmt.toInt(d['window_hours']),
          keywordCount: kws is List ? kws.length : 0,
        );
      });

  Future<Paged<BanEntry>> banned(
          {int page = 1, String? platform, String? search}) =>
      _safe(() async {
        final d = await _api.get<dynamic>('/moderation/banned', query: {
          'page': page,
          'per_page': 20,
          if (platform != null) 'platform': platform,
          if (search != null && search.isNotEmpty) 'search': search,
        });
        return Paged.parse(d, BanEntry.fromJson);
      });

  Future<BanIndex> activeBans() => _safe(() async {
        final d = await _api
            .get<dynamic>('/moderation/banned', query: {'per_page': 100});
        final p = Paged.parse(d, BanEntry.fromJson);
        return BanIndex(
          userIds: {
            for (final b in p.items)
              if (b.platformUserId.isNotEmpty) b.platformUserId
          },
          total: p.total,
        );
      });

  /// ดึงบิลจริงเพื่อหา platform + ID ที่ถูกต้อง (LINE เก็บใน platform_user_id ไม่ใช่ facebook_user_id)
  /// คืน null ถ้าบิลนี้ไม่มีบัญชีแชท (เช่น ดูดวงผ่านเว็บ)
  Future<BanTarget?> resolveTarget(int readingId) => _safe(() async {
        final d = _m(await _api.get<dynamic>('/fortune/readings/$readingId',
            query: {'preview': 1}));
        final platform = (d['platform'] ?? '').toString().trim().toLowerCase();
        final pid = _str(d['platform_user_id']) ?? _str(d['facebook_user_id']);
        if (pid == null) return null;
        return BanTarget(
          platform: const {'facebook', 'line', 'telegram'}.contains(platform)
              ? platform
              : 'facebook',
          platformUserId: pid,
          displayName:
              _str(d['facebook_user_name']) ?? _str(_m(d['user'])['name']),
          readingId: readingId,
        );
      });

  /// แบน — [minutes] null = ถาวร
  Future<String?> ban(BanTarget t, {int? minutes, required String reason}) =>
      _safe(() async {
        final (_, msg) = await _action('POST', '/moderation/ban', {
          'platform': t.platform,
          'platform_user_id': t.platformUserId,
          if (t.displayName != null) 'display_name': t.displayName,
          'reason': reason,
          if (minutes != null) 'minutes': minutes,
        });
        return msg;
      });

  Future<String?> unban(int banId) => _safe(() async {
        final (_, msg) =
            await _action('POST', '/moderation/unban/$banId', null);
        return msg;
      });

  Future<ModerationRules> rules() => _safe(() async {
        final d = await _api.get<dynamic>('/moderation/rules');
        return ModerationRules.fromJson(_m(d));
      });

  /// บันทึกคำต้องสงสัยเพิ่มเติม (แทนที่ทั้งชุด) — คืน (รายการที่บันทึกจริง, ข้อความ)
  Future<(List<String>, String?)> saveRules(List<String> extra) =>
      _safe(() async {
        final (data, msg) = await _action(
            'PUT', '/moderation/rules', {'extra_keywords': extra});
        final saved = data['extra_keywords'];
        return (saved is List ? saved.map((e) => '$e').toList() : extra, msg);
      });

  /// POST/PUT ที่ต้องการทั้ง data และ message — แปลง success:false เป็นข้อความไทย
  Future<(Map<String, dynamic>, String?)> _action(
      String method, String path, Object? data) async {
    final res = method == 'PUT'
        ? await _api.dio.put<Map<String, dynamic>>(path, data: data)
        : await _api.dio.post<Map<String, dynamic>>(path, data: data);
    final body = res.data ?? const {};
    final code = res.statusCode ?? 0;
    if (code >= 400 || body['success'] != true) {
      final msg = (body['message'] ?? '').toString();
      if (code == 401) {
        ApiClient.onUnauthorized?.call();
        throw ActionError('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
      }
      if (code == 403) throw ActionError('บัญชีนี้ไม่มีสิทธิ์ทำรายการนี้');
      if (code == 404) {
        throw ActionError('ไม่พบรายการนี้แล้ว (อาจถูกปลดแบนหรือลบไปก่อนหน้า)');
      }
      if (code == 429) {
        throw ActionError('ทำรายการถี่เกินไป รอสักครู่แล้วลองใหม่');
      }
      throw ActionError(_hasThai(msg)
          ? msg
          : (code == 422
              ? 'ข้อมูลไม่ถูกต้อง ตรวจสอบแล้วลองใหม่'
              : 'ทำรายการไม่สำเร็จ ($code)'));
    }
    final msg = body['message']?.toString();
    return (_m(body['data']), (msg != null && _hasThai(msg)) ? msg : null);
  }
}

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
    throw ActionError('โหลดข้อมูลไม่สำเร็จ (${e.statusCode})');
  }
}

final moderationRepositoryProvider = Provider<ModerationRepository>(
    (ref) => ModerationRepository(ref.watch(apiClientProvider)));

/// ผู้ต้องสงสัยตามช่วงเวลาที่สแกน (ชั่วโมง)
final suspectsProvider = FutureProvider.autoDispose.family<SuspectsResult, int>(
    (ref, hours) =>
        ref.watch(moderationRepositoryProvider).suspects(hours: hours));

final activeBansProvider = FutureProvider.autoDispose<BanIndex>(
    (ref) => ref.watch(moderationRepositoryProvider).activeBans());

final moderationRulesProvider = FutureProvider.autoDispose<ModerationRules>(
    (ref) => ref.watch(moderationRepositoryProvider).rules());
