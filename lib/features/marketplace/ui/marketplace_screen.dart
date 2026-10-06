import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/api/paged.dart';
import '../../../shared/ui/tp.dart';
import '../data/marketplace_repository.dart';

/// หน้า "ร้านค้า" — ยอดขายจากแพลตฟอร์มพันธมิตร (Lazada / Shopee / TikTok) · บัญชีที่เชื่อม · ออเดอร์แบ่งหน้า
///
/// อ่านอย่างเดียว — ข้อมูลซิงก์มาจากแพลตฟอร์ม (backend ไม่มี endpoint สินค้า/แก้สถานะในแอป)
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  MarketPeriod _period = MarketPeriod.month;
  String _status = '';
  int _reload = 0;
  int? _found;

  bool _searchOpen = false;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  String _query = '';

  /// สรุปช่วงก่อนหน้า — แสดงค้างไว้ระหว่างโหลดช่วงใหม่ (ไม่กระพริบเป็นโครง)
  MarketplaceDashboard? _lastDash;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_searchOpen) {
      _debounce?.cancel();
      _search.clear();
      setState(() {
        _searchOpen = false;
        if (_query.isNotEmpty) {
          _query = '';
          _found = null;
        }
      });
      FocusScope.of(context).unfocus();
    } else {
      setState(() => _searchOpen = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
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

  Future<void> _refresh() async {
    setState(() => _reload++);
    ref.invalidate(marketplaceStatusCountsProvider);
    try {
      ref.invalidate(marketplaceDashboardProvider(_period));
      await ref.read(marketplaceDashboardProvider(_period).future);
    } catch (_) {
      // การ์ดสรุปแสดง error เอง
    }
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(marketplaceDashboardProvider(_period));
    if (dash.hasValue) _lastDash = dash.requireValue;
    final d = dash.valueOrNull ?? (dash.isLoading ? _lastDash : null);
    final counts = ref.watch(marketplaceStatusCountsProvider).valueOrNull;

    return TpPage(
      title: 'ร้านค้า',
      subtitle: dash.valueOrNull == null
          ? 'ออเดอร์จากแพลตฟอร์มพันธมิตร'
          : 'ออเดอร์${_period.label} ${TpFmt.count(dash.valueOrNull!.ordersCount)} รายการ',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      actions: [
        TpGlassButton(
          icon: _searchOpen ? PhosphorIconsRegular.x : PhosphorIconsRegular.magnifyingGlass,
          gold: _searchOpen,
          tooltip: _searchOpen ? 'ปิดการค้นหา' : 'ค้นหาออเดอร์',
          onTap: _toggleSearch,
        ),
      ],
      headerBottom: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_searchOpen) ...[
          _HeaderSearchField(
            controller: _search,
            focusNode: _searchFocus,
            hint: 'เลขออเดอร์ หรือชื่อลูกค้า',
            onChanged: _onSearchChanged,
            onSubmitted: _applyQuery,
            onClear: () {
              _search.clear();
              _applyQuery('');
            },
          ),
          const SizedBox(height: 10),
        ],
        TpChips<String>(
          onHeader: true,
          padding: EdgeInsets.zero,
          value: _status,
          onChanged: (v) => setState(() {
            _status = v;
            _found = null;
          }),
          items: [
            TpChipItem('', 'ทั้งหมด', count: counts?['']),
            for (final s in MarketOrderStatus.values) TpChipItem(s.key, s.label, count: counts?[s.key]),
          ],
        ),
      ]),
      slivers: [
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _query.isEmpty
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _MarketHero(
                      dash: d,
                      loading: dash.isLoading,
                      error: d == null && dash.hasError ? dash.error : null,
                      period: _period,
                      onPeriod: (p) => setState(() => _period = p),
                      onRetry: () => ref.invalidate(marketplaceDashboardProvider(_period)),
                    ),
                    if (d != null && d.platforms.isNotEmpty) _Platforms(platforms: d.platforms),
                  ])
                : const SizedBox(width: double.infinity),
          ),
        ),
        SliverToBoxAdapter(
          child: TpSection(
            _query.isNotEmpty ? 'ผลการค้นหา' : 'ออเดอร์ล่าสุด',
            trailing: _found == null ? null : TpPill('${TpFmt.count(_found)} รายการ', dense: true),
          ),
        ),
        TpPagedSliver<MarketplaceOrder>(
          reloadKey: '$_status-$_query-$_reload',
          fetch: (page) => ref.read(marketplaceRepositoryProvider).orders(page: page, status: _status, search: _query),
          onLoaded: (Paged<MarketplaceOrder> p) {
            if (mounted) setState(() => _found = p.total);
          },
          empty: TpEmpty(
            art: TpArt.store,
            title: _query.isNotEmpty
                ? 'ไม่พบออเดอร์ที่ตรงกับคำค้น'
                : (_status.isEmpty ? 'ยังไม่มีออเดอร์' : 'ไม่มีออเดอร์ในสถานะนี้'),
            message: _query.isNotEmpty
                ? 'ลองค้นด้วยเลขออเดอร์บางส่วน หรือชื่อลูกค้า'
                : (_status.isEmpty ? 'ออเดอร์จะซิงก์เข้ามาเองเมื่อมีคนซื้อผ่านลิงก์พันธมิตร' : null),
            compact: true,
          ),
          itemBuilder: (context, o, _) => _OrderTile(o: o, onTap: () => _showOrderSheet(context, o)),
        ),
      ],
    );
  }
}

// ═════════════════════ โทนสี/ป้าย ═════════════════════

TpTone _statusTone(MarketOrderStatus? s) => switch (s) {
      MarketOrderStatus.pending => TpTone.warning,
      MarketOrderStatus.processing || MarketOrderStatus.shipped => TpTone.info,
      MarketOrderStatus.delivered || MarketOrderStatus.completed => TpTone.success,
      MarketOrderStatus.cancelled || MarketOrderStatus.refunded => TpTone.danger,
      null => TpTone.neutral,
    };

TpTone _paymentTone(String? v) => switch ((v ?? '').toLowerCase()) {
      'paid' || 'settled' => TpTone.success,
      'pending' || 'unpaid' => TpTone.warning,
      'refunded' || 'failed' || 'cancelled' || 'canceled' => TpTone.danger,
      _ => TpTone.neutral,
    };

TpTone _platformTone(String? code) {
  final c = (code ?? '').toLowerCase();
  if (c.contains('lazada')) return TpTone.info;
  if (c.contains('shopee')) return TpTone.warning;
  if (c.contains('tiktok')) return TpTone.navy;
  return TpTone.gold;
}

/// ไอคอนร้านในกล่องสีตามแพลตฟอร์ม
class _PlatformMark extends StatelessWidget {
  const _PlatformMark({required this.code, this.size = 40});
  final String? code;
  final double size;

  @override
  Widget build(BuildContext context) => TpIconTile(PhosphorIconsFill.storefront, tone: _platformTone(code), size: size);
}

// ═════════════════════ การ์ดสรุป ═════════════════════

class _MarketHero extends StatelessWidget {
  const _MarketHero({
    required this.dash,
    required this.loading,
    required this.error,
    required this.period,
    required this.onPeriod,
    required this.onRetry,
  });

  final MarketplaceDashboard? dash;
  final bool loading;
  final Object? error;
  final MarketPeriod period;
  final ValueChanged<MarketPeriod> onPeriod;
  final VoidCallback onRetry;

  static const _line = Color(0x14FFFFFF);

  @override
  Widget build(BuildContext context) {
    final d = dash;
    return TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PeriodSwitch(value: period, onChanged: onPeriod),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Text('ยอดขายที่ชำระแล้ว · ${period.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(13.5, TpPalette.heroMuted, w: FontWeight.w500)),
          ),
          if (loading && d != null)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: TpPalette.heroGold),
            ),
        ]),
        const SizedBox(height: 2),
        if (d == null && error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const Icon(PhosphorIconsRegular.warningCircle, size: 18, color: Color(0xFFFF8A7A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tpErrorText(error),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: TpType.body(13, TpPalette.heroText)),
              ),
              TextButton(
                onPressed: onRetry,
                child: Text('ลองใหม่', style: TpType.body(13, TpPalette.heroGold, w: FontWeight.w600)),
              ),
            ]),
          )
        else if (d == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: TpSkeleton(width: 190, height: 34),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: TpFoilText(TpFmt.baht(d.totalRevenue), style: TpType.money(38, Colors.white)),
          ),
        const SizedBox(height: 12),
        Container(height: 1, color: _line),
        const SizedBox(height: 11),
        Row(children: [
          _HeroSplit(label: 'ออเดอร์', value: d == null ? '-' : TpFmt.count(d.ordersCount)),
          _HeroSplit(
            label: 'คอมรอจ่าย',
            value: d == null ? '-' : TpFmt.bahtCompact(d.pendingCommissions),
            color: d != null && d.pendingCommissions > 0 ? TpPalette.heroGold : null,
            divider: true,
          ),
          _HeroSplit(label: 'สินค้าที่ขาย', value: d == null ? '-' : TpFmt.count(d.productsCount), divider: true),
        ]),
        if (d?.generatedAt != null) ...[
          const SizedBox(height: 10),
          Text('อัปเดต ${TpFmt.time(d!.generatedAt!)} · คอมรอจ่ายและสินค้านับทั้งระบบ',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(10.5, const Color(0x61FFFFFF))),
        ],
      ]),
    );
  }

}

/// ตัวเลือกช่วงเวลาแบบแคปซูลบนการ์ดฮีโร่ (มืดเสมอ)
class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({required this.value, required this.onChanged});
  final MarketPeriod value;
  final ValueChanged<MarketPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(children: [
        for (final p in MarketPeriod.values)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (p == value) return;
                HapticFeedback.selectionClick();
                onChanged(p);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: p == value
                      ? const LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF3DC9B), Color(0xFFD9B25C)])
                      : null,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(p.label,
                    maxLines: 1,
                    style: TpType.body(12.5, p == value ? TpPalette.onGold : const Color(0x8CFFFFFF), w: FontWeight.w600, height: 1.1)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _HeroSplit extends StatelessWidget {
  const _HeroSplit({required this.label, required this.value, this.color, this.divider = false});
  final String label;
  final String value;
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
          ]),
        ),
      );
}

/// บัญชีแพลตฟอร์มที่เชื่อมอยู่ + สถานะซิงก์
class _Platforms extends StatelessWidget {
  const _Platforms({required this.platforms});
  final List<MarketplacePlatform> platforms;

  @override
  Widget build(BuildContext context) {
    final stale = platforms.where((p) => p.syncStale).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TpSection(
        'บัญชีที่เชื่อมต่อ',
        trailing: stale > 0
            ? TpPill('ซิงก์ค้าง $stale', tone: TpTone.warning, dense: true)
            : TpPill('${platforms.length} บัญชี', dense: true),
      ),
      TpGroup(children: [
        for (final pl in platforms)
          TpRow(
            leading: _PlatformMark(code: pl.platform),
            title: pl.name,
            subtitle: [
              marketPlatformLabel(pl.platform),
              pl.lastSyncAt == null ? 'ยังไม่เคยซิงก์' : 'ซิงก์ล่าสุด ${TpFmt.ago(pl.lastSyncAt)}',
            ].join(' · '),
            chevron: false,
            trailing: pl.syncStale
                ? const TpPill('ซิงก์ค้าง', tone: TpTone.warning, icon: PhosphorIconsBold.warning, dense: true)
                : const TpPill('ปกติ', tone: TpTone.success, icon: PhosphorIconsBold.check, dense: true),
          ),
      ]),
    ]);
  }
}

// ═════════════════════ ออเดอร์ ═════════════════════

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.o, required this.onTap});
  final MarketplaceOrder o;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final st = o.status;
    final tone = _statusTone(st);
    final pay = marketPaymentLabel(o.paymentStatus);
    final accent = switch (st) {
      MarketOrderStatus.pending => p.warning,
      MarketOrderStatus.cancelled || MarketOrderStatus.refunded => p.danger,
      _ => null,
    };
    return TpCard(
      onTap: onTap,
      accent: accent,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PlatformMark(code: o.platform),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(o.orderNumber,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.money(14.5, p.textStrong, w: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              Text(TpFmt.ago(o.orderedAt), style: TpType.body(11.5, p.faint)),
            ]),
            Text('${o.customerName ?? 'ไม่ระบุชื่อลูกค้า'} · ${marketPlatformLabel(o.platform)}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(12.5, p.muted)),
            const SizedBox(height: 7),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 5, children: [
                  TpPill(o.statusLabel, tone: tone, dense: true),
                  if (pay != null) TpPill(pay, tone: _paymentTone(o.paymentStatus), dense: true),
                ]),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(TpFmt.baht(o.totalAmount), style: TpType.money(16, p.goldText)),
                  ),
                  if (o.commissionAmount > 0)
                    Text('คอม ${TpFmt.baht(o.commissionAmount)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(11.5, p.success, w: FontWeight.w600)),
                ]),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

Future<void> _showOrderSheet(BuildContext context, MarketplaceOrder o) => tpShowSheet<void>(
      context,
      initial: 0.74,
      min: 0.4,
      builder: (ctx, scroll) => _OrderSheet(o: o, scroll: scroll),
    );

class _OrderSheet extends StatelessWidget {
  const _OrderSheet({required this.o, required this.scroll});
  final MarketplaceOrder o;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final st = o.status;
    final pay = marketPaymentLabel(o.paymentStatus);
    final ful = marketFulfillmentLabel(o.fulfillmentStatus);
    final at = o.orderedAt;
    return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(18, 6, 18, 28), children: [
      Row(children: [
        _PlatformMark(code: o.platform, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.orderNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.money(16, p.textStrong)),
            Text(marketPlatformLabel(o.platform), style: TpType.body(12.5, p.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        TpPill(o.statusLabel, tone: _statusTone(st)),
      ]),
      const SizedBox(height: 20),
      Center(child: Text('ยอดออเดอร์', style: TpType.body(12.5, p.muted))),
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(TpFmt.baht(o.totalAmount, decimals: true), style: TpType.money(36, p.goldText)),
        ),
      ),
      if (o.commissionAmount > 0)
        Center(
          child: Text('คอมมิชชัน ${TpFmt.baht(o.commissionAmount, decimals: true)}',
              style: TpType.body(13, p.success, w: FontWeight.w600)),
        ),
      const SizedBox(height: 18),
      TpCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(children: [
          _CopyRow(label: 'เลขออเดอร์', value: o.orderNumber),
          if (o.externalOrderId != null) _CopyRow(label: 'เลขจากแพลตฟอร์ม', value: o.externalOrderId!),
          TpKv('ลูกค้า', o.customerName ?? 'ไม่ระบุชื่อ'),
          TpKv('แพลตฟอร์ม', marketPlatformLabel(o.platform)),
          TpKv('สั่งเมื่อ', at == null ? '-' : '${TpFmt.shortDate(at)} ${TpFmt.time(at)}'),
        ]),
      ),
      const SizedBox(height: 12),
      TpCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(children: [
          TpKv('สถานะออเดอร์', o.statusLabel, valueColor: p.fg(_statusTone(st))),
          TpKv('การชำระเงิน', pay ?? 'ไม่มีข้อมูล', valueColor: pay == null ? p.faint : p.fg(_paymentTone(o.paymentStatus))),
          TpKv('การจัดส่ง', ful ?? 'ไม่มีข้อมูล', valueColor: ful == null ? p.faint : null),
          if (st == null && o.orderStatus.isNotEmpty) TpKv('รหัสสถานะจากแพลตฟอร์ม', o.orderStatus, mono: true),
        ]),
      ),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(PhosphorIconsRegular.info, size: 15, color: p.faint),
        const SizedBox(width: 6),
        Expanded(
          child: Text('ข้อมูลซิงก์มาจากแพลตฟอร์มอัตโนมัติ — ในแอปดูได้อย่างเดียว แก้สถานะได้ที่หน้าเว็บแอดมิน',
              style: TpType.body(12, p.faint)),
        ),
      ]),
    ]);
  }
}

/// แถวข้อมูลที่แตะเพื่อคัดลอก — เปลี่ยนไอคอนเป็นติ๊ก (toast จะโดนแผ่นบัง)
class _CopyRow extends StatefulWidget {
  const _CopyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  State<_CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends State<_CopyRow> {
  bool _copied = false;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.value));
    HapticFeedback.selectionClick();
    _t?.cancel();
    setState(() => _copied = true);
    _t = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(width: 108, child: Text(widget.label, style: TpType.body(13, p.muted))),
          Expanded(
            child: Text(widget.value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TpType.money(13.5, p.textStrong, w: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _copied
                ? Icon(PhosphorIconsBold.check, key: const ValueKey(1), size: 16, color: p.success)
                : Icon(PhosphorIconsRegular.copy, key: const ValueKey(0), size: 16, color: p.goldText),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════ ช่องค้นหาบนหัว ═════════════════════

class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
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
        focusNode: focusNode,
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
