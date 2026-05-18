// Inbox + Chat models — mirror backend `fortune_readings` + `fortune_messages`
//
// Brain refs:
// - [[Thaiprompt Fortune Bot - Admin Takeover & FB Handover Limitations]]
//   FortuneTakeoverService::isActive() · admin_takeover_until field
//   Triggers: customer keyword / admin button / /ai resume
//   Settings: takeover_default_minutes (30-60) · customer_handoff_keywords
// - [[2026-05-17-session-fortune-celtic-shuffle-typing-delay-admin-takeover-chart-fix]]
//   admin manual send → HUMAN_AGENT message_tag (FB 7-day window vs 24hr)

import 'package:flutter/material.dart';

/// Aggregate state for a conversation (one per fortune_reading)
enum ConversationStatus {
  /// Bot กำลังคุย ลูกค้ายังไม่ได้ขอ admin
  activeBot,

  /// ลูกค้าพิมพ์ keyword "คุยกับแอดมิน" — รอ admin เปิด takeover
  customerRequestedAdmin,

  /// Admin takeover เปิดอยู่ + ยังไม่หมดเวลา
  takeoverActive,

  /// Takeover เหลือ < 5 นาที — เตือนให้ extend
  takeoverExpiring,

  /// Takeover หมดเวลาแล้ว — กลับมาเป็น bot
  takeoverExpired,

  /// Reading ปิดแล้ว
  closed,
}

extension ConversationStatusLabel on ConversationStatus {
  String get label => switch (this) {
        ConversationStatus.activeBot => 'Bot กำลังคุย',
        ConversationStatus.customerRequestedAdmin => 'ลูกค้าขอแอดมิน',
        ConversationStatus.takeoverActive => 'Takeover',
        ConversationStatus.takeoverExpiring => 'ใกล้หมดเวลา',
        ConversationStatus.takeoverExpired => 'หมดเวลา',
        ConversationStatus.closed => 'ปิดแล้ว',
      };

  Color get color => switch (this) {
        ConversationStatus.activeBot => const Color(0xFF6366F1),
        ConversationStatus.customerRequestedAdmin => const Color(0xFFEF4444),
        ConversationStatus.takeoverActive => const Color(0xFF22D3EE),
        ConversationStatus.takeoverExpiring => const Color(0xFFF59E0B),
        ConversationStatus.takeoverExpired => const Color(0xFF94A3B8),
        ConversationStatus.closed => const Color(0xFF64748B),
      };

  /// sort priority — lower = shown first
  int get sortRank => switch (this) {
        ConversationStatus.customerRequestedAdmin => 0,
        ConversationStatus.takeoverExpiring => 1,
        ConversationStatus.takeoverActive => 2,
        ConversationStatus.activeBot => 3,
        ConversationStatus.takeoverExpired => 4,
        ConversationStatus.closed => 5,
      };

  static ConversationStatus parse(String raw) => switch (raw) {
        'customer_requested_admin' =>
          ConversationStatus.customerRequestedAdmin,
        'takeover_active' => ConversationStatus.takeoverActive,
        'takeover_expiring' => ConversationStatus.takeoverExpiring,
        'takeover_expired' => ConversationStatus.takeoverExpired,
        'closed' => ConversationStatus.closed,
        _ => ConversationStatus.activeBot,
      };
}

class FortuneConversation {
  FortuneConversation({
    required this.readingId,
    required this.billNumber,
    required this.customerName,
    required this.platform,
    this.platformUserId,
    this.avatarUrl,
    required this.status,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSender,
    this.takeoverUntil,
    this.requestKeyword,
    this.unreadAdminCount = 0,
    this.tier,
  });

  final int readingId;
  final String billNumber;
  final String customerName;
  final String platform; // 'line' | 'facebook'
  final String? platformUserId;
  final String? avatarUrl;
  final ConversationStatus status;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSender; // 'customer' | 'bot' | 'admin'
  final DateTime? takeoverUntil;
  final String? requestKeyword;
  final int unreadAdminCount;
  final String? tier;

  factory FortuneConversation.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FortuneConversation(
      readingId: ((json['reading_id'] as num?) ?? 0).toInt(),
      billNumber: (json['bill_number'] as String?) ?? '',
      customerName: (user['name'] as String?) ?? '—',
      platform: (json['platform'] as String?) ?? 'line',
      platformUserId: json['platform_user_id'] as String?,
      avatarUrl: user['avatar_url'] as String?,
      status: ConversationStatusLabel.parse(
          (json['status'] as String?) ?? 'active_bot'),
      lastMessageAt:
          DateTime.tryParse((json['last_message_at'] as String?) ?? ''),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageSender: json['last_message_sender'] as String?,
      takeoverUntil:
          DateTime.tryParse((json['takeover_until'] as String?) ?? ''),
      requestKeyword: json['request_keyword'] as String?,
      unreadAdminCount: ((json['unread_admin_count'] as num?) ?? 0).toInt(),
      tier: json['tier'] as String?,
    );
  }

  /// Minutes remaining in takeover (null if not active)
  int? get takeoverMinutesLeft {
    if (takeoverUntil == null) return null;
    final diff = takeoverUntil!.difference(DateTime.now()).inSeconds;
    if (diff <= 0) return 0;
    return (diff / 60).ceil();
  }

  bool get needsAdmin =>
      status == ConversationStatus.customerRequestedAdmin ||
      status == ConversationStatus.takeoverExpiring;

  double get tierHue => switch (tier) {
        'celtic' => 320,
        'deep' => 270,
        'tarot_chat' => 200,
        _ => 220,
      };
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.readingId,
    required this.sender,
    required this.text,
    required this.at,
    this.adminName,
    this.imageUrls,
    this.isSystem = false,
    this.systemKind,
  });

  final int id;
  final int readingId;
  final String sender; // 'customer' | 'bot' | 'admin' | 'system'
  final String text;
  final DateTime at;
  final String? adminName;
  final List<String>? imageUrls;
  final bool isSystem;

  /// 'takeover_started' | 'takeover_ended' | 'takeover_extended' | 'keyword_match' | etc.
  final String? systemKind;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: ((json['id'] as num?) ?? 0).toInt(),
        readingId: ((json['reading_id'] as num?) ?? 0).toInt(),
        sender: (json['sender'] as String?) ?? 'bot',
        text: (json['text'] as String?) ?? '',
        at: DateTime.tryParse((json['at'] as String?) ?? '') ?? DateTime.now(),
        adminName: json['admin_name'] as String?,
        imageUrls: (json['image_urls'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        isSystem: (json['is_system'] as bool?) ?? false,
        systemKind: json['system_kind'] as String?,
      );

  bool get isCustomer => sender == 'customer';
  bool get isBot => sender == 'bot';
  bool get isAdmin => sender == 'admin';
}

class TakeoverStats {
  TakeoverStats({
    required this.customerRequests,
    required this.takeoverActive,
    required this.takeoverExpiring,
    required this.closedToday,
  });

  final int customerRequests;
  final int takeoverActive;
  final int takeoverExpiring;
  final int closedToday;

  factory TakeoverStats.fromJson(Map<String, dynamic> json) => TakeoverStats(
        customerRequests:
            ((json['customer_requests'] as num?) ?? 0).toInt(),
        takeoverActive: ((json['takeover_active'] as num?) ?? 0).toInt(),
        takeoverExpiring:
            ((json['takeover_expiring'] as num?) ?? 0).toInt(),
        closedToday: ((json['closed_today'] as num?) ?? 0).toInt(),
      );

  int get totalNeedsAdmin => customerRequests + takeoverExpiring;
}
