import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import '../../../shared/ui/tp_format.dart';
import '../../work/data/work_repository.dart';

Map<String, dynamic> _m(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};

/// ตัวกรองกล่องแชท (ตรงกับ `takeover/conversations?status=`)
enum ChatFilter {
  requested('requested', 'ขอคุยกับแอดมิน'),
  takenOver('taken_over', 'แอดมินคุมอยู่'),
  active('active', 'กำลังคุยทั้งหมด');

  const ChatFilter(this.key, this.label);
  final String key;
  final String label;
}

class Conversation {
  const Conversation({
    required this.readingId,
    required this.billNumber,
    this.customerName,
    this.platform,
    this.packageLabel,
    this.isPaid = false,
    this.stageLabel,
    this.isTakenOver = false,
    this.reasonLabel,
    this.requestedByCustomer = false,
    this.requestKeyword,
    this.takeoverUntil,
    this.remainingMinutes = 0,
    this.lastSender,
    this.lastText,
    this.lastAt,
    this.unread = false,
    this.updatedAt,
  });

  final int readingId;
  final String billNumber;
  final String? customerName;
  final String? platform;
  final String? packageLabel;
  final bool isPaid;
  final String? stageLabel;
  final bool isTakenOver;
  final String? reasonLabel;
  final bool requestedByCustomer;
  final String? requestKeyword;
  final DateTime? takeoverUntil;
  final int remainingMinutes;
  final String? lastSender;
  final String? lastText;
  final DateTime? lastAt;
  final bool unread;
  final DateTime? updatedAt;

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final last = _m(j['last_message']);
    final stage = j['stage'];
    return Conversation(
      readingId: TpFmt.toInt(j['reading_id'] ?? j['id']),
      billNumber: (j['bill_number'] ?? 'R${j['reading_id']}').toString(),
      customerName: j['customer_name']?.toString(),
      platform: j['platform']?.toString(),
      packageLabel: j['package_label']?.toString(),
      isPaid: j['is_paid'] == true,
      stageLabel: stage is Map ? stage['label']?.toString() : null,
      isTakenOver: j['is_taken_over'] == true,
      reasonLabel: j['takeover_reason_label']?.toString(),
      requestedByCustomer: j['requested_by_customer'] == true,
      requestKeyword: j['request_keyword']?.toString(),
      takeoverUntil: TpFmt.parse(j['takeover_until']),
      remainingMinutes: TpFmt.toInt(j['remaining_minutes']),
      lastSender: last['sender']?.toString(),
      lastText: last['text']?.toString(),
      lastAt: TpFmt.parse(last['at']),
      unread: j['unread'] == true,
      updatedAt: TpFmt.parse(j['updated_at']),
    );
  }
}

class ChatMsg {
  const ChatMsg({required this.id, required this.sender, required this.text, this.at, this.adminName, this.imageUrl});
  final int id;

  /// customer | bot | admin | system
  final String sender;
  final String text;
  final DateTime? at;
  final String? adminName;
  final String? imageUrl;

  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(
        id: TpFmt.toInt(j['id']),
        sender: (j['sender'] ?? j['role'] ?? 'system').toString(),
        text: (j['text'] ?? '').toString(),
        at: TpFmt.parse(j['at'] ?? j['ts']),
        adminName: j['admin_name']?.toString(),
        imageUrl: j['image_url']?.toString(),
      );
}

class TakeoverStats {
  const TakeoverStats({this.takenOver = 0, this.requested = 0, this.active = 0, this.today = 0, this.defaultMinutes = 30, this.enabled = true});
  final int takenOver;
  final int requested;
  final int active;
  final int today;
  final int defaultMinutes;
  final bool enabled;

  int count(ChatFilter f) => switch (f) {
        ChatFilter.requested => requested,
        ChatFilter.takenOver => takenOver,
        ChatFilter.active => active,
      };

  factory TakeoverStats.fromJson(Map<String, dynamic> j) => TakeoverStats(
        takenOver: TpFmt.toInt(j['taken_over']),
        requested: TpFmt.toInt(j['requested']),
        active: TpFmt.toInt(j['active_conversations']),
        today: TpFmt.toInt(j['takeovers_today']),
        defaultMinutes: TpFmt.toInt(j['default_minutes']) > 0 ? TpFmt.toInt(j['default_minutes']) : 30,
        enabled: j['takeover_enabled'] != false,
      );
}

class TakeoverState {
  const TakeoverState({required this.active, this.until, this.remainingMinutes = 0});
  final bool active;
  final DateTime? until;
  final int remainingMinutes;

  factory TakeoverState.fromJson(Map<String, dynamic> j) => TakeoverState(
        active: j['is_takeover'] == true,
        until: TpFmt.parse(j['until']),
        remainingMinutes: TpFmt.toInt(j['remaining_minutes']),
      );
}

class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<Paged<Conversation>> conversations(ChatFilter f, {int page = 1, String? search}) async {
    final data = await _api.get<dynamic>('/takeover/conversations', query: {
      'status': f.key,
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return Paged.parse(data, Conversation.fromJson);
  }

  Future<TakeoverStats> stats() async =>
      TakeoverStats.fromJson(await _api.get<Map<String, dynamic>>('/takeover/stats', parser: (d) => _m(d)));

  Future<List<ChatMsg>> messages(int readingId) async {
    final data = await _api.get<Map<String, dynamic>>('/takeover/$readingId/messages', parser: (d) => _m(d));
    final list = (data['messages'] as List?) ?? const [];
    return list.whereType<Map>().map((e) => ChatMsg.fromJson(e.cast<String, dynamic>())).toList();
  }

  /// ข้อมูลหัวห้องแชท (ชื่อลูกค้า/แพลตฟอร์ม/แพคเกจ) — ค้นบิลด้วย `#id`
  Future<FortuneBill?> header(int readingId) async {
    final data = await _api.get<dynamic>('/fortune/bills', query: {'status': 'all', 'search': '#$readingId', 'per_page': 1});
    final items = Paged.parse(data, FortuneBill.fromJson).items;
    return items.where((b) => b.id == readingId).firstOrNull ?? items.firstOrNull;
  }

  Future<TakeoverState> takeoverStatus(int readingId) async => TakeoverState.fromJson(
      await _api.get<Map<String, dynamic>>('/chat/takeover-status', query: {'reading_id': readingId}, parser: (d) => _m(d)));

  Future<TakeoverState> takeover(int readingId, {int minutes = 30}) =>
      _action('/chat/takeover', {'reading_id': readingId, 'minutes': minutes});

  Future<TakeoverState> extend(int readingId, int minutes) =>
      _action('/chat/extend', {'reading_id': readingId, 'minutes': minutes});

  Future<TakeoverState> resume(int readingId) => _action('/chat/resume', {'reading_id': readingId});

  /// ส่งข้อความหาลูกค้า — ล้ม = throw ข้อความไทย (เช่น LINE โควตาหมด / FB เกิน 24 ชม.)
  Future<void> send(int readingId, String text) async {
    final res = await _api.dio.post<Map<String, dynamic>>('/chat/send', data: {'reading_id': readingId, 'text': text});
    final b = res.data ?? const {};
    if (b['success'] == true) return;
    final code = res.statusCode ?? 0;
    final raw = (b['message'] ?? '').toString();
    if (raw.contains('platform service rejected') || code == 502) {
      throw ActionError('แพลตฟอร์มไม่รับข้อความ — LINE อาจหมดโควตา push หรือ Messenger เกิน 24 ชม.หลังลูกค้าทักล่าสุด');
    }
    throw ActionError(raw.isEmpty ? 'ส่งข้อความไม่สำเร็จ ($code)' : 'ส่งข้อความไม่สำเร็จ');
  }

  /// ให้ AI ร่างคำตอบจากบทสนทนาล่าสุด
  Future<String> suggest(int readingId, String context, {String? customerName}) async {
    final data = await _api.post<Map<String, dynamic>>('/chat/suggest',
        data: {'reading_id': readingId, 'context_text': context, if (customerName != null) 'customer_name': customerName},
        parser: (d) => _m(d));
    return (data['suggestion'] ?? '').toString().trim();
  }

  Future<TakeoverState> _action(String path, Map<String, dynamic> body) async {
    final res = await _api.dio.post<Map<String, dynamic>>(path, data: body);
    final b = res.data ?? const {};
    if (b['success'] != true) {
      throw ActionError((res.statusCode ?? 0) == 404 ? 'ไม่พบบทสนทนานี้' : 'ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
    final d = _m(b['data']);
    return TakeoverState(
      active: d['is_takeover'] == true,
      until: TpFmt.parse(d['until']),
      remainingMinutes: TpFmt.toInt(d['remaining_minutes']),
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));

final takeoverStatsProvider = FutureProvider.autoDispose<TakeoverStats>((ref) => ref.watch(chatRepositoryProvider).stats());
