import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/ai_repository.dart';

enum _AiTab {
  overview('ภาพรวม'),
  providers('ผู้ให้บริการ'),
  bots('บอท');

  const _AiTab(this.label);
  final String label;
}

enum _BotFilter {
  all('ทั้งหมด', null),
  on('เปิดอยู่', true),
  off('ปิดอยู่', false);

  const _BotFilter(this.label, this.active);
  final String label;
  final bool? active;
}

/// เวลาตอบแบบอ่านง่าย: 850 ms / 1.8 วิ
String _latency(int ms) {
  if (ms <= 0) return '-';
  if (ms < 1000) return '$ms ms';
  return '${(ms / 1000).toStringAsFixed(ms < 10000 ? 1 : 0)} วิ';
}

String _hourLabel(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:00';

/// อ่านสีจากเซิร์ฟเวอร์ ("#10b981" / "hsl(120, 70%, 55%)")
Color? _parseColor(String? s) {
  if (s == null) return null;
  final v = s.trim();
  if (v.startsWith('#')) {
    var hex = v.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
    if (hex.length == 6) hex = 'FF$hex';
    final n = int.tryParse(hex, radix: 16);
    return n == null ? null : Color(n);
  }
  final m = RegExp(r'hsl\(\s*([\d.]+)\s*,\s*([\d.]+)%\s*,\s*([\d.]+)%\s*\)').firstMatch(v);
  if (m == null) return null;
  final h = double.tryParse(m[1]!) ?? 0, sat = double.tryParse(m[2]!) ?? 0, l = double.tryParse(m[3]!) ?? 0;
  return HSLColor.fromAHSL(1, h % 360, (sat / 100).clamp(0, 1), (l / 100).clamp(0, 1)).toColor();
}

/// หน้า "AI และบอท" — การใช้งาน AI · ผู้ให้บริการ (ai_providers) · บอท AI (ai_bot_profiles)
class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  _AiTab _tab = _AiTab.overview;
  _BotFilter _botFilter = _BotFilter.all;
  int _botReload = 0;

  // สถานะเปิด/ปิดที่เซิร์ฟเวอร์ยืนยันแล้ว (ใช้ทับรายการเดิมจนกว่าจะโหลดใหม่)
  final Map<int, bool> _providerState = {};
  final Set<int> _providerBusy = {};
  final Map<int, AiConnectionTest> _tests = {};
  final Set<int> _testing = {};
  final Map<int, bool> _botState = {};
  final Set<int> _botBusy = {};

  Future<void> _refresh() async {
    ref.invalidate(aiOverviewProvider);
    ref.invalidate(aiUsageProvider);
    ref.invalidate(aiPerProviderUsageProvider);
    ref.invalidate(aiProvidersProvider);
    setState(() => _botReload++);
    try {
      await Future.wait([
        ref.read(aiOverviewProvider.future),
        ref.read(aiUsageProvider.future),
        ref.read(aiProvidersProvider.future),
      ]);
    } catch (_) {
      // error แสดงผ่าน TpAsync อยู่แล้ว
    }
    if (mounted) setState(_providerState.clear);
  }

  // ───────────── การกระทำ ─────────────

  Future<void> _toggleProvider(AiProviderItem p, bool want) async {
    if (_providerBusy.contains(p.id)) return;
    if (!want) {
      final ok = await tpConfirm(
        context,
        title: 'ปิด ${p.displayName}?',
        message:
            'บอท AI ที่ตั้งให้ใช้ผู้ให้บริการนี้จะเรียก AI ไม่ได้จนกว่าจะเปิดใหม่ (ไม่กระทบคีย์ AI Pool ของบอทดูดวง)',
        confirmLabel: 'ปิดใช้งาน',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _providerBusy.add(p.id));
    try {
      final r = await ref.read(aiRepositoryProvider).toggleProvider(p.id);
      if (!mounted) return;
      setState(() => _providerState[p.id] = r.item.isActive);
      if (r.item.isActive != want) {
        // backend "สลับ" ค่า — ถ้ามีคนเปลี่ยนจากที่อื่นก่อน ผลจะกลับทิศ ต้องบอกให้ชัด
        tpToast(context, 'สถานะถูกเปลี่ยนจากที่อื่นก่อนหน้า — ตอนนี้${r.item.isActive ? 'เปิด' : 'ปิด'}อยู่',
            kind: TpToastKind.info);
      } else {
        tpToast(context, r.message ?? (want ? 'เปิดใช้งานแล้ว' : 'ปิดใช้งานแล้ว'), kind: TpToastKind.success);
      }
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _providerBusy.remove(p.id));
    }
  }

  Future<void> _testProvider(AiProviderItem p) async {
    if (_testing.contains(p.id)) return;
    setState(() => _testing.add(p.id));
    try {
      final r = await ref.read(aiRepositoryProvider).testProvider(p.id);
      if (!mounted) return;
      setState(() => _tests[p.id] = r);
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _testing.remove(p.id));
    }
  }

  Future<void> _toggleBot(AiBotItem b, bool want) async {
    if (_botBusy.contains(b.id)) return;
    if (!want) {
      final ok = await tpConfirm(
        context,
        title: 'ปิดบอท ${b.displayName}?',
        message: b.lineConnected
            ? 'บอทจะหยุดตอบลูกค้าใน LINE OA ที่เชื่อมไว้ทันที จนกว่าจะเปิดใหม่'
            : 'บอทจะหยุดตอบทุกช่องทางจนกว่าจะเปิดใหม่',
        confirmLabel: 'ปิดบอท',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _botBusy.add(b.id));
    try {
      final r = await ref.read(aiRepositoryProvider).toggleBot(b.id);
      if (!mounted) return;
      setState(() => _botState[b.id] = r.item.isActive);
      ref.invalidate(aiOverviewProvider);
      if (r.item.isActive != want) {
        tpToast(context, 'สถานะถูกเปลี่ยนจากที่อื่นก่อนหน้า — ตอนนี้บอท${r.item.isActive ? 'เปิด' : 'ปิด'}อยู่',
            kind: TpToastKind.info);
      } else {
        tpToast(context, r.message ?? (want ? 'เปิดบอทแล้ว' : 'ปิดบอทแล้ว'), kind: TpToastKind.success);
      }
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _botBusy.remove(b.id));
    }
  }

  // ───────────── หน้าจอ ─────────────

  @override
  Widget build(BuildContext context) {
    final ov = ref.watch(aiOverviewProvider).valueOrNull;
    final providers = ref.watch(aiProvidersProvider).valueOrNull;

    return TpPage(
      title: 'AI และบอท',
      subtitle: ov == null
          ? 'การใช้งาน AI · ผู้ให้บริการ · บอท'
          : 'บอทเปิดอยู่ ${TpFmt.count(ov.botsActive)}/${TpFmt.count(ov.botsTotal)} · ${TpFmt.count(ov.requestsPerMin)} คำขอ/นาที',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom: TpChips<_AiTab>(
        onHeader: true,
        padding: EdgeInsets.zero,
        value: _tab,
        onChanged: (t) => setState(() => _tab = t),
        items: [
          const TpChipItem(_AiTab.overview, 'ภาพรวม'),
          TpChipItem(_AiTab.providers, _AiTab.providers.label, count: providers?.length),
          TpChipItem(_AiTab.bots, _AiTab.bots.label, count: ov?.botsTotal),
        ],
      ),
      slivers: switch (_tab) {
        _AiTab.overview => _overviewSlivers(),
        _AiTab.providers => _providerSlivers(),
        _AiTab.bots => _botSlivers(),
      },
    );
  }

  // ───────────── ภาพรวม ─────────────

  List<Widget> _overviewSlivers() {
    final usage = ref.watch(aiUsageProvider);
    final ov = ref.watch(aiOverviewProvider);
    final perProvider = ref.watch(aiPerProviderUsageProvider);
    final hero = SliverToBoxAdapter(
      child: TpAsync<AiUsageSeries>(
        value: usage,
        onRetry: () {
          ref.invalidate(aiUsageProvider);
          ref.invalidate(aiOverviewProvider);
          ref.invalidate(aiPerProviderUsageProvider);
        },
        loading: const _HeroSkeleton(),
        data: (u) => _UsageHero(u: u, ov: ov.valueOrNull),
      ),
    );
    // โหลดหัวไม่ได้ (มักเป็นออฟไลน์) — แสดงกล่อง error เดียว ไม่ซ้อนหลายกล่อง
    if (usage.hasError && !usage.hasValue) return [hero];
    return [
      hero,
      SliverToBoxAdapter(child: _kpiTiles(ov)),
      SliverToBoxAdapter(
        child: TpSection('แยกตามผู้ให้บริการ', trailing: const TpPill('24 ชม.', tone: TpTone.neutral, dense: true)),
      ),
      SliverToBoxAdapter(
        child: TpAsync<List<AiProviderUsage>>(
          value: perProvider,
          compactError: true,
          onRetry: () => ref.invalidate(aiPerProviderUsageProvider),
          loading: const TpSkeletonList(count: 3, itemHeight: 96),
          data: (list) {
            if (list.isEmpty) {
              return const TpCard(
                padding: EdgeInsets.zero,
                child: TpEmpty(
                  art: TpArt.ai,
                  title: 'ยังไม่มีคีย์ใน AI Pool',
                  message: 'เพิ่มคีย์ AI ของบอทดูดวงแล้วการใช้งานจะขึ้นที่นี่',
                  compact: true,
                ),
              );
            }
            final total = list.fold<int>(0, (a, b) => a + b.requests);
            return Column(children: [
              for (final u in list)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: _ProviderUsageCard(u: u, total: total)),
            ]);
          },
        ),
      ),
      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 4), child: _AiPoolLink())),
    ];
  }

  Widget _kpiTiles(AsyncValue<AiOverview> ov) {
    if (!ov.hasValue) {
      if (ov.hasError) {
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TpCard(
            padding: EdgeInsets.zero,
            child: TpErrorView(error: ov.error, compact: true, onRetry: () => ref.invalidate(aiOverviewProvider)),
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Row(children: [
          Expanded(child: TpSkeleton(height: 112, radius: 20)),
          SizedBox(width: 10),
          Expanded(child: TpSkeleton(height: 112, radius: 20)),
        ]),
      );
    }
    final o = ov.requireValue;
    final p = context.tp;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _Tile(
              art: TpArt.analytics,
              label: 'โทเคนเดือนนี้',
              value: TpFmt.compact(o.tokensMonth),
              sub: o.costThb > 0 ? 'ค่าใช้จ่าย ${TpFmt.bahtCompact(o.costThb)}' : 'ตั้งแต่วันที่ 1',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              art: TpArt.ai,
              label: 'บอทเปิดอยู่',
              value: '${TpFmt.count(o.botsActive)}/${TpFmt.count(o.botsTotal)}',
              sub: o.botsRentable > 0 ? 'ให้เช่า ${TpFmt.count(o.botsRentable)} ตัว' : 'แตะเพื่อจัดการ',
              valueColor: o.botsActive > 0 ? p.success : null,
              onTap: () => setState(() => _tab = _AiTab.bots),
            ),
          ),
        ]),
      ]),
    );
  }

  // ───────────── ผู้ให้บริการ ─────────────

  List<Widget> _providerSlivers() {
    final list = ref.watch(aiProvidersProvider);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                'ผู้ให้บริการของระบบบอท AI (บอทให้เช่า / LINE OA) — คนละชุดกับคีย์ AI ที่บอทดูดวงใช้',
                style: TpType.body(12.5, context.tp.muted),
              ),
            ),
            const _AiPoolLink(),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: TpAsync<List<AiProviderItem>>(
          value: list,
          onRetry: () => ref.invalidate(aiProvidersProvider),
          compactError: true,
          loading: const TpSkeletonList(count: 4, itemHeight: 120),
          data: (items) {
            if (items.isEmpty) {
              return const TpEmpty(
                art: TpArt.ai,
                title: 'ยังไม่มีผู้ให้บริการ AI',
                message: 'เพิ่มผู้ให้บริการได้จากหน้าเว็บแอดมิน',
                compact: true,
              );
            }
            return Column(children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProviderCard(
                    p: it.copyWith(isActive: _providerState[it.id]),
                    busy: _providerBusy.contains(it.id),
                    testing: _testing.contains(it.id),
                    test: _tests[it.id],
                    onToggle: (v) => _toggleProvider(it, v),
                    onTest: () => _testProvider(it),
                  ),
                ),
            ]);
          },
        ),
      ),
    ];
  }

  // ───────────── บอท ─────────────

  List<Widget> _botSlivers() => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TpChips<_BotFilter>(
              padding: EdgeInsets.zero,
              value: _botFilter,
              onChanged: (f) => setState(() => _botFilter = f),
              items: [for (final f in _BotFilter.values) TpChipItem(f, f.label)],
            ),
          ),
        ),
        TpPagedSliver<AiBotItem>(
          reloadKey: '${_botFilter.name}-$_botReload',
          fetch: (page) => ref.read(aiRepositoryProvider).bots(page: page, active: _botFilter.active),
          onLoaded: (_) {
            if (mounted && _botState.isNotEmpty) setState(_botState.clear);
          },
          skeletonCount: 5,
          empty: TpEmpty(
            art: TpArt.ai,
            title: _botFilter == _BotFilter.all ? 'ยังไม่มีบอท AI' : 'ไม่มีบอทในกลุ่มนี้',
            message: _botFilter == _BotFilter.all ? 'สร้างบอทได้จากหน้าเว็บแอดมิน' : null,
            compact: true,
          ),
          itemBuilder: (context, b, _) => _BotCard(
            b: b,
            active: _botState[b.id] ?? b.isActive,
            busy: _botBusy.contains(b.id),
            onToggle: (v) => _toggleBot(b, v),
          ),
        ),
      ];
}

// ═════════════════════ ฮีโร่การใช้งาน ═════════════════════

class _UsageHero extends StatelessWidget {
  const _UsageHero({required this.u, required this.ov});
  final AiUsageSeries u;
  final AiOverview? ov;

  @override
  Widget build(BuildContext context) {
    final pts = u.points;
    final total = u.totalRequests;
    final err = ov?.errorsPct ?? 0;
    final peak = u.peak;
    final busy = (ov?.requestsPerMin ?? 0) > 0 || total > 0;
    final (Color pillColor, IconData pillIcon, String pillLabel) = err >= 5
        ? (const Color(0xFFFF8A7A), PhosphorIconsBold.warning, 'ผิดพลาด ${err.toStringAsFixed(1)}%')
        : busy
            ? (const Color(0xFF4BE08E), PhosphorIconsBold.pulse, ov == null ? 'มีการใช้งาน' : 'ทำงานปกติ')
            : (const Color(0x8CFFFFFF), PhosphorIconsBold.moon, 'ช่วงนี้เงียบ');

    return TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('คำขอ AI · 24 ชม.ล่าสุด',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(13.5, TpPalette.heroMuted, w: FontWeight.w500)),
          ),
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration:
                BoxDecoration(color: pillColor.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(pillIcon, size: 13, color: pillColor),
              const SizedBox(width: 4),
              Text(pillLabel, style: TpType.body(12, pillColor, w: FontWeight.w600, height: 1.1)),
            ]),
          ),
        ]),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: TpFoilText(TpFmt.count(total), style: TpType.money(40, Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('คำขอ', style: TpType.body(13, const Color(0x8CFFFFFF))),
          ),
        ]),
        Text(
          peak == null
              ? 'นับจากคีย์ใน AI Pool ของบอทดูดวง'
              : 'พีค ${_hourLabel(peak.hour)} · ${TpFmt.count(peak.requests)} คำขอ · นับจาก AI Pool',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TpType.body(12, const Color(0x8CFFFFFF)),
        ),
        const SizedBox(height: 8),
        TpAreaChart(values: [for (final p in pts) p.requests.toDouble()], slots: pts.length, height: 84),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final i in [0, 6, 12, 18])
              if (i < pts.length) _hourLabel(pts[i].hour),
            'ตอนนี้',
          ].map((t) => Text(t, style: TpType.body(10.5, const Color(0x61FFFFFF), w: FontWeight.w500))).toList(),
        ),
        const SizedBox(height: 12),
        Container(height: 1, color: const Color(0x14FFFFFF)),
        const SizedBox(height: 11),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _HeroStat(label: 'ตอบเฉลี่ย', value: _latency(u.avgLatencyMs)),
          _HeroStat(label: 'p95 · 15 นาที', value: ov == null ? '-' : _latency(ov!.p95LatencyMs), divider: true),
          _HeroStat(
            label: 'คำขอ/นาที',
            value: ov == null ? '-' : TpFmt.count(ov!.requestsPerMin),
            divider: true,
          ),
        ]),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, this.divider = false});
  final String label;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: EdgeInsets.only(left: divider ? 12 : 0, right: 6),
          decoration: divider ? const BoxDecoration(border: Border(left: BorderSide(color: Color(0x14FFFFFF)))) : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(11.5, const Color(0x8CFFFFFF), w: FontWeight.w500)),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TpType.money(16, TpPalette.heroText)),
            ),
          ]),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.art, required this.label, required this.value, required this.sub, this.valueColor, this.onTap});
  final TpArt art;
  final String label;
  final String value;
  final String sub;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return TpCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Tp3D(art, size: 34),
          const Spacer(),
          if (onTap != null) Icon(PhosphorIconsRegular.caretRight, size: 15, color: p.faint),
        ]),
        const SizedBox(height: 8),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(12, p.muted, w: FontWeight.w500)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TpType.money(19, valueColor ?? p.textStrong)),
        ),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(11, p.faint)),
      ]),
    );
  }
}

// ═════════════════════ การใช้งานแยกผู้ให้บริการ ═════════════════════

class _ProviderUsageCard extends StatelessWidget {
  const _ProviderUsageCard({required this.u, required this.total});
  final AiProviderUsage u;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final color = _parseColor(u.color) ?? p.gold;
    final share = total <= 0 ? 0.0 : u.requests / total;
    final errTone = u.errorRatePct >= 10 ? p.danger : (u.errorRatePct >= 3 ? p.warning : p.muted);
    return TpCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(
                u.totalKeys == 0
                    ? 'ไม่มีคีย์'
                    : 'คีย์เปิด ${u.activeKeys}/${u.totalKeys} · โทเคนวันนี้ ${TpFmt.compact(u.tokensToday)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(12, p.muted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(TpFmt.count(u.requests), style: TpType.money(17, u.requests > 0 ? p.textStrong : p.faint)),
            Text(total > 0 ? '${(share * 100).toStringAsFixed(share >= 0.1 ? 0 : 1)}% ของคำขอ' : 'คำขอ',
                style: TpType.body(10.5, p.faint)),
          ]),
        ]),
        const SizedBox(height: 10),
        TpMeter(value: share, color: color, height: 4),
        const SizedBox(height: 9),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _MiniStat(icon: PhosphorIconsRegular.timer, text: 'เฉลี่ย ${_latency(u.avgLatencyMs)}'),
          _MiniStat(icon: PhosphorIconsRegular.gauge, text: 'p95 ${_latency(u.p95LatencyMs)}'),
          _MiniStat(
            icon: PhosphorIconsRegular.warningCircle,
            text: 'ผิดพลาด ${u.errorRatePct.toStringAsFixed(1)}%',
            color: errTone,
          ),
        ]),
        if (!u.isActive && u.totalKeys > 0) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: TpPill('ปิดคีย์ทุกตัวอยู่', tone: TpTone.warning, dense: true, icon: PhosphorIconsBold.pause),
          ),
        ],
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tp.muted;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 3),
      Text(text, style: TpType.body(11.5, c, w: FontWeight.w500)),
    ]);
  }
}

class _AiPoolLink extends StatelessWidget {
  const _AiPoolLink();

  @override
  Widget build(BuildContext context) => TpGroup(children: [
        TpRow(
          art: TpArt.tarot,
          dense: true,
          title: 'คีย์ AI ของบอทดูดวง',
          subtitle: 'จัดการคีย์และโหมดสลับคีย์ → AI Pool',
          onTap: () => context.push('/fortune/ai-pool'),
        ),
      ]);
}

// ═════════════════════ ผู้ให้บริการ ═════════════════════

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.p,
    required this.busy,
    required this.testing,
    required this.test,
    required this.onToggle,
    required this.onTest,
  });
  final AiProviderItem p;
  final bool busy;
  final bool testing;
  final AiConnectionTest? test;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;

  IconData get _icon => switch ((p.type ?? '').toLowerCase()) {
        'self-hosted' => PhosphorIconsRegular.hardDrives,
        'gateway' => PhosphorIconsRegular.shareNetwork,
        _ => PhosphorIconsRegular.cloud,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final sub = [p.typeLabel, if (p.host != null) p.host!].join(' · ');
    return TpCard(
      accent: p.isActive ? c.success : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          TpIconTile(_icon, tone: p.isActive ? TpTone.gold : TpTone.neutral, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, c.textStrong, w: FontWeight.w600)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(12, c.muted)),
            ]),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            height: 36,
            child: Center(
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                  : Switch.adaptive(value: p.isActive, onChanged: onToggle),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TpPill(p.isActive ? 'เปิดใช้งาน' : 'ปิดอยู่',
              tone: p.isActive ? TpTone.success : TpTone.neutral, dense: true),
          TpPill(p.isAvailable ? 'สถานะ: พร้อมใช้' : 'สถานะ: ไม่พร้อม',
              tone: p.isAvailable ? TpTone.info : TpTone.warning, dense: true),
          if (p.apiVersion != null) TpPill('API ${p.apiVersion}', tone: TpTone.neutral, dense: true),
        ]),
        if (test != null) ...[const SizedBox(height: 10), _TestResult(t: test!)],
        const SizedBox(height: 10),
        TpButton.outline(
          testing ? 'กำลังทดสอบ…' : 'ทดสอบการเชื่อมต่อ',
          icon: PhosphorIconsRegular.plugsConnected,
          height: 40,
          fontSize: 13.5,
          loading: testing,
          onPressed: onTest,
        ),
      ]),
    );
  }
}

class _TestResult extends StatelessWidget {
  const _TestResult({required this.t});
  final AiConnectionTest t;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final (TpTone tone, IconData icon, String title, String body) = t.isStub
        ? (
            TpTone.warning,
            PhosphorIconsFill.info,
            'ยังไม่ใช่การทดสอบจริง',
            'เซิร์ฟเวอร์ยังไม่เปิดระบบทดสอบการเชื่อมต่อ — ที่เห็นคือสถานะที่บันทึกไว้: ${t.reachable ? 'พร้อมใช้' : 'ไม่พร้อม'}',
          )
        : t.reachable
            ? (TpTone.success, PhosphorIconsFill.checkCircle, 'เชื่อมต่อได้', 'ผู้ให้บริการตอบกลับปกติ')
            : (TpTone.danger, PhosphorIconsFill.xCircle, 'เชื่อมต่อไม่ได้', 'ตรวจคีย์หรือปลายทาง API บนหน้าเว็บแอดมิน');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(color: p.soft(tone), borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: p.fg(tone)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$title · ${TpFmt.time(t.at)}', style: TpType.h(12.5, p.fg(tone), w: FontWeight.w600)),
            Text(body, style: TpType.body(12, p.text)),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════ บอท ═════════════════════

class _BotCard extends StatelessWidget {
  const _BotCard({required this.b, required this.active, required this.busy, required this.onToggle});
  final AiBotItem b;
  final bool active;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final engine = [b.providerName, b.modelName].whereType<String>().join(' · ');
    return TpCard(
      accent: active ? p.success : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          TpAvatar(name: b.displayName, size: 42, gold: active),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(engine.isEmpty ? 'ยังไม่ได้เลือกผู้ให้บริการ AI' : engine,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(12, p.muted)),
            ]),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            height: 36,
            child: Center(
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                  : Switch.adaptive(value: active, onChanged: onToggle),
            ),
          ),
        ]),
        if (b.description != null) ...[
          const SizedBox(height: 8),
          Text(b.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TpType.body(12.5, p.text)),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TpPill(active ? 'กำลังทำงาน' : 'ปิดอยู่', tone: active ? TpTone.success : TpTone.neutral, dense: true),
          if (b.lineConnected)
            const TpPill('LINE OA', tone: TpTone.success, icon: PhosphorIconsFill.chatCircle, dense: true),
          if (b.isPublic) const TpPill('สาธารณะ', tone: TpTone.info, icon: PhosphorIconsBold.globe, dense: true),
          if (b.isRentable)
            TpPill(
              b.rentalPerMonth > 0 ? 'ให้เช่า ${TpFmt.baht(b.rentalPerMonth)}/เดือน' : 'ให้เช่า',
              tone: TpTone.gold,
              icon: PhosphorIconsBold.tag,
              dense: true,
            ),
        ]),
      ]),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TpSkeleton(width: 140, height: 12),
        SizedBox(height: 10),
        TpSkeleton(width: 150, height: 36),
        SizedBox(height: 14),
        TpSkeleton(height: 84, radius: 12),
        SizedBox(height: 14),
        TpSkeleton(height: 30),
      ]),
    );
  }
}
