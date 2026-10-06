import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/ui/wallets_screen.dart' show showWalletSheet;
import '../data/users_repository.dart';

/// หน้ารายละเอียดสมาชิก (`/users/:id`) — โปรไฟล์ · ติดต่อ · กระเป๋าเงิน · สถานะ · ประวัติดูดวง
///
/// อ่านอย่างเดียว (backend ไม่มีปุ่มระงับ/แก้ไขสมาชิกในแอป) — ยกเว้นกระเป๋าเงินที่เปิดแผ่นจัดการได้
class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, this.userId = 0});
  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId <= 0) {
      return const TpPage(
        title: 'ข้อมูลสมาชิก',
        back: true,
        bottomSpace: 32,
        slivers: [
          SliverToBoxAdapter(
            child: TpEmpty(art: TpArt.members, title: 'ไม่พบสมาชิกนี้', message: 'ลิงก์ไม่ถูกต้องหรือสมาชิกถูกลบไปแล้ว'),
          ),
        ],
      );
    }
    final user = ref.watch(userDetailProvider(userId));
    final u = user.valueOrNull;

    Future<void> refresh() async {
      ref.invalidate(userReadingsProvider(userId));
      ref.invalidate(adminsOnlineProvider);
      try {
        ref.invalidate(userDetailProvider(userId));
        await ref.read(userDetailProvider(userId).future);
      } catch (_) {
        // แสดง error ผ่าน TpAsync อยู่แล้ว
      }
    }

    return TpPage(
      title: u?.displayName ?? 'ข้อมูลสมาชิก',
      subtitle: 'รหัสสมาชิก #$userId',
      back: true,
      bottomSpace: 32,
      onRefresh: refresh,
      slivers: [
        SliverToBoxAdapter(
          child: TpAsync<AdminListUser>(
            value: user,
            onRetry: () => ref.invalidate(userDetailProvider(userId)),
            loading: const _DetailSkeleton(),
            data: (u) => _UserBody(user: u),
          ),
        ),
        if (u != null) SliverToBoxAdapter(child: _Readings(userId: userId)),
      ],
    );
  }
}

class _UserBody extends ConsumerWidget {
  const _UserBody({required this.user});
  final AdminListUser user;

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    tpToast(context, 'คัดลอก$labelแล้ว');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.tp;
    final u = user;
    final online = u.isAdmin ? ref.watch(adminsOnlineProvider).valueOrNull : null;
    final presence = online == null ? null : online[u.id];
    final place = [u.city, u.country].whereType<String>().join(', ');

    final contact = <Widget>[
      if (u.email.isNotEmpty)
        TpRow(
          icon: PhosphorIconsRegular.envelopeSimple,
          title: u.email,
          subtitle: 'อีเมล · แตะเพื่อคัดลอก',
          chevron: false,
          trailing: Icon(PhosphorIconsRegular.copy, size: 17, color: p.goldText),
          onTap: () => _copy(context, 'อีเมล', u.email),
        ),
      if (u.phone != null)
        TpRow(
          icon: PhosphorIconsRegular.phone,
          iconTone: TpTone.success,
          title: u.phone!,
          subtitle: 'เบอร์โทร · แตะเพื่อคัดลอก',
          titleStyle: TpType.money(15, p.textStrong, w: FontWeight.w600),
          chevron: false,
          trailing: Icon(PhosphorIconsRegular.copy, size: 17, color: p.goldText),
          onTap: () => _copy(context, 'เบอร์โทร', u.phone!),
        ),
      if (u.referralCode != null)
        TpRow(
          icon: PhosphorIconsRegular.hash,
          iconTone: TpTone.gold,
          title: u.referralCode!,
          subtitle: 'รหัสแนะนำ · แตะเพื่อคัดลอก',
          titleStyle: TpType.money(15, p.textStrong, w: FontWeight.w600),
          chevron: false,
          trailing: Icon(PhosphorIconsRegular.copy, size: 17, color: p.goldText),
          onTap: () => _copy(context, 'รหัสแนะนำ', u.referralCode!),
        ),
      if (place.isNotEmpty)
        TpRow(icon: PhosphorIconsRegular.mapPin, iconTone: TpTone.info, title: place, subtitle: 'ที่อยู่ (ระดับเมือง)', chevron: false),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ProfileCard(user: u, presence: presence),
      const TpSection('ข้อมูลติดต่อ'),
      if (contact.isEmpty)
        TpCard(child: Text('สมาชิกนี้ยังไม่มีข้อมูลติดต่อในระบบ', style: TpType.body(13.5, p.muted)))
      else
        TpGroup(children: contact),
      const TpSection('กระเป๋าเงิน'),
      _WalletCard(user: u),
      const TpSection('สถานะบัญชี'),
      TpCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(children: [
          TpKv('สถานะ', u.isBlocked ? 'ถูกระงับ' : 'ใช้งานปกติ', valueColor: u.isBlocked ? p.danger : p.success),
          if (u.isBlocked && u.blockedAt != null) TpKv('ระงับเมื่อ', _when(u.blockedAt!)),
          TpKv('ระดับ', u.rankName ?? 'ยังไม่มีระดับ'),
          if (u.roleLabel != null) TpKv('บทบาท', u.roleLabel!, valueColor: p.goldText),
          TpKv('สมัครเมื่อ', u.createdAt == null ? '-' : _when(u.createdAt!)),
          TpKv('เข้าใช้ล่าสุด', u.lastLoginAt == null ? 'ไม่มีข้อมูล' : TpFmt.ago(u.lastLoginAt)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('ยืนยันตัวตน', style: TpType.body(13, p.muted)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: [
                  _VerifyPill('โทรศัพท์', u.phoneVerified),
                  _VerifyPill('LINE', u.lineVerified),
                  _VerifyPill('Facebook', u.facebookVerified),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  static String _when(DateTime d) => '${TpFmt.shortDate(d)} ${TpFmt.time(d)}';
}

class _VerifyPill extends StatelessWidget {
  const _VerifyPill(this.label, this.ok);
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) => TpPill(
        label,
        tone: ok ? TpTone.success : TpTone.neutral,
        icon: ok ? PhosphorIconsBold.check : PhosphorIconsBold.minus,
        dense: true,
      );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, this.presence});
  final AdminListUser user;
  final AdminPresence? presence;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final u = user;
    final role = u.roleLabel;
    return TpCard(
      goldBorder: true,
      padding: const EdgeInsets.all(18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TpAvatar(name: u.displayName, size: 62, gold: true, online: presence?.isOnline ?? false),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TpType.h(18, p.textStrong)),
            if (u.contactLine.isNotEmpty)
              Text(u.contactLine, maxLines: 2, overflow: TextOverflow.ellipsis, style: TpType.body(13, p.muted)),
            const SizedBox(height: 9),
            Wrap(spacing: 6, runSpacing: 6, children: [
              TpPill(u.rankName ?? 'ยังไม่มีระดับ',
                  tone: u.rankName == null ? TpTone.neutral : TpTone.gold, icon: PhosphorIconsFill.crown, dense: true),
              if (u.isBlocked) const TpPill('ถูกระงับ', tone: TpTone.danger, icon: PhosphorIconsBold.prohibit, dense: true),
              if (role != null) TpPill(role, tone: TpTone.navy, icon: PhosphorIconsFill.shieldCheck, dense: true),
              if (presence != null)
                presence!.isOnline
                    ? const TpPill('ออนไลน์อยู่', tone: TpTone.success, icon: PhosphorIconsFill.circle, dense: true)
                    : TpPill(
                        presence!.lastSeenAt == null ? 'ยังไม่เคยใช้แอป' : 'ใช้แอปล่าสุด ${TpFmt.ago(presence!.lastSeenAt)}',
                        tone: TpTone.neutral,
                        dense: true,
                      ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// การ์ดกระเป๋าเงิน — แตะเพื่อเปิดแผ่นจัดการ (ค้นกระเป๋าจาก user_id ก่อน)
class _WalletCard extends ConsumerStatefulWidget {
  const _WalletCard({required this.user});
  final AdminListUser user;

  @override
  ConsumerState<_WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends ConsumerState<_WalletCard> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final page = await ref.read(financeRepositoryProvider).wallets(userId: widget.user.id, perPage: 1);
      if (!mounted) return;
      setState(() => _busy = false);
      if (page.items.isEmpty) {
        tpToast(context, 'ไม่พบกระเป๋าเงินของสมาชิกนี้ในระบบ');
        return;
      }
      final id = widget.user.id;
      await showWalletSheet(context, page.items.first, showOwnerLink: false, onChanged: () {
        if (mounted) ref.invalidate(userDetailProvider(id));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final u = widget.user;
    if (!u.hasWallet) {
      return TpCard(
        child: Row(children: [
          const Opacity(opacity: 0.55, child: Tp3D(TpArt.wallet, size: 44)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ยังไม่มีกระเป๋าเงิน', style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text('สมาชิกนี้ยังไม่ได้เปิดใช้กระเป๋าเงินในระบบ', style: TpType.body(12.5, p.muted)),
            ]),
          ),
        ]),
      );
    }
    final bal = u.walletBalance ?? 0;
    return TpCard(
      goldBorder: true,
      onTap: _busy ? null : _open,
      child: Row(children: [
        const Tp3D(TpArt.wallet, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ยอดคงเหลือ', style: TpType.body(12.5, p.muted)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(TpFmt.baht(bal, decimals: true), style: TpType.money(22, bal > 0 ? p.goldText : p.text)),
            ),
            if (u.walletAddress != null)
              Text(u.walletAddress!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(11.5, p.faint)),
          ]),
        ),
        const SizedBox(width: 8),
        if (_busy)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('จัดการ', style: TpType.body(13, p.goldText, w: FontWeight.w600)),
            Icon(PhosphorIconsBold.caretRight, size: 13, color: p.goldText),
          ]),
      ]),
    );
  }
}

// ═════════════════════ ประวัติดูดวง ═════════════════════

class _Readings extends ConsumerWidget {
  const _Readings({required this.userId});
  final int userId;

  static const _limit = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.tp;
    final readings = ref.watch(userReadingsProvider(userId));
    final n = readings.valueOrNull?.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TpSection(
        'ประวัติดูดวง',
        trailing: n == null || n == 0 ? null : TpPill(n >= _limit ? 'ล่าสุด $n รายการ' : '$n รายการ', dense: true),
      ),
      TpAsync<List<UserReading>>(
        value: readings,
        compactError: true,
        onRetry: () => ref.invalidate(userReadingsProvider(userId)),
        loading: const TpSkeletonList(count: 3, itemHeight: 70),
        data: (list) {
          if (list.isEmpty) {
            return const TpCard(
              padding: EdgeInsets.zero,
              child: TpEmpty(
                art: TpArt.tarot,
                title: 'ยังไม่เคยดูดวง',
                message: 'เมื่อสมาชิกดูดวงผ่านบอท ประวัติจะขึ้นที่นี่',
                compact: true,
              ),
            );
          }
          return Column(children: [
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReadingTile(r: r, onTap: () => context.push('/chat/${r.id}')),
              ),
            if (list.length >= _limit)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('แสดง $_limit รายการล่าสุด', textAlign: TextAlign.center, style: TpType.body(12, p.faint)),
              ),
          ]);
        },
      ),
    ]);
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.r, required this.onTap});
  final UserReading r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final when = r.createdAt == null ? null : '${TpFmt.shortDate(r.createdAt!)} ${TpFmt.time(r.createdAt!)}';
    final meta = ['R${r.id}', if (when != null) when].join(' · ');
    final price = r.pricePaid ?? 0;
    return TpCard(
      onTap: onTap,
      accent: r.isPaid ? p.gold : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Tp3D(TpArt.tarot, size: 40),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.firstQuestion ?? 'ไม่มีคำถามในบันทึก',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TpType.h(14, r.firstQuestion == null ? p.muted : p.textStrong, w: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.money(12, p.faint, w: FontWeight.w500)),
            if (r.questions.length > 1 || r.rating != null) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (r.questions.length > 1) TpPill('${r.questions.length} คำถาม', dense: true),
                if (r.rating != null)
                  TpPill('ให้คะแนน ${r.rating}/5', tone: TpTone.gold, icon: PhosphorIconsFill.star, dense: true),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (r.isPaid && price > 0)
            Text(TpFmt.baht(price), style: TpType.money(15, p.goldText))
          else
            TpPill(r.isPaid ? 'จ่ายแล้ว' : 'ยังไม่จ่าย', tone: r.isPaid ? TpTone.success : TpTone.neutral, dense: true),
          const SizedBox(height: 8),
          Icon(PhosphorIconsRegular.chatCircleText, size: 18, color: p.goldText),
        ]),
      ]),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TpCard(
          padding: EdgeInsets.all(18),
          child: Row(children: [
            TpSkeleton(width: 62, height: 62, radius: 31),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TpSkeleton(width: 150, height: 16),
                SizedBox(height: 8),
                TpSkeleton(width: 190, height: 11),
                SizedBox(height: 12),
                TpSkeleton(width: 120, height: 18),
              ]),
            ),
          ]),
        ),
        SizedBox(height: 22),
        TpSkeletonList(count: 3, itemHeight: 64),
      ]);
}
