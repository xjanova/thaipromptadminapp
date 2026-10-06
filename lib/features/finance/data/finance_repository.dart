import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import '../../../shared/ui/tp_format.dart';

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

String? _s(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

final _thaiChar = RegExp(r'[฀-๿]');
final _emoji = RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
    unicode: true);

/// ตัดอีโมจิ + คำอังกฤษ "wallet" ออกจากข้อความที่จะแสดง
String _tidy(String s) => s
    .replaceAll(_emoji, '')
    .replaceAll(RegExp(r'\s*wallet\s*', caseSensitive: false), 'กระเป๋า')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

// ───────────────────────── สถานะกระเป๋า ─────────────────────────

/// ตัวกรองสถานะกระเป๋า (ตรงกับ `finance/wallets?status=`)
enum WalletStatusFilter {
  all('', 'ทั้งหมด'),
  active('active', 'ใช้งานปกติ'),
  locked('locked', 'ล็อกอยู่'),
  suspended('suspended', 'ถูกระงับ');

  const WalletStatusFilter(this.key, this.label);
  final String key;
  final String label;
}

/// สถานะที่หน้าจอใช้ตัดสินใจ (รวม "ล็อกชั่วคราว" จากการใส่ PIN ผิด)
enum WalletState { active, locked, suspended, inactive }

// ───────────────────────── โมเดล ─────────────────────────

/// กระเป๋าเงินสมาชิก จาก `finance/wallets` (WalletResource)
class AdminWallet {
  const AdminWallet({
    required this.id,
    required this.address,
    required this.balance,
    this.currency,
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.status = '',
    this.isActive = false,
    this.isLocked = false,
    this.lockedUntil,
    this.failedAttempts = 0,
    this.twoFactorEnabled = false,
    this.userId,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.lastTransactionAt,
    this.createdAt,
  });

  final int id;
  final String address;
  final double balance;
  final String? currency;
  final double totalIncome;
  final double totalExpense;
  final String status;
  final bool isActive;
  final bool isLocked;
  final DateTime? lockedUntil;
  final int failedAttempts;
  final bool twoFactorEnabled;
  final int? userId;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final DateTime? lastTransactionAt;
  final DateTime? createdAt;

  WalletState get state {
    if (status == 'suspended') return WalletState.suspended;
    if (isLocked || status == 'locked') return WalletState.locked;
    if (status == 'active' || isActive) return WalletState.active;
    return WalletState.inactive;
  }

  /// ล็อกชั่วคราวจากใส่ PIN ผิด (สถานะยัง active แต่มี locked_until ในอนาคต)
  bool get isTempLocked => status == 'active' && isLocked;

  /// เพิ่มเงินได้เฉพาะกระเป๋าที่ใช้งานปกติ (WalletService::deposit ตรวจ isActive)
  bool get canCredit => isActive;

  String get ownerName => (userName != null && userName!.isNotEmpty)
      ? userName!
      : (userEmail ?? 'สมาชิก');

  /// ที่อยู่กระเป๋าแบบย่อ (ไว้แสดงในรายการ)
  String get shortAddress {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}…${address.substring(address.length - 4)}';
  }

  factory AdminWallet.fromJson(Map<String, dynamic> j) {
    // show/adjust ห่อมาเป็น {wallet:{...}}
    if (!j.containsKey('id') && j['wallet'] is Map) {
      return AdminWallet.fromJson(_m(j['wallet']));
    }
    final u = _m(j['user']);
    return AdminWallet(
      id: TpFmt.toInt(j['id']),
      address: _s(j['wallet_address']) ?? '',
      balance: TpFmt.toDouble(j['balance']),
      currency: _s(j['currency']),
      totalIncome: TpFmt.toDouble(j['total_income']),
      totalExpense: TpFmt.toDouble(j['total_expense']),
      status: (_s(j['status']) ?? '').toLowerCase(),
      isActive: _b(j['is_active']),
      isLocked: _b(j['is_locked']),
      lockedUntil: TpFmt.parse(j['locked_until']),
      failedAttempts: TpFmt.toInt(j['failed_attempts']),
      twoFactorEnabled: _b(j['two_factor_enabled']),
      userId: u['id'] == null ? null : TpFmt.toInt(u['id']),
      userName: _s(u['name']),
      userEmail: _s(u['email']),
      userPhone: _s(u['phone']),
      lastTransactionAt: TpFmt.parse(j['last_transaction_at']),
      createdAt: TpFmt.parse(j['created_at']),
    );
  }
}

/// สถิติกระเป๋าทั้งระบบ จาก `finance/wallets/system-stats`
class WalletSystemStats {
  const WalletSystemStats({
    this.totalWallets = 0,
    this.activeWallets = 0,
    this.suspendedWallets = 0,
    this.lockedWallets = 0,
    this.totalBalance = 0,
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.todayTransactions = 0,
    this.todayVolume = 0,
    this.monthlyTransactions = 0,
    this.monthlyVolume = 0,
    this.averageBalance = 0,
  });

  final int totalWallets;
  final int activeWallets;
  final int suspendedWallets;
  final int lockedWallets;
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final int todayTransactions;
  final double todayVolume;

  /// 30 วันล่าสุด
  final int monthlyTransactions;
  final double monthlyVolume;
  final double averageBalance;

  int count(WalletStatusFilter f) => switch (f) {
        WalletStatusFilter.all => totalWallets,
        WalletStatusFilter.active => activeWallets,
        WalletStatusFilter.locked => lockedWallets,
        WalletStatusFilter.suspended => suspendedWallets,
      };

  factory WalletSystemStats.fromJson(Map<String, dynamic> j) =>
      WalletSystemStats(
        totalWallets: TpFmt.toInt(j['total_wallets']),
        activeWallets: TpFmt.toInt(j['active_wallets']),
        suspendedWallets: TpFmt.toInt(j['suspended_wallets']),
        lockedWallets: TpFmt.toInt(j['locked_wallets']),
        totalBalance: TpFmt.toDouble(j['total_balance']),
        totalIncome: TpFmt.toDouble(j['total_income']),
        totalExpense: TpFmt.toDouble(j['total_expense']),
        todayTransactions: TpFmt.toInt(j['today_transactions']),
        todayVolume: TpFmt.toDouble(j['today_volume']),
        monthlyTransactions: TpFmt.toInt(j['monthly_transactions']),
        monthlyVolume: TpFmt.toDouble(j['monthly_volume']),
        averageBalance: TpFmt.toDouble(j['average_balance']),
      );
}

/// รายละเอียดกระเป๋า 1 ใบ จาก `finance/wallets/{id}` = {wallet, stats}
class WalletDetail {
  const WalletDetail({
    required this.wallet,
    this.transactionsCount = 0,
    this.last30Income = 0,
    this.last30Expense = 0,
    this.monthIncome = 0,
    this.monthExpense = 0,
  });

  final AdminWallet wallet;
  final int transactionsCount;
  final double last30Income;
  final double last30Expense;
  final double monthIncome;
  final double monthExpense;

  factory WalletDetail.fromJson(Map<String, dynamic> j) {
    final st = _m(j['stats']);
    return WalletDetail(
      wallet: AdminWallet.fromJson(
          _m(j['wallet']).isNotEmpty ? _m(j['wallet']) : j),
      transactionsCount: TpFmt.toInt(st['transactions_count']),
      last30Income: TpFmt.toDouble(st['last_30_days_income']),
      last30Expense: TpFmt.toDouble(st['last_30_days_expense']),
      monthIncome: TpFmt.toDouble(st['this_month_income']),
      monthExpense: TpFmt.toDouble(st['this_month_expense']),
    );
  }
}

/// รายการเคลื่อนไหวในกระเป๋า จาก `finance/wallets/transactions` (WalletTransactionResource)
class WalletTxn {
  const WalletTxn({
    required this.id,
    required this.type,
    required this.amount,
    this.transactionId,
    this.status = '',
    this.balanceBefore,
    this.balanceAfter,
    this.description,
    this.referenceType,
    this.createdAt,
  });

  final int id;
  final String? transactionId;
  final String type;
  final String status;
  final double amount;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? description;
  final String? referenceType;
  final DateTime? createdAt;

  static const _creditTypes = {
    'deposit',
    'transfer_in',
    'commission',
    'bonus',
    'refund',
    'cashback'
  };

  bool get isAdminAdjustment => referenceType == 'admin_adjustment';

  /// เงินเข้า (ดูจากยอดก่อน/หลังก่อน ถ้าไม่มีค่อยเดาจากประเภท)
  bool get isCredit {
    final a = balanceAfter, b = balanceBefore;
    if (a != null && b != null && (a - b).abs() >= 0.005) return a > b;
    return _creditTypes.contains(type);
  }

  String get typeLabel {
    if (isAdminAdjustment) return isCredit ? 'แอดมินเพิ่มยอด' : 'แอดมินหักยอด';
    return switch (type) {
      'deposit' => 'ฝากเงิน',
      'withdrawal' => 'ถอนเงิน',
      'transfer_in' => 'รับโอน',
      'transfer_out' => 'โอนออก',
      'commission' => 'คอมมิชชั่น',
      'refund' => 'คืนเงิน',
      'fee' => 'ค่าธรรมเนียม',
      'bonus' => 'โบนัส',
      'cashback' => 'เงินคืน',
      'payment' || 'purchase' => 'ชำระเงิน',
      _ => 'รายการอื่น',
    };
  }

  String get statusLabel => switch (status) {
        'completed' => 'สำเร็จ',
        'processing' => 'กำลังดำเนินการ',
        'pending' => 'รอดำเนินการ',
        'failed' => 'ล้มเหลว',
        'cancelled' => 'ยกเลิก',
        _ => 'ไม่ทราบสถานะ',
      };

  /// คำอธิบายที่แสดงได้ (เฉพาะที่เป็นภาษาไทย · ตัดคำนำหน้า "การปรับยอดโดยแอดมิน:" ออกเหลือเหตุผล)
  String? get note {
    final d = description;
    if (d == null || !_thaiChar.hasMatch(d)) return null;
    var t = _tidy(d);
    const prefix = 'การปรับยอดโดยแอดมิน:';
    if (t.startsWith(prefix)) t = t.substring(prefix.length).trim();
    return t.isEmpty ? null : t;
  }

  factory WalletTxn.fromJson(Map<String, dynamic> j) {
    final ref = _m(j['reference']);
    return WalletTxn(
      id: TpFmt.toInt(j['id']),
      transactionId: _s(j['transaction_id']),
      type: (_s(j['type']) ?? '').toLowerCase(),
      status: (_s(j['status']) ?? '').toLowerCase(),
      amount: TpFmt.toDouble(j['amount']).abs(),
      balanceBefore: j['balance_before'] == null
          ? null
          : TpFmt.toDouble(j['balance_before']),
      balanceAfter: j['balance_after'] == null
          ? null
          : TpFmt.toDouble(j['balance_after']),
      description: _s(j['description']),
      referenceType: _s(ref['type'] ?? j['reference_type']),
      createdAt: TpFmt.parse(j['created_at']),
    );
  }
}

/// ทำรายการแล้วแต่ไม่ได้คำตอบ (เน็ตหลุด/หมดเวลา) — รายการ "อาจ" สำเร็จแล้วที่เซิร์ฟเวอร์
///
/// หน้าจอต้องโหลดรายการล่าสุดให้แอดมินตรวจก่อน ห้ามให้กดซ้ำทันที (กันปรับยอดซ้ำสองรอบ)
class UncertainActionError extends ActionError {
  UncertainActionError(super.message);
}

/// backend ตอบ 403 (ไม่มีสิทธิ์ manage_wallets) — หน้าจอใช้เทียบเพื่อซ่อนปุ่มจัดการ
class WalletForbiddenError extends ActionError {
  WalletForbiddenError() : super('บัญชีนี้ไม่มีสิทธิ์จัดการกระเป๋าเงิน');
}

/// ผลของการกระทำกับกระเป๋า: ข้อความไทยจาก backend + กระเป๋าหลังเปลี่ยน (ถ้ามี)
class WalletActionResult {
  const WalletActionResult(this.message, this.wallet);
  final String message;
  final AdminWallet? wallet;
}

// ───────────────────────── Repository ─────────────────────────

/// กระเป๋าเงินสมาชิก (`/api/admin/finance/wallets*`)
///
/// การกระทำทั้งหมด backend ตรวจสิทธิ์ `manage_wallets` / `view_all_wallets` (super admin ผ่านเสมอ)
class FinanceRepository {
  FinanceRepository(this._api);
  final ApiClient _api;

  /// `GET finance/wallets?search=&status=&user_id=&page=&per_page=`
  Future<Paged<AdminWallet>> wallets({
    int page = 1,
    String? search,
    WalletStatusFilter status = WalletStatusFilter.all,
    int? userId,
    int perPage = 20,
  }) =>
      _guard(() async {
        final data = await _api.get<dynamic>('/finance/wallets', query: {
          'page': page,
          'per_page': perPage,
          if (search != null && search.isNotEmpty) 'search': search,
          if (status.key.isNotEmpty) 'status': status.key,
          if (userId != null) 'user_id': userId,
        });
        return Paged.parse(data, AdminWallet.fromJson);
      });

  /// `GET finance/wallets/system-stats`
  Future<WalletSystemStats> systemStats() => _guard(() async {
        final data = await _api.get<dynamic>('/finance/wallets/system-stats');
        return WalletSystemStats.fromJson(_m(data));
      });

  /// `GET finance/wallets/{id}`
  Future<WalletDetail> wallet(int id) => _guard(() async {
        final data = await _api.get<dynamic>('/finance/wallets/$id');
        return WalletDetail.fromJson(_m(data));
      });

  /// `GET finance/wallets/transactions?wallet_id=&page=&per_page=`
  Future<Paged<WalletTxn>> transactions(
          {required int walletId, int page = 1, int perPage = 15}) =>
      _guard(() async {
        final data =
            await _api.get<dynamic>('/finance/wallets/transactions', query: {
          'wallet_id': walletId,
          'page': page,
          'per_page': perPage,
        });
        return Paged.parse(data, WalletTxn.fromJson);
      });

  /// `POST finance/wallets/{id}/adjust` body `{amount: "-150.00", reason}` — เงินเข้า/ออกจริง
  ///
  /// [amount] ส่งเป็นสตริงทศนิยม 2 ตำแหน่ง (กันปัดเศษ double) · ห้ามเป็น 0
  Future<WalletActionResult> adjust(int id,
          {required String amount, required String reason}) =>
      _act('/finance/wallets/$id/adjust', {'amount': amount, 'reason': reason},
          fallback: 'ปรับยอดไม่สำเร็จ', money: true);

  /// `POST finance/wallets/{id}/lock`
  Future<WalletActionResult> lock(int id) =>
      _act('/finance/wallets/$id/lock', const {},
          fallback: 'ล็อกกระเป๋าไม่สำเร็จ');

  /// `POST finance/wallets/{id}/unlock` (ล้างจำนวนครั้งใส่ PIN ผิดด้วย)
  Future<WalletActionResult> unlock(int id) =>
      _act('/finance/wallets/$id/unlock', const {},
          fallback: 'ปลดล็อกกระเป๋าไม่สำเร็จ');

  /// `POST finance/wallets/{id}/suspend` body `{reason}` (บังคับ ≤ 500 ตัวอักษร)
  Future<WalletActionResult> suspend(int id, String reason) =>
      _act('/finance/wallets/$id/suspend', {'reason': reason},
          fallback: 'ระงับกระเป๋าไม่สำเร็จ');

  /// `POST finance/wallets/{id}/unsuspend` body `{reason}`
  Future<WalletActionResult> unsuspend(int id, String reason) =>
      _act('/finance/wallets/$id/unsuspend', {'reason': reason},
          fallback: 'ยกเลิกการระงับไม่สำเร็จ');

  Future<WalletActionResult> _act(String path, Map<String, dynamic> body,
      {required String fallback, bool money = false}) async {
    Response<Map<String, dynamic>> res;
    try {
      res = await _api.dio.post<Map<String, dynamic>>(path, data: body);
    } on DioException catch (e) {
      final r = e.response;
      if (r != null) {
        // 5xx (validateStatus ปล่อยเฉพาะ < 500)
        final data = r.data;
        throw ActionError(_clean(
            data is Map ? data['message']?.toString() : null,
            fallback,
            r.statusCode));
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          throw ActionError(
              'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ — ยังไม่ได้ทำรายการ ลองใหม่อีกครั้ง');
        case DioExceptionType.cancel:
          throw ActionError('ยกเลิกคำขอแล้ว — ยังไม่ได้ทำรายการ');
        default:
          // ส่งคำขอออกไปแล้วแต่ไม่ได้คำตอบ = อาจสำเร็จที่เซิร์ฟเวอร์
          if (money) {
            throw UncertainActionError(
                'เครือข่ายขาดระหว่างทำรายการ — ยังไม่รู้ว่าปรับยอดสำเร็จหรือไม่ '
                'ตรวจรายการล่าสุดก่อน อย่าเพิ่งทำซ้ำ');
          }
          throw ActionError(
              'เครือข่ายขาดระหว่างทำรายการ — โหลดข้อมูลใหม่เพื่อตรวจผล');
      }
    }
    final b = res.data ?? const <String, dynamic>{};
    final code = res.statusCode ?? 0;
    if (code == 401) ApiClient.onUnauthorized?.call();
    if (code == 403) throw WalletForbiddenError();
    if (code >= 400 || b['success'] != true) {
      throw ActionError(_failText(b, code, fallback));
    }
    final w = _m(_m(b['data'])['wallet']);
    return WalletActionResult(
      _tidy(_clean(b['message']?.toString(), 'ทำรายการสำเร็จ', code)),
      w.isEmpty ? null : AdminWallet.fromJson(w),
    );
  }

  /// ข้อความผิดพลาดภาษาไทยตามรหัส/ฟิลด์ที่ backend ตอบ
  String _failText(Map<String, dynamic> b, int code, String fallback) {
    if (code == 401) return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่';
    if (code == 404) return 'ไม่พบกระเป๋านี้ในระบบ (อาจถูกลบไปแล้ว)';
    if (code == 429) return 'ทำรายการถี่เกินไป รอสักครู่แล้วลองใหม่';
    if (code == 422) {
      final errors = _m(b['errors']);
      if (errors.containsKey('amount')) {
        return 'จำนวนเงินไม่ถูกต้อง (ต้องเป็นตัวเลขและไม่เป็น 0)';
      }
      if (errors.containsKey('reason')) {
        return 'กรุณาระบุเหตุผล (ไม่เกิน 500 ตัวอักษร)';
      }
    }
    return _clean(b['message']?.toString(), fallback, code);
  }

  /// เก็บเฉพาะข้อความไทย — ท่อนอังกฤษจาก exception ดิบ (เช่น "ปรับยอดไม่สำเร็จ: Wallet is not active") แปล/ตัดทิ้ง
  String _clean(String? raw, String fallback, int? code) {
    final m = (raw ?? '').trim();
    final lower = m.toLowerCase();
    if (lower.contains('below zero')) {
      return 'หักเกินยอดคงเหลือไม่ได้ — ยอดในกระเป๋าไม่พอ';
    }
    if (lower.contains('not active')) {
      return 'กระเป๋านี้ถูกล็อกหรือระงับอยู่ ต้องปลดก่อนจึงจะเพิ่มยอดได้';
    }
    if (m.isEmpty || !_thaiChar.hasMatch(m)) {
      return (code ?? 0) >= 500
          ? '$fallback (เซิร์ฟเวอร์ขัดข้อง $code)'
          : fallback;
    }
    final i = m.indexOf(':');
    if (i > 0 && !_thaiChar.hasMatch(m.substring(i + 1))) {
      return _tidy(m.substring(0, i));
    }
    return _tidy(m);
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

final financeRepositoryProvider = Provider<FinanceRepository>(
    (ref) => FinanceRepository(ref.watch(apiClientProvider)));

final walletSystemStatsProvider = FutureProvider.autoDispose<WalletSystemStats>(
    (ref) => ref.watch(financeRepositoryProvider).systemStats());

final walletDetailProvider = FutureProvider.autoDispose
    .family<WalletDetail, int>(
        (ref, id) => ref.watch(financeRepositoryProvider).wallet(id));

// ───────────────────────── ของเดิม (คงไว้ชั่วคราว) ─────────────────────────

/// ⚠️ คงไว้ให้ `features/ai/data/ai_repository.dart` ใช้จนกว่าจะย้ายไป [Paged] — ของใหม่ห้ามใช้
class PagedResult<T> {
  PagedResult(
      {required this.items,
      required this.currentPage,
      required this.lastPage,
      required this.total});
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  static PagedResult<T> fromJson<T>(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) itemParser) {
    final p = Paged.parse<T>(json, itemParser);
    return PagedResult<T>(
        items: p.items,
        currentPage: p.page,
        lastPage: p.lastPage,
        total: p.total);
  }
}
