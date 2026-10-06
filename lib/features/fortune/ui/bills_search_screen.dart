import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../work/data/work_repository.dart';
import '../../work/ui/bill_widgets.dart';
import '../data/fortune_repository.dart';

/// กองสถานะที่ค้นได้ (`all` = ทุกกอง) — ป้ายตรงกับแท็บงานรอทำ
enum _Status {
  all('all', 'ทั้งหมด', null),
  awaiting('awaiting', 'รอตรวจ', BillBucket.awaiting),
  unpaid('unpaid', 'รอโอน', BillBucket.unpaid),
  paid('paid', 'จ่ายแล้ว', BillBucket.paid),
  refunded('refunded', 'คืนเงิน', BillBucket.refunded),
  cancelled('cancelled', 'ยกเลิก', BillBucket.cancelled),
  closed('closed', 'ปิดไม่ชำระ', BillBucket.closed);

  const _Status(this.key, this.label, this.bucket);
  final String key;
  final String label;
  final BillBucket? bucket;
}

/// ค้นหาบิลดูดวงทุกสถานะ — ชื่อลูกค้า · เลขบิล · PSID/LINE id · #รหัส
class BillsSearchScreen extends ConsumerStatefulWidget {
  const BillsSearchScreen({super.key});

  @override
  ConsumerState<BillsSearchScreen> createState() => _BillsSearchScreenState();
}

class _BillsSearchScreenState extends ConsumerState<BillsSearchScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  String _query = '';
  _Status _status = _Status.all;
  FortunePlatform? _platform;
  FortunePackage? _package;
  int _reload = 0;
  int? _total;

  bool get _filtered => _query.isNotEmpty || _platform != null || _package != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// พิมพ์แล้วรอ 400 ms ค่อยค้น (กันยิงทุกตัวอักษร)
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _apply(v));
  }

  void _apply(String v) {
    _debounce?.cancel();
    if (!mounted) return;
    final q = v.trim();
    if (q == _query) return;
    setState(() {
      _query = q;
      _total = null;
    });
  }

  void _clearSearch() {
    _search.clear();
    _apply('');
  }

  void _clearFilters() {
    _search.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _platform = null;
      _package = null;
      _status = _Status.all;
      _total = null;
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(billStatsProvider);
    setState(() => _reload++);
  }

  Future<void> _pickPackage() async {
    _focus.unfocus();
    final picked = await tpShowSheet<({FortunePackage? pkg})>(
      context,
      initial: 0.6,
      min: 0.4,
      max: 0.8,
      builder: (ctx, scroll) => _PackageSheet(scroll: scroll, current: _package),
    );
    if (picked == null || !mounted || picked.pkg == _package) return;
    setState(() {
      _package = picked.pkg;
      _total = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(billStatsProvider).valueOrNull;

    // ตัวนับต่อกองมาจาก bills/stats (ทั้งระบบ) — โชว์เฉพาะตอนไม่ได้กรองอื่น ไม่งั้นตัวเลขจะไม่ตรงกับรายการ
    int? countOf(_Status s) {
      if (stats == null || _filtered) return null;
      if (s.bucket != null) return stats.count(s.bucket!);
      return stats.counts.values.fold<int>(0, (a, b) => a + b);
    }

    return TpPage(
      title: 'ค้นหาบิล',
      subtitle: _total == null ? 'บิลดูดวงทุกสถานะ ทุกช่องทาง' : 'พบ ${TpFmt.count(_total)} บิล',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      actions: [
        TpGlassButton(
          icon: PhosphorIconsRegular.funnel,
          tooltip: 'กรองตามแพคเกจ',
          dot: _package != null,
          onTap: _pickPackage,
        ),
      ],
      headerBottom: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SearchField(controller: _search, focusNode: _focus, onChanged: _onChanged, onSubmitted: _apply, onClear: _clearSearch),
        const SizedBox(height: 12),
        TpChips<_Status>(
          onHeader: true,
          padding: EdgeInsets.zero,
          value: _status,
          onChanged: (s) => setState(() {
            _status = s;
            _total = null;
          }),
          items: [for (final s in _Status.values) TpChipItem(s, s.label, count: countOf(s))],
        ),
      ]),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TpChips<FortunePlatform?>(
                padding: EdgeInsets.zero,
                value: _platform,
                onChanged: (v) => setState(() {
                  _platform = v;
                  _total = null;
                }),
                items: [
                  const TpChipItem<FortunePlatform?>(null, 'ทุกช่องทาง'),
                  for (final pf in FortunePlatform.values) TpChipItem<FortunePlatform?>(pf, pf.label),
                ],
              ),
              if (_package != null) ...[
                const SizedBox(height: 10),
                _ActiveFilter(
                  label: 'แพคเกจ: ${_package!.label}',
                  onClear: () => setState(() {
                    _package = null;
                    _total = null;
                  }),
                ),
              ],
            ]),
          ),
        ),
        TpPagedSliver<FortuneBill>(
          reloadKey: '${_status.key}|$_query|${_platform?.key}|${_package?.key}|$_reload',
          fetch: (page) => ref.read(fortuneRepositoryProvider).searchBills(
                status: _status.key,
                search: _query,
                platform: _platform,
                package: _package,
                page: page,
              ),
          onLoaded: (res) {
            if (mounted) setState(() => _total = res.total);
          },
          empty: _empty(),
          itemBuilder: (context, bill, _) => BillCard(
            bill: bill,
            onTap: () async {
              _focus.unfocus();
              if (await showBillSheet(context, bill)) {
                if (mounted) setState(() => _reload++);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    if (_query.isNotEmpty) {
      return TpEmpty(
        art: TpArt.emptyInbox,
        title: 'ไม่พบบิลที่ตรงกับ “$_query”',
        message: 'ลองค้นด้วยเลขบิลเต็ม หรือพิมพ์ # ตามด้วยรหัสบิล — แล้วตรวจตัวกรองสถานะและช่องทางอีกครั้ง',
        actionLabel: 'ล้างการค้นหาและตัวกรอง',
        onAction: _clearFilters,
        compact: true,
      );
    }
    if (_filtered || _status != _Status.all) {
      return TpEmpty(
        art: TpArt.emptyInbox,
        title: 'ไม่มีบิลตามตัวกรองนี้',
        message: 'สถานะ “${_status.label}”'
            '${_platform == null ? '' : ' · ${_platform!.label}'}'
            '${_package == null ? '' : ' · ${_package!.label}'}',
        actionLabel: _filtered ? 'ล้างตัวกรอง' : null,
        onAction: _filtered ? _clearFilters : null,
        compact: true,
      );
    }
    return const TpEmpty(
      art: TpArt.emptyInbox,
      title: 'ยังไม่มีบิลดูดวง',
      message: 'บิลจะขึ้นที่นี่เมื่อบอทแม่หมอออกบิลให้ลูกค้า',
      compact: true,
    );
  }
}

/// ช่องค้นหาบนหัวหน้าจอ (พื้นกระจก ให้กลืนกับหัวทั้งสองโหมด)
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: (v) {
        onSubmitted(v);
        focusNode.unfocus();
      },
      textInputAction: TextInputAction.search,
      inputFormatters: [LengthLimitingTextInputFormatter(100)],
      cursorColor: p.gold,
      style: TpType.body(15, p.onHeader, w: FontWeight.w500),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: p.glass,
        hintText: 'ชื่อลูกค้า · เลขบิล · #รหัส',
        hintStyle: TpType.body(14.5, p.onHeaderMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: p.onHeaderMuted),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'ล้างคำค้น',
                  icon: Icon(PhosphorIconsBold.xCircle, size: 19, color: p.onHeaderMuted),
                  onPressed: onClear,
                ),
        ),
        border: border(p.glassBorder),
        enabledBorder: border(p.glassBorder),
        focusedBorder: border(p.gold, 1.4),
      ),
    );
  }
}

/// ป้ายตัวกรองที่ใช้อยู่ + ปุ่มเอาออก
class _ActiveFilter extends StatelessWidget {
  const _ActiveFilter({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Material(
      color: p.goldSoft,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          HapticFeedback.selectionClick();
          onClear();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIconsBold.funnel, size: 13, color: p.goldText),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12.5, p.goldText, w: FontWeight.w600, height: 1.1)),
            ),
            const SizedBox(width: 6),
            Icon(PhosphorIconsBold.x, size: 13, color: p.goldText),
          ]),
        ),
      ),
    );
  }
}

/// แผ่นเลือกแพคเกจ — คืน (pkg: null) = ทุกแพคเกจ · ปิดแผ่นเฉย ๆ = null
class _PackageSheet extends StatelessWidget {
  const _PackageSheet({required this.scroll, required this.current});
  final ScrollController scroll;
  final FortunePackage? current;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    Widget row(FortunePackage? pkg, String title, String? subtitle) {
      final on = pkg == current;
      return TpRow(
        icon: pkg == null ? PhosphorIconsRegular.stack : PhosphorIconsRegular.cards,
        iconTone: on ? TpTone.gold : TpTone.navy,
        title: title,
        subtitle: subtitle,
        chevron: false,
        trailing: Icon(on ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
            size: 22, color: on ? p.gold : p.faint),
        onTap: () => Navigator.pop(context, (pkg: pkg)),
      );
    }

    return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
      Text('กรองตามแพคเกจ', style: TpType.h(18, p.textStrong)),
      const SizedBox(height: 2),
      Text('ใช้ร่วมกับสถานะ ช่องทาง และคำค้นได้', style: TpType.body(13, p.muted)),
      const SizedBox(height: 14),
      TpGroup(children: [
        row(null, 'ทุกแพคเกจ', null),
        for (final pkg in FortunePackage.values)
          row(pkg, pkg.label, pkg == FortunePackage.juntra ? 'บิลจากเว็บจันทรา (จันทราเก็บเงินเอง)' : null),
      ]),
    ]);
  }
}
