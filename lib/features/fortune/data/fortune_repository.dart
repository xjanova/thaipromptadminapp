import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/mock/mock_config.dart';
import '../../../core/mock/mock_data.dart';
import '../../finance/data/finance_repository.dart' show PagedResult;
import 'models/fortune_models.dart';

/// Repository สำหรับ /api/admin/fortune/*
class FortuneRepository {
  FortuneRepository(this._api);
  final ApiClient _api;

  Future<FortuneDashboardData> dashboard({String period = 'month'}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/fortune/dashboard',
      query: {'period': period},
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return FortuneDashboardData.fromJson(json);
  }

  Future<PagedResult<FortuneReading>> readings({
    int page = 1,
    String? search,
    bool? isPaid,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/fortune/readings',
      query: {
        'page': page,
        if (search != null && search.isNotEmpty) 'search': search,
        if (isPaid != null) 'is_paid': isPaid ? 1 : 0,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return PagedResult.fromJson<FortuneReading>(json, FortuneReading.fromJson);
  }

  Future<Map<String, dynamic>> readingStats() async {
    return _api.get<Map<String, dynamic>>(
      '/fortune/readings/stats',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
  }

  // ── Bills ──
  Future<PagedResult<FortuneBill>> bills({
    int page = 1,
    String? status,
    String? tier,
    String? search,
  }) async {
    if (kMockMode) return mockDelay(Mock.fortuneBills(status: status, tier: tier));
    final json = await _api.get<Map<String, dynamic>>(
      '/fortune/bills',
      query: {
        'page': page,
        if (status != null) 'status': status,
        if (tier != null) 'tier': tier,
        if (search != null && search.isNotEmpty) 'search': search,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return PagedResult.fromJson<FortuneBill>(json, FortuneBill.fromJson);
  }

  Future<FortuneBillStats> billStats() async {
    if (kMockMode) return mockDelay(Mock.fortuneBillStats());
    final json = await _api.get<Map<String, dynamic>>(
      '/fortune/bills/stats',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return FortuneBillStats.fromJson(json);
  }

  Future<void> approveBill(int id) async {
    if (kMockMode) {
      Mock.setBillStatus(id, 'confirmed');
      await mockDelay(null);
      return;
    }
    await _api.post<dynamic>('/fortune/bills/$id/approve');
  }

  Future<void> rejectBill(int id, String reason) async {
    if (kMockMode) {
      Mock.setBillStatus(id, 'rejected', rejectReason: reason);
      await mockDelay(null);
      return;
    }
    await _api.post<dynamic>(
      '/fortune/bills/$id/reject',
      data: {'reason': reason},
    );
  }

  Future<void> refundBill(int id, String reason) async {
    if (kMockMode) {
      Mock.setBillStatus(id, 'refunded', rejectReason: reason);
      await mockDelay(null);
      return;
    }
    await _api.post<dynamic>(
      '/fortune/bills/$id/refund',
      data: {'reason': reason},
    );
  }

  /// Resend last card image (for stuck readings — pattern from
  /// "Fortune LINE Celtic — recovery patterns" brain note)
  Future<void> resendLastImage(int id) async {
    if (kMockMode) {
      await mockDelay(null);
      return;
    }
    await _api.post<dynamic>('/fortune/bills/$id/resend-image');
  }

  // ── Active Readings (Live monitor) ──
  Future<List<FortuneActiveReading>> activeReadings() async {
    if (kMockMode) return mockDelay(Mock.fortuneActiveReadings());
    final json = await _api.get<Map<String, dynamic>>(
      '/fortune/active-readings',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    final list = (json['data'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((m) => FortuneActiveReading.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Admin Ask AI — sync AJAX takeover (pattern from
  /// [[2026-05-17-fortune-celtic-admin-ai-debug-tools-bill-race-lock]])
  /// admin waits 30-60s; bypasses canAskMoreCeltic + time window;
  /// uses MAX(seq)+1 + retry to avoid race with customer thread
  Future<void> adminAskAi(int readingId, String question) async {
    if (kMockMode) {
      Mock.markAdminTakeover(readingId);
      // realistic AI takeover delay (1-2s in mock to feel responsive)
      await mockDelay(null, delay: const Duration(milliseconds: 1200));
      return;
    }
    await _api.post<dynamic>(
      '/fortune/active-readings/$readingId/admin-ask-ai',
      data: {'question': question},
    );
  }

  /// Admin sends a text message to customer (bypassing bot)
  Future<void> sendAdminMessage(int readingId, String text) async {
    if (kMockMode) {
      await mockDelay(null);
      return;
    }
    await _api.post<dynamic>(
      '/fortune/active-readings/$readingId/send-message',
      data: {'text': text},
    );
  }

  /// Cancel reading + refund (combined safety hatch)
  Future<void> cancelReading(int readingId, String reason) async {
    if (kMockMode) {
      Mock.cancelActiveReading(readingId);
      await mockDelay(null);
      return;
    }
    await _api.post<dynamic>(
      '/fortune/active-readings/$readingId/cancel',
      data: {'reason': reason},
    );
  }
}

final fortuneRepositoryProvider = Provider<FortuneRepository>((ref) {
  return FortuneRepository(ref.watch(apiClientProvider));
});

final fortuneDashboardProvider = FutureProvider<FortuneDashboardData>((ref) async {
  if (kMockMode) return mockDelay(Mock.fortuneDashboard());
  return ref.watch(fortuneRepositoryProvider).dashboard();
});

final fortuneReadingsProvider = FutureProvider<PagedResult<FortuneReading>>((ref) async {
  if (kMockMode) return mockDelay(Mock.fortuneReadings());
  return ref.watch(fortuneRepositoryProvider).readings();
});

/// Bills list filtered by status (null = all)
final fortuneBillsProvider =
    FutureProvider.family<PagedResult<FortuneBill>, String?>(
        (ref, status) async {
  return ref.watch(fortuneRepositoryProvider).bills(status: status);
});

final fortuneBillStatsProvider = FutureProvider<FortuneBillStats>((ref) async {
  return ref.watch(fortuneRepositoryProvider).billStats();
});

/// Active readings (Live monitor) — auto-refresh ทุก 10s ด้วย Timer
/// ใน UI (Riverpod ไม่มี polling built-in — ใช้ `ref.invalidate()` แทน)
final fortuneActiveReadingsProvider =
    FutureProvider<List<FortuneActiveReading>>((ref) async {
  return ref.watch(fortuneRepositoryProvider).activeReadings();
});
