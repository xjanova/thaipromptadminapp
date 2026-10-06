import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/moderation_repository.dart';

enum _ModTab {
  suspects('ผู้ต้องสงสัย'),
  banned('ถูกแบน'),
  rules('กติกา');

  const _ModTab(this.label);
  final String label;
}

/// ช่วงย้อนหลังที่สแกนหาผู้ต้องสงสัย (backend รับ since_hours 1–720)
enum _Window {
  h24(24, '24 ชม.'),
  d3(72, '3 วัน'),
  d7(168, '7 วัน'),
  d30(720, '30 วัน');

  const _Window(this.hours, this.label);
  final int hours;
  final String label;
}

enum _PlatformFilter {
  all(null, 'ทุกช่องทาง'),
  facebook('facebook', 'Messenger'),
  line('line', 'LINE'),
  telegram('telegram', 'Telegram');

  const _PlatformFilter(this.key, this.label);
  final String? key;
  final String label;
}

/// ระยะเวลาแบน (ส่งเป็น minutes · null = ถาวร)
enum _BanDuration {
  d1(60 * 24, '1 วัน'),
  d3(60 * 24 * 3, '3 วัน'),
  d7(60 * 24 * 7, '7 วัน'),
  d30(60 * 24 * 30, '30 วัน'),
  forever(null, 'ถาวร');

  const _BanDuration(this.minutes, this.label);
  final int? minutes;
  final String label;
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// "เหลือ 3 วัน" / "เหลือ 5 ชม." / "เหลือ 12 นาที"
String _remaining(DateTime until) {
  final d = until.difference(DateTime.now());
  if (d.isNegative) return 'หมดเวลาแล้ว';
  if (d.inDays >= 1) return 'เหลือ ${d.inDays} วัน';
  if (d.inHours >= 1) return 'เหลือ ${d.inHours} ชม.';
  return 'เหลือ ${d.inMinutes < 1 ? 1 : d.inMinutes} นาที';
}

/// หน้า "ความปลอดภัย" — ผู้ต้องสงสัยจากบทสนทนาดูดวง · รายชื่อที่ถูกแบน · คำต้องสงสัย
class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  _ModTab _tab = _ModTab.suspects;
  _Window _window = _Window.h24;

  // ── ถูกแบน ──
  _PlatformFilter _platform = _PlatformFilter.all;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  int _bannedReload = 0;
  final Set<int> _unbanning = {};

  // ── ผู้ต้องสงสัย ──
  final Set<int> _resolving = {};
  final Set<String> _bannedNow = {}; // platform_user_id ที่แบนจากหน้านี้
  final Set<int> _bannedReadings =
      {}; // บิลที่กดแบนจากหน้านี้ (ลูกค้า LINE ไม่มี ID ในรายการ)

  // ── กติกา ──
  final _kwCtrl = TextEditingController();
  List<String>? _draft; // null = ยังไม่แก้
  List<String>? _savedExtra; // ผลบันทึกล่าสุด (ใช้จนกว่าจะรีเฟรช)
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _kwCtrl.dispose();
    super.dispose();
  }

  List<String>? get _serverExtra =>
      _savedExtra ?? ref.read(moderationRulesProvider).valueOrNull?.extra;

  bool get _dirty {
    final d = _draft;
    final s = _serverExtra;
    return d != null && s != null && !_sameList(d, s);
  }

  Future<void> _refresh() async {
    ref.invalidate(suspectsProvider(_window.hours));
    ref.invalidate(activeBansProvider);
    ref.invalidate(moderationRulesProvider);
    setState(() => _bannedReload++);
    try {
      await Future.wait([
        ref.read(suspectsProvider(_window.hours).future),
        ref.read(activeBansProvider.future),
        ref.read(moderationRulesProvider.future),
      ]);
    } catch (_) {
      // error แสดงผ่าน TpAsync อยู่แล้ว
    }
    if (!mounted) return;
    setState(() {
      _bannedNow.clear();
      _bannedReadings.clear();
      // ข้อมูลใหม่จากเซิร์ฟเวอร์มาแล้ว — เลิกใช้ผลบันทึกที่จำไว้ (ร่างที่ยังไม่บันทึกคงไว้)
      _savedExtra = null;
    });
  }

  Future<bool> _confirmDiscard() => tpConfirm(
        context,
        title: 'ทิ้งการแก้ไขกติกา?',
        message: 'คำที่เพิ่มหรือลบไว้ยังไม่ได้บันทึก ถ้าออกตอนนี้จะหายทั้งหมด',
        confirmLabel: 'ทิ้งการแก้ไข',
        cancelLabel: 'อยู่ต่อ',
        danger: true,
      );

  Future<void> _leave() async {
    if (_dirty) {
      final ok = await _confirmDiscard();
      if (!ok || !mounted) return;
      setState(() => _draft = null);
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final q = v.trim();
      if (q != _search) setState(() => _search = q);
    });
    setState(() {}); // ปุ่มล้างคำค้น
  }

  // ───────────── แบน / ปลดแบน ─────────────

  Future<void> _startBan(Suspect s) async {
    if (_resolving.contains(s.readingId)) return;
    setState(() => _resolving.add(s.readingId));
    BanTarget? target;
    Object? error;
    try {
      target = await ref
          .read(moderationRepositoryProvider)
          .resolveTarget(s.readingId);
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    setState(() => _resolving.remove(s.readingId));
    if (error != null) {
      tpToast(context, tpErrorText(error), kind: TpToastKind.error);
      return;
    }
    if (target == null) {
      tpToast(context, 'บิลนี้ไม่มีบัญชีแชทที่แบนได้ (อาจดูดวงผ่านเว็บ)',
          kind: TpToastKind.info);
      return;
    }
    final suggested = [
      if (s.keywords.isNotEmpty)
        'พบคำต้องสงสัย: ${s.keywords.take(5).join(', ')}',
      if (s.lowRating) 'ให้คะแนน ${s.rating ?? '-'} ดาว',
    ].join(' · ');
    final done = await tpShowSheet<bool>(
      context,
      initial: 0.88,
      builder: (ctx, scroll) => _BanSheet(
          target: target!, scroll: scroll, suggestedReason: suggested),
    );
    if (done == true && mounted) {
      setState(() {
        _bannedNow.add(target!.platformUserId);
        _bannedReadings.add(s.readingId);
        _bannedReload++;
      });
      ref.invalidate(activeBansProvider);
    }
  }

  Future<void> _unban(BanEntry b) async {
    if (_unbanning.contains(b.id)) return;
    final name = b.displayName ?? modShortId(b.platformUserId);
    final ok = await tpConfirm(
      context,
      title: 'ปลดแบน $name?',
      message:
          'ลูกค้าจะทักบอททาง ${modPlatformLabel(b.platform)} ได้ทันที และประวัติการแบนครั้งนี้จะถูกลบออกจากระบบ',
      confirmLabel: 'ปลดแบน',
    );
    if (!ok || !mounted) return;
    setState(() => _unbanning.add(b.id));
    try {
      final msg = await ref.read(moderationRepositoryProvider).unban(b.id);
      if (!mounted) return;
      tpToast(context, msg ?? 'ปลดแบนแล้ว', kind: TpToastKind.success);
      setState(() {
        _bannedNow.remove(b.platformUserId);
        _bannedReload++;
      });
      ref.invalidate(activeBansProvider);
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _unbanning.remove(b.id));
    }
  }

  // ───────────── กติกา ─────────────

  void _addKeyword(ModerationRules r) {
    final v = _kwCtrl.text.trim();
    if (v.isEmpty) return;
    if (v.length > 120) {
      tpToast(context, 'คำยาวเกิน 120 ตัวอักษร', kind: TpToastKind.error);
      return;
    }
    final current = _draft ?? _serverExtra ?? r.extra;
    final lower = v.toLowerCase();
    if (current.any((k) => k.toLowerCase() == lower) ||
        r.defaults.any((k) => k.toLowerCase() == lower)) {
      tpToast(context, 'มีคำ "$v" อยู่ในรายการแล้ว');
      return;
    }
    setState(() {
      _draft = [...current, v];
      _kwCtrl.clear();
    });
  }

  void _removeKeyword(ModerationRules r, String k) {
    final current = _draft ?? _serverExtra ?? r.extra;
    setState(() => _draft = current.where((e) => e != k).toList());
  }

  Future<void> _saveRules(ModerationRules r) async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final before = _serverExtra ?? r.extra;
    final removed = before.where((k) => !draft.contains(k)).toList();
    if (removed.isNotEmpty) {
      final ok = await tpConfirm(
        context,
        title: 'ลบคำ ${removed.length} คำ?',
        message:
            'คำที่จะลบ: ${removed.take(6).join(', ')}${removed.length > 6 ? ' …' : ''}\n'
            'ระบบจะไม่ใช้คำเหล่านี้หาผู้ต้องสงสัยอีก',
        confirmLabel: 'บันทึก',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      final (saved, msg) =
          await ref.read(moderationRepositoryProvider).saveRules(draft);
      if (!mounted) return;
      setState(() {
        _savedExtra = saved;
        _draft = null;
        _saving = false;
      });
      ref.invalidate(suspectsProvider);
      tpToast(context, msg ?? 'บันทึกคำต้องสงสัยแล้ว',
          kind: TpToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    }
  }

  // ───────────── หน้าจอ ─────────────

  @override
  Widget build(BuildContext context) {
    final suspects = ref.watch(suspectsProvider(_window.hours)).valueOrNull;
    final bans = ref.watch(activeBansProvider).valueOrNull;
    // ฟังกติกาไว้ตลอด (คำนวณ "มีการแก้ไขค้าง" ตอนกดย้อนกลับได้แม่น)
    ref.watch(moderationRulesProvider);
    final dirty = _dirty;

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: TpPage(
        title: 'ความปลอดภัย',
        subtitle: suspects == null && bans == null
            ? 'ผู้ต้องสงสัย · รายชื่อแบน · กติกา'
            : 'ผู้ต้องสงสัย ${TpFmt.count(suspects?.total ?? 0)} · ถูกแบนอยู่ ${TpFmt.count(bans?.total ?? 0)}',
        back: true,
        onBack: _leave,
        bottomSpace: 32,
        onRefresh: _refresh,
        headerBottom: TpChips<_ModTab>(
          onHeader: true,
          padding: EdgeInsets.zero,
          value: _tab,
          onChanged: (t) {
            FocusScope.of(context).unfocus();
            setState(() => _tab = t);
          },
          items: [
            TpChipItem(_ModTab.suspects, _ModTab.suspects.label,
                count: suspects?.total),
            TpChipItem(_ModTab.banned, _ModTab.banned.label,
                count: bans?.total),
            TpChipItem(_ModTab.rules, dirty ? 'กติกา •' : _ModTab.rules.label),
          ],
        ),
        slivers: switch (_tab) {
          _ModTab.suspects => _suspectSlivers(),
          _ModTab.banned => _bannedSlivers(),
          _ModTab.rules => _ruleSlivers(),
        },
      ),
    );
  }

  // ───────────── ผู้ต้องสงสัย ─────────────

  List<Widget> _suspectSlivers() {
    final p = context.tp;
    final res = ref.watch(suspectsProvider(_window.hours));
    final banIds =
        ref.watch(activeBansProvider).valueOrNull?.userIds ?? const <String>{};
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TpChips<_Window>(
            padding: EdgeInsets.zero,
            value: _window,
            onChanged: (w) => setState(() => _window = w),
            items: [for (final w in _Window.values) TpChipItem(w, w.label)],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'สแกนบทสนทนาดูดวง ${_window.label}ล่าสุด หาคำต้องสงสัย'
            '${res.valueOrNull == null ? '' : ' ${res.valueOrNull!.keywordCount} คำ'} + ลูกค้าที่ให้ ≤ 2 ดาว · ระบบไม่แบนเอง แอดมินเป็นคนตัดสิน',
            style: TpType.body(12.5, p.muted),
          ),
        ),
      ),
      _suspectList(res, banIds),
    ];
  }

  /// รายการผู้ต้องสงสัยแบบ lazy (สูงสุด 100 ใบ)
  Widget _suspectList(AsyncValue<SuspectsResult> res, Set<String> banIds) {
    final r = res.valueOrNull;
    if (r == null) {
      return SliverToBoxAdapter(
        child: TpAsync<SuspectsResult>(
          value: res,
          compactError: true,
          onRetry: () => ref.invalidate(suspectsProvider(_window.hours)),
          data: (_) => const SizedBox.shrink(),
        ),
      );
    }
    if (r.items.isEmpty) {
      return SliverToBoxAdapter(
        child: TpEmpty(
          art: TpArt.emptyDone,
          title: 'ไม่พบผู้ต้องสงสัย',
          message: 'ไม่มีบทสนทนาที่เข้าข่ายใน ${_window.label}ล่าสุด',
          compact: true,
        ),
      );
    }
    final more = r.total > r.items.length;
    return SliverList.builder(
      itemCount: r.items.length + (more ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= r.items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'แสดง ${TpFmt.count(r.items.length)} รายการที่คะแนนสูงสุด จากทั้งหมด ${TpFmt.count(r.total)}',
              textAlign: TextAlign.center,
              style: TpType.body(12, context.tp.faint),
            ),
          );
        }
        final s = r.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SuspectCard(
            s: s,
            banned: _bannedReadings.contains(s.readingId) ||
                (s.platformUserId != null &&
                    (banIds.contains(s.platformUserId) ||
                        _bannedNow.contains(s.platformUserId))),
            resolving: _resolving.contains(s.readingId),
            onBan: () => _startBan(s),
            onChat: () => context.push('/chat/${s.readingId}'),
          ),
        );
      },
    );
  }

  // ───────────── ถูกแบน ─────────────

  List<Widget> _bannedSlivers() {
    final p = context.tp;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            style: TpType.body(14.5, p.text),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'ค้นหาชื่อหรือ ID ลูกค้า',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass,
                  size: 19, color: p.muted),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'ล้างคำค้น',
                      icon: Icon(PhosphorIconsRegular.xCircle,
                          size: 19, color: p.muted),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TpChips<_PlatformFilter>(
            padding: EdgeInsets.zero,
            value: _platform,
            onChanged: (f) => setState(() => _platform = f),
            items: [
              for (final f in _PlatformFilter.values) TpChipItem(f, f.label)
            ],
          ),
        ),
      ),
      TpPagedSliver<BanEntry>(
        reloadKey: '${_platform.name}|$_search|$_bannedReload',
        fetch: (page) => ref
            .read(moderationRepositoryProvider)
            .banned(page: page, platform: _platform.key, search: _search),
        empty: TpEmpty(
          art: TpArt.emptyDone,
          title: _search.isNotEmpty ? 'ไม่พบชื่อที่ค้นหา' : 'ไม่มีผู้ถูกแบน',
          message: _search.isNotEmpty
              ? 'ลองค้นด้วยชื่ออื่นหรือ ID บางส่วน'
              : (_platform == _PlatformFilter.all
                  ? 'ตอนนี้ไม่มีใครติดแบนอยู่'
                  : 'ไม่มีผู้ถูกแบนใน ${_platform.label}'),
          compact: true,
        ),
        itemBuilder: (context, b, _) => _BanCard(
          b: b,
          busy: _unbanning.contains(b.id),
          onUnban: () => _unban(b),
        ),
      ),
    ];
  }

  // ───────────── กติกา ─────────────

  List<Widget> _ruleSlivers() {
    final rules = ref.watch(moderationRulesProvider);
    return [
      SliverToBoxAdapter(
        child: TpAsync<ModerationRules>(
          value: rules,
          compactError: true,
          onRetry: () => ref.invalidate(moderationRulesProvider),
          loading: const Column(children: [
            TpSkeleton(height: 96, radius: 22),
            SizedBox(height: 22),
            TpSkeleton(height: 180, radius: 22),
          ]),
          data: (r) => _rulesBody(r),
        ),
      ),
    ];
  }

  Widget _rulesBody(ModerationRules r) {
    final p = context.tp;
    final server = _serverExtra ?? r.extra;
    final draft = _draft ?? server;
    final dirty = _draft != null && !_sameList(_draft!, server);
    final added = draft.where((k) => !server.contains(k)).length;
    final removed = server.where((k) => !draft.contains(k)).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TpCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Tp3D(TpArt.shield, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ระบบให้คะแนนอย่างไร', style: TpType.h(14.5, p.textStrong)),
              const SizedBox(height: 2),
              Text(
                'สแกนคำถามลูกค้าและคำตอบบอท เจอคำในรายการ +1 คะแนนต่อคำ · ลูกค้าให้ ≤ 2 ดาว +1 · '
                'คะแนนยิ่งสูงยิ่งน่าตรวจ — ระบบไม่แบนเอง',
                style: TpType.body(12.5, p.muted),
              ),
            ]),
          ),
        ]),
      ),
      TpSection('คำที่ตั้งเพิ่มเอง',
          trailing:
              TpPill('${draft.length} คำ', tone: TpTone.gold, dense: true)),
      TpCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _kwCtrl,
                enabled: !_saving,
                maxLength: 120,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addKeyword(r),
                style: TpType.body(14.5, p.text),
                decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: 'พิมพ์คำ เช่น "ขอเงินคืน"',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TpButton('เพิ่ม',
                icon: PhosphorIconsBold.plus,
                expand: false,
                height: 46,
                fontSize: 14,
                onPressed: _saving ? null : () => _addKeyword(r)),
          ]),
          const SizedBox(height: 12),
          if (draft.isEmpty)
            Text('ยังไม่มีคำเพิ่มเติม — ตอนนี้ใช้เฉพาะคำมาตรฐานของระบบด้านล่าง',
                style: TpType.body(12.5, p.muted))
          else
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in draft)
                _KeywordChip(
                    label: k,
                    isNew: !server.contains(k),
                    onRemove: _saving ? null : () => _removeKeyword(r, k)),
            ]),
        ]),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: !dirty
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TpCard(
                  goldBorder: true,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Icon(PhosphorIconsFill.pencilSimple,
                              size: 16, color: p.goldText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ยังไม่บันทึก · ${[
                                if (added > 0) 'เพิ่ม $added',
                                if (removed > 0) 'ลบ $removed'
                              ].join(' · ')}',
                              style: TpType.h(13.5, p.textStrong,
                                  w: FontWeight.w600),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TpButton.outline('ยกเลิก',
                                height: 44,
                                fontSize: 14,
                                onPressed: _saving
                                    ? null
                                    : () => setState(() => _draft = null)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TpButton('บันทึก',
                                icon: PhosphorIconsBold.floppyDisk,
                                height: 44,
                                fontSize: 14,
                                loading: _saving,
                                onPressed: () => _saveRules(r)),
                          ),
                        ]),
                      ]),
                ),
              ),
      ),
      TpSection('คำมาตรฐานของระบบ',
          trailing:
              const TpPill('แก้ไขไม่ได้', tone: TpTone.neutral, dense: true)),
      TpCard(
        padding: const EdgeInsets.all(14),
        child: r.defaults.isEmpty
            ? Text('ไม่มีคำมาตรฐาน', style: TpType.body(12.5, p.muted))
            : Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in r.defaults)
                  TpPill(k, tone: TpTone.neutral, dense: true),
              ]),
      ),
    ]);
  }
}

// ═════════════════════ การ์ดผู้ต้องสงสัย ═════════════════════

class _SuspectCard extends StatelessWidget {
  const _SuspectCard({
    required this.s,
    required this.banned,
    required this.resolving,
    required this.onBan,
    required this.onChat,
  });
  final Suspect s;
  final bool banned;
  final bool resolving;
  final VoidCallback onBan;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final tone = s.score >= 3
        ? TpTone.danger
        : (s.score == 2 ? TpTone.warning : TpTone.gold);
    final name = s.displayName ??
        (s.userId != null ? 'สมาชิก #${s.userId}' : 'ลูกค้าไม่ทราบชื่อ');
    final extra = s.keywords.length > 4 ? s.keywords.length - 4 : 0;
    return TpCard(
      accent: p.fg(tone),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          TpAvatar(name: name, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text('${TpFmt.ago(s.createdAt)} · บิล #${s.readingId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12, p.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('คะแนน', style: TpType.body(10.5, p.faint)),
            TpCount(s.score, tone: tone),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in s.keywords.take(4))
            TpPill(k, tone: TpTone.danger, dense: true),
          if (extra > 0) TpPill('+$extra คำ', tone: TpTone.danger, dense: true),
          if (s.lowRating)
            TpPill('ให้ ${s.rating ?? '-'} ดาว',
                tone: TpTone.warning,
                icon: PhosphorIconsFill.star,
                dense: true),
          TpPill(s.isPaid ? 'จ่ายแล้ว' : 'ยังไม่จ่าย',
              tone: s.isPaid ? TpTone.success : TpTone.neutral, dense: true),
          if (banned)
            const TpPill('แบนอยู่',
                tone: TpTone.danger,
                icon: PhosphorIconsBold.prohibit,
                dense: true),
        ]),
        if (s.preview != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: p.inset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.border),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(PhosphorIconsFill.quotes, size: 14, color: p.faint),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(s.preview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TpType.body(12.5, p.text)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TpButton.outline('เปิดแชท',
                icon: PhosphorIconsRegular.chatCircleText,
                height: 40,
                fontSize: 13.5,
                onPressed: onChat),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: banned
                ? TpButton.outline('แบนแล้ว',
                    icon: PhosphorIconsRegular.check,
                    height: 40,
                    fontSize: 13.5)
                : TpButton.danger('แบน',
                    icon: PhosphorIconsRegular.prohibit,
                    height: 40,
                    fontSize: 13.5,
                    loading: resolving,
                    onPressed: onBan),
          ),
        ]),
      ]),
    );
  }
}

// ═════════════════════ แผ่นแบน ═════════════════════

class _BanSheet extends ConsumerStatefulWidget {
  const _BanSheet(
      {required this.target,
      required this.scroll,
      required this.suggestedReason});
  final BanTarget target;
  final ScrollController scroll;
  final String suggestedReason;

  @override
  ConsumerState<_BanSheet> createState() => _BanSheetState();
}

class _BanSheetState extends ConsumerState<_BanSheet> {
  late final TextEditingController _reason =
      TextEditingController(text: widget.suggestedReason);
  _BanDuration _duration = _BanDuration.d7;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final reason = _reason.text.trim();
    if (reason.isEmpty) return;
    final t = widget.target;
    final name = t.displayName ?? 'ลูกค้ารายนี้';
    final permanent = _duration.minutes == null;
    final ok = await tpConfirm(
      context,
      title: permanent ? 'แบน $name ถาวร?' : 'แบน $name ${_duration.label}?',
      message: permanent
          ? 'ลูกค้าจะคุยกับบอททาง ${modPlatformLabel(t.platform)} ไม่ได้อีกเลย จนกว่าแอดมินจะปลดแบน'
          : 'ลูกค้าจะคุยกับบอททาง ${modPlatformLabel(t.platform)} ไม่ได้ ${_duration.label} แล้วปลดอัตโนมัติ',
      confirmLabel: 'แบน',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final msg = await ref
          .read(moderationRepositoryProvider)
          .ban(t, minutes: _duration.minutes, reason: reason);
      if (!mounted) return;
      tpToast(context, msg ?? 'แบนแล้ว', kind: TpToastKind.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final t = widget.target;
    final until = _duration.minutes == null
        ? null
        : DateTime.now().add(Duration(minutes: _duration.minutes!));
    final canSubmit = _reason.text.trim().isNotEmpty;
    // ระหว่างยิงคำสั่งแบน ห้ามปิดแผ่น (กดย้อนกลับ/แตะพื้นหลัง) — กันผลหายกลางทาง
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(children: [
          Expanded(
            child: ListView(
                controller: widget.scroll,
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                children: [
                  Text('แบนลูกค้า', style: TpType.title(20, p.textStrong)),
                  const SizedBox(height: 12),
                  TpCard(
                    child: Row(children: [
                      TpAvatar(
                          name: t.displayName, platform: t.platform, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.displayName ?? 'ลูกค้าไม่ทราบชื่อ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TpType.h(15.5, p.textStrong)),
                              Text(
                                  '${modPlatformLabel(t.platform)} · ID ${modShortId(t.platformUserId)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TpType.body(12.5, p.muted)),
                              Text('จากบิล #${t.readingId}',
                                  style: TpType.body(12, p.faint)),
                            ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Text('ระยะเวลา', style: TpType.h(14, p.textStrong)),
                  const SizedBox(height: 8),
                  TpChips<_BanDuration>(
                    padding: EdgeInsets.zero,
                    value: _duration,
                    onChanged:
                        _busy ? (_) {} : (d) => setState(() => _duration = d),
                    items: [
                      for (final d in _BanDuration.values)
                        TpChipItem(d, d.label)
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: until == null ? p.dangerSoft : p.inset,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                              until == null
                                  ? PhosphorIconsFill.warning
                                  : PhosphorIconsRegular.clockCountdown,
                              size: 16,
                              color: until == null ? p.danger : p.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              until == null
                                  ? 'แบนถาวร — ไม่ปลดเอง ต้องให้แอดมินปลดแบนจากแท็บ "ถูกแบน"'
                                  : 'ปลดแบนอัตโนมัติ ${TpFmt.shortDate(until)} ${TpFmt.time(until)}',
                              style: TpType.body(
                                  12.5, until == null ? p.danger : p.text,
                                  w: FontWeight.w500),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(height: 18),
                  Text('เหตุผล (บันทึกไว้ตรวจสอบภายหลัง)',
                      style: TpType.h(14, p.textStrong)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reason,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: (_) => setState(() {}),
                    style: TpType.body(14.5, p.text),
                    decoration: const InputDecoration(
                        hintText: 'เช่น ขู่ทวงเงินคืนซ้ำหลายครั้ง'),
                  ),
                ]),
          ),
          TpBottomBar(
            child: TpButton.danger(
              _duration.minutes == null ? 'แบนถาวร' : 'แบน ${_duration.label}',
              icon: PhosphorIconsBold.prohibit,
              loading: _busy,
              onPressed: canSubmit ? _submit : null,
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════ การ์ดผู้ถูกแบน ═════════════════════

class _BanCard extends StatelessWidget {
  const _BanCard({required this.b, required this.busy, required this.onUnban});
  final BanEntry b;
  final bool busy;
  final VoidCallback onUnban;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final (category, detail) = b.reasonParts;
    final name = b.displayName ?? 'ลูกค้าไม่ทราบชื่อ';
    final until = b.bannedUntil;
    return TpCard(
      accent: b.isPermanent ? p.danger : p.warning,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          TpAvatar(name: name, platform: b.platform, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(
                  '${modPlatformLabel(b.platform)} · ID ${modShortId(b.platformUserId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12, p.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TpPill(
              b.isPermanent || until == null ? 'ถาวร' : _remaining(until),
              tone: b.isPermanent ? TpTone.danger : TpTone.warning,
              dense: true,
            ),
            const SizedBox(height: 3),
            Text(TpFmt.ago(b.createdAt), style: TpType.body(11, p.faint)),
          ]),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
          decoration: BoxDecoration(
              color: p.inset, borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category,
                style: TpType.h(13, p.textStrong, w: FontWeight.w600)),
            if (detail != null)
              Text(detail,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12.5, p.muted)),
          ]),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _Meta(
            icon: b.bannedByName != null
                ? PhosphorIconsRegular.userCircle
                : PhosphorIconsRegular.robot,
            text: b.bannedByName != null
                ? 'โดย ${b.bannedByName}'
                : 'โดยระบบอัตโนมัติ',
          ),
          if (until != null && !b.isPermanent)
            _Meta(
                icon: PhosphorIconsRegular.calendarCheck,
                text: 'ถึง ${TpFmt.shortDate(until)} ${TpFmt.time(until)}'),
          if (b.attemptCount > 0)
            _Meta(
              icon: PhosphorIconsRegular.chatDots,
              text: 'ทักมาระหว่างแบน ${TpFmt.count(b.attemptCount)} ครั้ง',
              color: b.attemptCount >= 10 ? p.warning : null,
            ),
        ]),
        const SizedBox(height: 10),
        TpButton.outline('ปลดแบน',
            icon: PhosphorIconsRegular.lockOpen,
            height: 40,
            fontSize: 13.5,
            loading: busy,
            onPressed: onUnban),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tp.muted;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 4),
      Flexible(
          child: Text(text, style: TpType.body(11.5, c, w: FontWeight.w500))),
    ]);
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.label, required this.isNew, this.onRemove});
  final String label;
  final bool isNew;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 11, right: 4),
      decoration: BoxDecoration(
        color: isNew ? p.goldSoft : p.inset,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: isNew ? p.borderGold : p.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isNew) ...[
          Icon(PhosphorIconsBold.plus, size: 11, color: p.goldText),
          const SizedBox(width: 3)
        ],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TpType.body(12.5, isNew ? p.goldText : p.text,
                  w: FontWeight.w600, height: 1.1)),
        ),
        const SizedBox(width: 2),
        InkResponse(
          onTap: onRemove,
          radius: 16,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(PhosphorIconsBold.x,
                size: 12, color: onRemove == null ? p.faint : p.muted),
          ),
        ),
      ]),
    );
  }
}
