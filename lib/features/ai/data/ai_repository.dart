import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import 'models/ai_models.dart';

export 'models/ai_models.dart';

Map<String, dynamic> _m(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};

bool _hasThai(String s) => RegExp(r'[฀-๿]').hasMatch(s);

/// ผลการกระทำ (เปิด/ปิด) — ของที่อัปเดตแล้ว + ข้อความไทยจาก backend (ถ้ามี)
class AiActionResult<T> {
  const AiActionResult(this.item, this.message);
  final T item;
  final String? message;
}

/// Repository สำหรับ `/api/admin/ai/*`
class AiRepository {
  AiRepository(this._api);
  final ApiClient _api;

  /// สรุปการใช้งาน (โทเคนเดือนนี้ · ค่าตอบสนอง 15 นาทีล่าสุด · จำนวนบอท)
  Future<AiOverview> overview() => _safe(() async {
        final d = await _api.get<dynamic>('/ai/dashboard', query: {'period': 'month'});
        return AiOverview.fromJson(_m(d));
      });

  /// คำขอรายชั่วโมง 24 ชม.ล่าสุด
  Future<AiUsageSeries> usage({int hours = 24}) => _safe(() async {
        final d = await _api.get<dynamic>('/ai/dashboard/timeseries', query: {'hours': hours});
        return AiUsageSeries.fromJson(_m(d), hours: hours);
      });

  /// การใช้งานแยกตามผู้ให้บริการ (มากไปน้อย)
  Future<List<AiProviderUsage>> perProvider({int hours = 24}) => _safe(() async {
        final d = await _api.get<dynamic>('/ai/usage/per-provider', query: {'hours': hours});
        final raw = _m(d)['providers'];
        final list = raw is List
            ? raw.whereType<Map>().map((e) => AiProviderUsage.fromJson(e.cast<String, dynamic>())).toList()
            : <AiProviderUsage>[];
        list.sort((a, b) {
          final r = b.requests.compareTo(a.requests);
          return r != 0 ? r : b.tokensMonth.compareTo(a.tokensMonth);
        });
        return list;
      });

  /// ผู้ให้บริการ AI ของระบบบอท (ตาราง ai_providers)
  Future<List<AiProviderItem>> providers() => _safe(() async {
        final d = await _api.get<dynamic>('/ai/providers');
        return Paged.parse(d, AiProviderItem.fromJson).items;
      });

  /// สลับเปิด/ปิดผู้ให้บริการ (backend สลับค่า ไม่ได้ตั้งค่า — ต้องเช็คผลที่คืนมา)
  Future<AiActionResult<AiProviderItem>> toggleProvider(int id) => _safe(() async {
        final (data, msg) = await _action('/ai/providers/$id/toggle');
        return AiActionResult(AiProviderItem.fromJson(data), msg);
      });

  Future<AiConnectionTest> testProvider(int id) => _safe(() async {
        final (data, _) = await _action('/ai/providers/$id/test-connection');
        return AiConnectionTest.fromJson(data);
      });

  /// รายการบอทแบบแบ่งหน้า (`{data, links, meta}`)
  Future<Paged<AiBotItem>> bots({int page = 1, bool? active, String? search}) => _safe(() async {
        final d = await _api.get<dynamic>('/ai/bots', query: {
          'page': page,
          'per_page': 20,
          if (active != null) 'active': active ? 1 : 0,
          if (search != null && search.isNotEmpty) 'search': search,
        });
        return Paged.parse(d, AiBotItem.fromJson);
      });

  Future<AiActionResult<AiBotItem>> toggleBot(int id) => _safe(() async {
        final (data, msg) = await _action('/ai/bots/$id/toggle');
        return AiActionResult(AiBotItem.fromJson(data), msg);
      });

  /// POST ที่ต้องการทั้ง data และ message — แปลง success:false เป็นข้อความไทย
  Future<(Map<String, dynamic>, String?)> _action(String path) async {
    final res = await _api.dio.post<Map<String, dynamic>>(path);
    final body = res.data ?? const {};
    final code = res.statusCode ?? 0;
    if (code == 401) ApiClient.onUnauthorized?.call();
    if (code >= 400 || body['success'] != true) {
      final msg = (body['message'] ?? '').toString();
      if (code == 401) throw ActionError('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
      if (code == 403) throw ActionError(_hasThai(msg) ? msg : 'บัญชีนี้ไม่มีสิทธิ์ทำรายการนี้');
      if (code == 404) throw ActionError('ไม่พบรายการนี้ในระบบ (อาจถูกลบไปแล้ว)');
      throw ActionError(_hasThai(msg) ? msg : 'ทำรายการไม่สำเร็จ ($code)');
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
    if (code >= 500) throw ActionError('เซิร์ฟเวอร์ขัดข้องชั่วคราว ($code) ลองใหม่อีกครั้ง');
    rethrow;
  } on ApiException catch (e) {
    if (const {401, 403, 404, 429}.contains(e.statusCode)) rethrow;
    if (_hasThai(e.message)) throw ActionError(e.message);
    throw ActionError('โหลดข้อมูล AI ไม่สำเร็จ (${e.statusCode})');
  }
}

// ── Providers (Riverpod) ──

final aiRepositoryProvider = Provider<AiRepository>((ref) => AiRepository(ref.watch(apiClientProvider)));

final aiOverviewProvider = FutureProvider.autoDispose<AiOverview>((ref) => ref.watch(aiRepositoryProvider).overview());

final aiUsageProvider = FutureProvider.autoDispose<AiUsageSeries>((ref) => ref.watch(aiRepositoryProvider).usage());

final aiPerProviderUsageProvider =
    FutureProvider.autoDispose<List<AiProviderUsage>>((ref) => ref.watch(aiRepositoryProvider).perProvider());

final aiProvidersProvider =
    FutureProvider.autoDispose<List<AiProviderItem>>((ref) => ref.watch(aiRepositoryProvider).providers());
