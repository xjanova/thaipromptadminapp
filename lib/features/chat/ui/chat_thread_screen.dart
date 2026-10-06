import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../home/data/ops_repository.dart';
import '../../work/data/work_repository.dart';
import '../../work/ui/bill_widgets.dart';
import '../data/chat_repository.dart';

/// ห้องแชทกับลูกค้า 1 คน (ผูกกับบิลดูดวง) — รับช่วงจากบอท / คืนให้บอท / ส่งข้อความ / ให้ AI ช่วยร่าง
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.readingId});
  final int readingId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  FortuneBill? _bill;
  TakeoverState? _takeover;
  List<ChatMsg> _messages = const [];
  bool _loaded = false;
  Object? _error;
  bool _sending = false;
  bool _actionBusy = false;
  bool _drafting = false;
  String? _draft;
  Timer? _poll;
  Timer? _tick;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load(first: true);
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _load());
    // นับถอยหลังเวลาเทคโอเวอร์ทุก 15 วินาที (ไม่ต้องยิงเซิร์ฟเวอร์)
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    try {
      final results = await Future.wait([
        _repo.messages(widget.readingId),
        _repo.takeoverStatus(widget.readingId),
        if (first || _bill == null) _repo.header(widget.readingId),
      ]);
      if (!mounted) return;
      final msgs = results[0] as List<ChatMsg>;
      setState(() {
        final grew = msgs.length != _messages.length;
        _messages = msgs;
        _takeover = results[1] as TakeoverState;
        if (results.length > 2) _bill = results[2] as FortuneBill?;
        _loaded = true;
        _error = null;
        if (grew) _scrollToEnd();
      });
    } catch (e) {
      if (!mounted) return;
      if (!_loaded) setState(() => _error = e);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _takeoverNow() async {
    setState(() => _actionBusy = true);
    try {
      final s = await _repo.takeover(widget.readingId, minutes: 30);
      if (!mounted) return;
      setState(() => _takeover = s);
      tpToast(context, 'รับช่วงแล้ว · บอทหยุดตอบ 30 นาที',
          kind: TpToastKind.success);
      ref.invalidate(opsSummaryProvider);
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _extend() async {
    setState(() => _actionBusy = true);
    try {
      final s = await _repo.extend(widget.readingId, 15);
      if (!mounted) return;
      setState(() => _takeover = s);
      tpToast(context, 'ต่อเวลาอีก 15 นาที', kind: TpToastKind.success);
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _resume() async {
    final yes = await tpConfirm(
      context,
      title: 'คืนห้องนี้ให้บอท?',
      message: 'บอทแม่หมอจะกลับมาตอบลูกค้าต่อทันที',
      confirmLabel: 'คืนให้บอท',
    );
    if (!yes || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      final s = await _repo.resume(widget.readingId);
      if (!mounted) return;
      setState(() => _takeover = s);
      tpToast(context, 'บอทกลับมาตอบแล้ว', kind: TpToastKind.success);
      ref.invalidate(opsSummaryProvider);
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    // กันบอทพูดแทรก: ถ้ายังไม่ได้รับช่วง ให้ถามก่อน
    if (_takeover?.active != true) {
      final yes = await tpConfirm(
        context,
        title: 'รับช่วงจากบอทก่อนส่ง?',
        message: 'ถ้าไม่หยุดบอท ลูกค้าอาจได้คำตอบจากบอทแทรกข้อความของคุณ',
        confirmLabel: 'รับช่วงและส่ง',
        cancelLabel: 'ยกเลิก',
      );
      if (!yes || !mounted) return;
      await _takeoverNow();
      if (_takeover?.active != true || !mounted) return;
    }
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      await _repo.send(widget.readingId, text);
      if (!mounted) return;
      _input.clear();
      setState(() {
        _draft = null;
        _messages = [
          ..._messages,
          ChatMsg(
              id: -DateTime.now().millisecondsSinceEpoch,
              sender: 'admin',
              text: text,
              at: DateTime.now())
        ];
      });
      _scrollToEnd();
      Future.delayed(const Duration(seconds: 2), _load);
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _aiDraft() async {
    setState(() => _drafting = true);
    try {
      final ctx = _messages
          .where((m) => m.sender != 'system' && m.text.trim().isNotEmpty)
          .toList()
          .reversed
          .take(12)
          .toList()
          .reversed
          .map((m) => '${switch (m.sender) {
                'customer' => 'ลูกค้า',
                'bot' => 'บอท',
                'admin' => 'แอดมิน',
                _ => m.sender
              }}: ${m.text}')
          .join('\n');
      final s = await _repo.suggest(
          widget.readingId, ctx.isEmpty ? 'ลูกค้าเพิ่งทักมา' : ctx,
          customerName: _bill?.customerName);
      if (!mounted) return;
      setState(() => _draft = s.isEmpty ? null : s);
      if (s.isEmpty) tpToast(context, 'AI ร่างไม่สำเร็จ ลองใหม่อีกครั้ง');
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final b = _bill;
    final platform = TpAvatar.platformStyle(b?.platform);
    final ops = ref.watch(opsSummaryProvider).valueOrNull;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: p.bg,
        resizeToAvoidBottomInset: true,
        body: Column(children: [
          TpHeader(
            title: b?.customerName ?? 'ลูกค้า',
            subtitle: [platform?.$3, b?.packageLabel, b?.billNumber]
                .whereType<String>()
                .join(' · '),
            back: true,
            leading: TpAvatar(
                name: b?.customerName, platform: b?.platform, size: 40),
            actions: [
              if (b != null)
                TpGlassButton(
                  icon: PhosphorIconsRegular.receipt,
                  tooltip: 'ดูบิล',
                  onTap: () => showBillSheet(context, b),
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
          _TakeoverBanner(
            state: _takeover,
            busy: _actionBusy,
            onTakeover: _takeoverNow,
            onExtend: _extend,
            onResume: _resume,
          ),
          if (b?.platform?.toLowerCase() == 'line')
            _Note(
              icon: PhosphorIconsRegular.warning,
              tone: (ops?.linePushExhausted ?? false)
                  ? TpTone.danger
                  : TpTone.warning,
              text: (ops?.linePushExhausted ?? false)
                  ? 'โควตา LINE push เดือนนี้หมดแล้ว — ส่งข้อความหาลูกค้า LINE ไม่ได้'
                  : 'ข้อความแอดมินบน LINE ใช้โควตา push${ops?.linePushUsed == null ? '' : ' (ใช้ไป ${ops!.linePushUsed}/${ops.linePushLimit})'} — พิมพ์ให้ครบในข้อความเดียว',
            )
          else if (b?.platform?.toLowerCase() == 'facebook')
            const _Note(
              icon: PhosphorIconsRegular.info,
              tone: TpTone.info,
              text: 'Messenger ส่งได้เฉพาะลูกค้าที่ทักมาภายใน 24 ชม.',
            ),
          Expanded(child: _body()),
          if (_draft != null || _drafting)
            _DraftCard(
                text: _draft,
                loading: _drafting,
                onUse: () {
                  _input.text = _draft ?? '';
                  _input.selection =
                      TextSelection.collapsed(offset: _input.text.length);
                  setState(() => _draft = null);
                  _focus.requestFocus();
                },
                onRetry: _aiDraft,
                onClose: () => setState(() => _draft = null)),
          _Composer(
            controller: _input,
            focus: _focus,
            sending: _sending,
            drafting: _drafting,
            onSend: _send,
            onDraft: _aiDraft,
          ),
        ]),
      ),
    );
  }

  Widget _body() {
    if (!_loaded) {
      if (_error != null) {
        return Center(
            child: TpErrorView(
                error: _error,
                onRetry: () => _load(first: true),
                compact: true));
      }
      return const Padding(
          padding: EdgeInsets.all(16),
          child: TpSkeletonList(count: 4, itemHeight: 64));
    }
    if (_messages.isEmpty) {
      return const Center(
          child: TpEmpty(
              art: TpArt.emptyInbox,
              title: 'ยังไม่มีข้อความวันนี้',
              compact: true));
    }
    final items = _messages.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        final older = i + 1 < items.length ? items[i + 1] : null;
        final showDay = m.at != null &&
            (older?.at == null ||
                older!.at!.day != m.at!.day ||
                older.at!.month != m.at!.month);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDay) _DayDivider(at: m.at!),
              _Bubble(m: m),
            ]);
      },
    );
  }
}

class _TakeoverBanner extends StatelessWidget {
  const _TakeoverBanner(
      {required this.state,
      required this.busy,
      required this.onTakeover,
      required this.onExtend,
      required this.onResume});
  final TakeoverState? state;
  final bool busy;
  final VoidCallback onTakeover;
  final VoidCallback onExtend;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final s = state;
    if (s == null) return const SizedBox(height: 4);
    final remaining = s.until == null
        ? s.remainingMinutes
        : s.until!.difference(DateTime.now()).inMinutes.clamp(0, 9999);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: s.active ? p.goldSoft : p.cardSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.active ? p.borderGold : p.border),
      ),
      child: Row(children: [
        Icon(s.active ? PhosphorIconsFill.headset : PhosphorIconsFill.robot,
            color: s.active ? p.goldText : p.navyIcon, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.active ? 'คุณกำลังคุยแทนบอท' : 'บอทแม่หมอกำลังตอบอยู่',
                style: TpType.h(13.5, s.active ? p.goldText : p.textStrong)),
            Text(
                s.active
                    ? 'เหลืออีก ${TpFmt.duration(remaining)} แล้วบอทจะกลับมาเอง'
                    : 'รับช่วงเพื่อหยุดบอทแล้วคุยเอง',
                style: TpType.body(12, p.muted)),
          ]),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (s.active) ...[
          _MiniBtn(label: '+15 นาที', onTap: onExtend),
          const SizedBox(width: 6),
          _MiniBtn(label: 'คืนให้บอท', onTap: onResume),
        ] else
          _MiniBtn(label: 'รับช่วงต่อ', gold: true, onTap: onTakeover),
      ]),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.label, required this.onTap, this.gold = false});
  final String label;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Material(
      color: gold ? null : p.cardSolid,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        decoration: gold
            ? BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: TpPalette.goldButton),
                borderRadius: BorderRadius.circular(10),
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(label,
                style: TpType.body(12.5, gold ? TpPalette.onGold : p.text,
                    w: FontWeight.w600, height: 1.1)),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(
      {required this.icon, required this.text, this.tone = TpTone.info});
  final IconData icon;
  final String text;
  final TpTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(children: [
        Icon(icon, size: 14, color: p.fg(tone)),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: TpType.body(11.5, p.fg(tone), w: FontWeight.w500))),
      ]),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.at});
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final now = DateTime.now();
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: p.inset, borderRadius: BorderRadius.circular(99)),
          child: Text(today ? 'วันนี้' : TpFmt.shortDate(at),
              style: TpType.body(11.5, p.muted, w: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});
  final ChatMsg m;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    if (m.sender == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Divider(color: p.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
                m.text
                    .replaceAll(
                        RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
                            unicode: true),
                        '')
                    .trim(),
                style: TpType.body(11.5, p.muted, w: FontWeight.w500)),
          ),
          Expanded(child: Divider(color: p.divider)),
        ]),
      );
    }
    final mine = m.sender == 'admin';
    final bot = m.sender == 'bot';
    final maxW = MediaQuery.sizeOf(context).width * 0.78;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 6),
      bottomRight: Radius.circular(mine ? 6 : 18),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (bot || (mine && m.adminName != null))
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      bot ? PhosphorIconsFill.robot : PhosphorIconsFill.headset,
                      size: 12,
                      color: bot ? p.navyIcon : p.goldText),
                  const SizedBox(width: 4),
                  Text(bot ? 'บอทแม่หมอ' : m.adminName!,
                      style: TpType.body(11, bot ? p.navyIcon : p.goldText,
                          w: FontWeight.w600)),
                ]),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Container(
                padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
                decoration: BoxDecoration(
                  color: mine ? null : (bot ? p.bubbleBot : p.bubbleIn),
                  gradient: mine
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: p.bubbleAdmin)
                      : null,
                  borderRadius: radius,
                  border: (!mine && !bot) ? Border.all(color: p.border) : null,
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(m.imageUrl!,
                                width: 200,
                                fit: BoxFit.cover,
                                cacheWidth: 600,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink()),
                          ),
                        ),
                      if (m.text.isNotEmpty)
                        SelectableText(m.text,
                            style: TpType.body(
                                14, mine ? p.onBubbleAdmin : p.text,
                                w: mine ? FontWeight.w500 : FontWeight.w400,
                                height: 1.5)),
                    ]),
              ),
            ),
            if (m.at != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
                child:
                    Text(TpFmt.time(m.at!), style: TpType.body(10.5, p.faint)),
              ),
          ]),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard(
      {required this.text,
      required this.loading,
      required this.onUse,
      required this.onRetry,
      required this.onClose});
  final String? text;
  final bool loading;
  final VoidCallback onUse;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: p.cardSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderGold),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(PhosphorIconsFill.sparkle, size: 15, color: p.goldText),
          const SizedBox(width: 5),
          Expanded(
              child:
                  Text('ร่างคำตอบด้วย AI', style: TpType.h(12.5, p.goldText))),
          InkWell(
              onTap: onClose,
              child: Icon(PhosphorIconsRegular.x, size: 16, color: p.faint)),
        ]),
        const SizedBox(height: 5),
        if (loading)
          const TpSkeleton(height: 34)
        else
          Text(text ?? '', style: TpType.body(13.5, p.text, height: 1.5)),
        if (!loading) ...[
          const SizedBox(height: 8),
          Row(children: [
            _MiniBtn(label: 'ใช้ข้อความนี้', gold: true, onTap: onUse),
            const SizedBox(width: 8),
            _MiniBtn(label: 'ร่างใหม่', onTap: onRetry),
          ]),
        ],
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.sending,
    required this.drafting,
    required this.onSend,
    required this.onDraft,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final bool sending;
  final bool drafting;
  final VoidCallback onSend;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
          color: p.sheet, border: Border(top: BorderSide(color: p.divider))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Tooltip(
          message: 'ให้ AI ช่วยร่าง',
          child: Material(
            color: p.goldSoft,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: drafting ? null : onDraft,
              child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(PhosphorIconsFill.sparkle,
                      color: p.goldText, size: 20)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            minLines: 1,
            maxLines: 5,
            maxLength: 2000,
            textInputAction: TextInputAction.newline,
            style: TpType.body(14.5, p.text),
            decoration: InputDecoration(
              hintText: 'พิมพ์ข้อความถึงลูกค้า…',
              counterText: '',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: p.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: p.border)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, v, _) {
            final enabled = v.text.trim().isNotEmpty && !sending;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: enabled || sending ? 1 : 0.45,
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
                    onTap: enabled ? onSend : null,
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
