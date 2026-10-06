import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/api/paged.dart';
import '../../../shared/ui/tp.dart';
import '../../auth/data/models/admin_user.dart';
import '../../auth/providers/auth_controller.dart';
import '../data/finance_repository.dart';

/// หน้า "กระเป๋าเงิน" — ยอดเงินทั้งระบบ · ค้นหา/กรองสถานะ · แตะกระเป๋า → แผ่นจัดการ (ปรับยอด/ล็อก/ระงับ)
class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  WalletStatusFilter _status = WalletStatusFilter.all;
  int _reload = 0;
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
      _status = WalletStatusFilter.all;
      _found = null;
    });
  }

  /// มีการเปลี่ยนแปลงจากแผ่นจัดการ → รีโหลดรายการ + ยอดรวม
  void _changed() {
    if (!mounted) return;
    setState(() => _reload++);
    ref.invalidate(walletSystemStatsProvider);
  }

  Future<void> _refresh() async {
    setState(() => _reload++);
    try {
      ref.invalidate(walletSystemStatsProvider);
      await ref.read(walletSystemStatsProvider.future);
    } catch (_) {
      // การ์ดสรุปแสดง error เอง
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(walletSystemStatsProvider);
    final s = stats.valueOrNull;
    final filtered = _query.isNotEmpty || _status != WalletStatusFilter.all;

    return TpPage(
      title: 'กระเป๋าเงิน',
      subtitle: s == null ? 'กระเป๋าเงินสมาชิกทั้งระบบ' : 'สมาชิก ${TpFmt.count(s.totalWallets)} กระเป๋า',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _HeaderSearchField(
          controller: _search,
          hint: 'ชื่อ อีเมล หรือเลขกระเป๋า',
          onChanged: _onSearchChanged,
          onSubmitted: _applyQuery,
          onClear: () {
            _search.clear();
            _applyQuery('');
          },
        ),
        const SizedBox(height: 10),
        TpChips<WalletStatusFilter>(
          onHeader: true,
          padding: EdgeInsets.zero,
          value: _status,
          onChanged: (f) => setState(() {
            _status = f;
            _found = null;
          }),
          items: [for (final f in WalletStatusFilter.values) TpChipItem(f, f.label, count: s?.count(f))],
        ),
      ]),
      slivers: [
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _query.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _WalletHero(value: stats, onRetry: () => ref.invalidate(walletSystemStatsProvider)),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        SliverToBoxAdapter(child: _ResultLine(found: _found, query: _query, filtered: filtered, onClear: _clearAll)),
        TpPagedSliver<AdminWallet>(
          reloadKey: '${_status.key}-$_query-$_reload',
          fetch: (page) => ref.read(financeRepositoryProvider).wallets(page: page, search: _query, status: _status),
          onLoaded: (Paged<AdminWallet> p) {
            if (mounted) setState(() => _found = p.total);
          },
          empty: TpEmpty(
            art: TpArt.wallet,
            title: _query.isNotEmpty ? 'ไม่พบกระเป๋าที่ตรงกับคำค้น' : 'ไม่มีกระเป๋าในกลุ่มนี้',
            message: _query.isNotEmpty ? 'ลองค้นด้วยชื่อ อีเมล หรือเลขกระเป๋าบางส่วน' : null,
            actionLabel: filtered ? 'ล้างตัวกรอง' : null,
            onAction: filtered ? _clearAll : null,
            compact: true,
          ),
          itemBuilder: (context, w, _) => _WalletTile(
            w: w,
            onTap: () => showWalletSheet(context, w, onChanged: _changed),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════ สถานะกระเป๋า (สี/ป้าย) ═════════════════════

(String, TpTone) _stateStyle(AdminWallet w) => switch (w.state) {
      WalletState.active => ('ใช้งานปกติ', TpTone.success),
      WalletState.locked => (w.isTempLocked ? 'ล็อกชั่วคราว' : 'ล็อกอยู่', TpTone.warning),
      WalletState.suspended => ('ถูกระงับ', TpTone.danger),
      WalletState.inactive => ('ปิดใช้งาน', TpTone.neutral),
    };

/// ใครจัดการกระเป๋าได้ (ตรงกับ WalletController::canManageWallets)
///
/// ไม่รู้สิทธิ์ (ยังไม่โหลด / backend เก่าส่งรายการสิทธิ์ว่าง) = แสดงปุ่มแล้วให้ backend ตัดสิน (403 → ข้อความไทย)
bool _canManageWallets(AdminUser? a) {
  if (a == null || a.isSuperAdmin || a.permissions.isEmpty) return true;
  return a.can('manage_wallets') || a.can('view_all_wallets');
}

// ═════════════════════ การ์ดสรุป ═════════════════════

class _WalletHero extends StatelessWidget {
  const _WalletHero({required this.value, required this.onRetry});
  final AsyncValue<WalletSystemStats> value;
  final VoidCallback onRetry;

  static const _red = Color(0xFFFF8A7A);
  static const _line = Color(0x14FFFFFF);

  @override
  Widget build(BuildContext context) {
    if (!value.hasValue) {
      if (value.hasError) return _HeroError(error: value.error, onRetry: onRetry);
      return const TpHeroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TpSkeleton(width: 130, height: 12),
          SizedBox(height: 10),
          TpSkeleton(width: 200, height: 34),
          SizedBox(height: 8),
          TpSkeleton(width: 150, height: 11),
          SizedBox(height: 18),
          TpSkeleton(height: 38),
        ]),
      );
    }
    final s = value.requireValue;
    final held = s.lockedWallets + s.suspendedWallets;
    return TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('เงินในกระเป๋าทั้งระบบ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(13.5, TpPalette.heroMuted, w: FontWeight.w500)),
          ),
          _HeroChip(icon: PhosphorIconsBold.wallet, label: '${TpFmt.count(s.totalWallets)} กระเป๋า', color: TpPalette.heroGold),
        ]),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: TpFoilText(TpFmt.baht(s.totalBalance, decimals: true), style: TpType.money(36, Colors.white)),
        ),
        Text('เฉลี่ย ${TpFmt.baht(s.averageBalance)} ต่อกระเป๋า',
            style: TpType.body(12.5, const Color(0x8CFFFFFF), w: FontWeight.w500)),
        const SizedBox(height: 12),
        Container(height: 1, color: _line),
        const SizedBox(height: 11),
        Text('ยอดเงินเคลื่อนไหว (สำเร็จ)', style: TpType.body(11, const Color(0x73FFFFFF), w: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(children: [
          _HeroSplit(label: 'วันนี้', value: TpFmt.bahtCompact(s.todayVolume), sub: '${TpFmt.count(s.todayTransactions)} รายการ'),
          _HeroSplit(
            label: '30 วันล่าสุด',
            value: TpFmt.bahtCompact(s.monthlyVolume),
            sub: '${TpFmt.count(s.monthlyTransactions)} รายการ',
            divider: true,
          ),
          _HeroSplit(
            label: 'ล็อก · ระงับ',
            value: TpFmt.count(held),
            sub: held == 0 ? 'ไม่มี' : 'ล็อก ${s.lockedWallets} · ระงับ ${s.suspendedWallets}',
            color: held > 0 ? _red : null,
            divider: true,
          ),
        ]),
      ]),
    );
  }
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
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
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
            Text('โหลดยอดรวมไม่สำเร็จ', style: TpType.h(13.5, p.textStrong, w: FontWeight.w600)),
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
                ? 'กำลังโหลด…'
                : query.isNotEmpty
                    ? 'พบ ${TpFmt.count(found)} กระเป๋า จาก “$query”'
                    : (filtered ? 'พบ ${TpFmt.count(found)} กระเป๋า' : 'เปิดล่าสุด · ${TpFmt.count(found)} กระเป๋า'),
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

class _WalletTile extends StatelessWidget {
  const _WalletTile({required this.w, required this.onTap});
  final AdminWallet w;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final (label, tone) = _stateStyle(w);
    final normal = w.state == WalletState.active;
    return TpCard(
      onTap: onTap,
      accent: normal ? null : p.fg(tone),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        TpAvatar(name: w.ownerName, size: 44),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.ownerName,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
            Text(w.userEmail ?? w.shortAddress,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(12.5, p.muted)),
            const SizedBox(height: 5),
            Row(children: [
              if (!normal) ...[TpPill(label, tone: tone, dense: true), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  w.lastTransactionAt == null ? 'ยังไม่มีรายการ' : 'เคลื่อนไหว ${TpFmt.ago(w.lastTransactionAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(11.5, p.faint),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 118),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(TpFmt.baht(w.balance), style: TpType.money(17, w.balance > 0 ? p.goldText : p.faint)),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════ แผ่นจัดการกระเป๋า ═════════════════════

/// เปิดแผ่นจัดการกระเป๋า 1 ใบ (ใช้ทั้งหน้ากระเป๋าเงินและหน้ารายละเอียดสมาชิก)
///
/// [onChanged] ถูกเรียกทุกครั้งที่ยอด/สถานะเปลี่ยน (แม้ผู้ใช้ปิดแผ่นไประหว่างรอผล) — ใช้รีโหลดหน้าที่เปิดอยู่ข้างหลัง
Future<void> showWalletSheet(
  BuildContext context,
  AdminWallet wallet, {
  VoidCallback? onChanged,
  bool showOwnerLink = true,
}) =>
    tpShowSheet<void>(
      context,
      initial: 0.88,
      builder: (ctx, scroll) => _WalletSheet(
        initial: wallet,
        scroll: scroll,
        onChanged: onChanged,
        showOwnerLink: showOwnerLink,
      ),
    );

enum _NoticeKind { success, error, warning }

class _Notice {
  const _Notice(this.kind, this.text);
  final _NoticeKind kind;
  final String text;
}

class _WalletSheet extends ConsumerStatefulWidget {
  const _WalletSheet({required this.initial, required this.scroll, this.onChanged, this.showOwnerLink = true});
  final AdminWallet initial;
  final ScrollController scroll;
  final VoidCallback? onChanged;
  final bool showOwnerLink;

  @override
  ConsumerState<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends ConsumerState<_WalletSheet> {
  late AdminWallet _w = widget.initial;
  WalletDetail? _detail;
  bool _detailLoading = true;

  /// ปุ่มที่กำลังยิง API ('lock' / 'unlock' / 'suspend' / 'unsuspend') — null = ว่าง
  String? _busy;

  /// backend ตอบ 403 แล้ว → ซ่อนปุ่มจัดการ
  bool _denied = false;

  /// ข้อความแจ้งผลในแผ่น (toast ปกติจะโดนแผ่นนี้บัง)
  _Notice? _notice;

  // รายการเคลื่อนไหว (แบ่งหน้าเองในแผ่น)
  final List<WalletTxn> _tx = [];
  int _txPage = 0;
  int _txLast = 1;
  int _txTotal = 0;
  bool _txLoading = false;
  bool _txLoadedOnce = false;
  Object? _txError;
  int _txGen = 0;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadTx(reset: true);
  }

  Future<void> _loadDetail() async {
    setState(() => _detailLoading = true);
    try {
      final d = await ref.read(financeRepositoryProvider).wallet(_w.id);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _w = d.wallet;
        _detailLoading = false;
      });
    } catch (_) {
      // รายละเอียดเสริมโหลดไม่ได้ = ใช้ข้อมูลจากรายการไปก่อน (ไม่บังทั้งแผ่น)
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  Future<void> _loadTx({bool reset = false}) async {
    if (_txLoading && !reset) return;
    final gen = reset ? ++_txGen : _txGen;
    final page = reset ? 1 : _txPage + 1;
    setState(() {
      _txLoading = true;
      _txError = null;
    });
    try {
      final res = await ref.read(financeRepositoryProvider).transactions(walletId: _w.id, page: page);
      if (!mounted || gen != _txGen) return;
      setState(() {
        if (reset) _tx.clear();
        _tx.addAll(res.items);
        _txPage = res.page;
        _txLast = res.lastPage;
        _txTotal = res.total;
        _txLoading = false;
        _txLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted || gen != _txGen) return;
      setState(() {
        _txLoading = false;
        _txError = e;
      });
    }
  }

  /// หลังทำรายการสำเร็จ/ไม่แน่ใจ: แจ้งหน้าข้างหลัง → อัปเดตแผ่น → โหลดยอด/รายการใหม่
  void _afterChange(AdminWallet? updated, _Notice notice) {
    widget.onChanged?.call();
    if (!mounted) return;
    setState(() {
      if (updated != null) _w = updated;
      _notice = notice;
    });
    _loadDetail();
    _loadTx(reset: true);
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() {
      _busy = null;
      _notice = _Notice(_NoticeKind.error, tpErrorText(e));
      if (e is WalletForbiddenError) _denied = true;
    });
  }

  Future<void> _run(String key, Future<WalletActionResult> Function() action) async {
    if (_busy != null) return;
    setState(() {
      _busy = key;
      _notice = null;
    });
    try {
      final r = await action();
      if (!mounted) {
        widget.onChanged?.call();
        return;
      }
      setState(() => _busy = null);
      _afterChange(r.wallet, _Notice(_NoticeKind.success, r.message));
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _lock() async {
    final ok = await tpConfirm(
      context,
      title: 'ล็อกกระเป๋าของ ${_w.ownerName}?',
      message: 'สมาชิกจะโอน จ่าย และถอนเงินจากกระเป๋าไม่ได้ จนกว่าแอดมินจะปลดล็อก',
      confirmLabel: 'ล็อกกระเป๋า',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run('lock', () => ref.read(financeRepositoryProvider).lock(_w.id));
  }

  Future<void> _unlock() async {
    final ok = await tpConfirm(
      context,
      title: 'ปลดล็อกกระเป๋า?',
      message: 'สมาชิกจะกลับมาใช้กระเป๋าได้ตามปกติ และล้างจำนวนครั้งที่ใส่ PIN ผิด',
      confirmLabel: 'ปลดล็อก',
    );
    if (!ok || !mounted) return;
    await _run('unlock', () => ref.read(financeRepositoryProvider).unlock(_w.id));
  }

  Future<void> _suspend() async {
    final reason = await tpPrompt(
      context,
      title: 'ระงับกระเป๋าของ ${_w.ownerName}?',
      message: 'ใช้เมื่อพบความผิดปกติ — กระเป๋าจะใช้งานไม่ได้จนกว่าแอดมินจะยกเลิกการระงับ',
      hint: 'เหตุผล (บันทึกในประวัติระบบ)',
      confirmLabel: 'ระงับกระเป๋า',
      danger: true,
    );
    if (reason == null || !mounted) return;
    if (reason.length > 500) {
      setState(() => _notice = const _Notice(_NoticeKind.error, 'เหตุผลยาวเกิน 500 ตัวอักษร'));
      return;
    }
    await _run('suspend', () => ref.read(financeRepositoryProvider).suspend(_w.id, reason));
  }

  Future<void> _unsuspend() async {
    final reason = await tpPrompt(
      context,
      title: 'ยกเลิกการระงับ?',
      message: 'กระเป๋าจะกลับมาใช้งานได้ตามปกติ',
      hint: 'เหตุผลที่ยกเลิกการระงับ',
      confirmLabel: 'ยกเลิกระงับ',
    );
    if (reason == null || !mounted) return;
    if (reason.length > 500) {
      setState(() => _notice = const _Notice(_NoticeKind.error, 'เหตุผลยาวเกิน 500 ตัวอักษร'));
      return;
    }
    await _run('unsuspend', () => ref.read(financeRepositoryProvider).unsuspend(_w.id, reason));
  }

  Future<void> _openAdjust() async {
    if (_busy != null) return;
    setState(() => _notice = null);
    await tpShowSheet<void>(
      context,
      initial: 0.92,
      min: 0.6,
      builder: (ctx, scroll) => _AdjustSheet(
        wallet: _w,
        scroll: scroll,
        onDone: (updated, message) => _afterChange(updated, _Notice(_NoticeKind.success, message)),
        onUncertain: (message) => _afterChange(null, _Notice(_NoticeKind.warning, message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final w = _w;
    final d = _detail;
    final (label, tone) = _stateStyle(w);
    final admin = ref.watch(authControllerProvider).admin;
    final canManage = !_denied && _canManageWallets(admin);
    final now = DateTime.now();
    final lockedForever = w.lockedUntil != null && w.lockedUntil!.isAfter(now.add(const Duration(days: 365)));

    return Column(children: [
      Expanded(
        child: ListView(controller: widget.scroll, padding: const EdgeInsets.fromLTRB(18, 6, 18, 18), children: [
          // ── เจ้าของ ──
          Row(children: [
            TpAvatar(name: w.ownerName, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.ownerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.h(16, p.textStrong)),
                Text([w.userEmail, w.userPhone].whereType<String>().join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(12.5, p.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            TpPill(label, tone: tone),
          ]),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _NoticeBanner(notice: _notice!, onClose: () => setState(() => _notice = null)),
          ],
          const SizedBox(height: 18),
          // ── ยอดคงเหลือ ──
          Center(child: Text('ยอดคงเหลือ', style: TpType.body(12.5, p.muted))),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(TpFmt.baht(w.balance, decimals: true), style: TpType.money(38, p.goldText)),
            ),
          ),
          Center(
            child: Text('รับเข้ารวม ${TpFmt.bahtCompact(w.totalIncome)} · จ่ายออกรวม ${TpFmt.bahtCompact(w.totalExpense)}',
                textAlign: TextAlign.center, style: TpType.body(12.5, p.faint)),
          ),
          const SizedBox(height: 16),
          // ── เดือนนี้ ──
          TpCard(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: d == null && _detailLoading
                ? const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: TpSkeleton(height: 36))
                : Row(children: [
                    Expanded(
                      child: TpStat(
                        label: 'รับเข้าเดือนนี้',
                        value: TpFmt.bahtCompact(d?.monthIncome ?? 0),
                        color: p.success,
                        align: CrossAxisAlignment.center,
                      ),
                    ),
                    Container(width: 1, height: 32, color: p.divider),
                    Expanded(
                      child: TpStat(
                        label: 'จ่ายออกเดือนนี้',
                        value: TpFmt.bahtCompact(d?.monthExpense ?? 0),
                        color: p.danger,
                        align: CrossAxisAlignment.center,
                      ),
                    ),
                    Container(width: 1, height: 32, color: p.divider),
                    Expanded(
                      child: TpStat(
                        label: 'รายการทั้งหมด',
                        value: TpFmt.count(d?.transactionsCount ?? _txTotal),
                        align: CrossAxisAlignment.center,
                      ),
                    ),
                  ]),
          ),
          const SizedBox(height: 12),
          // ── ข้อมูลกระเป๋า ──
          TpCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(children: [
              if (w.address.isNotEmpty) _CopyRow(label: 'เลขกระเป๋า', value: w.address),
              TpKv('สกุลเงิน', w.currency ?? 'THB'),
              TpKv('PIN สองชั้น', w.twoFactorEnabled ? 'เปิดอยู่' : 'ปิดอยู่',
                  valueColor: w.twoFactorEnabled ? p.success : p.muted),
              if (w.failedAttempts > 0) TpKv('ใส่ PIN ผิด', '${w.failedAttempts} ครั้ง', valueColor: p.warning),
              if (w.state == WalletState.locked && w.lockedUntil != null)
                TpKv('ล็อกถึง',
                    lockedForever
                        ? 'จนกว่าแอดมินจะปลด'
                        : '${TpFmt.shortDate(w.lockedUntil!)} ${TpFmt.time(w.lockedUntil!)}',
                    valueColor: p.warning),
              TpKv('เคลื่อนไหวล่าสุด', w.lastTransactionAt == null ? 'ยังไม่มีรายการ' : TpFmt.ago(w.lastTransactionAt)),
              if (w.createdAt != null) TpKv('เปิดกระเป๋าเมื่อ', TpFmt.shortDate(w.createdAt!)),
            ]),
          ),
          if (widget.showOwnerLink && w.userId != null) ...[
            const SizedBox(height: 6),
            Center(
              child: TpButton.ghost('ดูข้อมูลสมาชิก', icon: PhosphorIconsRegular.userCircle, onPressed: () {
                final router = GoRouter.of(context);
                final uid = w.userId;
                Navigator.of(context).pop();
                router.push('/users/$uid');
              }),
            ),
          ],
          // ── รายการเคลื่อนไหว ──
          TpSection(
            'รายการเคลื่อนไหว',
            trailing: _txLoadedOnce && _txTotal > 0 ? TpPill('${TpFmt.count(_txTotal)} รายการ', dense: true) : null,
          ),
          _txBody(p),
        ]),
      ),
      if (canManage)
        TpBottomBar(child: _actions(w))
      else
        TpBottomBar(
          child: Row(children: [
            Icon(PhosphorIconsRegular.lockSimple, size: 18, color: p.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text('บัญชีของคุณดูได้อย่างเดียว — ปรับยอด ล็อก หรือระงับ ต้องมีสิทธิ์จัดการกระเป๋าเงิน',
                  style: TpType.body(12.5, p.muted)),
            ),
          ]),
        ),
    ]);
  }

  Widget _txBody(TpPalette p) {
    if (!_txLoadedOnce) {
      if (_txError != null) {
        return TpErrorView(error: _txError, onRetry: () => _loadTx(reset: true), compact: true);
      }
      return const TpSkeletonList(count: 3, itemHeight: 66);
    }
    if (_tx.isEmpty) {
      return const TpCard(
        padding: EdgeInsets.zero,
        child: TpEmpty(art: TpArt.emptyInbox, title: 'ยังไม่มีรายการเคลื่อนไหว', compact: true),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TpGroup(children: [for (final t in _tx) _TxnRow(t: t)]),
      if (_txError != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(child: TpButton.ghost('โหลดต่อไม่สำเร็จ · ลองใหม่', onPressed: _loadTx)),
        )
      else if (_txPage < _txLast)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: TpButton.ghost('ดูรายการก่อนหน้า', icon: PhosphorIconsRegular.clockCounterClockwise, loading: _txLoading, onPressed: _loadTx),
          ),
        ),
    ]);
  }

  Widget _actions(AdminWallet w) {
    final busy = _busy != null;
    final small = <Widget>[];
    switch (w.state) {
      case WalletState.suspended:
        small.add(TpButton.outline('ยกเลิกการระงับ',
            icon: PhosphorIconsRegular.arrowCounterClockwise,
            height: 44,
            fontSize: 13.5,
            loading: _busy == 'unsuspend',
            onPressed: busy ? null : _unsuspend));
      case WalletState.locked:
      case WalletState.inactive:
        small.add(TpButton.outline(w.state == WalletState.inactive ? 'เปิดใช้งาน' : 'ปลดล็อก',
            icon: PhosphorIconsRegular.lockSimpleOpen,
            height: 44,
            fontSize: 13.5,
            loading: _busy == 'unlock',
            onPressed: busy ? null : _unlock));
        small.add(TpButton.danger('ระงับ',
            icon: PhosphorIconsRegular.prohibit,
            height: 44,
            fontSize: 13.5,
            loading: _busy == 'suspend',
            onPressed: busy ? null : _suspend));
      case WalletState.active:
        small.add(TpButton.outline('ล็อก',
            icon: PhosphorIconsRegular.lockSimple,
            height: 44,
            fontSize: 13.5,
            loading: _busy == 'lock',
            onPressed: busy ? null : _lock));
        small.add(TpButton.danger('ระงับ',
            icon: PhosphorIconsRegular.prohibit,
            height: 44,
            fontSize: 13.5,
            loading: _busy == 'suspend',
            onPressed: busy ? null : _suspend));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TpButton('ปรับยอดเงิน', icon: PhosphorIconsBold.plusMinus, onPressed: busy ? null : _openAdjust),
      const SizedBox(height: 10),
      Row(children: [
        for (var i = 0; i < small.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: small[i]),
        ],
      ]),
    ]);
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.notice, required this.onClose});
  final _Notice notice;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final (tone, icon) = switch (notice.kind) {
      _NoticeKind.success => (TpTone.success, PhosphorIconsFill.checkCircle),
      _NoticeKind.error => (TpTone.danger, PhosphorIconsFill.warningCircle),
      _NoticeKind.warning => (TpTone.warning, PhosphorIconsFill.warning),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: p.soft(tone), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: p.fg(tone))),
        const SizedBox(width: 8),
        Expanded(child: Text(notice.text, style: TpType.body(13, p.text, w: FontWeight.w500))),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(PhosphorIconsRegular.x, size: 15, color: p.muted),
          ),
        ),
      ]),
    );
  }
}

/// แถวข้อมูลที่แตะเพื่อคัดลอกได้ — เปลี่ยนไอคอนเป็นติ๊กแทน toast (toast จะโดนแผ่นบัง)
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
          SizedBox(width: 92, child: Text(widget.label, style: TpType.body(13, p.muted))),
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

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.t});
  final WalletTxn t;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final credit = t.isCredit;
    final color = credit ? p.success : p.danger;
    final done = t.status.isEmpty || t.status == 'completed';
    final sub = t.note ?? t.transactionId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TpIconTile(credit ? PhosphorIconsBold.arrowDownLeft : PhosphorIconsBold.arrowUpRight,
            tone: credit ? TpTone.success : TpTone.danger, size: 36),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(t.typeLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.h(14, p.textStrong, w: FontWeight.w600)),
              ),
              if (!done) ...[
                const SizedBox(width: 6),
                TpPill(t.statusLabel,
                    tone: t.status == 'failed' || t.status == 'cancelled' ? TpTone.danger : TpTone.warning, dense: true),
              ],
            ]),
            if (sub != null)
              Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TpType.body(12.5, p.muted)),
            Text(t.createdAt == null ? '-' : '${TpFmt.shortDate(t.createdAt!)} ${TpFmt.time(t.createdAt!)}',
                style: TpType.body(11.5, p.faint)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${credit ? '+' : '−'}${TpFmt.baht(t.amount)}', style: TpType.money(14.5, done ? color : p.muted)),
          if (t.balanceAfter != null)
            Text('คงเหลือ ${TpFmt.baht(t.balanceAfter)}', style: TpType.body(11, p.faint)),
        ]),
      ]),
    );
  }
}

// ═════════════════════ แผ่นปรับยอด (เงินเข้า/ออกจริง) ═════════════════════

class _AdjustSheet extends ConsumerStatefulWidget {
  const _AdjustSheet({
    required this.wallet,
    required this.scroll,
    required this.onDone,
    required this.onUncertain,
  });

  final AdminWallet wallet;
  final ScrollController scroll;

  /// สำเร็จ — เรียกแม้แผ่นถูกปิดไประหว่างรอ (ให้หน้าข้างหลังรีโหลด)
  final void Function(AdminWallet? updated, String message) onDone;

  /// เน็ตขาดระหว่างส่ง — ไม่รู้ผล ต้องให้แอดมินตรวจรายการก่อนทำซ้ำ
  final void Function(String message) onUncertain;

  @override
  ConsumerState<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends ConsumerState<_AdjustSheet> {
  late bool _credit = widget.wallet.canCredit;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _error;

  static final _amountPattern = RegExp(r'^\d{0,9}(\.\d{0,2})?$');

  /// ยอดเกินนี้ (บาท) เตือนให้ตรวจเลขศูนย์
  static const _bigCents = 100000 * 100;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  int get _balanceCents => (widget.wallet.balance * 100).round();

  /// จำนวนเงินเป็นสตางค์ (คำนวณจากสตริง ไม่ผ่าน double — กันปัดเศษ)
  int? get _cents {
    final m = RegExp(r'^(\d{0,9})(?:\.(\d{0,2}))?$').firstMatch(_amount.text.trim());
    if (m == null) return null;
    final whole = (m.group(1) ?? '').isEmpty ? 0 : int.parse(m.group(1)!);
    final frac = (m.group(2) ?? '').padRight(2, '0');
    return whole * 100 + int.parse(frac);
  }

  static String _centsText(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

  /// ข้อความว่าทำไมยังยืนยันไม่ได้ (null = พร้อม)
  String? get _blocker {
    final c = _cents;
    if (_credit && !widget.wallet.canCredit) return 'กระเป๋าถูกล็อกหรือระงับ — เพิ่มเงินไม่ได้จนกว่าจะปลด';
    if (c == null || c <= 0) return 'กรอกจำนวนเงิน';
    if (!_credit && c > _balanceCents) return 'หักได้ไม่เกินยอดคงเหลือ ${TpFmt.baht(widget.wallet.balance, decimals: true)}';
    if (_reason.text.trim().isEmpty) return 'ระบุเหตุผลก่อนยืนยัน';
    return null;
  }

  void _setAmount(int cents) {
    final t = _centsText(cents).replaceAll(RegExp(r'\.00$'), '');
    _amount.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
    setState(() => _error = null);
  }

  Future<bool> _submit() async {
    final c = _cents;
    if (_blocker != null || c == null) return false;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final amount = '${_credit ? '' : '-'}${_centsText(c)}';
    try {
      final r = await ref
          .read(financeRepositoryProvider)
          .adjust(widget.wallet.id, amount: amount, reason: _reason.text.trim());
      final after = r.wallet?.balance;
      final msg = after == null ? r.message : '${r.message} — ยอดใหม่ ${TpFmt.baht(after, decimals: true)}';
      widget.onDone(r.wallet, msg);
      if (mounted) Navigator.of(context).pop();
      return true;
    } on UncertainActionError catch (e) {
      widget.onUncertain(e.message);
      if (mounted) Navigator.of(context).pop();
      return false;
    } catch (e) {
      if (mounted) setState(() => _error = tpErrorText(e));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final w = widget.wallet;
    final c = _cents ?? 0;
    final afterCents = _credit ? _balanceCents + c : _balanceCents - c;
    final blocker = _blocker;
    final verb = _credit ? 'เพิ่ม' : 'หัก';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(children: [
        Expanded(
          child: ListView(
            controller: widget.scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            children: [
              Row(children: [
                const Tp3D(TpArt.wallet, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ปรับยอดเงิน', style: TpType.h(17, p.textStrong)),
                    Text('กระเป๋าของ ${w.ownerName}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(12.5, p.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              TpCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Text('ยอดปัจจุบัน', style: TpType.body(13, p.muted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(TpFmt.baht(w.balance, decimals: true), style: TpType.money(17, p.textStrong)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _ModeCard(
                    selected: _credit,
                    enabled: w.canCredit,
                    tone: TpTone.success,
                    icon: PhosphorIconsBold.plus,
                    title: 'เพิ่มเงิน',
                    subtitle: 'เข้ากระเป๋า',
                    onTap: () => setState(() {
                      _credit = true;
                      _error = null;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeCard(
                    selected: !_credit,
                    enabled: true,
                    tone: TpTone.danger,
                    icon: PhosphorIconsBold.minus,
                    title: 'หักเงิน',
                    subtitle: 'ออกจากกระเป๋า',
                    onTap: () => setState(() {
                      _credit = false;
                      _error = null;
                    }),
                  ),
                ),
              ]),
              if (!w.canCredit) ...[
                const SizedBox(height: 8),
                Text('กระเป๋านี้ถูกล็อกหรือระงับ — เพิ่มเงินได้หลังปลดเท่านั้น (หักเงินทำได้)',
                    style: TpType.body(12, p.warning, w: FontWeight.w500)),
              ],
              const SizedBox(height: 16),
              Text('จำนวนเงินที่จะ$verb (บาท)', style: TpType.body(13, p.muted, w: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  TextInputFormatter.withFunction((old, nu) {
                    final t = nu.text.replaceAll(',', '.');
                    if (!_amountPattern.hasMatch(t)) return old;
                    return nu.copyWith(text: t);
                  }),
                ],
                style: TpType.money(24, _credit ? p.success : p.danger),
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TpType.money(24, p.faint, w: FontWeight.w500),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 6),
                    child: Text(_credit ? '+฿' : '−฿', style: TpType.money(22, _credit ? p.success : p.danger)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final b in const [100, 500, 1000, 5000])
                  _QuickChip(label: TpFmt.baht(b), onTap: () => _setAmount(b * 100)),
                if (!_credit && _balanceCents > 0)
                  _QuickChip(label: 'หักทั้งหมด', onTap: () => _setAmount(_balanceCents)),
              ]),
              const SizedBox(height: 16),
              Text('เหตุผล (บันทึกในประวัติกระเป๋า)', style: TpType.body(13, p.muted, w: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                style: TpType.body(14.5, p.text),
                decoration: const InputDecoration(hintText: 'เช่น ชดเชยยอดที่ระบบตัดซ้ำ บิล R12345'),
              ),
              const SizedBox(height: 4),
              // ── สรุปก่อนยืนยัน ──
              TpCard(
                goldBorder: c > 0,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(children: [
                  Row(children: [
                    Text('ยอดหลังปรับ', style: TpType.body(13, p.muted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          c <= 0 ? '-' : TpFmt.baht(afterCents / 100, decimals: true),
                          style: TpType.money(19, c <= 0 ? p.faint : (afterCents < 0 ? p.danger : p.textStrong)),
                        ),
                      ),
                    ),
                  ]),
                  if (c > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('$verb ${TpFmt.baht(c / 100, decimals: true)}',
                          style: TpType.body(12, _credit ? p.success : p.danger, w: FontWeight.w600)),
                    ),
                ]),
              ),
              if (c >= _bigCents) ...[
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(PhosphorIconsFill.warning, size: 16, color: p.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('ยอดสูงผิดปกติ — ตรวจจำนวนหลักให้แน่ใจก่อนเลื่อนยืนยัน',
                        style: TpType.body(12.5, p.warning, w: FontWeight.w600)),
                  ),
                ]),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                _NoticeBanner(
                  notice: _Notice(_NoticeKind.error, _error!),
                  onClose: () => setState(() => _error = null),
                ),
              ],
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(PhosphorIconsRegular.info, size: 15, color: p.faint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('เงินเข้า/ออกทันทีและย้อนกลับไม่ได้ ถ้าผิดต้องปรับยอดกลับด้วยมือ',
                      style: TpType.body(12, p.faint)),
                ),
              ]),
            ],
          ),
        ),
        TpBottomBar(
          child: TpSlideToConfirm(
            label: blocker ?? 'เลื่อนเพื่อ$verb ${TpFmt.baht(c / 100, decimals: true)}',
            enabled: blocker == null,
            onConfirmed: _submit,
          ),
        ),
      ]),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.enabled,
    required this.tone,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final TpTone tone;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final fg = p.fg(tone);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled && !selected
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: selected ? p.soft(tone) : p.cardSolid,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? fg : p.border, width: selected ? 1.5 : 1),
            ),
            child: Row(children: [
              TpIconTile(icon, tone: tone, size: 34),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.h(14, selected ? fg : p.textStrong)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(11.5, p.muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Material(
      color: p.cardSolid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11), side: BorderSide(color: p.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label, style: TpType.money(13, p.text, w: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ═════════════════════ ช่องค้นหาบนหัว ═════════════════════

/// ช่องค้นหาแบบกระจกบนหัวหน้าจอ
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
