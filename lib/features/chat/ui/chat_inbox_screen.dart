import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../home/data/ops_repository.dart';
import '../data/chat_repository.dart';

/// แท็บ "แชท" — ลูกค้าที่ขอคุยกับคน · ห้องที่แอดมินคุมอยู่ · บทสนทนาที่ยังไม่จบ
class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  ChatFilter _filter = ChatFilter.requested;
  int _reload = 0;
  Timer? _poll;
  bool _autoPicked = false;

  @override
  void initState() {
    super.initState();
    // รีเฟรชทุก 15 วินาที — ลูกค้าที่ขอคุยกับคนรอไม่ได้นาน
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      ref.invalidate(takeoverStatsProvider);
      setState(() => _reload++);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(takeoverStatsProvider).valueOrNull;
    // เปิดครั้งแรก: ถ้าไม่มีลูกค้าขอคุย ให้เริ่มที่ "แอดมินคุมอยู่" หรือ "ทั้งหมด"
    if (!_autoPicked && stats != null) {
      _autoPicked = true;
      if (stats.requested == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _filter =
                stats.takenOver > 0 ? ChatFilter.takenOver : ChatFilter.active);
          }
        });
      }
    }
    return TpPage(
      title: 'แชทลูกค้า',
      subtitle: stats == null
          ? 'บทสนทนาบอทดูดวงทุกช่องทาง'
          : 'คุมอยู่ ${stats.takenOver} · เทคโอเวอร์วันนี้ ${stats.today}',
      showMark: true,
      onRefresh: () async {
        ref.invalidate(takeoverStatsProvider);
        ref.invalidate(opsSummaryProvider);
        setState(() => _reload++);
      },
      headerBottom: TpChips<ChatFilter>(
        onHeader: true,
        padding: EdgeInsets.zero,
        value: _filter,
        onChanged: (f) => setState(() => _filter = f),
        items: [
          for (final f in ChatFilter.values)
            TpChipItem(f, f.label, count: stats?.count(f))
        ],
      ),
      slivers: [
        TpPagedSliver<Conversation>(
          reloadKey: '${_filter.key}-$_reload',
          gap: 10,
          fetch: (page) => ref
              .read(chatRepositoryProvider)
              .conversations(_filter, page: page),
          empty: TpEmpty(
            art: TpArt.emptyDone,
            title: switch (_filter) {
              ChatFilter.requested => 'ไม่มีลูกค้ารอคุยกับแอดมิน',
              ChatFilter.takenOver => 'บอทดูแลทุกห้องอยู่',
              ChatFilter.active => 'ยังไม่มีบทสนทนาที่เปิดอยู่',
            },
            message: _filter == ChatFilter.requested
                ? 'เมื่อลูกค้าพิมพ์ขอคุยกับคน จะเด้งขึ้นที่นี่ทันที'
                : null,
            compact: true,
          ),
          itemBuilder: (context, c, _) => _ConversationTile(
            c: c,
            onTap: () async {
              await context.push('/chat/${c.readingId}');
              if (mounted) setState(() => _reload++);
            },
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.c, required this.onTap});
  final Conversation c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final prefix = switch (c.lastSender) {
      'admin' => 'คุณ: ',
      'bot' => 'บอท: ',
      _ => '',
    };
    final preview = c.lastText == null
        ? (c.requestKeyword ?? c.stageLabel ?? '')
        : '$prefix${c.lastText}';
    return TpCard(
      onTap: onTap,
      accent: c.requestedByCustomer && c.isTakenOver
          ? p.danger
          : (c.isTakenOver ? p.gold : null),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TpAvatar(name: c.customerName, platform: c.platform, size: 46),
        const SizedBox(width: 11),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(c.customerName ?? 'ลูกค้า',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TpType.h(15, p.textStrong, w: FontWeight.w600)),
              ),
              Text(TpFmt.ago(c.lastAt ?? c.updatedAt),
                  style: TpType.body(11.5, c.unread ? p.goldText : p.faint)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: Text(preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TpType.body(13, c.unread ? p.text : p.muted,
                        w: c.unread ? FontWeight.w600 : FontWeight.w400)),
              ),
              if (c.unread)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: p.gold,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: p.gold, blurRadius: 8)]),
                ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (c.packageLabel != null)
                TpPill(c.packageLabel!, tone: TpTone.gold, dense: true),
              if (c.requestedByCustomer)
                const TpPill('ขอคุยกับคน',
                    tone: TpTone.danger,
                    icon: PhosphorIconsFill.handWaving,
                    dense: true),
              if (c.isTakenOver)
                TpPill('คุมอยู่ · เหลือ ${TpFmt.duration(c.remainingMinutes)}',
                    tone:
                        c.remainingMinutes <= 5 ? TpTone.warning : TpTone.navy,
                    icon: PhosphorIconsFill.headset,
                    dense: true)
              else if (c.stageLabel != null)
                TpPill(c.stageLabel!, tone: TpTone.neutral, dense: true),
              if (c.deferred.isNotEmpty)
                TpPill('พักไว้ ${c.deferred.length}',
                    tone: TpTone.gold,
                    icon: PhosphorIconsFill.package,
                    dense: true),
            ]),
          ]),
        ),
      ]),
    );
  }
}
