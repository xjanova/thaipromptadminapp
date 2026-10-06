import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/pin_manager.dart';
import '../../../core/update/update_checker.dart';
import '../../../core/update/update_dialog.dart';
import '../../../shared/ui/tp.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/ui/pin_entry_screen.dart';

/// หน้า "บัญชี" — โปรไฟล์ · หน้าตาแอป · ความปลอดภัย · อัปเดต · ออกจากระบบ
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _bioSupported = false;
  bool _bioEnabled = false;
  bool _bioBusy = false;
  bool _checkingUpdate = false;
  bool _loggingOut = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bio = ref.read(biometricServiceProvider);
    final supported = await bio.isSupported();
    final enabled = await bio.isEnabled();
    final pkg = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _bioSupported = supported;
      _bioEnabled = enabled;
      _version = 'v${pkg.version} (${pkg.buildNumber})';
    });
  }

  Future<void> _setupOrChangePin(bool hasPin) async {
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PinEntryScreen(mode: hasPin ? PinScreenMode.change : PinScreenMode.setup, canCancel: true),
    ));
    if (ok == true && mounted) {
      ref.read(appLockControllerProvider.notifier).onPinSet();
      tpToast(context, hasPin ? 'เปลี่ยน PIN แล้ว' : 'ตั้ง PIN แล้ว · แอปจะล็อกเมื่อไม่ได้ใช้เกิน 5 นาที',
          kind: TpToastKind.success);
    }
  }

  Future<void> _clearPin() async {
    final yes = await tpConfirm(
      context,
      title: 'ปิดการล็อกด้วย PIN?',
      message: 'ใครก็ตามที่ถือเครื่องนี้จะเปิดแอปแอดมินได้ทันที (ลายนิ้วมือจะถูกปิดด้วย)',
      confirmLabel: 'ปิด PIN',
      danger: true,
    );
    if (!yes || !mounted) return;
    // ยืนยันตัวตนด้วย PIN เดิมก่อนปิด
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PinEntryScreen(mode: PinScreenMode.unlock, canCancel: true),
    ));
    if (ok != true || !mounted) return;
    await ref.read(pinManagerProvider).clearPin();
    await ref.read(biometricServiceProvider).setEnabled(false);
    ref.read(appLockControllerProvider.notifier).onPinCleared();
    if (!mounted) return;
    setState(() => _bioEnabled = false);
    tpToast(context, 'ปิดการล็อกด้วย PIN แล้ว');
  }

  Future<void> _toggleBio(bool on) async {
    setState(() => _bioBusy = true);
    final bio = ref.read(biometricServiceProvider);
    if (on) {
      final ok = await bio.authenticate(reason: 'ยืนยันเพื่อเปิดปลดล็อกด้วยลายนิ้วมือ', biometricOnly: true);
      if (!ok) {
        if (mounted) {
          setState(() => _bioBusy = false);
          tpToast(context, 'ยืนยันลายนิ้วมือไม่สำเร็จ', kind: TpToastKind.error);
        }
        return;
      }
    }
    await bio.setEnabled(on);
    if (!mounted) return;
    setState(() {
      _bioEnabled = on;
      _bioBusy = false;
    });
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    final result = await ref.read(updateCheckerProvider).check();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    if (result.hasUpdate) {
      await showUpdateAvailableDialog(context, result);
    } else {
      tpToast(context, 'ใช้เวอร์ชันล่าสุดอยู่แล้ว (${result.current.label})', kind: TpToastKind.success);
    }
  }

  Future<void> _logout({bool all = false}) async {
    final yes = await tpConfirm(
      context,
      title: all ? 'ออกจากระบบทุกเครื่อง?' : 'ออกจากระบบ?',
      message: all
          ? 'token ของแอปแอดมินทุกเครื่องจะถูกเพิกถอน ต้องเข้าสู่ระบบใหม่ทั้งหมด'
          : 'ต้องเข้าสู่ระบบด้วยรหัสผ่านหรือสแกน QR ใหม่อีกครั้ง',
      confirmLabel: 'ออกจากระบบ',
      danger: true,
    );
    if (!yes || !mounted) return;
    setState(() => _loggingOut = true);
    if (all) {
      try {
        await ref.read(apiClientProvider).post<dynamic>('/auth/logout-all');
      } catch (_) {
        // ล้มก็ยังออกจากเครื่องนี้ต่อ
      }
    }
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final admin = ref.watch(authControllerProvider).admin;
    final look = ref.watch(tpLookProvider);
    final hasPin = ref.watch(appLockControllerProvider).hasPin;

    return TpPage(
      title: 'บัญชีของฉัน',
      subtitle: 'โปรไฟล์ ความปลอดภัย และหน้าตาแอป',
      showMark: true,
      onRefresh: () => ref.read(authControllerProvider.notifier).refreshMe(),
      slivers: [
        SliverList.list(children: [
          // ── โปรไฟล์ ──
          TpCard(
            goldBorder: true,
            child: Row(children: [
              TpAvatar(name: admin?.name, size: 58, gold: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(admin?.name ?? '-', style: TpType.h(17, p.textStrong), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(admin?.email ?? '', style: TpType.body(13, p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    TpPill(admin?.roleLabel ?? 'ผู้ดูแล', tone: TpTone.gold, icon: PhosphorIconsFill.crown, dense: true),
                    TpPill(admin?.twoFactorEnabled == true ? '2FA เปิดอยู่' : '2FA ปิดอยู่',
                        tone: admin?.twoFactorEnabled == true ? TpTone.success : TpTone.warning,
                        icon: PhosphorIconsBold.shieldCheck,
                        dense: true),
                  ]),
                ]),
              ),
            ]),
          ),

          // ── หน้าตาแอป ──
          const TpSection('หน้าตาแอป'),
          Row(children: [
            Expanded(
              child: _LookCard(
                look: TpLook.midnight,
                selected: look == TpLook.midnight,
                title: 'มิดไนท์โกลด์',
                subtitle: 'มืด ทองเรือง',
                onTap: () => ref.read(tpLookProvider.notifier).set(TpLook.midnight),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LookCard(
                look: TpLook.royal,
                selected: look == TpLook.royal,
                title: 'รอยัลงาช้าง',
                subtitle: 'กรมท่า พื้นงาช้าง',
                onTap: () => ref.read(tpLookProvider.notifier).set(TpLook.royal),
              ),
            ),
          ]),

          // ── ความปลอดภัย ──
          const TpSection('ความปลอดภัยของเครื่องนี้'),
          TpGroup(children: [
            TpRow(
              icon: PhosphorIconsRegular.password,
              iconTone: TpTone.gold,
              title: hasPin ? 'เปลี่ยนรหัส PIN' : 'ตั้งรหัส PIN',
              subtitle: hasPin ? 'ล็อกอัตโนมัติเมื่อไม่ได้ใช้เกิน 5 นาที' : 'แนะนำ — กันคนอื่นเปิดแอปแอดมินจากเครื่องนี้',
              trailing: hasPin ? null : const TpPill('ยังไม่ตั้ง', tone: TpTone.warning, dense: true),
              onTap: () => _setupOrChangePin(hasPin),
            ),
            if (hasPin && _bioSupported)
              TpSwitchRow(
                icon: PhosphorIconsRegular.fingerprint,
                title: 'ปลดล็อกด้วยลายนิ้วมือ',
                subtitle: 'ใช้แทน PIN ได้ทุกครั้ง',
                value: _bioEnabled,
                busy: _bioBusy,
                onChanged: _toggleBio,
              ),
            if (hasPin)
              TpRow(
                icon: PhosphorIconsRegular.lockSimpleOpen,
                iconTone: TpTone.danger,
                title: 'ปิดการล็อกด้วย PIN',
                titleStyle: TpType.h(14.5, p.danger, w: FontWeight.w600),
                onTap: _clearPin,
              ),
          ]),

          // ── แอป ──
          const TpSection('แอป'),
          TpGroup(children: [
            TpRow(
              icon: PhosphorIconsRegular.arrowsClockwise,
              iconTone: TpTone.info,
              title: 'ตรวจหาอัปเดต',
              subtitle: 'ดาวน์โหลดจาก GitHub Releases · เวอร์ชันนี้ $_version',
              trailing: _checkingUpdate
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: _checkingUpdate ? null : _checkUpdate,
            ),
            TpRow(
              icon: PhosphorIconsRegular.devices,
              iconTone: TpTone.navy,
              title: 'ออกจากระบบทุกเครื่อง',
              subtitle: 'เพิกถอน token แอปแอดมินทั้งหมด',
              onTap: _loggingOut ? null : () => _logout(all: true),
            ),
          ]),
          const SizedBox(height: 18),
          TpButton.danger('ออกจากระบบ', icon: PhosphorIconsBold.signOut, loading: _loggingOut, onPressed: () => _logout()),
          const SizedBox(height: 14),
          Center(child: Text('ไทยพร้อม แอดมิน $_version', style: TpType.body(12, p.faint))),
        ]),
      ],
    );
  }
}

/// การ์ดเลือกธีมพร้อมภาพย่อจำลองหน้าจอ
class _LookCard extends StatelessWidget {
  const _LookCard({
    required this.look,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final TpLook look;
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final preview = TpPalette.of(look);
    return TpCard(
      padding: const EdgeInsets.all(10),
      goldBorder: selected,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ภาพย่อ: หัว + การ์ดฮีโร่ + การ์ด 2 ใบ
        Container(
          height: 92,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: preview.bg, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Container(
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: preview.header),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 8),
              child: Image.asset('assets/images/brand/tp-mark.webp', width: 14, cacheWidth: 42),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: preview.bg,
                  borderRadius: preview.bodyOverlap > 0 ? const BorderRadius.vertical(top: Radius.circular(10)) : null,
                ),
                padding: const EdgeInsets.all(6),
                child: Column(children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: TpPalette.heroCard),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(width: 30, height: 5, color: const Color(0xFFF0C96A)),
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    Expanded(child: Container(height: 20, decoration: BoxDecoration(color: preview.cardSolid, borderRadius: BorderRadius.circular(5)))),
                    const SizedBox(width: 5),
                    Expanded(child: Container(height: 20, decoration: BoxDecoration(color: preview.cardSolid, borderRadius: BorderRadius.circular(5)))),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TpType.h(13.5, p.textStrong)),
              Text(subtitle, style: TpType.body(11.5, p.muted)),
            ]),
          ),
          Icon(selected ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
              color: selected ? p.gold : p.faint, size: 20),
        ]),
      ]),
    );
  }
}
