import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/approvals_repository.dart';
import 'approval_widgets.dart';

/// หน้า "ตั๋วซัพพอร์ต" (`/approvals/tickets`) — ด่วนก่อน แล้วรอนานสุดก่อน · แตะ → ห้องตั๋ว
class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  TicketFilter _filter = TicketFilter.open;
  TicketPriority _priority = TicketPriority.any;
  String _query = '';
  int _reload = 0;
  int? _found;

  Future<void> _refresh() async {
    setState(() => _reload++);
    try {
      ref.invalidate(approvalsSummaryProvider);
      await ref.read(approvalsSummaryProvider.future);
    } catch (_) {}
  }

  Future<void> _open(TicketItem t) async {
    await context.push('/approvals/tickets/${t.id}');
    // กลับมาจากห้องตั๋ว → สถานะ/จำนวนตอบอาจเปลี่ยน
    if (!mounted) return;
    setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(approvalsSummaryProvider).valueOrNull;
    return TpPage(
      title: 'ตั๋วซัพพอร์ต',
      subtitle: _found == null
          ? 'เรื่องที่ลูกค้าแจ้งเข้ามา'
          : 'พบ ${TpFmt.count(_found)} ใบ',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ApprovalSearchBar(
          hint: 'หัวข้อ เลขตั๋ว หรือชื่อลูกค้า',
          onQuery: (q) => setState(() {
            _query = q;
            _found = null;
          }),
        ),
        const SizedBox(height: 10),
        TpChips<TicketFilter>(
          onHeader: true,
          padding: EdgeInsets.zero,
          value: _filter,
          onChanged: (f) => setState(() {
            _filter = f;
            _found = null;
          }),
          items: [
            for (final f in TicketFilter.values)
              TpChipItem(f, f.label,
                  count: f == TicketFilter.open
                      ? s?.box(ApprovalQueue.tickets)?.count
                      : null),
          ],
        ),
      ]),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TpChips<TicketPriority>(
              padding: EdgeInsets.zero,
              value: _priority,
              onChanged: (v) => setState(() {
                _priority = v;
                _found = null;
              }),
              items: [
                for (final v in TicketPriority.values) TpChipItem(v, v.label)
              ],
            ),
          ),
        ),
        TpPagedSliver<TicketItem>(
          reloadKey: '${_filter.key}|${_priority.key}|$_query|$_reload',
          fetch: (page) => ref.read(approvalsRepositoryProvider).tickets(
              filter: _filter, priority: _priority, search: _query, page: page),
          onLoaded: (pg) {
            if (mounted) setState(() => _found = pg.total);
          },
          empty: TpEmpty(
            art: _filter == TicketFilter.open
                ? TpArt.emptyDone
                : TpArt.emptyInbox,
            title: _query.isNotEmpty
                ? 'ไม่พบตั๋วที่ค้นหา'
                : (_filter == TicketFilter.open
                    ? 'ไม่มีตั๋วรอทีมงาน'
                    : 'ไม่มีตั๋วในกลุ่มนี้'),
            compact: true,
          ),
          itemBuilder: (context, t, _) =>
              _TicketCard(t: t, onTap: () => _open(t)),
        ),
      ],
    );
  }
}

TpTone _priorityTone(String? p) => switch (p) {
      'critical' => TpTone.danger,
      'high' => TpTone.warning,
      'medium' => TpTone.info,
      _ => TpTone.neutral,
    };

String _priorityLabel(TicketItem t) {
  if (t.priorityLabel != null) return t.priorityLabel!;
  for (final v in TicketPriority.values) {
    if (v.key != null && v.key == t.priority) return v.label;
  }
  return 'ไม่ระบุระดับ';
}

(String, TpTone) _statusOf(TicketItem t) {
  final tone = switch (t.status) {
    'open' => TpTone.info,
    'in_progress' => TpTone.gold,
    'waiting_customer' => TpTone.navy,
    'resolved' => TpTone.success,
    'closed' => TpTone.neutral,
    _ => TpTone.neutral,
  };
  final label = t.statusLabel ??
      TicketDetail.fallbackStatuses
          .firstWhere((s) => s.$1 == t.status,
              orElse: () => (t.status, t.status))
          .$2;
  return (label, tone);
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.t, required this.onTap});
  final TicketItem t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final (status, statusTone) = _statusOf(t);
    final pTone = _priorityTone(t.priority);
    return TpCard(
      accent: t.isClosed
          ? p.faint
          : p.fg(pTone == TpTone.neutral ? TpTone.info : pTone),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TpAvatar(name: t.user?.display),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(
                [t.user?.display, t.ticketNumber]
                    .whereType<String>()
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(12.5, p.muted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (t.repliesCount > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(PhosphorIconsRegular.chatCircleText,
                    size: 14, color: p.faint),
                const SizedBox(width: 3),
                Text(TpFmt.count(t.repliesCount),
                    style: TpType.money(12.5, p.muted, w: FontWeight.w600)),
              ]),
            Text(TpFmt.ago(t.lastReplyAt ?? t.createdAt),
                style: TpType.body(11.5, p.faint)),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TpPill(pillText(_priorityLabel(t)),
              tone: pTone, icon: PhosphorIconsBold.flag, dense: true),
          TpPill(pillText(status), tone: statusTone, dense: true),
          if (t.isOverdue)
            const TpPill('เลยกำหนด',
                tone: TpTone.danger,
                icon: PhosphorIconsBold.clockCountdown,
                dense: true),
          if (!t.isClosed) WaitPill(t.waitingMinutes),
          if (t.category != null) TpPill(pillText(t.category!), dense: true),
        ]),
      ]),
    );
  }
}

// ═════════════════════ ห้องตั๋ว ═════════════════════

/// ห้องตั๋ว (`/approvals/tickets/:id`) — ข้อความทั้งหมด + ช่องตอบลูกค้า + เปลี่ยนสถานะ
class TicketThreadScreen extends ConsumerStatefulWidget {
  const TicketThreadScreen({super.key, required this.ticketId});
  final int ticketId;

  @override
  ConsumerState<TicketThreadScreen> createState() => _TicketThreadScreenState();
}

class _TicketThreadScreenState extends ConsumerState<TicketThreadScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _statusBusy = false;

  int get _id => widget.ticketId;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      ref.invalidate(ticketDetailProvider(_id));
      await ref.read(ticketDetailProvider(_id).future);
    } catch (_) {
      // error แสดงผ่าน TpAsync อยู่แล้ว
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.runes.length > 10000) {
      tpToast(context, 'ข้อความยาวเกิน 10,000 ตัวอักษร',
          kind: TpToastKind.error);
      return;
    }
    setState(() => _sending = true);
    try {
      final r =
          await ref.read(approvalsRepositoryProvider).replyTicket(_id, text);
      if (!mounted) return;
      _input.clear();
      ref.invalidate(approvalsSummaryProvider);
      tpToast(context, r.message,
          kind: r.already ? TpToastKind.info : TpToastKind.success);
      await _reload();
      _scrollToEnd();
    } catch (e) {
      // คงข้อความที่พิมพ์ไว้ให้ส่งใหม่ได้
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeStatus(TicketDetail d) async {
    if (_statusBusy) return;
    final picked = await tpShowSheet<String>(
      context,
      initial: 0.55,
      min: 0.3,
      max: 0.8,
      builder: (ctx, scroll) => _StatusPicker(
          scroll: scroll, current: d.ticket.status, statuses: d.statuses),
    );
    if (picked == null || picked == d.ticket.status || !mounted) return;
    String? notes;
    if (picked == 'resolved' || picked == 'closed') {
      notes = await tpPrompt(
        context,
        title: picked == 'resolved' ? 'บันทึกการแก้ไข' : 'ปิดตั๋ว',
        message: 'สรุปสิ่งที่ทำให้ลูกค้า (ไม่บังคับ) — ลูกค้าจะได้รับแจ้งผล',
        hint: 'เช่น ตรวจสอบแล้ว เงินเข้ากระเป๋าเรียบร้อย',
        confirmLabel: 'บันทึก',
        required: false,
      );
      if (notes == null || !mounted) return;
    }
    setState(() => _statusBusy = true);
    final ok = await runApprovalAction(
      context,
      () => ref
          .read(approvalsRepositoryProvider)
          .setTicketStatus(_id, picked, resolutionNotes: notes),
      closeSheet: false,
    );
    if (!mounted) return;
    setState(() => _statusBusy = false);
    if (ok) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    if (_id <= 0) {
      return const TpPage(
        title: 'ตั๋วซัพพอร์ต',
        back: true,
        bottomSpace: 32,
        slivers: [
          SliverToBoxAdapter(
            child: TpEmpty(
                art: TpArt.headset,
                title: 'ไม่พบตั๋วนี้',
                message: 'ลิงก์ไม่ถูกต้องหรือตั๋วถูกลบไปแล้ว'),
          ),
        ],
      );
    }
    final detail = ref.watch(ticketDetailProvider(_id));
    final d = detail.valueOrNull;
    final t = d?.ticket;
    final statusLabel = t == null ? null : _statusOf(t).$1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: p.bg,
        resizeToAvoidBottomInset: true,
        body: Column(children: [
          TpHeader(
            title: t?.subject ?? 'ตั๋วซัพพอร์ต',
            subtitle: t == null
                ? 'กำลังโหลด…'
                : [t.ticketNumber, statusLabel].whereType<String>().join(' · '),
            back: true,
            actions: [
              if (d != null)
                TpGlassButton(
                  icon: _statusBusy
                      ? PhosphorIconsRegular.hourglassMedium
                      : PhosphorIconsRegular.sliders,
                  tooltip: 'เปลี่ยนสถานะ',
                  onTap: _statusBusy ? null : () => _changeStatus(d),
                ),
            ],
          ),
          if (p.bodyOverlap > 0)
            ColoredBox(
              color: p.header.last,
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                    color: p.bg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22))),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              color: TpPalette.onGold,
              backgroundColor: p.gold,
              onRefresh: _reload,
              child: TpAsync<TicketDetail>(
                value: detail,
                onRetry: () => ref.invalidate(ticketDetailProvider(_id)),
                loading: const Padding(
                    padding: EdgeInsets.all(16),
                    child: TpSkeletonList(count: 4, itemHeight: 70)),
                data: (d) => ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  children: [
                    _TicketInfo(d: d),
                    const SizedBox(height: 12),
                    for (final m in d.messages) _MessageBubble(m: m),
                    if (d.messages.isEmpty)
                      const TpEmpty(
                          art: TpArt.emptyInbox,
                          title: 'ยังไม่มีข้อความ',
                          compact: true),
                  ],
                ),
              ),
            ),
          ),
          _Composer(
            controller: _input,
            focus: _focus,
            sending: _sending,
            enabled: d != null,
            onSend: _send,
          ),
        ]),
      ),
    );
  }
}

class _TicketInfo extends StatelessWidget {
  const _TicketInfo({required this.d});
  final TicketDetail d;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final t = d.ticket;
    final (status, statusTone) = _statusOf(t);
    return TpCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          TpAvatar(name: t.user?.display, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.user?.display ?? 'ลูกค้า',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              if (t.user?.memberNumber != null)
                Text(t.user!.memberNumber!,
                    style: TpType.money(12, p.muted, w: FontWeight.w500)),
            ]),
          ),
          if (t.user != null)
            TpButton.ghost('ดูสมาชิก',
                height: 32,
                fontSize: 13,
                onPressed: () => context.push('/users/${t.user!.id}')),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TpPill(pillText(_priorityLabel(t)),
              tone: _priorityTone(t.priority),
              icon: PhosphorIconsBold.flag,
              dense: true),
          TpPill(pillText(status), tone: statusTone, dense: true),
          if (t.isOverdue)
            const TpPill('เลยกำหนด', tone: TpTone.danger, dense: true),
          if (t.category != null) TpPill(pillText(t.category!), dense: true),
        ]),
        const SizedBox(height: 6),
        TpKv('เปิดเมื่อ', approvalWhen(t.createdAt)),
        if (d.dueAt != null)
          TpKv('กำหนดตอบ', approvalWhen(d.dueAt),
              valueColor: t.isOverdue ? p.danger : null),
        TpKv(
            'ตอบครั้งแรก',
            d.firstResponseAt == null
                ? 'ยังไม่ตอบ'
                : approvalWhen(d.firstResponseAt),
            valueColor: d.firstResponseAt == null ? p.warning : null),
        TpKv('ผู้รับผิดชอบ', t.assignedTo ?? 'ยังไม่มี'),
        if (d.resolutionNotes != null)
          TpKv('บันทึกการแก้ไข', d.resolutionNotes!),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.m});
  final TicketMessage m;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final staff = m.fromStaff;
    final internal = m.internal;
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(staff ? 18 : 6),
      bottomRight: Radius.circular(staff ? 6 : 18),
    );
    final fg = internal ? p.text : (staff ? p.onBubbleAdmin : p.text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment:
            staff ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  internal
                      ? PhosphorIconsFill.lockSimple
                      : (staff
                          ? PhosphorIconsFill.headset
                          : PhosphorIconsFill.userCircle),
                  size: 12,
                  color:
                      internal ? p.warning : (staff ? p.goldText : p.navyIcon)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  internal
                      ? 'บันทึกภายใน · ${m.author ?? 'ทีมงาน'} (ลูกค้าไม่เห็น)'
                      : (m.author ?? (staff ? 'ทีมงาน' : 'ลูกค้า')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(11,
                      internal ? p.warning : (staff ? p.goldText : p.navyIcon),
                      w: FontWeight.w600),
                ),
              ),
            ]),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
              decoration: BoxDecoration(
                color: internal ? p.warningSoft : (staff ? null : p.bubbleIn),
                gradient: (staff && !internal)
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: p.bubbleAdmin)
                    : null,
                borderRadius: radius,
                border: internal
                    ? Border.all(color: p.warning.withValues(alpha: 0.4))
                    : (!staff ? Border.all(color: p.border) : null),
              ),
              child: SelectableText(m.message,
                  style: TpType.body(14, fg,
                      w: staff && !internal ? FontWeight.w500 : FontWeight.w400,
                      height: 1.5)),
            ),
          ),
          if (m.at != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
              child: Text(TpFmt.dateTime(m.at!),
                  style: TpType.body(10.5, p.faint)),
            ),
        ],
      ),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker(
      {required this.scroll, required this.current, required this.statuses});
  final ScrollController scroll;
  final String current;
  final List<(String, String)> statuses;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text('เปลี่ยนสถานะตั๋ว', style: TpType.h(17, p.textStrong)),
        ),
        TpGroup(children: [
          for (final s in statuses)
            TpRow(
              icon: switch (s.$1) {
                'open' => PhosphorIconsRegular.envelopeSimpleOpen,
                'in_progress' => PhosphorIconsRegular.hourglassMedium,
                'waiting_customer' => PhosphorIconsRegular.userCircle,
                'resolved' => PhosphorIconsRegular.checkCircle,
                'closed' => PhosphorIconsRegular.lock,
                _ => PhosphorIconsRegular.circle,
              },
              iconTone: s.$1 == current ? TpTone.gold : TpTone.navy,
              title: s.$2,
              subtitle: switch (s.$1) {
                'waiting_customer' => 'ย้ายไปกอง "รอลูกค้า"',
                'resolved' => 'แจ้งลูกค้าว่าแก้ไขแล้ว',
                'closed' => 'ปิดเรื่อง',
                _ => null,
              },
              chevron: false,
              trailing: s.$1 == current
                  ? const TpPill('ตอนนี้', tone: TpTone.gold, dense: true)
                  : null,
              onTap: () => Navigator.of(context).pop(s.$1),
            ),
        ]),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c));
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
          color: p.sheet, border: Border(top: BorderSide(color: p.divider))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            enabled: enabled,
            minLines: 1,
            maxLines: 5,
            maxLength: 10000,
            textInputAction: TextInputAction.newline,
            style: TpType.body(14.5, p.text),
            decoration: InputDecoration(
              hintText: 'ตอบลูกค้า (ลูกค้าเห็นข้อความนี้)…',
              counterText: '',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: border(p.border),
              enabledBorder: border(p.border),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, v, _) {
            final can = enabled && v.text.trim().isNotEmpty && !sending;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: can || sending ? 1 : 0.45,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: TpPalette.goldButton),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: can
                        ? () {
                            HapticFeedback.lightImpact();
                            onSend();
                          }
                        : null,
                    child: Center(
                      child: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: TpPalette.onGold))
                          : const Icon(PhosphorIconsFill.paperPlaneTilt,
                              color: TpPalette.onGold, size: 20),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}
