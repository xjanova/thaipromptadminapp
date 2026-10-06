import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import '../../../shared/ui/tp_format.dart';

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

// ───────────────────────── บิลดูดวง ─────────────────────────

/// สถานะบิลตามกลุ่มที่แอปแสดง (ตรงกับ backend `fortune/bills?status=`)
enum BillBucket {
  awaiting('awaiting', 'รอตรวจ'),
  unpaid('unpaid', 'รอโอน'),
  paid('paid', 'จ่ายแล้ว'),
  refunded('refunded', 'คืนเงิน'),
  cancelled('cancelled', 'ยกเลิก'),
  closed('closed', 'ปิดไม่ชำระ');

  const BillBucket(this.key, this.label);
  final String key;
  final String label;
}

class SmsMatch {
  const SmsMatch(
      {required this.matched, this.amount, this.at, this.bank, this.sender});
  final bool matched;
  final double? amount;
  final DateTime? at;
  final String? bank;
  final String? sender;

  factory SmsMatch.fromJson(dynamic j) {
    if (j == null) return const SmsMatch(matched: false);
    if (j is bool) return SmsMatch(matched: j);
    final m = _m(j);
    return SmsMatch(
      matched: m['matched'] == true,
      amount: m['amount'] == null ? null : TpFmt.toDouble(m['amount']),
      at: TpFmt.parse(m['at'] ?? m['sms_timestamp']),
      bank: m['bank']?.toString(),
      sender: m['sender']?.toString(),
    );
  }
}

class FortuneBill {
  const FortuneBill({
    required this.id,
    required this.billNumber,
    required this.packageLabel,
    required this.amount,
    required this.status,
    this.statusLabel,
    this.platform,
    this.customerName,
    this.createdAt,
    this.paidAt,
    this.slipUrl,
    this.sms = const SmsMatch(matched: false),
    this.question,
    this.priorPaid = 0,
    this.slipNeedsAuth = false,
    this.slipAt,
    this.statusReason,
    this.canMarkPaid,
    this.canRefund,
    this.canCancel,
    this.stageLabel,
    this.amountReceived,
  });

  final int id;
  final String billNumber;
  final String packageLabel;
  final double amount;
  final String status;
  final String? statusLabel;
  final String? platform;
  final String? customerName;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? slipUrl;
  final SmsMatch sms;
  final String? question;
  final int priorPaid;
  final bool slipNeedsAuth;
  final DateTime? slipAt;
  final String? statusReason;

  /// คำใบ้จาก backend ว่าปุ่มไหนกดได้ (null = backend ไม่ได้ส่ง → เดาจากสถานะ)
  final bool? canMarkPaid;
  final bool? canRefund;
  final bool? canCancel;
  final String? stageLabel;
  final double? amountReceived;

  bool get isPaid => status == 'paid' || (status.isEmpty && paidAt != null);
  bool get isClosed =>
      status == 'cancelled' || status == 'refunded' || status == 'closed';
  bool get isFloating => statusReason == 'floating';

  /// ยืนยันจ่ายได้ไหม — บิลลอย / ลูกค้าจ่ายบิลอื่นแทนแล้ว ห้ามอนุมัติ (= เก็บเงินซ้ำ)
  bool get mayMarkPaid => canMarkPaid ?? (!isPaid && !isClosed);
  bool get mayRefund => canRefund ?? isPaid;
  bool get mayCancel => canCancel ?? (!isPaid && !isClosed);

  factory FortuneBill.fromJson(Map<String, dynamic> j) {
    final user = _m(j['customer'] ?? j['user']);
    final slip = _m(j['slip']);
    final actions = _m(j['actions']);
    bool? flag(String k) => actions.containsKey(k) ? actions[k] == true : null;
    return FortuneBill(
      id: TpFmt.toInt(j['id'] ?? j['reading_id']),
      billNumber:
          (j['bill_number'] ?? j['bill_no'] ?? 'R${j['id']}').toString(),
      packageLabel: (j['package_label'] ??
              j['tier_label'] ??
              j['package'] ??
              j['tier'] ??
              'ดูดวง')
          .toString(),
      amount: TpFmt.toDouble(j['amount_thb'] ?? j['amount']),
      status: (j['status'] ?? '').toString(),
      statusLabel: j['status_label']?.toString(),
      platform: j['platform']?.toString(),
      customerName: (j['customer_name'] ?? user['name'] ?? user['display_name'])
          ?.toString(),
      createdAt: TpFmt.parse(j['created_at']),
      paidAt: TpFmt.parse(j['paid_at']),
      slipUrl: (j['slip_image_url'] ?? j['slip_url'])?.toString(),
      sms: SmsMatch.fromJson(j['sms_match'] ?? j['sms']),
      question: (j['question_preview'] ?? j['question'])?.toString(),
      priorPaid:
          TpFmt.toInt(j['customer_prior_paid_count'] ?? j['prior_paid_count']),
      slipNeedsAuth: slip['image_requires_auth'] == true,
      slipAt: TpFmt.parse(slip['received_at']),
      statusReason: j['status_reason']?.toString(),
      canMarkPaid: flag('can_mark_paid'),
      canRefund: flag('can_refund'),
      canCancel: flag('can_cancel'),
      stageLabel:
          j['stage'] is Map ? (j['stage'] as Map)['label']?.toString() : null,
      amountReceived: j['amount_received_thb'] == null
          ? null
          : TpFmt.toDouble(j['amount_received_thb']),
    );
  }
}

class BillStats {
  const BillStats(
      {this.counts = const {},
      this.paidTodayAmount = 0,
      this.paidTodayCount = 0,
      this.awaitingAmount = 0});
  final Map<String, int> counts;
  final double paidTodayAmount;
  final int paidTodayCount;
  final double awaitingAmount;

  int count(BillBucket b) => counts[b.key] ?? 0;

  factory BillStats.fromJson(Map<String, dynamic> j) {
    final c = <String, int>{};
    final raw = _m(j['counts']).isNotEmpty ? _m(j['counts']) : j;
    for (final b in BillBucket.values) {
      final v = raw[b.key] ?? raw['${b.key}_count'];
      if (v != null) c[b.key] = TpFmt.toInt(v);
    }
    final pt = _m(j['paid_today']);
    return BillStats(
      counts: c,
      paidTodayAmount: TpFmt.toDouble(
          pt['revenue_thb'] ?? j['paid_today_thb'] ?? j['today_revenue_thb']),
      paidTodayCount: TpFmt.toInt(pt['count'] ?? j['paid_today_count']),
      awaitingAmount: TpFmt.toDouble(j['awaiting_amount_thb']),
    );
  }
}

// ───────────────────────── ถอนเงิน ─────────────────────────

class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.requestId,
    required this.amount,
    required this.fee,
    required this.net,
    required this.status,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.method,
    this.details = const {},
    this.userNote,
    this.createdAt,
    this.rejectionReason,
  });

  final int id;
  final String requestId;
  final double amount;
  final double fee;
  final double net;
  final String status;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? method;
  final Map<String, dynamic> details;
  final String? userNote;
  final DateTime? createdAt;
  final String? rejectionReason;

  /// ชื่อธนาคาร/เลขบัญชี/ชื่อบัญชี จาก payment_details (คีย์ต่างกันตามช่องทาง)
  String? get bankName =>
      (details['bank_name'] ?? details['bank'] ?? details['bank_code'])
          ?.toString();
  String? get accountNumber => (details['account_number'] ??
          details['account_no'] ??
          details['promptpay'] ??
          details['phone'])
      ?.toString();
  String? get accountName =>
      (details['account_name'] ?? details['name'] ?? details['holder_name'])
          ?.toString();

  factory Withdrawal.fromJson(Map<String, dynamic> j) {
    final u = _m(j['user']);
    final pm = _m(j['payment_method']);
    return Withdrawal(
      id: TpFmt.toInt(j['id']),
      requestId: (j['request_id'] ?? '#${j['id']}').toString(),
      amount: TpFmt.toDouble(j['amount']),
      fee: TpFmt.toDouble(j['fee']) + TpFmt.toDouble(j['tax']),
      net: TpFmt.toDouble(j['net_amount'] ?? j['amount']),
      status: (j['status'] ?? '').toString(),
      userName: u['name']?.toString(),
      userEmail: u['email']?.toString(),
      userPhone: u['phone']?.toString(),
      method: (pm['name'] ?? j['payment_type'])?.toString(),
      details: _m(j['payment_details']),
      userNote: j['user_note']?.toString(),
      createdAt: TpFmt.parse(j['created_at']),
      rejectionReason: j['rejection_reason']?.toString(),
    );
  }
}

// ───────────────────────── SMS ธนาคาร ─────────────────────────

class BankSms {
  const BankSms({
    required this.id,
    required this.bank,
    required this.amount,
    required this.status,
    this.type,
    this.from,
    this.account,
    this.reference,
    this.at,
    this.matchedBillId,
  });

  final int id;
  final String bank;
  final double amount;
  final String status;
  final String? type;
  final String? from;
  final String? account;
  final String? reference;
  final DateTime? at;
  final int? matchedBillId;

  factory BankSms.fromJson(Map<String, dynamic> j) => BankSms(
        id: TpFmt.toInt(j['id']),
        bank: (j['bank'] ?? '-').toString(),
        amount: TpFmt.toDouble(j['amount']),
        status: (j['status'] ?? '').toString(),
        type: j['type']?.toString(),
        from: j['sender_or_receiver']?.toString(),
        account: j['account_number']?.toString(),
        reference: j['reference_number']?.toString(),
        at: TpFmt.parse(j['sms_timestamp'] ?? j['created_at']),
        matchedBillId: j['matched_transaction_id'] == null
            ? null
            : TpFmt.toInt(j['matched_transaction_id']),
      );
}

// ───────────────────────── คำทำนายที่กำลังทำ ─────────────────────────

class ActiveReading {
  const ActiveReading({
    required this.id,
    required this.billNumber,
    required this.packageLabel,
    required this.stuck,
    required this.idleMinutes,
    this.stage,
    this.customerName,
    this.platform,
    this.question,
    this.takenOver = false,
    this.stuckReason,
  });

  final int id;
  final String billNumber;
  final String packageLabel;
  final bool stuck;
  final int idleMinutes;
  final String? stage;
  final String? customerName;
  final String? platform;
  final String? question;
  final bool takenOver;

  final String? stuckReason;

  /// เหตุผลที่ค้างเป็นภาษาไทย
  String? get stuckLabel => switch (stuckReason) {
        'ai_generating_timeout' => 'AI ทำนายไม่เสร็จ',
        'deep_job_failed' => 'งานทำนายล้มเหลว',
        null => null,
        _ => 'ระบบไม่ขยับ',
      };

  factory ActiveReading.fromJson(Map<String, dynamic> j) {
    final u = _m(j['customer'] ?? j['user']);
    final stage = j['stage'];
    return ActiveReading(
      id: TpFmt.toInt(j['reading_id'] ?? j['id']),
      billNumber:
          (j['bill_number'] ?? 'R${j['reading_id'] ?? j['id']}').toString(),
      packageLabel: (j['package_label'] ?? j['package'] ?? 'ดูดวง').toString(),
      stuck: j['stuck'] == true,
      idleMinutes:
          TpFmt.toInt(j['minutes_since_activity'] ?? j['idle_minutes']),
      stage: stage is Map
          ? stage['label']?.toString()
          : (j['stage_label'] ?? stage)?.toString(),
      customerName: (j['customer_name'] ?? u['name'])?.toString(),
      platform: j['platform']?.toString(),
      question: (j['question_preview'] ?? j['question'])?.toString(),
      takenOver: j['is_taken_over'] == true || j['admin_taken_over'] == true,
      stuckReason: j['stuck_reason']?.toString(),
    );
  }
}

// ───────────────────────── เคสลูกค้าต้องดูแล ─────────────────────────

class TriageCase {
  const TriageCase({
    required this.id,
    required this.kind,
    required this.critical,
    this.platform,
    this.readingId,
    this.reasons = const [],
    this.preview,
    this.at,
    this.count = 1,
    this.mood,
  });

  final String id;
  final String kind;
  final bool critical;
  final String? platform;
  final int? readingId;
  final List<String> reasons;
  final String? preview;
  final DateTime? at;
  final int count;
  final int? mood;

  String get kindLabel => switch (kind) {
        'emotional' => 'อารมณ์ลบ',
        'lead' => 'เริ่มแต่ยังไม่จ่าย',
        'refund' || 'money' || 'payment' => 'เรื่องเงิน',
        'complaint' => 'ร้องเรียน',
        _ => 'ต้องดูแล',
      };

  factory TriageCase.fromJson(Map<String, dynamic> j) => TriageCase(
        id: (j['case_id'] ?? '').toString(),
        kind: (j['kind'] ?? '').toString(),
        critical: j['severity'] == 'crit',
        platform: j['platform']?.toString(),
        readingId:
            j['reading_id'] == null ? null : TpFmt.toInt(j['reading_id']),
        reasons: ((j['reasons'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty && !e.startsWith('service:'))
            .toList(),
        preview: j['preview']?.toString(),
        at: TpFmt.parse(j['last_at']),
        count: TpFmt.toInt(j['count']) == 0 ? 1 : TpFmt.toInt(j['count']),
        mood: j['mood_level'] == null ? null : TpFmt.toInt(j['mood_level']),
      );
}

// ───────────────────────── Repository ─────────────────────────

class WorkRepository {
  WorkRepository(this._api);
  final ApiClient _api;

  Future<Paged<FortuneBill>> bills(BillBucket bucket,
      {int page = 1, String? search}) async {
    final data = await _api.get<dynamic>('/fortune/bills', query: {
      'status': bucket.key,
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return Paged.parse(data, FortuneBill.fromJson);
  }

  Future<BillStats> billStats() async {
    final data = await _api.get<Map<String, dynamic>>('/fortune/bills/stats',
        parser: (d) => _m(d));
    return BillStats.fromJson(data);
  }

  /// ยืนยันว่าจ่ายแล้ว → backend ส่งคำทำนายให้ลูกค้าทันที (FortuneReadingsController@markPaid)
  Future<String?> markPaid(int readingId,
      {required double amount, String? note}) async {
    // ส่งยอดจริงของบิลเสมอ — backend เดิมใส่ 49 บาทเองถ้าไม่ส่ง (บิล 39/99 จะบันทึกผิด)
    final res = await _api.dio.post<Map<String, dynamic>>(
        '/fortune/readings/$readingId/mark-paid',
        data: {
          if (amount > 0) 'amount': amount.toStringAsFixed(2),
          if (note != null && note.isNotEmpty) 'note': note,
        });
    return _expectOk(res.data, res.statusCode);
  }

  Future<String?> cancelBill(int readingId, {String? reason}) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
        '/fortune/readings/$readingId/cancel',
        data: {if (reason != null) 'reason': reason});
    return _expectOk(res.data, res.statusCode);
  }

  Future<String?> refundBill(int readingId, {String? reason}) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
        '/fortune/readings/$readingId/refund',
        data: {if (reason != null) 'reason': reason});
    return _expectOk(res.data, res.statusCode);
  }

  Future<Paged<Withdrawal>> withdrawals(
      {String status = 'pending', int page = 1}) async {
    final data = await _api.get<dynamic>('/finance/withdrawals',
        query: {'status': status, 'page': page});
    return Paged.parse(data, Withdrawal.fromJson);
  }

  Future<String?> approveWithdrawal(int id, {String? note}) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
        '/finance/withdrawals/$id/approve',
        data: {if (note != null && note.isNotEmpty) 'admin_note': note});
    return _expectOk(res.data, res.statusCode);
  }

  Future<String?> rejectWithdrawal(int id, String reason) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
        '/finance/withdrawals/$id/reject',
        data: {'reason': reason});
    return _expectOk(res.data, res.statusCode);
  }

  /// ปิดงานถอนเงินหลังโอนแล้ว — แนบสลิป (รูป ≤ 5MB) + หมายเหตุ
  Future<String?> completeWithdrawal(int id,
      {String? slipPath, String? note}) async {
    final form = FormData.fromMap({
      if (note != null && note.isNotEmpty) 'transfer_note': note,
      if (slipPath != null)
        'transfer_slip':
            await MultipartFile.fromFile(slipPath, filename: 'slip_$id.jpg'),
    });
    final res = await _api.dio.post<Map<String, dynamic>>(
        '/finance/withdrawals/$id/complete',
        data: form,
        options: Options(contentType: 'multipart/form-data'));
    return _expectOk(res.data, res.statusCode);
  }

  /// เคสลูกค้าที่ต้องดูแล (อารมณ์ลบ / ทวงเงิน / เริ่มแต่ยังไม่จ่าย) — ชุดเดียวกับ Warroom triage
  Future<List<TriageCase>> triage({int sinceMinutes = 180}) async {
    final data = await _api.get<Map<String, dynamic>>(
        '/fortune/triage/behavior',
        query: {'since_minutes': sinceMinutes},
        parser: (d) => _m(d));
    final list = (data['cases'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => TriageCase.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Paged<BankSms>> sms({String status = 'pending', int page = 1}) async {
    final data = await _api.get<dynamic>('/payment/sms/inbox',
        query: {'status': status, 'page': page});
    return Paged.parse(data, BankSms.fromJson);
  }

  /// ลองจับคู่ SMS กับบิลอีกครั้ง (backend: attemptMatch) — คืน (สำเร็จ, ข้อความ)
  Future<(bool, String)> rematchSms(int id) async {
    final res =
        await _api.dio.post<Map<String, dynamic>>('/payment/sms/$id/match');
    final body = res.data ?? const {};
    final ok = body['success'] == true;
    return (
      ok,
      (body['message'] ??
              (ok ? 'จับคู่สำเร็จ' : 'ยังไม่พบบิลที่ตรงกับ SMS นี้'))
          .toString()
    );
  }

  Future<String?> rejectSms(int id, String reason) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
        '/payment/sms/$id/reject',
        data: {'reason': reason});
    return _expectOk(res.data, res.statusCode);
  }

  Future<List<ActiveReading>> activeReadings() async {
    final data = await _api.get<dynamic>('/fortune/active-readings');
    return Paged.parse(data, ActiveReading.fromJson).items;
  }

  /// คืนข้อความสำเร็จจาก backend หรือ throw ข้อความ error ภาษาไทยที่อ่านได้
  String? _expectOk(Map<String, dynamic>? body, int? code) {
    final b = body ?? const {};
    if ((code ?? 500) >= 400 || b['success'] == false) {
      throw ActionError(
          (b['message'] ?? 'ทำรายการไม่สำเร็จ ($code)').toString());
    }
    return b['message']?.toString();
  }
}

final workRepositoryProvider = Provider<WorkRepository>(
    (ref) => WorkRepository(ref.watch(apiClientProvider)));

final billStatsProvider = FutureProvider.autoDispose<BillStats>(
    (ref) => ref.watch(workRepositoryProvider).billStats());

final billsProvider = FutureProvider.autoDispose
    .family<Paged<FortuneBill>, BillBucket>(
        (ref, b) => ref.watch(workRepositoryProvider).bills(b));

final pendingWithdrawalsProvider =
    FutureProvider.autoDispose<Paged<Withdrawal>>(
        (ref) => ref.watch(workRepositoryProvider).withdrawals());

final pendingSmsProvider = FutureProvider.autoDispose<Paged<BankSms>>(
    (ref) => ref.watch(workRepositoryProvider).sms());

final activeReadingsProvider = FutureProvider.autoDispose<List<ActiveReading>>(
    (ref) => ref.watch(workRepositoryProvider).activeReadings());

final triageProvider = FutureProvider.autoDispose<List<TriageCase>>(
    (ref) => ref.watch(workRepositoryProvider).triage());
