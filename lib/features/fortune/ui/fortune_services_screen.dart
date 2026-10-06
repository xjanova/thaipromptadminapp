import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/fortune_repository.dart';

/// บริการและราคา (อ่านอย่างเดียว) — แพคเกจดูดวง + หมวดคำถาม พร้อมสถิติหมวดเดือนนี้
class FortuneServicesScreen extends ConsumerWidget {
  const FortuneServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(fortuneServicesProvider);
    // สถิติหมวด (เดือนนี้) เป็นของเสริม — โหลดไม่ได้ก็ยังแสดงรายการได้
    final month = ref.watch(fortuneDashboardProvider(FortunePeriod.month)).valueOrNull;

    Future<void> refresh() async {
      ref.invalidate(fortuneDashboardProvider(FortunePeriod.month));
      ref.invalidate(fortuneServicesProvider);
      try {
        await ref.read(fortuneServicesProvider.future);
      } catch (_) {
        // error แสดงผ่าน TpAsync อยู่แล้ว
      }
    }

    return TpPage(
      title: 'บริการและราคา',
      subtitle: 'แพคเกจดูดวงและหมวดคำถาม',
      back: true,
      bottomSpace: 32,
      onRefresh: refresh,
      slivers: [
        SliverToBoxAdapter(
          child: TpAsync<FortuneServices>(
            value: services,
            onRetry: () => ref.invalidate(fortuneServicesProvider),
            loading: const TpSkeletonList(count: 5, itemHeight: 70),
            data: (d) => _Body(d: d, month: month),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.d, this.month});
  final FortuneServices d;
  final FortuneDashboard? month;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final activeServices = d.services.where((s) => s.isActive).length;
    final activeCats = d.categories.where((c) => c.isActive).length;
    final stats = {for (final c in month?.categories ?? const <FortuneCategoryStat>[]) c.id: c};

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!d.writable) const _ReadOnlyNote(),

      // ── แพคเกจ ──
      TpSection(
        'แพคเกจ',
        trailing: d.services.isEmpty
            ? null
            : TpPill(
                'เปิดขาย $activeServices/${d.services.length}',
                tone: activeServices == 0 ? TpTone.danger : TpTone.success,
                dense: true,
              ),
      ),
      if (d.services.isEmpty)
        const TpCard(
          padding: EdgeInsets.zero,
          child: TpEmpty(art: TpArt.tarot, title: 'ยังไม่มีแพคเกจในระบบ', compact: true),
        )
      else
        TpGroup(children: [for (final s in d.services) _ServiceRow(s: s)]),

      // ── หมวดคำถาม ──
      TpSection(
        'หมวดคำถาม',
        trailing: d.categories.isEmpty
            ? null
            : TpPill('เปิด $activeCats/${d.categories.length}', tone: TpTone.navy, dense: true),
      ),
      if (d.categories.isEmpty)
        const TpCard(
          padding: EdgeInsets.zero,
          child: TpEmpty(
            art: TpArt.emptyInbox,
            title: 'ยังไม่มีหมวดคำถาม',
            message: 'เพิ่มหมวดได้ที่หน้าเว็บแอดมิน',
            compact: true,
          ),
        )
      else ...[
        TpGroup(children: [for (final c in d.categories) _CategoryRow(c: c, stat: stats[c.id])]),
        if (month != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'สถิติใต้ชื่อหมวด = จำนวนครั้งที่ถามและยอดบิลจ่ายแล้วของเดือนนี้ (เฉพาะหมวดที่เปิดอยู่)',
              style: TpType.body(11.5, p.faint),
            ),
          ),
      ],
    ]);
  }
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return TpCard(
      accent: p.info,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        const TpIconTile(PhosphorIconsRegular.desktop, tone: TpTone.info),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('แก้ราคา/เปิดปิดแพคเกจได้ที่หน้าเว็บแอดมิน', style: TpType.h(14, p.textStrong)),
            const SizedBox(height: 1),
            Text(
              'ในแอปดูได้อย่างเดียว — ราคาและการเปิดขายตั้งรวมกันในหน้าตั้งค่าแม่หมอบนเว็บ',
              style: TpType.body(12.5, p.muted),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.s});
  final FortuneServiceItem s;

  @override
  Widget build(BuildContext context) {
    return TpRow(
      leading: _PriceTile(price: s.price, active: s.isActive),
      title: s.name,
      subtitle: s.price <= 0 ? 'ไม่มีค่าใช้จ่าย' : 'ราคา ${TpFmt.baht(s.price)} ต่อบิล',
      chevron: false,
      trailing: TpPill(
        s.isActive ? 'เปิดขาย' : 'ปิดอยู่',
        tone: s.isActive ? TpTone.success : TpTone.neutral,
        icon: s.isActive ? PhosphorIconsBold.check : PhosphorIconsBold.pauseCircle,
        dense: true,
      ),
    );
  }
}

/// กล่องราคาแทนไอคอน (ทองเมื่อเปิดขาย · เทาเมื่อปิด)
class _PriceTile extends StatelessWidget {
  const _PriceTile({required this.price, required this.active});
  final double price;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? p.goldSoft : p.inset,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: active ? p.borderGold : p.border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          price <= 0 ? 'ฟรี' : TpFmt.baht(price),
          style: TpType.money(14, active ? p.goldText : p.muted),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.c, this.stat});
  final FortuneCategoryItem c;
  final FortuneCategoryStat? stat;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final color = fortuneHexColor(c.color) ?? p.gold;
    final st = stat;
    return TpRow(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c.isActive ? color : p.faint, shape: BoxShape.circle),
        ),
      ),
      title: c.name,
      subtitle: st == null
          ? null
          : st.sessions == 0
              ? 'เดือนนี้ยังไม่มีคนถาม'
              : 'เดือนนี้ ${TpFmt.count(st.sessions)} ครั้ง${st.revenue > 0 ? ' · ${TpFmt.baht(st.revenue)}' : ''}',
      chevron: false,
      trailing: TpPill(c.isActive ? 'เปิด' : 'ปิด', tone: c.isActive ? TpTone.success : TpTone.neutral, dense: true),
    );
  }
}
