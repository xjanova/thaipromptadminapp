import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/api/paged.dart';
import '../../../shared/ui/tp.dart';
import '../data/users_repository.dart';

/// หน้า "สมาชิก" — สรุปจำนวน · ค้นหา · กรองสถานะ/ระดับ · รายชื่อแบ่งหน้า (แตะ → หน้ารายละเอียด)
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  UserFilter _filter = UserFilter.all;
  int? _rankId;
  int _reload = 0;

  /// จำนวนที่พบตามตัวกรองปัจจุบัน (จากหน้าแรกของรายการ)
  int? _found;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _applyQuery(v));
  }

  void _applyQuery(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (!mounted || q == _query) return;
    setState(() {
      _query = q;
      _found = null;
    });
  }

  void _clearAll() {
    _search.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _filter = UserFilter.all;
      _rankId = null;
      _found = null;
    });
  }

  Future<void> _refresh() async {
    setState(() => _reload++);
    ref.invalidate(ranksListProvider);
    try {
      ref.invalidate(usersStatsProvider);
      await ref.read(usersStatsProvider.future);
    } catch (_) {
      // การ์ดสรุปแสดง error เองอยู่แล้ว
    }
  }

  int _countOf(UsersStats s, UserFilter f) => switch (f) {
        UserFilter.all => s.total,
        UserFilter.active => s.active,
        UserFilter.blocked => s.blocked,
        UserFilter.admins => s.admins,
      };

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(usersStatsProvider);
    final s = stats.valueOrNull;
    final ranks = ref.watch(ranksListProvider).valueOrNull ?? const <AdminRank>[];
    final filtered = _query.isNotEmpty || _filter != UserFilter.all || _rankId != null;

    return TpPage(
      title: 'สมาชิก',
      subtitle: s == null ? 'ค้นหาและดูข้อมูลสมาชิกทั้งระบบ' : 'ทั้งหมด ${TpFmt.count(s.total)} คน',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _HeaderSearchField(
          controller: _search,
          hint: 'ชื่อ อีเมล เบอร์โทร หรือรหัสแนะนำ',
          onChanged: _onSearchChanged,
          onSubmitted: _applyQuery,
          onClear: () {
            _search.clear();
            _applyQuery('');
          },
        ),
        const SizedBox(height: 10),
        TpChips<UserFilter>(
          onHeader: true,
          padding: EdgeInsets.zero,
          value: _filter,
          onChanged: (f) => setState(() {
            _filter = f;
            _found = null;
          }),
          items: [for (final f in UserFilter.values) TpChipItem(f, f.label, count: s == null ? null : _countOf(s, f))],
        ),
      ]),
      slivers: [
        // การ์ดสรุป — ซ่อนตอนค้นหา ให้ผลลัพธ์ขึ้นมาใกล้มือ
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _query.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _UsersHero(value: stats, onRetry: () => ref.invalidate(usersStatsProvider)),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        if (ranks.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TpChips<int>(
                padding: EdgeInsets.zero,
                value: _rankId ?? 0,
                onChanged: (v) => setState(() {
                  _rankId = v == 0 ? null : v;
                  _found = null;
                }),
                items: [
                  const TpChipItem(0, 'ทุกระดับ'),
                  for (final r in ranks) TpChipItem(r.id, r.displayName),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _ResultLine(found: _found, query: _query, filtered: filtered, onClear: _clearAll),
        ),
        TpPagedSliver<AdminListUser>(
          reloadKey: '${_filter.name}-${_rankId ?? 0}-$_query-$_reload',
          fetch: (page) => ref
              .read(usersRepositoryProvider)
              .users(page: page, search: _query, filter: _filter, rankId: _rankId),
          onLoaded: (Paged<AdminListUser> p) {
            if (mounted) setState(() => _found = p.total);
          },
          empty: TpEmpty(
            art: TpArt.members,
            title: _query.isNotEmpty ? 'ไม่พบสมาชิกที่ตรงกับคำค้น' : 'ไม่มีสมาชิกในกลุ่มนี้',
            message: _query.isNotEmpty ? 'ลองค้นด้วยชื่อบางส่วน อีเมล เบอร์โทร หรือรหัสแนะนำ' : null,
            actionLabel: filtered ? 'ล้างตัวกรอง' : null,
            onAction: filtered ? _clearAll : null,
            compact: true,
          ),
          itemBuilder: (context, u, _) => _UserTile(user: u, onTap: () => context.push('/users/${u.id}')),
        ),
      ],
    );
  }
}

// ═════════════════════ การ์ดสรุป ═════════════════════

class _UsersHero extends StatelessWidget {
  const _UsersHero({required this.value, required this.onRetry});
  final AsyncValue<UsersStats> value;
  final VoidCallback onRetry;

  static const _green = Color(0xFF4BE08E);
  static const _red = Color(0xFFFF8A7A);
  static const _line = Color(0x14FFFFFF);

  @override
  Widget build(BuildContext context) {
    if (!value.hasValue) {
      if (value.hasError) return _HeroError(error: value.error, onRetry: onRetry);
      return const _HeroSkeleton();
    }
    final s = value.requireValue;
    final total = s.total <= 0 ? 1 : s.total;
    final month = s.newThisMonth;
    // สัดส่วนแถบ (ต่อพัน) — ช่องที่เป็น 0 ไม่วาด
    final af = (s.active * 1000 ~/ total).clamp(0, 1000);
    final bf = (s.blocked * 1000 ~/ total).clamp(0, 1000 - af);
    final rest = 1000 - af - bf;
    return TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('สมาชิกทั้งหมด', style: TpType.body(13.5, TpPalette.heroMuted, w: FontWeight.w500)),
          ),
          if (s.newToday > 0)
            _HeroChip(icon: PhosphorIconsBold.trendUp, label: '+${TpFmt.count(s.newToday)} วันนี้', color: _green),
        ]),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            TpFoilText(TpFmt.count(s.total), style: TpType.money(38, Colors.white)),
            const SizedBox(width: 6),
            Text('คน', style: TpType.body(15, TpPalette.heroMuted, w: FontWeight.w500)),
          ]),
        ),
        const SizedBox(height: 10),
        // สัดส่วนใช้งานปกติ / ถูกระงับ
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: Row(children: [
              if (af > 0) Expanded(flex: af, child: const ColoredBox(color: _green)),
              if (bf > 0) Expanded(flex: bf, child: const ColoredBox(color: _red)),
              if (rest > 0) Expanded(flex: rest, child: const ColoredBox(color: _line)),
            ]),
          ),
        ),
        const SizedBox(height: 7),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _Legend(color: _green, label: 'ใช้งานปกติ ${TpFmt.count(s.active)}'),
          _Legend(color: _red, label: 'ถูกระงับ ${TpFmt.count(s.blocked)}'),
        ]),
        const SizedBox(height: 12),
        Container(height: 1, color: _line),
        const SizedBox(height: 11),
        Row(children: [
          _HeroSplit(label: 'สมัครวันนี้', value: '+${TpFmt.count(s.newToday)}', color: s.newToday > 0 ? _green : null),
          month != null
              ? _HeroSplit(label: 'เดือนนี้', value: '+${TpFmt.count(month)}', divider: true)
              : _HeroSplit(label: 'สัปดาห์นี้', value: '+${TpFmt.count(s.newThisWeek)}', divider: true),
          _HeroSplit(
            label: 'แอดมิน',
            value: TpFmt.count(s.admins),
            sub: s.superAdmins > 0 ? 'สูงสุด ${TpFmt.count(s.superAdmins)}' : null,
            divider: true,
          ),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TpType.body(11.5, const Color(0x8CFFFFFF), w: FontWeight.w500)),
      ]);
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TpType.body(12, color, w: FontWeight.w600, height: 1.1)),
        ]),
      );
}

class _HeroSplit extends StatelessWidget {
  const _HeroSplit({required this.label, required this.value, this.sub, this.color, this.divider = false});
  final String label;
  final String value;
  final String? sub;
  final Color? color;
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
              child: Text(value, style: TpType.money(16, color ?? TpPalette.heroText)),
            ),
            if (sub != null)
              Text(sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(10.5, const Color(0x73FFFFFF), w: FontWeight.w500)),
          ]),
        ),
      );
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => const TpHeroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TpSkeleton(width: 96, height: 12),
          SizedBox(height: 10),
          TpSkeleton(width: 170, height: 34),
          SizedBox(height: 14),
          TpSkeleton(height: 5),
          SizedBox(height: 18),
          TpSkeleton(height: 34),
        ]),
      );
}

/// การ์ดสรุปโหลดไม่ได้ — แถบบาง ๆ พร้อมปุ่มลองใหม่ (ไม่บังรายชื่อด้านล่าง)
class _HeroError extends StatelessWidget {
  const _HeroError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return TpCard(
      accent: p.warning,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(children: [
        Icon(PhosphorIconsRegular.warningCircle, size: 20, color: p.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('โหลดสรุปสมาชิกไม่สำเร็จ', style: TpType.h(13.5, p.textStrong, w: FontWeight.w600)),
            Text(tpErrorText(error), maxLines: 2, overflow: TextOverflow.ellipsis, style: TpType.body(12, p.muted)),
          ]),
        ),
        TpButton.ghost('ลองใหม่', height: 38, onPressed: onRetry),
      ]),
    );
  }
}

// ═════════════════════ รายการ ═════════════════════

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.found, required this.query, required this.filtered, required this.onClear});
  final int? found;
  final String query;
  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(children: [
        Expanded(
          child: Text(
            found == null
                ? 'กำลังค้นหา…'
                : query.isNotEmpty
                    ? 'พบ ${TpFmt.count(found)} คน จาก “$query”'
                    : (filtered ? 'พบ ${TpFmt.count(found)} คน' : 'สมาชิกล่าสุด · ${TpFmt.count(found)} คน'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TpType.h(13.5, p.muted, w: FontWeight.w600),
          ),
        ),
        if (filtered)
          GestureDetector(
            onTap: onClear,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(PhosphorIconsRegular.x, size: 13, color: p.goldText),
                const SizedBox(width: 3),
                Text('ล้างตัวกรอง', style: TpType.body(12.5, p.goldText, w: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});
  final AdminListUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final u = user;
    final role = u.roleLabel;
    final pills = <Widget>[
      if (u.rankName != null) _RankPill(name: u.rankName!, color: u.rankColor),
      if (u.isBlocked) const TpPill('ถูกระงับ', tone: TpTone.danger, icon: PhosphorIconsBold.prohibit, dense: true),
      if (role != null) TpPill(role, tone: TpTone.navy, icon: PhosphorIconsFill.shieldCheck, dense: true),
    ];
    return TpCard(
      onTap: onTap,
      accent: u.isBlocked ? p.danger : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TpAvatar(name: u.displayName, size: 44, gold: u.isAdmin),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(u.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              Text(TpFmt.ago(u.createdAt), style: TpType.body(11.5, p.faint)),
            ]),
            Text(u.contactLine.isEmpty ? 'ไม่มีข้อมูลติดต่อ' : u.contactLine,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(12.5, p.muted)),
            if (pills.isNotEmpty || u.hasWallet) ...[
              const SizedBox(height: 7),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Wrap(spacing: 6, runSpacing: 5, children: pills)),
                if (u.hasWallet) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(TpFmt.baht(u.walletBalance),
                          style: TpType.money(14.5, (u.walletBalance ?? 0) > 0 ? p.goldText : p.faint)),
                    ),
                  ),
                ],
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// ป้ายระดับสมาชิก — พื้นทอง + จุดสีประจำระดับจากหลังบ้าน
class _RankPill extends StatelessWidget {
  const _RankPill({required this.name, this.color});
  final String name;
  final String? color;

  static Color? _parse(String? hex) {
    final h = (hex ?? '').replaceAll('#', '').trim();
    if (h.length != 6 && h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(h.length == 6 ? 0xFF000000 | v : v);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final dot = _parse(color) ?? p.gold;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(color: p.goldSoft, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: p.gold, width: 0.6)),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TpType.body(11, p.goldText, w: FontWeight.w600, height: 1.1)),
        ),
      ]),
    );
  }
}

// ═════════════════════ ช่องค้นหาบนหัว ═════════════════════

/// ช่องค้นหาแบบกระจกบนหัวหน้าจอ (อ่านง่ายทั้งสองโหมด เพราะหัวมืดเสมอ)
class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c));
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, v, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TpType.body(14.5, p.onHeader),
        cursorColor: p.gold,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: p.glass,
          hintText: hint,
          hintStyle: TpType.body(14, p.onHeaderMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 19, color: p.onHeaderMuted),
          suffixIcon: v.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'ล้างคำค้น',
                  icon: Icon(PhosphorIconsRegular.xCircle, size: 19, color: p.onHeaderMuted),
                  onPressed: onClear,
                ),
          border: border(p.glassBorder),
          enabledBorder: border(p.glassBorder),
          focusedBorder: border(p.gold.withValues(alpha: 0.65)),
        ),
      ),
    );
  }
}
