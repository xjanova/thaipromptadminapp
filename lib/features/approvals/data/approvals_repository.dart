import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import '../../../shared/ui/tp_format.dart';
import '../../home/data/ops_repository.dart';

// สัญญา JSON: Thaiprompt-Affiliate/docs/ADMIN_APP_API.md หัวข้อ 8 "Approvals"
// ทุกตัวอ่านแบบทนทาน (คีย์หาย/ชนิดเพี้ยน = ค่าว่าง ไม่ throw) เพราะ endpoint ยังไม่ขึ้น production

// ───────────────────────── ตัวช่วยอ่าน JSON ─────────────────────────

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

final _emoji =
    RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true);

/// ข้อความจาก JSON (ตัดอีโมจิ + ช่องว่าง) — ว่าง = null
String? _s(dynamic v) {
  if (v == null || v is Map || v is List) return null;
  final t = v.toString().replaceAll(_emoji, '').trim();
  return t.isEmpty ? null : t;
}

int? _intOrNull(dynamic v) => v == null ? null : TpFmt.toInt(v);
double? _dblOrNull(dynamic v) => v == null ? null : TpFmt.toDouble(v);
bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
bool? _bOrNull(dynamic v) => v == null ? null : _b(v);

List<String> _strs(dynamic v) => v is List
    ? [
        for (final e in v)
          if (_s(e) != null) _s(e)!
      ]
    : const [];

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? [
        for (final e in v)
          if (e is Map) e.cast<String, dynamic>()
      ]
    : const [];

final _thai = RegExp(r'[฀-๿]');

/// บุคคลแบบย่อในรายการ (`{id, name, member_number}`) — ไม่มีอีเมล/เบอร์ (PDPA)
class PersonRef {
  const PersonRef({required this.id, required this.name, this.memberNumber});
  final int id;
  final String name;
  final String? memberNumber;

  String get display =>
      name.isNotEmpty ? name : (memberNumber ?? 'สมาชิก #$id');

  static PersonRef? parse(dynamic j) {
    if (j is! Map) return null;
    final m = _m(j);
    return PersonRef(
      id: TpFmt.toInt(m['id']),
      name: _s(m['name'] ?? m['full_name']) ?? '',
      memberNumber: _s(m['member_number']),
    );
  }
}

// ───────────────────────── ผลการกระทำ / ข้อผิดพลาด ─────────────────────────

/// ผลของปุ่มอนุมัติ/ปฏิเสธ — [already] = รายการเป็นผลนี้อยู่แล้ว (กดซ้ำ / แอดมินอีกคนทำไปก่อน) ไม่มีอะไรขยับซ้ำ
class ApprovalResult {
  const ApprovalResult(
      {required this.message, this.already = false, this.data = const {}});
  final String message;
  final bool already;
  final Map<String, dynamic> data;
}

/// ข้อผิดพลาดของคิวอนุมัติ — ข้อความไทยจากเซิร์ฟเวอร์ + สถานะ HTTP / error_code ไว้ให้หน้าจอตัดสินใจ
class ApprovalError extends ActionError {
  ApprovalError(super.message,
      {this.statusCode = 0, this.errorCode, this.data = const {}});
  final int statusCode;
  final String? errorCode;
  final Map<String, dynamic> data;

  bool get forbidden => statusCode == 403;

  /// รายการเปลี่ยนสถานะไปแล้ว (คนอื่นตัดสิน / ถูกลบ) → ควรปิดแผ่นแล้วโหลดรายการใหม่
  bool get stale =>
      statusCode == 404 ||
      const {
        'EKYC_ALREADY_DECIDED',
        'ALREADY_PROCESSED',
        'INVALID_STATUS',
        'HANDOVER_FINAL',
        'INVALID_TRANSITION',
        'NOT_APPROVED',
      }.contains(errorCode);
}

// ───────────────────────── 8.1 สรุปทุกคิว ─────────────────────────

enum ApprovalQueue {
  ekyc('ekyc'),
  sellerApplications('seller_applications'),
  riderApplications('rider_applications'),
  riderDocuments('rider_documents'),
  riderJobs('rider_jobs'),
  tickets('tickets'),
  mlmCommissions('mlm_commissions');

  const ApprovalQueue(this.key);
  final String key;
}

/// ตัวเลขของคิวหนึ่ง (null ทั้งก้อน = อ่านไม่ได้ ห้ามตีเป็น 0)
class ApprovalBox {
  const ApprovalBox({
    this.count = 0,
    this.oldestMinutes,
    this.disputed,
    this.awaitingRelease,
    this.manualNeeded,
    this.amountThb,
    this.approvedUnpaid,
  });

  final int count;
  final int? oldestMinutes;

  // rider_jobs (แยกย่อย อาจซ้อนกัน)
  final int? disputed;
  final int? awaitingRelease;
  final int? manualNeeded;

  // mlm_commissions
  final double? amountThb;

  /// อนุมัติแล้วรอจ่าย (ไม่นับใน [count])
  final int? approvedUnpaid;

  static ApprovalBox? parse(dynamic j) {
    if (j is num) return ApprovalBox(count: j.toInt());
    if (j is! Map) return null;
    final m = _m(j);
    return ApprovalBox(
      count: TpFmt.toInt(m['count']),
      oldestMinutes: _intOrNull(m['oldest_minutes']),
      disputed: _intOrNull(m['disputed']),
      awaitingRelease: _intOrNull(m['awaiting_release']),
      manualNeeded: _intOrNull(m['manual_needed']),
      amountThb: _dblOrNull(m['amount_thb']),
      approvedUnpaid: _intOrNull(m['approved_unpaid']),
    );
  }
}

class ApprovalsSummary {
  const ApprovalsSummary({
    required this.boxes,
    required this.total,
    this.computedAt,
    this.degraded = const [],
  });

  final Map<ApprovalQueue, ApprovalBox?> boxes;
  final int total;
  final DateTime? computedAt;
  final List<String> degraded;

  /// null = คิวนี้อ่านไม่ได้รอบนี้ (แสดง "ไม่ทราบ")
  ApprovalBox? box(ApprovalQueue q) =>
      degraded.contains(q.key) ? null : boxes[q];

  int count(ApprovalQueue q) => box(q)?.count ?? 0;

  bool get anyUnknown => ApprovalQueue.values.any((q) => box(q) == null);

  /// เวลารอนานสุดของทุกคิวที่อ่านได้
  int? get oldestMinutes {
    int? best;
    for (final q in ApprovalQueue.values) {
      final b = box(q);
      if (b == null || b.count == 0 || b.oldestMinutes == null) continue;
      if (best == null || b.oldestMinutes! > best) best = b.oldestMinutes;
    }
    return best;
  }

  factory ApprovalsSummary.fromJson(Map<String, dynamic> j) {
    final queues = _m(j['queues']);
    final degraded = _strs(j['degraded']);
    final boxes = <ApprovalQueue, ApprovalBox?>{
      for (final q in ApprovalQueue.values)
        q: degraded.contains(q.key) ? null : ApprovalBox.parse(queues[q.key]),
    };
    final sum = boxes.values.fold<int>(0, (a, b) => a + (b?.count ?? 0));
    return ApprovalsSummary(
      boxes: boxes,
      total: j['total'] == null ? sum : TpFmt.toInt(j['total']),
      computedAt: TpFmt.parse(j['computed_at'] ?? j['generated_at']),
      degraded: degraded,
    );
  }
}

// ───────────────────────── 8.2 eKYC ─────────────────────────

enum EkycFilter {
  pending('pending', 'รอตรวจ'),
  retake('retake', 'ขอถ่ายใหม่'),
  approved('approved', 'อนุมัติแล้ว'),
  rejected('rejected', 'ปฏิเสธแล้ว'),
  all('all', 'ทั้งหมด');

  const EkycFilter(this.key, this.label);
  final String key;
  final String label;
}

/// คะแนน AI (0–1) — null = AI ไม่ได้ให้คะแนนข้อนี้
class EkycScores {
  const EkycScores(
      {this.decision,
      this.faceMatch,
      this.liveness,
      this.real,
      this.cardReal,
      this.ocr});
  final String? decision;
  final double? faceMatch;
  final double? liveness;
  final double? real;
  final double? cardReal;
  final double? ocr;

  factory EkycScores.fromJson(dynamic j) {
    final m = _m(j);
    return EkycScores(
      decision: _s(m['decision']),
      faceMatch: _dblOrNull(m['face_match']),
      liveness: _dblOrNull(m['liveness']),
      real: _dblOrNull(m['real']),
      cardReal: _dblOrNull(m['card_real']),
      ocr: _dblOrNull(m['ocr']),
    );
  }
}

class EkycItem {
  const EkycItem({
    required this.id,
    required this.status,
    this.user,
    this.statusLabel,
    this.documentTypeLabel,
    this.idLast4,
    this.submittedAt,
    this.waitingMinutes,
    this.ai = const EkycScores(),
    this.reasonTexts = const [],
    this.flags = const {},
  });

  final int id;
  final String status;
  final PersonRef? user;
  final String? statusLabel;
  final String? documentTypeLabel;
  final String? idLast4;
  final DateTime? submittedAt;
  final int? waitingMinutes;
  final EkycScores ai;
  final List<String> reasonTexts;

  /// ธงเตือน (duplicate_id, replay_suspected, ...) — เก็บเฉพาะที่เป็น true
  final Set<String> flags;

  bool get isPending => status == 'pending';

  factory EkycItem.fromJson(Map<String, dynamic> j) {
    final f = _m(j['flags']);
    return EkycItem(
      id: TpFmt.toInt(j['id']),
      status: _s(j['status']) ?? '',
      user: PersonRef.parse(j['user']),
      statusLabel: _s(j['status_label']),
      documentTypeLabel: _s(j['document_type_label'] ?? j['document_type']),
      idLast4: _s(j['id_last4']),
      submittedAt: TpFmt.parse(j['submitted_at']),
      waitingMinutes: _intOrNull(j['waiting_minutes']),
      ai: EkycScores.fromJson(j['ai']),
      reasonTexts: _strs(j['reason_texts']).isNotEmpty
          ? _strs(j['reason_texts'])
          : _strs(j['reasons']),
      flags: {
        for (final e in f.entries)
          if (_b(e.value)) e.key
      },
    );
  }
}

class EkycImage {
  const EkycImage(
      {required this.kind,
      required this.label,
      this.available = false,
      this.url});
  final String kind;
  final String label;
  final bool available;
  final String? url;

  factory EkycImage.fromJson(Map<String, dynamic> j) => EkycImage(
        kind: _s(j['kind']) ?? '',
        label: _s(j['label']) ?? 'รูป',
        available: _b(j['available']) && _s(j['url']) != null,
        url: _s(j['url']),
      );
}

/// ผู้ใช้แก้ค่าที่ AI อ่านจากบัตร (`corrections.{field}: {ocr, user}`)
class EkycCorrection {
  const EkycCorrection({required this.field, this.ocr, this.user});
  final String field;
  final String? ocr;
  final String? user;
}

class EkycView {
  const EkycView({this.viewer, this.kind, this.at});
  final String? viewer;
  final String? kind;
  final DateTime? at;
}

class EkycDetail {
  const EkycDetail({
    required this.item,
    this.cardNameTh,
    this.cardNameEn,
    this.birthDate,
    this.expiryDate,
    this.lifelong = false,
    this.idMasked,
    this.checksumOk,
    this.accountName,
    this.accountKycStatus,
    this.nameMatchesCard,
    this.accountCreatedAt,
    this.matchScore,
    this.livenessPassed,
    this.challenges = const {},
    this.thresholds = const {},
    this.modelVersion,
    this.corrections = const [],
    this.duplicateNow = false,
    this.images = const [],
    this.imageRequiresAuth = true,
    this.recentViews = const [],
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    this.canApprove = false,
    this.canReject = false,
    this.canRequestRetake = false,
  });

  final EkycItem item;
  final String? cardNameTh;
  final String? cardNameEn;
  final String? birthDate;
  final String? expiryDate;
  final bool lifelong;
  final String? idMasked;
  final bool? checksumOk;
  final String? accountName;
  final String? accountKycStatus;
  final bool? nameMatchesCard;
  final DateTime? accountCreatedAt;
  final double? matchScore;
  final bool? livenessPassed;
  final Map<String, bool> challenges;
  final Map<String, double> thresholds;
  final String? modelVersion;
  final List<EkycCorrection> corrections;

  /// เช็คสด ณ ตอนเปิด — บัตรนี้ยืนยันกับบัญชีอื่นแล้ว (อนุมัติจะถูกปฏิเสธ)
  final bool duplicateNow;
  final List<EkycImage> images;
  final bool imageRequiresAuth;
  final List<EkycView> recentViews;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final bool canApprove;
  final bool canReject;
  final bool canRequestRetake;

  double threshold(String key, double fallback) => thresholds[key] ?? fallback;

  factory EkycDetail.fromJson(Map<String, dynamic> j) {
    final card = _m(j['card']);
    final account = _m(j['account']);
    final ai = _m(j['ai_detail']);
    final review = _m(j['review']);
    final actions = _m(j['actions']);
    final item = EkycItem.fromJson(j);
    final pending = item.isPending;
    bool flag(String k, bool fallback) =>
        actions.containsKey(k) ? _b(actions[k]) : fallback;
    return EkycDetail(
      item: item,
      cardNameTh: _s(card['name_th']),
      cardNameEn: _s(card['name_en']),
      birthDate: _s(card['birth_date']),
      expiryDate: _s(card['expiry_date']),
      lifelong: _b(card['lifelong']),
      idMasked: _s(card['id_masked']),
      checksumOk: _bOrNull(card['checksum_ok']),
      accountName: _s(account['name']),
      accountKycStatus: _s(account['kyc_status']),
      nameMatchesCard: _bOrNull(account['name_matches_card']),
      accountCreatedAt: TpFmt.parse(account['created_at']),
      matchScore: _dblOrNull(ai['match_score']),
      livenessPassed: _bOrNull(ai['liveness_passed']),
      challenges: {
        for (final e in _m(ai['challenges']).entries) e.key: _b(e.value)
      },
      thresholds: {
        for (final e in _m(ai['thresholds']).entries)
          if (e.value is num || double.tryParse('${e.value}') != null)
            e.key: TpFmt.toDouble(e.value)
      },
      modelVersion: _s(ai['model_version']),
      corrections: [
        for (final e in _m(j['corrections']).entries)
          EkycCorrection(
            field: e.key,
            ocr: _s(_m(e.value)['ocr']),
            user: _s(_m(e.value)['user']) ?? _s(e.value),
          )
      ],
      duplicateNow: _b(j['duplicate_now']),
      images: _maps(j['images']).map(EkycImage.fromJson).toList(),
      imageRequiresAuth: j['image_requires_auth'] == null
          ? true
          : _b(j['image_requires_auth']),
      recentViews: [
        for (final v in _maps(j['recent_views']))
          EkycView(
              viewer: _s(v['viewer']),
              kind: _s(v['kind']),
              at: TpFmt.parse(v['at']))
      ],
      reviewedBy: _s(review['reviewed_by']),
      reviewedAt: TpFmt.parse(review['reviewed_at']),
      reviewNote: _s(review['note']),
      canApprove: flag('can_approve', pending),
      canReject: flag('can_reject', pending),
      canRequestRetake: flag('can_request_retake', pending),
    );
  }
}

// ───────────────────────── 8.3 คำขอเปิดร้าน ─────────────────────────

enum SellerFilter {
  pending('pending', 'รออนุมัติ'),
  active('active', 'อนุมัติแล้ว'),
  closed('closed', 'ถูกปฏิเสธ'),
  all('all', 'ทั้งหมด');

  const SellerFilter(this.key, this.label);
  final String key;
  final String label;
}

class SellerApplication {
  const SellerApplication({
    required this.id,
    required this.storeName,
    required this.status,
    this.statusLabel,
    this.businessTypeLabel,
    this.companyName,
    this.taxIdMasked,
    this.phoneMasked,
    this.province,
    this.owner,
    this.rejectionReason,
    this.submittedAt,
    this.waitingMinutes,
  });

  final int id;
  final String storeName;
  final String status;
  final String? statusLabel;
  final String? businessTypeLabel;
  final String? companyName;
  final String? taxIdMasked;
  final String? phoneMasked;
  final String? province;
  final PersonRef? owner;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final int? waitingMinutes;

  bool get isPending => status == 'pending';

  factory SellerApplication.fromJson(Map<String, dynamic> j) =>
      SellerApplication(
        id: TpFmt.toInt(j['id']),
        storeName: _s(j['store_name']) ?? 'ร้าน #${j['id']}',
        status: _s(j['status']) ?? '',
        statusLabel: _s(j['status_label']),
        businessTypeLabel: _s(j['business_type_label'] ?? j['business_type']),
        companyName: _s(j['company_name']),
        taxIdMasked: _s(j['tax_id_masked']),
        phoneMasked: _s(j['phone_masked']),
        province: _s(j['province']),
        owner: PersonRef.parse(j['owner']),
        rejectionReason: _s(j['rejection_reason']),
        submittedAt: TpFmt.parse(j['submitted_at']),
        waitingMinutes: _intOrNull(j['waiting_minutes']),
      );
}

class SellerDetail {
  const SellerDetail({
    required this.app,
    this.description,
    this.storePhone,
    this.storeEmail,
    this.addressLine,
    this.city,
    this.state,
    this.postalCode,
    this.hasOwnerDetail = false,
    this.ownerRole,
    this.ownerKycStatus,
    this.ownerKycVerified = false,
    this.ownerSuspended = false,
    this.ownerDeleted = false,
    this.ownerJoinedAt,
    this.canApprove = false,
    this.canReject = false,
  });

  final SellerApplication app;
  final String? description;
  final String? storePhone;
  final String? storeEmail;
  final String? addressLine;
  final String? city;
  final String? state;
  final String? postalCode;
  final bool hasOwnerDetail;
  final String? ownerRole;
  final String? ownerKycStatus;
  final bool ownerKycVerified;
  final bool ownerSuspended;
  final bool ownerDeleted;
  final DateTime? ownerJoinedAt;
  final bool canApprove;
  final bool canReject;

  String get address => [addressLine, city, state, postalCode]
      .whereType<String>()
      .where((e) => e.isNotEmpty)
      .join(' ');

  factory SellerDetail.fromJson(Map<String, dynamic> j) {
    final app = SellerApplication.fromJson(j);
    final a = _m(j['address']);
    final o = j['owner_detail'];
    final od = _m(o);
    final actions = _m(j['actions']);
    bool flag(String k) =>
        actions.containsKey(k) ? _b(actions[k]) : app.isPending;
    return SellerDetail(
      app: app,
      description: _s(j['store_description']),
      storePhone: _s(j['store_phone']),
      storeEmail: _s(j['store_email']),
      addressLine: _s(a['line']),
      city: _s(a['city']),
      state: _s(a['state']),
      postalCode: _s(a['postal_code']),
      hasOwnerDetail: o is Map,
      ownerRole: _s(od['role']),
      ownerKycStatus: _s(od['kyc_status']),
      ownerKycVerified: _b(od['kyc_verified']),
      ownerSuspended: _b(od['suspended']),
      ownerDeleted: _b(od['deleted']),
      ownerJoinedAt: TpFmt.parse(od['joined_at']),
      canApprove: flag('can_approve'),
      canReject: flag('can_reject'),
    );
  }
}

// ───────────────────────── 8.4 ไรเดอร์ ─────────────────────────

enum RiderFilter {
  pending('pending', 'รอตรวจ'),
  documentsChanged('documents_changed', 'เปลี่ยนเอกสาร'),
  rejected('rejected', 'ถูกปฏิเสธ'),
  all('all', 'ทั้งหมด');

  const RiderFilter(this.key, this.label);
  final String key;
  final String label;

  static RiderFilter parse(String? v) => RiderFilter.values
      .firstWhere((f) => f.key == v, orElse: () => RiderFilter.pending);
}

class RiderApplication {
  const RiderApplication({
    required this.id,
    required this.fullName,
    required this.status,
    this.statusText,
    this.phoneMasked,
    this.idCardMasked,
    this.vehicleTypeText,
    this.vehiclePlate,
    this.province,
    this.user,
    this.kycVerified = false,
    this.documentsComplete = true,
    this.documentsMissing = const [],
    this.documentsMissingText,
    this.documentsChangedAt,
    this.submittedAt,
    this.waitingMinutes,
  });

  final int id;
  final String fullName;
  final String status;
  final String? statusText;
  final String? phoneMasked;
  final String? idCardMasked;
  final String? vehicleTypeText;
  final String? vehiclePlate;
  final String? province;
  final PersonRef? user;
  final bool kycVerified;
  final bool documentsComplete;
  final List<String> documentsMissing;
  final String? documentsMissingText;
  final DateTime? documentsChangedAt;
  final DateTime? submittedAt;
  final int? waitingMinutes;

  factory RiderApplication.fromJson(Map<String, dynamic> j) => RiderApplication(
        id: TpFmt.toInt(j['id']),
        fullName: _s(j['full_name']) ?? 'ไรเดอร์ #${j['id']}',
        status: _s(j['status']) ?? '',
        statusText: _s(j['status_text'] ?? j['status_label']),
        phoneMasked: _s(j['phone_masked']),
        idCardMasked: _s(j['id_card_masked']),
        vehicleTypeText: _s(j['vehicle_type_text'] ?? j['vehicle_type']),
        vehiclePlate: _s(j['vehicle_plate']),
        province: _s(j['province']),
        user: PersonRef.parse(j['user']),
        kycVerified: _b(j['kyc_verified']),
        documentsComplete: j['documents_complete'] == null
            ? true
            : _b(j['documents_complete']),
        documentsMissing: _strs(j['documents_missing']),
        documentsMissingText: _s(j['documents_missing_text']),
        documentsChangedAt: TpFmt.parse(j['documents_changed_at']),
        submittedAt: TpFmt.parse(j['submitted_at']),
        waitingMinutes: _intOrNull(j['waiting_minutes']),
      );
}

class RiderDocument {
  const RiderDocument({
    required this.type,
    required this.label,
    this.uploaded = false,
    this.required = false,
    this.url,
    this.requiresAuth = true,
  });
  final String type;
  final String label;
  final bool uploaded;
  final bool required;
  final String? url;
  final bool requiresAuth;

  factory RiderDocument.fromJson(Map<String, dynamic> j) => RiderDocument(
        type: _s(j['type']) ?? '',
        label: _s(j['label']) ?? 'เอกสาร',
        uploaded: _b(j['uploaded']) && _s(j['url']) != null,
        required: _b(j['required']),
        url: _s(j['url']),
        requiresAuth:
            j['requires_auth'] == null ? true : _b(j['requires_auth']),
      );
}

class RiderDetail {
  const RiderDetail({
    required this.rider,
    this.phone,
    this.birthDate,
    this.addressLine,
    this.district,
    this.addressProvince,
    this.vehicleTypeText,
    this.vehiclePlate,
    this.vehicleBrand,
    this.vehicleColor,
    this.riderType,
    this.rejectionReason,
    this.suspensionReason,
    this.approvedAt,
    this.documents = const [],
    this.canApprove = false,
    this.canReject = false,
    this.canMarkDocumentsReviewed = false,
  });

  final RiderApplication rider;
  final String? phone;
  final String? birthDate;
  final String? addressLine;
  final String? district;
  final String? addressProvince;
  final String? vehicleTypeText;
  final String? vehiclePlate;
  final String? vehicleBrand;
  final String? vehicleColor;
  final String? riderType;
  final String? rejectionReason;
  final String? suspensionReason;
  final DateTime? approvedAt;
  final List<RiderDocument> documents;
  final bool canApprove;
  final bool canReject;
  final bool canMarkDocumentsReviewed;

  String get address => [addressLine, district, addressProvince]
      .whereType<String>()
      .where((e) => e.isNotEmpty)
      .join(' ');

  String get vehicle => [vehicleTypeText, vehicleBrand, vehicleColor]
      .whereType<String>()
      .where((e) => e.isNotEmpty)
      .join(' · ');

  factory RiderDetail.fromJson(Map<String, dynamic> j) {
    final rider = RiderApplication.fromJson(j);
    final a = _m(j['address']);
    final v = _m(j['vehicle']);
    final actions = _m(j['actions']);
    return RiderDetail(
      rider: rider,
      phone: _s(j['phone']),
      birthDate: _s(j['birth_date']),
      addressLine: _s(a['line']),
      district: _s(a['district']),
      addressProvince: _s(a['province']),
      vehicleTypeText: _s(v['type_text'] ?? v['type']) ?? rider.vehicleTypeText,
      vehiclePlate: _s(v['plate']) ?? rider.vehiclePlate,
      vehicleBrand: _s(v['brand']),
      vehicleColor: _s(v['color']),
      riderType: _s(j['rider_type']),
      rejectionReason: _s(j['rejection_reason']),
      suspensionReason: _s(j['suspension_reason']),
      approvedAt: TpFmt.parse(j['approved_at']),
      documents: _maps(j['documents']).map(RiderDocument.fromJson).toList(),
      canApprove: _b(actions['can_approve']),
      canReject: _b(actions['can_reject']),
      canMarkDocumentsReviewed: _b(actions['can_mark_documents_reviewed']),
    );
  }
}

// ───────────────────────── 8.5 งานไรเดอร์ (เคลื่อนเงิน) ─────────────────────────

enum RiderJobFilter {
  needsDecision('needs_decision', 'รอตัดสินทั้งหมด'),
  disputed('disputed', 'ผู้ซื้อร้องเรียน'),
  awaitingRelease('awaiting_release', 'เงินพักรอปลด'),
  manualNeeded('manual_needed', 'หาไรเดอร์ไม่ได้'),
  handoverReview('handover_review', 'ตัดสินการส่งมอบ');

  const RiderJobFilter(this.key, this.label);
  final String key;
  final String label;

  static RiderJobFilter parse(String? v) =>
      RiderJobFilter.values.firstWhere((f) => f.key == v,
          orElse: () => RiderJobFilter.needsDecision);
}

class RiderJobAmounts {
  const RiderJobAmounts({
    this.orderTotal = 0,
    this.deliveryFee = 0,
    this.riderEarnings = 0,
    this.platformFee = 0,
    this.shopBonus = 0,
    this.cod = 0,
  });
  final double orderTotal;
  final double deliveryFee;
  final double riderEarnings;
  final double platformFee;
  final double shopBonus;
  final double cod;

  factory RiderJobAmounts.fromJson(dynamic j) {
    final m = _m(j);
    return RiderJobAmounts(
      orderTotal: TpFmt.toDouble(m['order_total_thb']),
      deliveryFee: TpFmt.toDouble(m['delivery_fee_thb']),
      riderEarnings: TpFmt.toDouble(m['rider_earnings_thb']),
      platformFee: TpFmt.toDouble(m['platform_fee_thb']),
      shopBonus: TpFmt.toDouble(m['shop_bonus_thb']),
      cod: TpFmt.toDouble(m['cod_thb']),
    );
  }
}

class RiderJob {
  const RiderJob({
    required this.id,
    required this.jobNumber,
    required this.status,
    this.statusText,
    this.jobType,
    this.decisionType,
    this.reasonText,
    this.reasonNote,
    this.amounts = const RiderJobAmounts(),
    this.orderNumber,
    this.rider,
    this.customer,
    this.handoverStatusText,
    this.disputedAt,
    this.waitedPhotoAt,
    this.buyerConfirmedAt,
    this.autoReleaseAt,
    this.createdAt,
    this.waitingMinutes,
    this.canRelease = false,
    this.canRefund = false,
    this.canReassign = false,
    this.canRedispatch = false,
  });

  final int id;
  final String jobNumber;
  final String status;
  final String? statusText;
  final String? jobType;

  /// dispute · awaiting_release · manual_dispatch · handover_review · none
  final String? decisionType;
  final String? reasonText;
  final String? reasonNote;
  final RiderJobAmounts amounts;
  final String? orderNumber;
  final PersonRef? rider;
  final PersonRef? customer;
  final String? handoverStatusText;
  final DateTime? disputedAt;
  final DateTime? waitedPhotoAt;
  final DateTime? buyerConfirmedAt;
  final DateTime? autoReleaseAt;
  final DateTime? createdAt;
  final int? waitingMinutes;
  final bool canRelease;
  final bool canRefund;
  final bool canReassign;
  final bool canRedispatch;

  bool get hasAction => canRelease || canRefund || canReassign || canRedispatch;

  factory RiderJob.fromJson(Map<String, dynamic> j) {
    final reason = j['reason'];
    final r = _m(reason);
    final order = _m(j['order']);
    final h = _m(j['handover']);
    final actions = _m(j['actions']);
    return RiderJob(
      id: TpFmt.toInt(j['id']),
      jobNumber: _s(j['job_number']) ?? 'งาน #${j['id']}',
      status: _s(j['status']) ?? '',
      statusText: _s(j['status_text']),
      jobType: _s(j['job_type']),
      decisionType: _s(j['decision_type']),
      reasonText: reason is Map ? _s(r['text']) : _s(reason),
      reasonNote: _s(r['note']),
      amounts: RiderJobAmounts.fromJson(j['amounts']),
      orderNumber: _s(order['order_number']) ??
          (order['id'] == null ? null : '#${order['id']}'),
      rider: PersonRef.parse(j['rider']),
      customer: PersonRef.parse(j['customer']),
      handoverStatusText: _s(h['status_text']),
      disputedAt: TpFmt.parse(h['disputed_at']),
      waitedPhotoAt: TpFmt.parse(h['waited_photo_at']),
      buyerConfirmedAt: TpFmt.parse(h['buyer_confirmed_at']),
      autoReleaseAt: TpFmt.parse(h['auto_release_at']),
      createdAt: TpFmt.parse(j['created_at']),
      waitingMinutes: _intOrNull(j['waiting_minutes']),
      canRelease: _b(actions['can_release']),
      canRefund: _b(actions['can_refund']),
      canReassign: _b(actions['can_reassign']),
      canRedispatch: _b(actions['can_redispatch']),
    );
  }
}

class HandoverPhoto {
  const HandoverPhoto(
      {required this.kind, required this.label, this.takenAt, this.url});
  final String kind;
  final String label;
  final DateTime? takenAt;
  final String? url;
}

class EligibleRider {
  const EligibleRider({
    required this.id,
    required this.fullName,
    this.vehicleTypeText,
    this.availabilityText,
    this.online = false,
    this.distanceKm,
  });
  final int id;
  final String fullName;
  final String? vehicleTypeText;
  final String? availabilityText;
  final bool online;
  final double? distanceKm;
}

class RiderJobDetail {
  const RiderJobDetail({
    required this.job,
    this.title,
    this.pickupAddress,
    this.pickupContact,
    this.deliveryAddress,
    this.deliveryContact,
    this.distanceKm,
    this.timeline = const [],
    this.cancellationReason,
    this.failureReason,
    this.dispatchRound,
    this.photos = const [],
    this.eligibleRiders = const [],
  });

  final RiderJob job;
  final String? title;
  final String? pickupAddress;
  final String? pickupContact;
  final String? deliveryAddress;
  final String? deliveryContact;
  final double? distanceKm;

  /// ลำดับเหตุการณ์ที่มีเวลาแล้ว (ชื่อไทย, เวลา) เรียงตามเวลา
  final List<(String, DateTime)> timeline;
  final String? cancellationReason;
  final String? failureReason;
  final int? dispatchRound;
  final List<HandoverPhoto> photos;
  final List<EligibleRider> eligibleRiders;

  static const _steps = {
    'created_at': 'สร้างงาน',
    'accepted_at': 'ไรเดอร์รับงาน',
    'picked_up_at': 'รับของแล้ว',
    'delivered_at': 'ส่งถึงปลายทาง',
    'completed_at': 'ปิดงานสำเร็จ',
    'cancelled_at': 'ยกเลิกงาน',
    'failed_at': 'ส่งไม่สำเร็จ',
  };

  factory RiderJobDetail.fromJson(Map<String, dynamic> j) {
    final job = RiderJob.fromJson(j);
    final p = _m(j['pickup']);
    final d = _m(j['delivery']);
    final t = _m(j['timeline']);
    final steps = <(String, DateTime)>[
      for (final e in _steps.entries)
        if (TpFmt.parse(t[e.key]) != null) (e.value, TpFmt.parse(t[e.key])!)
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return RiderJobDetail(
      job: job,
      title: _s(j['title']),
      pickupAddress: _s(p['address']),
      pickupContact: _s(p['contact_name']),
      deliveryAddress: _s(d['address']),
      deliveryContact: _s(d['contact_name']),
      distanceKm: _dblOrNull(j['distance_km']),
      timeline: steps,
      cancellationReason: _s(j['cancellation_reason']),
      failureReason: _s(j['failure_reason']),
      dispatchRound: _intOrNull(j['dispatch_round']),
      photos: [
        for (final ph in _maps(j['handover_photos']))
          HandoverPhoto(
            kind: _s(ph['kind']) ?? '',
            label: _s(ph['label']) ?? 'รูปหลักฐาน',
            takenAt: TpFmt.parse(ph['taken_at']),
            url: _s(ph['url']),
          )
      ],
      eligibleRiders: [
        for (final r in _maps(j['eligible_riders']))
          EligibleRider(
            id: TpFmt.toInt(r['id']),
            fullName: _s(r['full_name'] ?? r['name']) ?? 'ไรเดอร์ #${r['id']}',
            vehicleTypeText: _s(r['vehicle_type_text']),
            availabilityText: _s(r['availability_text']),
            online: _s(r['availability']) == 'online',
            distanceKm: _dblOrNull(r['distance_to_pickup_km']),
          )
      ],
    );
  }
}

// ───────────────────────── 8.7 ตั๋วซัพพอร์ต ─────────────────────────

enum TicketFilter {
  open('open', 'รอทีมงาน'),
  pending('pending', 'รอลูกค้า'),
  closed('closed', 'ปิดแล้ว'),
  all('all', 'ทั้งหมด');

  const TicketFilter(this.key, this.label);
  final String key;
  final String label;
}

enum TicketPriority {
  any(null, 'ทุกระดับ'),
  critical('critical', 'วิกฤต'),
  high('high', 'สูง'),
  medium('medium', 'กลาง'),
  low('low', 'ต่ำ');

  const TicketPriority(this.key, this.label);
  final String? key;
  final String label;
}

class TicketItem {
  const TicketItem({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.status,
    this.statusLabel,
    this.bucket,
    this.priority,
    this.priorityLabel,
    this.category,
    this.user,
    this.assignedTo,
    this.repliesCount = 0,
    this.isOverdue = false,
    this.createdAt,
    this.lastReplyAt,
    this.waitingMinutes,
  });

  final int id;
  final String ticketNumber;
  final String subject;
  final String status;
  final String? statusLabel;
  final String? bucket;
  final String? priority;
  final String? priorityLabel;
  final String? category;
  final PersonRef? user;
  final String? assignedTo;
  final int repliesCount;
  final bool isOverdue;
  final DateTime? createdAt;
  final DateTime? lastReplyAt;
  final int? waitingMinutes;

  bool get isClosed =>
      bucket == 'closed' || status == 'resolved' || status == 'closed';

  factory TicketItem.fromJson(Map<String, dynamic> j) => TicketItem(
        id: TpFmt.toInt(j['id']),
        ticketNumber: _s(j['ticket_number']) ?? '#${j['id']}',
        subject: _s(j['subject']) ?? 'ไม่มีหัวข้อ',
        status: _s(j['status']) ?? '',
        statusLabel: _s(j['status_label']),
        bucket: _s(j['bucket']),
        priority: _s(j['priority']),
        priorityLabel: _s(j['priority_label']),
        category: _s(j['category']),
        user: PersonRef.parse(j['user']),
        assignedTo: _s(_m(j['assigned_to'])['name']) ?? _s(j['assigned_to']),
        repliesCount: TpFmt.toInt(j['replies_count']),
        isOverdue: _b(j['is_overdue']),
        createdAt: TpFmt.parse(j['created_at']),
        lastReplyAt: TpFmt.parse(j['last_reply_at']),
        waitingMinutes: _intOrNull(j['waiting_minutes']),
      );
}

class TicketMessage {
  const TicketMessage({
    this.id,
    required this.sender,
    required this.message,
    this.author,
    this.internal = false,
    this.at,
  });
  final int? id;

  /// customer · staff
  final String sender;
  final String message;
  final String? author;
  final bool internal;
  final DateTime? at;

  bool get fromStaff => sender != 'customer';

  factory TicketMessage.fromJson(Map<String, dynamic> j) => TicketMessage(
        id: _intOrNull(j['id']),
        sender: _s(j['sender']) ?? 'customer',
        message: (j['message'] ?? '').toString().trim(),
        author: _s(j['author']),
        internal: _b(j['is_internal_note']),
        at: TpFmt.parse(j['at']),
      );
}

class TicketDetail {
  const TicketDetail({
    required this.ticket,
    this.description,
    this.resolutionNotes,
    this.dueAt,
    this.firstResponseAt,
    this.resolvedAt,
    this.closedAt,
    this.messages = const [],
    this.statuses = const [],
  });

  final TicketItem ticket;
  final String? description;
  final String? resolutionNotes;
  final DateTime? dueAt;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final List<TicketMessage> messages;

  /// สถานะที่ตั้งได้ (key, ป้ายไทย)
  final List<(String, String)> statuses;

  static const fallbackStatuses = [
    ('open', 'เปิด'),
    ('in_progress', 'กำลังดำเนินการ'),
    ('waiting_customer', 'รอลูกค้าตอบ'),
    ('resolved', 'แก้ไขแล้ว'),
    ('closed', 'ปิดตั๋ว'),
  ];

  factory TicketDetail.fromJson(Map<String, dynamic> j) {
    final st = [
      for (final s in _maps(j['statuses']))
        if (_s(s['key']) != null)
          (_s(s['key'])!, _s(s['label']) ?? _s(s['key'])!)
    ];
    return TicketDetail(
      ticket: TicketItem.fromJson(j),
      description: _s(j['description']),
      resolutionNotes: _s(j['resolution_notes']),
      dueAt: TpFmt.parse(j['due_at']),
      firstResponseAt: TpFmt.parse(j['first_response_at']),
      resolvedAt: TpFmt.parse(j['resolved_at']),
      closedAt: TpFmt.parse(j['closed_at']),
      messages: _maps(j['messages'])
          .map(TicketMessage.fromJson)
          .where((m) => m.message.isNotEmpty)
          .toList(),
      statuses: st.isEmpty ? fallbackStatuses : st,
    );
  }
}

// ───────────────────────── 8.8 คอมมิชชัน MLM (เคลื่อนเงิน) ─────────────────────────

enum MlmFilter {
  pending('pending', 'รออนุมัติ'),
  approved('approved', 'รอจ่าย'),
  paid('paid', 'จ่ายแล้ว'),
  rejected('rejected', 'ปฏิเสธแล้ว'),
  all('all', 'ทั้งหมด');

  const MlmFilter(this.key, this.label);
  final String key;
  final String label;
}

class MlmCommission {
  const MlmCommission({
    required this.id,
    required this.status,
    required this.amount,
    this.type,
    this.level,
    this.statusLabel,
    this.salesAmount,
    this.pvAmount,
    this.recipient,
    this.fromMember,
    this.plan,
    this.sourceType,
    this.sourceId,
    this.createdAt,
    this.approvedAt,
    this.paidAt,
    this.waitingMinutes,
    this.canApprove = false,
    this.canPay = false,
  });

  final int id;
  final String status;
  final double amount;
  final String? type;
  final int? level;
  final String? statusLabel;
  final double? salesAmount;
  final double? pvAmount;
  final PersonRef? recipient;
  final String? fromMember;
  final String? plan;
  final String? sourceType;
  final int? sourceId;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final int? waitingMinutes;
  final bool canApprove;
  final bool canPay;

  /// ชื่อประเภทคอมภาษาไทย
  String get typeLabel => switch (type) {
        'direct_referral' || 'direct' => 'ค่าแนะนำตรง',
        'unilevel' => 'ค่าคอมสายงาน',
        'unilevel_rollup' => 'ค่าคอมสายงาน (ทบขึ้น)',
        'binary' || 'binary_pair' => 'ค่าคอมจับคู่',
        'matching' => 'โบนัสแมตชิ่ง',
        'pool_bonus' || 'pool' => 'โบนัสกองกลาง',
        'leadership' => 'โบนัสผู้นำ',
        'rank_bonus' => 'โบนัสระดับ',
        null => 'คอมมิชชัน',
        _ => type!.replaceAll('_', ' '),
      };

  factory MlmCommission.fromJson(Map<String, dynamic> j) {
    final actions = _m(j['actions']);
    final status = _s(j['status']) ?? '';
    final source = _m(j['source']);
    return MlmCommission(
      id: TpFmt.toInt(j['id']),
      status: status,
      amount: TpFmt.toDouble(j['amount_thb'] ?? j['commission_amount']),
      type: _s(j['type']),
      level: _intOrNull(j['level']),
      statusLabel: _s(j['status_label']),
      salesAmount: _dblOrNull(j['sales_amount_thb']),
      pvAmount: _dblOrNull(j['pv_amount']),
      recipient: PersonRef.parse(j['recipient']),
      fromMember: _s(_m(j['from_member'])['name']),
      plan: _s(j['plan']),
      sourceType: _s(source['type']),
      sourceId: _intOrNull(source['id']),
      createdAt: TpFmt.parse(j['created_at']),
      approvedAt: TpFmt.parse(j['approved_at']),
      paidAt: TpFmt.parse(j['paid_at']),
      waitingMinutes: _intOrNull(j['waiting_minutes']),
      canApprove: actions.containsKey('can_approve')
          ? _b(actions['can_approve'])
          : status == 'pending',
      canPay: actions.containsKey('can_pay')
          ? _b(actions['can_pay'])
          : status == 'approved',
    );
  }
}

class MlmTotals {
  const MlmTotals(
      {this.pendingCount = 0,
      this.pendingAmount = 0,
      this.approvedCount = 0,
      this.approvedAmount = 0});
  final int pendingCount;
  final double pendingAmount;
  final int approvedCount;
  final double approvedAmount;

  static MlmTotals? parse(dynamic j) {
    if (j is! Map) return null;
    final m = _m(j);
    return MlmTotals(
      pendingCount: TpFmt.toInt(m['pending_count']),
      pendingAmount: TpFmt.toDouble(m['pending_amount_thb']),
      approvedCount: TpFmt.toInt(m['approved_count']),
      approvedAmount: TpFmt.toDouble(m['approved_amount_thb']),
    );
  }
}

// ───────────────────────── Repository ─────────────────────────

/// คิวอนุมัติทั้งหมด (`/api/admin/approvals/*`) + ระงับ/ยกเลิกระงับ/รีเซ็ต PIN ผู้ใช้
///
/// ทุกการกระทำ: success:false / HTTP ≥ 400 → throw [ApprovalError] (ข้อความไทยจากเซิร์ฟเวอร์)
/// · `already_decided` / `already` = สำเร็จ (ไม่มีอะไรขยับซ้ำ)
class ApprovalsRepository {
  ApprovalsRepository(this._api);
  final ApiClient _api;

  // ── สรุป ──
  Future<ApprovalsSummary> summary() async =>
      ApprovalsSummary.fromJson(_m(await _get('/approvals/summary')));

  // ── eKYC ──
  Future<Paged<EkycItem>> ekycList(
          {EkycFilter filter = EkycFilter.pending,
          String? search,
          int page = 1}) async =>
      Paged.parse(
          await _get('/approvals/ekyc',
              {'status': filter.key, 'search': search, 'page': page}),
          EkycItem.fromJson);

  Future<EkycDetail> ekycDetail(int id) async =>
      EkycDetail.fromJson(_m(await _get('/approvals/ekyc/$id')));

  Future<ApprovalResult> approveEkyc(int id) =>
      _act('/approvals/ekyc/$id/approve',
          done: 'อนุมัติการยืนยันตัวตนเรียบร้อยแล้ว');

  Future<ApprovalResult> rejectEkyc(int id, String reason) =>
      _act('/approvals/ekyc/$id/reject',
          body: {'reason': reason}, done: 'ปฏิเสธการยืนยันตัวตนแล้ว');

  Future<ApprovalResult> requestEkycRetake(int id, String reason) =>
      _act('/approvals/ekyc/$id/request-retake',
          body: {'reason': reason}, done: 'ส่งคำขอให้ถ่ายใหม่แล้ว');

  // ── ร้านค้า ──
  Future<Paged<SellerApplication>> sellerList(
          {SellerFilter filter = SellerFilter.pending,
          String? search,
          int page = 1}) async =>
      Paged.parse(
          await _get('/approvals/seller-applications',
              {'status': filter.key, 'search': search, 'page': page}),
          SellerApplication.fromJson);

  Future<SellerDetail> sellerDetail(int id) async => SellerDetail.fromJson(
      _m(await _get('/approvals/seller-applications/$id')));

  Future<ApprovalResult> approveSeller(int id) =>
      _act('/approvals/seller-applications/$id/approve',
          done: 'อนุมัติร้านค้าเรียบร้อย');

  Future<ApprovalResult> rejectSeller(int id, String reason) =>
      _act('/approvals/seller-applications/$id/reject',
          body: {'reason': reason}, done: 'ปฏิเสธคำขอเปิดร้านแล้ว');

  // ── ไรเดอร์ ──
  Future<Paged<RiderApplication>> riderList(
          {RiderFilter filter = RiderFilter.pending,
          String? search,
          int page = 1}) async =>
      Paged.parse(
          await _get('/approvals/riders',
              {'status': filter.key, 'search': search, 'page': page}),
          RiderApplication.fromJson);

  Future<RiderDetail> riderDetail(int id) async =>
      RiderDetail.fromJson(_m(await _get('/approvals/riders/$id')));

  Future<ApprovalResult> approveRider(int id) =>
      _act('/approvals/riders/$id/approve', done: 'อนุมัติไรเดอร์เรียบร้อย');

  Future<ApprovalResult> rejectRider(int id, String reason) =>
      _act('/approvals/riders/$id/reject',
          body: {'reason': reason}, done: 'ปฏิเสธใบสมัครไรเดอร์แล้ว');

  Future<ApprovalResult> riderDocumentsReviewed(int id) =>
      _act('/approvals/riders/$id/documents-reviewed',
          done: 'ยืนยันเอกสารแล้ว ไรเดอร์รับงานต่อได้');

  // ── งานไรเดอร์ (เคลื่อนเงิน) ──
  Future<Paged<RiderJob>> riderJobs(
          {RiderJobFilter filter = RiderJobFilter.needsDecision,
          int page = 1}) async =>
      Paged.parse(
          await _get(
              '/approvals/rider-jobs', {'filter': filter.key, 'page': page}),
          RiderJob.fromJson);

  Future<RiderJobDetail> riderJobDetail(int id) async =>
      RiderJobDetail.fromJson(_m(await _get('/approvals/rider-jobs/$id')));

  Future<ApprovalResult> releaseRiderJob(int id, {String? reason}) =>
      _act('/approvals/rider-jobs/$id/release',
          body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
          done: 'ปล่อยเงินแล้ว งานปิดเป็นส่งสำเร็จ');

  Future<ApprovalResult> refundRiderJob(int id, String reason) =>
      _act('/approvals/rider-jobs/$id/refund',
          body: {'reason': reason}, done: 'คืนเงินผู้ซื้อเต็มจำนวนแล้ว');

  Future<ApprovalResult> reassignRiderJob(int id, int riderId) =>
      _act('/approvals/rider-jobs/$id/reassign',
          body: {'rider_id': riderId}, done: 'มอบหมายงานให้ไรเดอร์แล้ว');

  Future<ApprovalResult> redispatchRiderJob(int id) =>
      _act('/approvals/rider-jobs/$id/redispatch',
          done: 'สร้างงานใหม่ให้ออเดอร์นี้แล้ว');

  // ── ตั๋ว ──
  Future<Paged<TicketItem>> tickets(
          {TicketFilter filter = TicketFilter.open,
          TicketPriority priority = TicketPriority.any,
          String? search,
          int page = 1}) async =>
      Paged.parse(
          await _get('/approvals/tickets', {
            'status': filter.key,
            'priority': priority.key,
            'search': search,
            'page': page,
          }),
          TicketItem.fromJson);

  Future<TicketDetail> ticketDetail(int id) async =>
      TicketDetail.fromJson(_m(await _get('/approvals/tickets/$id')));

  /// ตอบลูกค้า — `already` = ข้อความเดิมเพิ่งส่งไป (ไม่ส่งซ้ำถึงลูกค้า)
  Future<ApprovalResult> replyTicket(int id, String message) async {
    final r = await _act('/approvals/tickets/$id/reply',
        body: {'message': message}, done: 'ส่งข้อความตอบกลับแล้ว');
    return r.data['duplicate'] == true
        ? ApprovalResult(
            message: 'ข้อความนี้เพิ่งส่งไปแล้ว — ไม่ได้ส่งซ้ำถึงลูกค้า',
            already: true,
            data: r.data)
        : r;
  }

  Future<ApprovalResult> setTicketStatus(int id, String status,
          {String? resolutionNotes}) =>
      _act('/approvals/tickets/$id/status',
          body: {
            'status': status,
            if (resolutionNotes != null && resolutionNotes.isNotEmpty)
              'resolution_notes': resolutionNotes,
          },
          done: 'อัปเดตสถานะตั๋วเรียบร้อยแล้ว');

  // ── คอมมิชชัน MLM (เคลื่อนเงิน) ──
  Future<(Paged<MlmCommission>, MlmTotals?)> mlmCommissions(
      {MlmFilter filter = MlmFilter.pending, int page = 1}) async {
    final data = await _get(
        '/approvals/mlm-commissions', {'status': filter.key, 'page': page});
    return (
      Paged.parse(data, MlmCommission.fromJson),
      MlmTotals.parse(_m(data)['summary'])
    );
  }

  Future<ApprovalResult> approveMlm(int id) =>
      _act('/approvals/mlm-commissions/$id/approve',
          done: 'อนุมัติคอมมิชชั่นแล้ว');

  Future<ApprovalResult> payMlm(int id) =>
      _act('/approvals/mlm-commissions/$id/pay', done: 'จ่ายคอมมิชชั่นแล้ว');

  // ── ผู้ใช้ ──
  Future<ApprovalResult> suspendUser(int userId, {String? reason}) =>
      _act('/users/$userId/suspend',
          body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
          done: 'ระงับบัญชีเรียบร้อย');

  Future<ApprovalResult> unsuspendUser(int userId) =>
      _act('/users/$userId/unsuspend', done: 'ยกเลิกการระงับบัญชีแล้ว');

  Future<ApprovalResult> resetWalletPin(int userId) =>
      _act('/users/$userId/reset-wallet-pin',
          done: 'รีเซ็ต PIN สำเร็จ ผู้ใช้ตั้ง PIN ใหม่ได้');

  // ───────────── ภายใน ─────────────

  /// GET แล้วคืน `data` ใน envelope — ทุก error แปลงเป็นข้อความไทย (ยกเว้นเน็ตหลุด/หมดเวลา ปล่อยให้ tpErrorText จัดการ)
  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    final q = <String, dynamic>{
      for (final e in (query ?? const <String, dynamic>{}).entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: e.value
    };
    final Response<dynamic> res;
    try {
      res = await _api.dio.get<dynamic>(path, queryParameters: q);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) throw _error(e.response);
      rethrow;
    }
    final body = _m(res.data);
    if ((res.statusCode ?? 0) >= 400 || body['success'] != true) {
      throw _error(res);
    }
    return body['data'];
  }

  /// POST การกระทำ → [ApprovalResult] หรือ throw [ApprovalError]
  Future<ApprovalResult> _act(String path,
      {Map<String, dynamic>? body, required String done}) async {
    final Response<dynamic> res;
    try {
      res = await _api.dio
          .post<dynamic>(path, data: body ?? const <String, dynamic>{});
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) throw _error(e.response);
      rethrow;
    }
    final b = _m(res.data);
    final data = _m(b['data']);
    final already = _b(data['already_decided']) || _b(data['already']);
    final msg = _s(b['message']);
    final okMsg = (msg != null && _thai.hasMatch(msg)) ? msg : done;
    if ((res.statusCode ?? 0) >= 400 || b['success'] != true) {
      // ทนไว้: ถ้าเซิร์ฟเวอร์บอกว่าเป็นผลนี้อยู่แล้ว ถือว่าสำเร็จ
      if (already) {
        return ApprovalResult(message: okMsg, already: true, data: data);
      }
      throw _error(res);
    }
    return ApprovalResult(message: okMsg, already: already, data: data);
  }

  ApprovalError _error(Response<dynamic>? res) {
    final code = res?.statusCode ?? 0;
    final b = _m(res?.data);
    final errorCode = _s(b['error_code'] ?? b['code']);
    var msg = _s(b['message']);
    // ข้อความภาษาอังกฤษจาก framework (route ไม่มี / Unauthenticated / Too Many Attempts) ห้ามโชว์ดิบ
    if (msg == null || !_thai.hasMatch(msg)) msg = null;
    // ข้อผิดพลาดแรกของ validation (ถ้ามี) เป็นภาษาไทย
    if (msg == null && b['errors'] is Map) {
      for (final v in _m(b['errors']).values) {
        final first = v is List && v.isNotEmpty ? _s(v.first) : _s(v);
        if (first != null && _thai.hasMatch(first)) {
          msg = first;
          break;
        }
      }
    }
    msg ??= switch (code) {
      401 => 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
      403 => 'บัญชีนี้ไม่มีสิทธิ์ทำรายการนี้',
      404 when errorCode == null =>
        'เซิร์ฟเวอร์ยังไม่รองรับคิวอนุมัติ — รออัปเดตระบบหลังบ้าน',
      404 => 'ไม่พบรายการนี้ (อาจถูกลบหรือเปลี่ยนสถานะไปแล้ว)',
      409 => 'รายการนี้เปลี่ยนสถานะไปแล้ว — โหลดรายการใหม่',
      422 => 'ข้อมูลไม่ถูกต้อง',
      429 => 'ทำรายการถี่เกินไป รอสักครู่แล้วลองใหม่',
      >= 500 => 'เซิร์ฟเวอร์ขัดข้องชั่วคราว ($code) ลองใหม่อีกครั้ง',
      _ => 'ทำรายการไม่สำเร็จ ($code)',
    };
    return ApprovalError(msg,
        statusCode: code, errorCode: errorCode, data: _m(b['data']));
  }
}

final approvalsRepositoryProvider = Provider<ApprovalsRepository>(
    (ref) => ApprovalsRepository(ref.watch(apiClientProvider)));

/// ตัวเลขป้ายทุกคิว — รีเฟรชตามรอบของสรุปงานหลัก (แอปรีเฟรชทุก 30 วินาทีและหยุดตอนพับแอป)
/// จึงไม่ต้องตั้งเวลาเอง · เซิร์ฟเวอร์แคช 20 วินาทีใช้ร่วมทุกแอดมิน
final approvalsSummaryProvider =
    FutureProvider.autoDispose<ApprovalsSummary>((ref) {
  ref.watch(opsSummaryProvider.select((s) => s.valueOrNull?.fetchedAt));
  return ref.watch(approvalsRepositoryProvider).summary();
});

final ekycDetailProvider = FutureProvider.autoDispose.family<EkycDetail, int>(
    (ref, id) => ref.watch(approvalsRepositoryProvider).ekycDetail(id));

final sellerDetailProvider = FutureProvider.autoDispose
    .family<SellerDetail, int>(
        (ref, id) => ref.watch(approvalsRepositoryProvider).sellerDetail(id));

final riderDetailProvider = FutureProvider.autoDispose.family<RiderDetail, int>(
    (ref, id) => ref.watch(approvalsRepositoryProvider).riderDetail(id));

final riderJobDetailProvider = FutureProvider.autoDispose
    .family<RiderJobDetail, int>(
        (ref, id) => ref.watch(approvalsRepositoryProvider).riderJobDetail(id));

final ticketDetailProvider = FutureProvider.autoDispose
    .family<TicketDetail, int>(
        (ref, id) => ref.watch(approvalsRepositoryProvider).ticketDetail(id));
