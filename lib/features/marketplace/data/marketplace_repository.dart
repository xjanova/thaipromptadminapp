import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import '../../../shared/ui/tp_format.dart';

Map<String, dynamic> _m(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};

String? _s(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

/// ช่วงเวลาของการ์ดสรุป (ตรงกับ `marketplace/dashboard?period=`)
enum MarketPeriod {
  today('today', 'วันนี้'),
  week('week', 'สัปดาห์นี้'),
  month('month', 'เดือนนี้');

  const MarketPeriod(this.key, this.label);
  final String key;
  final String label;
}

/// สถานะออเดอร์ที่ใช้กรอง (ตรงกับ `marketplace/orders?status=` = คอลัมน์ order_status)
enum MarketOrderStatus {
  pending('pending', 'รอดำเนินการ'),
  processing('processing', 'กำลังเตรียม'),
  shipped('shipped', 'จัดส่งแล้ว'),
  delivered('delivered', 'ส่งถึงแล้ว'),
  completed('completed', 'สำเร็จ'),
  cancelled('cancelled', 'ยกเลิก'),
  refunded('refunded', 'คืนเงิน');

  const MarketOrderStatus(this.key, this.label);
  final String key;
  final String label;

  /// อ่านค่าจากแพลตฟอร์ม (ตัวพิมพ์/สะกดต่างกันได้ เช่น canceled) — ไม่รู้จัก = null
  static MarketOrderStatus? parse(String? v) {
    final k = (v ?? '').trim().toLowerCase();
    if (k.isEmpty) return null;
    if (k == 'canceled') return MarketOrderStatus.cancelled;
    if (k == 'complete' || k == 'fulfilled') return MarketOrderStatus.completed;
    for (final s in MarketOrderStatus.values) {
      if (s.key == k) return s;
    }
    return null;
  }
}

/// ชื่อแพลตฟอร์มที่แสดงให้แอดมิน
String marketPlatformLabel(String? code) {
  final c = (code ?? '').toLowerCase();
  if (c.contains('lazada')) return 'Lazada';
  if (c.contains('shopee')) return 'Shopee';
  if (c.contains('tiktok')) return 'TikTok Shop';
  if (c.isEmpty || c == 'unknown') return 'ไม่ระบุแพลตฟอร์ม';
  return code!;
}

/// สถานะการชำระเงินภาษาไทย (null = แพลตฟอร์มไม่ส่งมา)
String? marketPaymentLabel(String? v) => switch ((v ?? '').toLowerCase()) {
      '' => null,
      'paid' || 'settled' => 'ชำระแล้ว',
      'pending' || 'unpaid' => 'รอชำระ',
      'refunded' => 'คืนเงินแล้ว',
      'failed' => 'ชำระไม่สำเร็จ',
      'cancelled' || 'canceled' => 'ยกเลิก',
      _ => 'อื่น ๆ',
    };

/// สถานะการจัดส่งภาษาไทย
String? marketFulfillmentLabel(String? v) => switch ((v ?? '').toLowerCase()) {
      '' => null,
      'unfulfilled' || 'pending' => 'ยังไม่จัดส่ง',
      'processing' || 'ready_to_ship' => 'กำลังเตรียมส่ง',
      'shipped' || 'in_transit' => 'อยู่ระหว่างขนส่ง',
      'delivered' || 'fulfilled' => 'ส่งถึงแล้ว',
      'returned' => 'ตีกลับ',
      'cancelled' || 'canceled' => 'ยกเลิก',
      _ => 'อื่น ๆ',
    };

// ───────────────────────── โมเดล ─────────────────────────

/// สรุปร้านค้า จาก `GET marketplace/dashboard`
class MarketplaceDashboard {
  const MarketplaceDashboard({
    this.totalRevenue = 0,
    this.ordersCount = 0,
    this.productsCount = 0,
    this.pendingCommissions = 0,
    this.platforms = const [],
    this.generatedAt,
  });

  /// ยอดขายที่ชำระแล้วในช่วงเวลา (payment_status = paid)
  final double totalRevenue;

  /// จำนวนออเดอร์ทั้งหมดในช่วงเวลา
  final int ordersCount;

  /// สินค้าที่เปิดขายอยู่ (ทั้งระบบ ไม่ขึ้นกับช่วงเวลา)
  final int productsCount;

  /// คอมมิชชันที่ยังรอจ่าย (ทั้งระบบ)
  final double pendingCommissions;
  final List<MarketplacePlatform> platforms;
  final DateTime? generatedAt;

  factory MarketplaceDashboard.fromJson(Map<String, dynamic> j) {
    final hero = _m(j['hero']);
    final ps = j['platforms'];
    return MarketplaceDashboard(
      totalRevenue: TpFmt.toDouble(hero['total_revenue_thb']),
      ordersCount: TpFmt.toInt(hero['orders_count']),
      productsCount: TpFmt.toInt(hero['products_count']),
      pendingCommissions: TpFmt.toDouble(hero['pending_commissions_thb']),
      platforms: ps is List
          ? ps.whereType<Map>().map((e) => MarketplacePlatform.fromJson(e.cast<String, dynamic>())).toList()
          : const [],
      generatedAt: TpFmt.parse(j['generated_at']),
    );
  }
}

/// บัญชีแพลตฟอร์มที่เชื่อมอยู่ (Lazada / Shopee / TikTok)
class MarketplacePlatform {
  const MarketplacePlatform({required this.id, required this.name, this.platform, this.isActive = false, this.lastSyncAt});
  final int id;
  final String name;
  final String? platform;
  final bool isActive;
  final DateTime? lastSyncAt;

  /// ไม่ได้ซิงก์เกิน 24 ชม. = น่าจะค้าง
  bool get syncStale => lastSyncAt == null || DateTime.now().difference(lastSyncAt!).inHours >= 24;

  factory MarketplacePlatform.fromJson(Map<String, dynamic> j) => MarketplacePlatform(
        id: TpFmt.toInt(j['id']),
        name: _s(j['name']) ?? marketPlatformLabel(_s(j['platform'])),
        platform: _s(j['platform']),
        isActive: j['is_active'] == true || j['is_active'] == 1,
        lastSyncAt: TpFmt.parse(j['last_sync_at']),
      );
}

/// ออเดอร์ 1 รายการ จาก `GET marketplace/orders`
class MarketplaceOrder {
  const MarketplaceOrder({
    required this.id,
    required this.orderNumber,
    this.externalOrderId,
    this.platform,
    this.customerName,
    this.totalAmount = 0,
    this.commissionAmount = 0,
    this.orderStatus = '',
    this.paymentStatus,
    this.fulfillmentStatus,
    this.orderedAt,
  });

  final int id;
  final String orderNumber;
  final String? externalOrderId;
  final String? platform;
  final String? customerName;
  final double totalAmount;
  final double commissionAmount;
  final String orderStatus;
  final String? paymentStatus;
  final String? fulfillmentStatus;
  final DateTime? orderedAt;

  MarketOrderStatus? get status => MarketOrderStatus.parse(orderStatus);

  /// ป้ายสถานะภาษาไทย (สถานะที่ไม่รู้จักจากแพลตฟอร์ม = "สถานะอื่น")
  String get statusLabel => status?.label ?? (orderStatus.isEmpty ? 'ไม่ระบุสถานะ' : 'สถานะอื่น');

  factory MarketplaceOrder.fromJson(Map<String, dynamic> j) => MarketplaceOrder(
        id: TpFmt.toInt(j['id']),
        orderNumber: _s(j['order_number']) ?? '#${j['id']}',
        externalOrderId: _s(j['external_order_id']),
        platform: _s(j['platform']),
        customerName: _s(j['customer_name']),
        totalAmount: TpFmt.toDouble(j['total_amount']),
        commissionAmount: TpFmt.toDouble(j['commission_amount']),
        orderStatus: (_s(j['order_status']) ?? '').toLowerCase(),
        paymentStatus: _s(j['payment_status']),
        fulfillmentStatus: _s(j['fulfillment_status']),
        orderedAt: TpFmt.parse(j['ordered_at']),
      );
}

// ───────────────────────── Repository ─────────────────────────

/// ร้านค้าออนไลน์ (ออเดอร์จากแพลตฟอร์มพันธมิตร) — อ่านอย่างเดียว · backend ไม่มี endpoint สินค้า
class MarketplaceRepository {
  MarketplaceRepository(this._api);
  final ApiClient _api;

  /// `GET marketplace/dashboard?period=today|week|month`
  Future<MarketplaceDashboard> dashboard({MarketPeriod period = MarketPeriod.month}) => _guard(() async {
        final data = await _api.get<dynamic>('/marketplace/dashboard', query: {'period': period.key});
        return MarketplaceDashboard.fromJson(_m(data));
      });

  /// `GET marketplace/orders?status=&search=&page=&per_page=`
  Future<Paged<MarketplaceOrder>> orders({int page = 1, String? status, String? search, int perPage = 20}) =>
      _guard(() async {
        final data = await _api.get<dynamic>('/marketplace/orders', query: {
          'page': page,
          'per_page': perPage,
          if (status != null && status.isNotEmpty) 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
        });
        return Paged.parse(data, MarketplaceOrder.fromJson);
      });

  /// จำนวนออเดอร์ต่อสถานะ (backend ไม่มี endpoint นับ → ขอทีละสถานะแบบ per_page=1 แล้วอ่าน total)
  ///
  /// คีย์ '' = ทั้งหมด · สถานะไหนล้มจะไม่มีในผลลัพธ์ (ชิปไม่แสดงตัวเลข) ไม่ทำให้ทั้งก้อนล้ม
  Future<Map<String, int>> statusCounts() async {
    final keys = ['', ...MarketOrderStatus.values.map((s) => s.key)];
    final results = await Future.wait(keys.map((k) async {
      try {
        final p = await orders(status: k, perPage: 1);
        return MapEntry(k, p.total);
      } catch (_) {
        return null;
      }
    }));
    return {for (final e in results.whereType<MapEntry<String, int>>()) e.key: e.value};
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (e.type == DioExceptionType.badResponse && code >= 500) {
        throw ActionError('เซิร์ฟเวอร์ขัดข้องชั่วคราว ($code) ลองใหม่อีกครั้ง');
      }
      rethrow;
    }
  }
}

final marketplaceRepositoryProvider =
    Provider<MarketplaceRepository>((ref) => MarketplaceRepository(ref.watch(apiClientProvider)));

final marketplaceDashboardProvider = FutureProvider.autoDispose
    .family<MarketplaceDashboard, MarketPeriod>((ref, p) => ref.watch(marketplaceRepositoryProvider).dashboard(period: p));

final marketplaceStatusCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) => ref.watch(marketplaceRepositoryProvider).statusCounts());
