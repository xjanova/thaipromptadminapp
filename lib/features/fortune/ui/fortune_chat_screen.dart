import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../data/fortune_repository.dart';
import '../data/models/chat_models.dart';

/// Chat thread screen — bidirectional message thread with takeover controls
///
/// Per brain ([[Thaiprompt Fortune Bot - Admin Takeover & FB Handover Limitations]]
/// and [[2026-05-17 takeover-chart-fix]]):
/// - Admin sends with HUMAN_AGENT tag (7-day window vs FB 24hr default)
/// - Takeover state: takeover_until timestamp · /ai command resumes AI
/// - Auto-poll messages every 5s (real backend uses Pusher/websocket;
///   mock uses Timer for now)
class FortuneChatScreen extends ConsumerStatefulWidget {
  const FortuneChatScreen({super.key, required this.readingId});
  final int readingId;

  @override
  ConsumerState<FortuneChatScreen> createState() =>
      _FortuneChatScreenState();
}

class _FortuneChatScreenState extends ConsumerState<FortuneChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _refreshTimer;
  Timer? _tickTimer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Poll messages every 5s (mock — backend should use websocket)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(chatMessagesProvider(widget.readingId));
      ref.invalidate(fortuneConversationsProvider);
    });
    // Tick every 1s to update "X mins ago" + takeover countdown
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Auto-scroll to bottom after first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _refreshTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(fortuneRepositoryProvider)
          .sendChatMessage(widget.readingId, text);
      if (!mounted) return;
      _textCtrl.clear();
      ref.invalidate(chatMessagesProvider(widget.readingId));
      ref.invalidate(fortuneConversationsProvider);
      // give a beat for the new message to land then scroll
      await Future.delayed(const Duration(milliseconds: 380));
      _scrollToBottom();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startTakeover() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(fortuneRepositoryProvider)
          .startTakeover(widget.readingId, minutes: 60);
      ref.invalidate(chatMessagesProvider(widget.readingId));
      ref.invalidate(fortuneConversationsProvider);
      ref.invalidate(takeoverStatsProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('เริ่ม Takeover แล้ว · 60 นาที'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _extendTakeover() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(fortuneRepositoryProvider)
          .extendTakeover(widget.readingId, minutes: 30);
      ref.invalidate(chatMessagesProvider(widget.readingId));
      ref.invalidate(fortuneConversationsProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ต่อเวลา Takeover อีก 30 นาที'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _resumeAi() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title: const Text('คืนให้ AI?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'AI จะกลับมาตอบลูกค้าต่อ · เหมือนพิมพ์ /ai',
          style: TextStyle(color: Color(0xD9FFFFFF)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('คืนให้ AI')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(fortuneRepositoryProvider).resumeAi(widget.readingId);
      ref.invalidate(chatMessagesProvider(widget.readingId));
      ref.invalidate(fortuneConversationsProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('คืน control ให้ AI แล้ว'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(fortuneConversationsProvider);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.readingId));
    final conversation = conversationsAsync.maybeWhen(
      data: (list) => list
          .where((c) => c.readingId == widget.readingId)
          .cast<FortuneConversation?>()
          .firstWhere((c) => true, orElse: () => null),
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0A1F),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.7),
                  radius: 1.3,
                  colors: [
                    Color(0xFF4C1D95),
                    Color(0xFF1E1B4B),
                    Color(0xFF0F0A1F)
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _appBar(conversation),
                if (conversation != null) _statusBanner(conversation),
                Expanded(
                  child: messagesAsync.when(
                    data: (msgs) {
                      if (msgs.isEmpty) {
                        return const Center(
                          child: Text(
                            'ยังไม่มีข้อความ',
                            style:
                                TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                          ),
                        );
                      }
                      return _MessageList(
                        controller: _scrollCtrl,
                        messages: msgs,
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        e is ApiException ? e.message : 'โหลดไม่สำเร็จ',
                        style: const TextStyle(color: Color(0xCCFFFFFF)),
                      ),
                    ),
                  ),
                ),
                _inputBar(conversation),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Top bar + status banner
  // ────────────────────────────────────────────────────────────

  Widget _appBar(FortuneConversation? c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 4),
          if (c != null)
            ClayBall(
              size: 38,
              hue: c.tierHue,
              saturation: 0.85,
              lightness: 0.6,
              child: Icon(
                c.platform == 'line'
                    ? Icons.chat_bubble_outline
                    : Icons.facebook,
                color: Colors.white,
                size: 14,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c?.customerName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (c != null)
                  Text(
                    '${c.billNumber} · ${c.platform.toUpperCase()}',
                    style: const TextStyle(
                        color: Color(0xCCFFFFFF), fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(FortuneConversation c) {
    final status = c.status;
    if (status == ConversationStatus.customerRequestedAdmin) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.3),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.priority_high,
                color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ลูกค้าขอคุยกับแอดมิน',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'เริ่ม takeover เพื่อตอบโดยตรง · บอทจะหยุดตอบ',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _startTakeover,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Takeover',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
            duration: const Duration(seconds: 2),
            color: Colors.white.withValues(alpha: 0.15),
          );
    }

    if (status == ConversationStatus.takeoverActive ||
        status == ConversationStatus.takeoverExpiring) {
      final isExpiring = status == ConversationStatus.takeoverExpiring;
      final minutesLeft = c.takeoverMinutesLeft ?? 0;
      final color = isExpiring ? AppColors.warning : AppColors.cyanStart;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.support_agent, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpiring
                        ? 'Takeover ใกล้หมด · ${minutesLeft}m'
                        : 'Takeover active · เหลือ ${minutesLeft}m',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'พิมพ์ในกล่องด้านล่าง → ส่งหาลูกค้าโดยตรง (HUMAN_AGENT tag)',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _extendTakeover,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text(
                '+30m',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: _resumeAi,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text(
                '/ai',
                style: TextStyle(
                  color: AppColors.purpleStart,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (status == ConversationStatus.activeBot) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.purpleStart.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.purpleStart.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.smart_toy_outlined,
                color: AppColors.purpleStart, size: 14),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Bot กำลังตอบ · เปิด Takeover เพื่อตอบเอง',
                style: TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 11,
                ),
              ),
            ),
            InkWell(
              onTap: _startTakeover,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.purpleStart.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Takeover',
                  style: TextStyle(
                    color: AppColors.purpleStart,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _inputBar(FortuneConversation? c) {
    final disabled = c == null || c.status == ConversationStatus.closed;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0F2E),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.attach_file,
                  color: Color(0x99FFFFFF), size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: TextField(
                  controller: _textCtrl,
                  enabled: !disabled && !_sending,
                  textInputAction: TextInputAction.newline,
                  maxLines: 4,
                  minLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: disabled
                        ? 'Conversation ปิดแล้ว'
                        : 'พิมพ์ข้อความถึงลูกค้า...',
                    hintStyle: const TextStyle(
                        color: Color(0x99FFFFFF), fontSize: 13),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: disabled ||
                      _sending ||
                      _textCtrl.text.trim().isEmpty
                  ? null
                  : _send,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: disabled ||
                          _sending ||
                          _textCtrl.text.trim().isEmpty
                      ? null
                      : const LinearGradient(
                          colors: [
                            AppColors.purpleStart,
                            AppColors.pinkStart
                          ],
                        ),
                  color: disabled ||
                          _sending ||
                          _textCtrl.text.trim().isEmpty
                      ? Colors.white.withValues(alpha: 0.08)
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow:
                      !disabled && !_sending && _textCtrl.text.trim().isNotEmpty
                          ? [
                              BoxShadow(
                                color: AppColors.pinkStart
                                    .withValues(alpha: 0.5),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: disabled ||
                                _textCtrl.text.trim().isEmpty
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.white,
                        size: 18,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Message list
// ────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({required this.controller, required this.messages});
  final ScrollController controller;
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm');
    // Group with date separators when day changes
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final m = messages[i];
        final prev = i > 0 ? messages[i - 1] : null;
        final showDateSep = prev == null ||
            !_sameDay(prev.at, m.at) ||
            m.at.difference(prev.at).inMinutes > 30;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDateSep) _dateSeparator(m.at),
            _bubble(m, time),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dateSeparator(DateTime at) {
    final today = DateTime.now();
    final label = _sameDay(at, today)
        ? 'วันนี้ ${DateFormat('HH:mm').format(at)}'
        : DateFormat('d MMM · HH:mm').format(at);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
              child: Container(
                  height: 1, color: Colors.white.withValues(alpha: 0.08))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10),
            ),
          ),
          Expanded(
              child: Container(
                  height: 1, color: Colors.white.withValues(alpha: 0.08))),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m, DateFormat timeFmt) {
    if (m.isSystem || m.sender == 'system') {
      // System notice — centered pill
      Color color;
      IconData icon;
      switch (m.systemKind) {
        case 'takeover_started':
          color = AppColors.cyanStart;
          icon = Icons.support_agent;
          break;
        case 'takeover_ended':
          color = AppColors.purpleStart;
          icon = Icons.smart_toy;
          break;
        case 'closed':
          color = AppColors.success;
          icon = Icons.check_circle_outline;
          break;
        default:
          color = const Color(0xFF94A3B8);
          icon = Icons.info_outline;
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 12),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (m.isCustomer) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(right: 60),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeFmt.format(m.at),
                      style: const TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (m.isBot) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(left: 60),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.purpleStart.withValues(alpha: 0.7),
                      AppColors.purpleEnd.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy,
                                  color: Colors.white, size: 9),
                              SizedBox(width: 3),
                              Text(
                                'BOT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      m.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeFmt.format(m.at),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Admin
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(left: 60),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.cyanStart, AppColors.cyanEnd],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyanStart.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.support_agent,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              m.adminName ?? 'ADMIN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    m.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeFmt.format(m.at),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.done_all,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 11),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
