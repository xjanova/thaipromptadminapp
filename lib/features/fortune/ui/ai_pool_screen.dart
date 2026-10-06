import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../home/data/ops_repository.dart';
import '../data/fortune_repository.dart';

/// AI Pool — คีย์ AI ที่บอทแม่หมอใช้ทำนาย: สุขภาพ · โหมดวนคีย์ราย provider · เปิด/ปิด · ทดสอบ
class AiPoolScreen extends ConsumerStatefulWidget {
  const AiPoolScreen({super.key});

  @override
  ConsumerState<AiPoolScreen> createState() => _AiPoolScreenState();
}

class _AiPoolScreenState extends ConsumerState<AiPoolScreen> {
  /// คีย์ที่กำลังสลับ / กำลังทดสอบ (กันกดซ้ำ)
  final Set<int> _toggling = {};
  final Set<int> _testing = {};

  /// provider ที่กำลังตั้งโหมด
  String? _modeBusy;

  FortuneRepository get _repo => ref.read(fortuneRepositoryProvider);

  Future<void> _refresh() async {
    ref.invalidate(aiPoolProvider);
    try {
      await ref.read(aiPoolProvider.future);
    } catch (_) {
      // error แสดงผ่านหน้าจออยู่แล้ว
    }
  }

  /// หลังแก้คีย์ — ให้ตัวนับ AI Pool หน้าแรก/โมดูลตรงกัน
  void _syncOps() => ref.invalidate(opsSummaryProvider);

  Future<void> _toggle(AiPool pool, AiKey k, bool on) async {
    if (_toggling.contains(k.id) || !pool.canManage) return;

    // ปิดคีย์สุดท้ายที่พร้อมใช้ของ provider (หรือทั้งระบบ) → ต้องยืนยันก่อน
    if (!on && k.healthy) {
      final healthyInProvider =
          pool.keys.where((x) => x.provider == k.provider && x.healthy).length;
      if (healthyInProvider <= 1) {
        final lastOverall = pool.healthy <= 1;
        final ok = await tpConfirm(
          context,
          title: lastOverall
              ? 'ปิดคีย์สุดท้ายที่พร้อมใช้?'
              : 'ปิดคีย์สุดท้ายของ ${k.providerName}?',
          message: lastOverall
              ? 'นี่คือคีย์เดียวในระบบที่พร้อมใช้อยู่ ถ้าปิด บอทแม่หมอจะเรียก AI ไม่ได้และตอบลูกค้าไม่ได้จนกว่าจะเปิดคีย์อื่น'
              : '${k.providerName} จะไม่เหลือคีย์ที่พร้อมใช้ บอทต้องพึ่งคีย์ของผู้ให้บริการอื่นแทน งานที่ผูกกับ ${k.providerName} อาจล้มเหลว',
          confirmLabel: 'ปิดคีย์',
          danger: true,
        );
        if (!ok || !mounted) return;
      }
    }

    setState(() => _toggling.add(k.id));
    try {
      final (fresh, msg) = await _repo.toggleKey(k.id);
      if (!mounted) return;
      if (fresh != null) {
        ref.read(aiPoolProvider.notifier).patchKey(fresh);
      } else {
        ref.invalidate(aiPoolProvider);
      }
      _syncOps();
      final nowOn = fresh?.isActive ?? on;
      if (nowOn != on) {
        // endpoint เป็นการ "สลับ" — ถ้ามีคนเปลี่ยนจากเว็บไปก่อน ผลจะกลับด้านกับที่ตั้งใจ
        tpToast(
          context,
          'สถานะคีย์ถูกเปลี่ยนจากที่อื่นก่อนหน้านี้ ตอนนี้คีย์${nowOn ? 'เปิด' : 'ปิด'}อยู่ ตรวจอีกครั้งก่อนสลับ',
        );
      } else {
        tpToast(context,
            msg ?? (nowOn ? 'เปิดใช้งานคีย์แล้ว' : 'ปิดใช้งานคีย์แล้ว'),
            kind: TpToastKind.success);
      }
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _toggling.remove(k.id));
    }
  }

  Future<void> _test(AiPool pool, AiKey k) async {
    if (_testing.contains(k.id) || !pool.canManage) return;
    setState(() => _testing.add(k.id));
    try {
      final r = await _repo.testKey(k.id);
      if (!mounted) return;
      if (r.key != null) ref.read(aiPoolProvider.notifier).patchKey(r.key!);
      _syncOps();
      if (r.passed) {
        final ms = r.responseTimeMs == null
            ? ''
            : ' (${TpFmt.count(r.responseTimeMs)} ms)';
        final warn = r.modelWarning == null ? '' : ' · ${r.modelWarning}';
        tpToast(context, _short('${r.message ?? 'คีย์ใช้งานได้ปกติ'}$ms$warn'),
            kind: TpToastKind.success);
      } else {
        tpToast(
            context, _short(r.message ?? 'ทดสอบไม่ผ่าน คีย์นี้ยังใช้งานไม่ได้'),
            kind: TpToastKind.error);
      }
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _testing.remove(k.id));
    }
  }

  Future<void> _pickMode(AiPool pool, AiProviderInfo pv) async {
    if (!pool.canManage || _modeBusy != null) return;
    final picked = await tpShowSheet<String>(
      context,
      initial: 0.66,
      min: 0.4,
      max: 0.92,
      builder: (ctx, scroll) =>
          _ModeSheet(scroll: scroll, provider: pv, modes: pool.modes),
    );
    if (picked == null || picked == pv.rotationMode || !mounted) return;
    setState(() => _modeBusy = pv.provider);
    try {
      await _repo.setProviderMode(pv.provider, picked);
      if (!mounted) return;
      ref.read(aiPoolProvider.notifier).patchMode(pv.provider, picked);
      tpToast(
          context, 'ตั้งโหมดของ ${pv.name} เป็น ${pool.modeTitle(picked)} แล้ว',
          kind: TpToastKind.success);
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _modeBusy = null);
    }
  }

  static String _short(String s) =>
      s.length > 180 ? '${s.substring(0, 177)}…' : s;

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(aiPoolProvider);
    final d = pool.valueOrNull;

    final List<Widget> slivers;
    if (d != null) {
      slivers = _content(d);
    } else if (pool.hasError) {
      slivers = [
        SliverToBoxAdapter(
            child: TpErrorView(
                error: pool.error,
                onRetry: () => ref.invalidate(aiPoolProvider))),
      ];
    } else {
      slivers = const [SliverToBoxAdapter(child: _PoolSkeleton())];
    }

    return TpPage(
      title: 'AI Pool',
      subtitle: d == null
          ? 'คีย์ AI ของบอทแม่หมอ'
          : 'คีย์ AI ของบอทแม่หมอ · ${d.providers.length} ผู้ให้บริการ',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      slivers: slivers,
    );
  }

  List<Widget> _content(AiPool d) {
    if (d.keys.isEmpty) {
      return [
        SliverToBoxAdapter(child: _SummaryHero(pool: d)),
        const SliverToBoxAdapter(
          child: TpEmpty(
            art: TpArt.ai,
            title: 'ยังไม่มีคีย์ AI ในระบบ',
            message: 'เพิ่มคีย์ได้ที่หน้าเว็บแอดมิน เมนู AI API Keys',
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(child: _SummaryHero(pool: d)),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverToBoxAdapter(child: _GlobalModeCard(pool: d)),
      if (!d.canManage)
        const SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.only(top: 10), child: _ReadOnlyNote()),
        ),
      for (final pv in d.providers) ...[
        SliverToBoxAdapter(
          child: TpSection(
            pv.name,
            trailing: TpPill(
              '${pv.keysHealthy}/${pv.keysTotal} พร้อม',
              tone: pv.keysHealthy == 0
                  ? TpTone.danger
                  : (pv.keysHealthy < pv.keysTotal
                      ? TpTone.warning
                      : TpTone.success),
              dense: true,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProviderModeRow(
              pool: d,
              provider: pv,
              busy: _modeBusy == pv.provider,
              onTap: () => _pickMode(d, pv),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: d.keysOf(pv.provider).length,
          itemBuilder: (context, i) {
            final k = d.keysOf(pv.provider)[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _KeyCard(
                k: k,
                canManage: d.canManage,
                toggling: _toggling.contains(k.id),
                testing: _testing.contains(k.id),
                onToggle: (on) => _toggle(d, k, on),
                onTest: () => _test(d, k),
              ),
            );
          },
        ),
      ],
    ];
  }
}

// ═════════════════════ สรุปบนสุด ═════════════════════

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.pool});
  final AiPool pool;

  @override
  Widget build(BuildContext context) {
    final total = pool.total;
    final healthy = pool.healthy;
    // การ์ดฮีโร่มืดเสมอ — ใช้สีสถานะของชุดมิดไนท์ (อ่านออกบนพื้นเข้ม)
    const ok = TpPalette.midnight;
    final (String label, Color color) = total == 0
        ? ('ยังไม่มีคีย์', TpPalette.heroGold)
        : healthy == 0
            ? ('ไม่มีคีย์พร้อมใช้', ok.danger)
            : healthy < (total / 2).ceil()
                ? ('คีย์พร้อมใช้เหลือน้อย', ok.warning)
                : ('พร้อมทำงาน', ok.success);
    final ratio = total == 0 ? 0.0 : healthy / total;

    return TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('คีย์พร้อมใช้งาน',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TpType.body(13.5, TpPalette.heroMuted, w: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          _HeroPill(label: label, color: color),
        ]),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          TpFoilText(TpFmt.count(healthy),
              style: TpType.money(42, Colors.white)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('/ ${TpFmt.count(total)} คีย์',
                style:
                    TpType.money(17, TpPalette.heroMuted, w: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(children: [
            Container(
                height: 5, color: TpPalette.heroText.withValues(alpha: 0.08)),
            FractionallySizedBox(
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(height: 5, color: color),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: TpPalette.heroText.withValues(alpha: 0.08)),
        const SizedBox(height: 12),
        Row(children: [
          _HeroStat(label: 'เปิดใช้อยู่', value: TpFmt.count(pool.active)),
          _HeroStat(
              label: 'เรียกใช้วันนี้',
              value: TpFmt.compact(pool.requestsToday),
              divider: true),
          _HeroStat(
            label: 'ผิดพลาดวันนี้',
            value: TpFmt.count(pool.errorsToday),
            color: pool.errorsToday > 0 ? ok.danger : null,
            divider: true,
          ),
        ]),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color, blurRadius: 6)]),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TpType.body(12, color, w: FontWeight.w600, height: 1.1)),
        ]),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(
      {required this.label,
      required this.value,
      this.divider = false,
      this.color});
  final String label;
  final String value;
  final bool divider;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: EdgeInsets.only(left: divider ? 12 : 0, right: 6),
          decoration: divider
              ? BoxDecoration(
                  border: Border(
                      left: BorderSide(
                          color: TpPalette.heroText.withValues(alpha: 0.08))))
              : null,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(
                    11.5, TpPalette.heroText.withValues(alpha: 0.55),
                    w: FontWeight.w500)),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TpType.money(16, color ?? TpPalette.heroText)),
            ),
          ]),
        ),
      );
}

// ═════════════════════ โหมดรวม / สิทธิ์ ═════════════════════

class _GlobalModeCard extends StatelessWidget {
  const _GlobalModeCard({required this.pool});
  final AiPool pool;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final mode = pool.mode(pool.globalMode);
    return TpCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TpIconTile(PhosphorIconsRegular.shuffleAngular,
            tone: TpTone.gold),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('โหมดรวมข้ามผู้ให้บริการ', style: TpType.body(12, p.muted)),
            Text(mode?.title ?? pool.globalMode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.h(15, p.textStrong)),
            if (mode?.description != null)
              Text(mode!.description!, style: TpType.body(12.5, p.text)),
            const SizedBox(height: 4),
            Text(
              pool.globalModeWritable
                  ? 'แก้โหมดรวมได้ที่หน้าเว็บแอดมิน'
                  : 'ตั้งจากค่า env บนเซิร์ฟเวอร์ (AI_CROSS_PROVIDER_ROTATION) — แก้จากแอปไม่ได้ ปรับได้เฉพาะโหมดรายผู้ให้บริการด้านล่าง',
              style: TpType.body(11.5, p.faint),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child:
              Icon(PhosphorIconsRegular.lockSimple, size: 16, color: p.faint),
        ),
      ]),
    );
  }
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return TpCard(
      accent: p.warning,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        const TpIconTile(PhosphorIconsRegular.eye, tone: TpTone.warning),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ดูได้อย่างเดียว', style: TpType.h(14, p.textStrong)),
            Text(
              'บัญชีนี้ไม่มีสิทธิ์จัดการคีย์ AI — ต้องเป็นผู้ดูแลสูงสุด หรือได้รับสิทธิ์ manage_api_keys จึงจะเปิด/ปิด ทดสอบ หรือเปลี่ยนโหมดได้',
              style: TpType.body(12.5, p.muted),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ProviderModeRow extends StatelessWidget {
  const _ProviderModeRow(
      {required this.pool,
      required this.provider,
      required this.busy,
      required this.onTap});
  final AiPool pool;
  final AiProviderInfo provider;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final mode = pool.mode(provider.rotationMode);
    return TpCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: TpRow(
        dense: true,
        icon: PhosphorIconsRegular.shuffle,
        iconTone: TpTone.gold,
        title: 'โหมดวนคีย์ · ${mode?.title ?? provider.rotationMode}',
        subtitle:
            mode?.description ?? 'วิธีที่บอทสลับใช้คีย์ภายใน ${provider.name}',
        trailing: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : pool.canManage
                ? null
                : Icon(PhosphorIconsRegular.lockSimple,
                    size: 16, color: p.faint),
        onTap: pool.canManage && !busy ? onTap : null,
      ),
    );
  }
}

// ═════════════════════ การ์ดคีย์ ═════════════════════

class _KeyCard extends StatelessWidget {
  const _KeyCard({
    required this.k,
    required this.canManage,
    required this.toggling,
    required this.testing,
    required this.onToggle,
    required this.onTest,
  });

  final AiKey k;
  final bool canManage;
  final bool toggling;
  final bool testing;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;

  /// ป้ายสุขภาพ + สีแถบซ้าย
  (String, TpTone, IconData) _health() {
    if (k.healthy) {
      return ('พร้อมใช้', TpTone.success, PhosphorIconsBold.checkCircle);
    }
    if (!k.isActive) {
      return ('ปิดอยู่', TpTone.neutral, PhosphorIconsBold.pauseCircle);
    }
    if (k.isCritical) {
      return ('ใช้งานไม่ได้', TpTone.danger, PhosphorIconsBold.warningCircle);
    }
    if (k.isSuspended) {
      return (
        'พักถึง ${TpFmt.dateTime(k.disabledUntil!)}',
        TpTone.warning,
        PhosphorIconsBold.clockCountdown
      );
    }
    if (k.lastTestPassedAt == null) {
      return ('ยังไม่ผ่านการทดสอบ', TpTone.warning, PhosphorIconsBold.flask);
    }
    return ('ไม่พร้อม', TpTone.warning, PhosphorIconsBold.warning);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final (healthLabel, healthTone, healthIcon) = _health();
    final accent = switch (healthTone) {
      TpTone.success => p.success,
      TpTone.danger => p.danger,
      TpTone.neutral => p.faint,
      _ => p.warning,
    };

    // ข้อความผิดพลาดที่ควรให้แอดมินเห็น: คีย์ไม่พร้อม หรือยังผิดพลาดติดกันอยู่
    final String? errorText = (!k.healthy || k.consecutiveErrors > 0)
        ? (k.lastError ?? (k.lastTestFailed ? k.lastTestMessage : null))
        : null;
    final errorAt = k.lastError != null ? k.lastErrorAt : k.lastTestFailedAt;

    final (String testText, Color testColor) = k.lastTestFailed
        ? ('ทดสอบไม่ผ่าน ${TpFmt.ago(k.lastTestFailedAt)}', p.danger)
        : k.lastTestPassedAt != null
            ? ('ทดสอบผ่าน ${TpFmt.ago(k.lastTestPassedAt)}', p.success)
            : ('ยังไม่เคยทดสอบ', p.muted);

    return TpCard(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(
                [if (k.model != null) k.model!, k.keyMasked].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.money(12, p.muted, w: FontWeight.w500),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            height: 36,
            child: Center(
              child: toggling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Switch.adaptive(
                      value: k.isActive,
                      onChanged: canManage && !testing ? onToggle : null,
                    ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TpPill(healthLabel, tone: healthTone, icon: healthIcon, dense: true),
          if (k.consecutiveErrors > 0)
            TpPill('ผิดพลาดติดกัน ${k.consecutiveErrors} ครั้ง',
                tone: TpTone.danger, dense: true),
          if (k.purposeShort != null)
            TpPill(k.purposeShort!, tone: TpTone.navy, dense: true),
          TpPill('ลำดับ ${k.priority}', tone: TpTone.neutral, dense: true),
        ]),
        if (errorText != null) ...[
          const SizedBox(height: 10),
          _ErrorNote(text: errorText, at: errorAt),
        ],
        const SizedBox(height: 10),
        _UsageStrip(k: k),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(testText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12, testColor, w: FontWeight.w600)),
              Text(
                k.lastUsedAt == null
                    ? 'ยังไม่ถูกเรียกใช้'
                    : 'ใช้ล่าสุด ${TpFmt.ago(k.lastUsedAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(11.5, p.faint),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: TpButton.outline(
              'ทดสอบ',
              icon: PhosphorIconsRegular.lightning,
              height: 38,
              fontSize: 13.5,
              loading: testing,
              onPressed: canManage && !toggling ? onTest : null,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.text, this.at});
  final String text;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
          color: p.dangerSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(PhosphorIconsRegular.warningCircle,
              size: 16, color: p.danger),
        ),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                at == null
                    ? 'ข้อผิดพลาดล่าสุดจากผู้ให้บริการ'
                    : 'ข้อผิดพลาดล่าสุด · ${TpFmt.ago(at)}',
                style: TpType.body(11.5, p.danger, w: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(12.5, p.text, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

/// การใช้งานวันนี้ของคีย์
class _UsageStrip extends StatelessWidget {
  const _UsageStrip({required this.k});
  final AiKey k;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(11, p.muted)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child:
                  Text(value, style: TpType.money(14, color ?? p.textStrong)),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
          color: p.inset, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        cell('เรียกวันนี้', TpFmt.count(k.usageRequests)),
        Container(width: 1, height: 26, color: p.divider),
        cell('โทเคน', TpFmt.compact(k.usageTokens)),
        Container(width: 1, height: 26, color: p.divider),
        cell('ผิดพลาด', TpFmt.count(k.usageErrors),
            color: k.usageErrors > 0 ? p.danger : null),
      ]),
    );
  }
}

// ═════════════════════ แผ่นเลือกโหมด ═════════════════════

class _ModeSheet extends StatelessWidget {
  const _ModeSheet(
      {required this.scroll, required this.provider, required this.modes});
  final ScrollController scroll;
  final AiProviderInfo provider;
  final List<AiMode> modes;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Text('โหมดวนคีย์ของ ${provider.name}',
              style: TpType.h(18, p.textStrong)),
          const SizedBox(height: 2),
          Text(
              'เลือกวิธีที่บอทสลับใช้คีย์ภายในผู้ให้บริการนี้ มีผลกับคำขอถัดไปทันที',
              style: TpType.body(13, p.muted)),
          const SizedBox(height: 14),
          if (modes.isEmpty)
            const TpCard(
              padding: EdgeInsets.zero,
              child: TpEmpty(
                  art: TpArt.settings,
                  title: 'เซิร์ฟเวอร์ไม่ได้ส่งรายการโหมดมา',
                  compact: true),
            )
          else
            TpGroup(children: [
              for (final m in modes)
                TpRow(
                  title: m.title,
                  subtitle: m.description,
                  chevron: false,
                  trailing: Icon(
                    m.key == provider.rotationMode
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.circle,
                    size: 22,
                    color: m.key == provider.rotationMode ? p.gold : p.faint,
                  ),
                  onTap: () => Navigator.pop(context, m.key),
                ),
            ]),
        ]);
  }
}

class _PoolSkeleton extends StatelessWidget {
  const _PoolSkeleton();

  @override
  Widget build(BuildContext context) =>
      const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TpHeroCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TpSkeleton(width: 110, height: 12),
            SizedBox(height: 10),
            TpSkeleton(width: 140, height: 36),
            SizedBox(height: 12),
            TpSkeleton(height: 5),
            SizedBox(height: 18),
            TpSkeleton(height: 32),
          ]),
        ),
        SizedBox(height: 14),
        TpSkeletonList(count: 3, itemHeight: 150),
      ]);
}
