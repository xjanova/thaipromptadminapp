import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/update/app_version_provider.dart';
import '../../../core/update/update_checker.dart';
import '../../../core/update/update_dialog.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/data/models/admin_user.dart';
import '../../auth/providers/auth_controller.dart';

/// Settings / Profile Screen
///
/// Layout (per design handoff screens-3.jsx):
/// - Hero gradient (slate → indigo → purple) + 2 orbs
/// - Clay avatar + crown badge + SUPER ADMIN chip
/// - Floating stats card (3 cols)
/// - Sections: บัญชีของฉัน · แอดมิน · ระบบ (with toggle/chevron/badge per row)
/// - Logout (red pill)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authControllerProvider).admin;
    final versionAsync = ref.watch(appVersionStringProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
        children: [
          _heroSection(admin),
          Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _floatingStats(),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel('บัญชีของฉัน'),
                  _section([
                    _RowItem(
                      icon: Icons.person_outline,
                      label: 'ข้อมูลส่วนตัว',
                      sub: admin?.email ?? '—',
                      hue: 200,
                    ),
                    _RowItem(
                      icon: Icons.shield_outlined,
                      label: 'ความปลอดภัย',
                      sub: admin?.twoFactorEnabled == true
                          ? '2FA เปิดใช้งาน'
                          : '2FA ปิด',
                      hue: 130,
                      badge: admin?.twoFactorEnabled == true ? 'ปลอดภัย' : null,
                    ),
                    _RowItem(
                      icon: Icons.lock_outline,
                      label: 'เปลี่ยนรหัสผ่าน',
                      sub: 'อัปเดต 30 วันก่อน',
                      hue: 280,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _sectionLabel('แอดมิน'),
                  _section([
                    _RowItem(
                      icon: Icons.group_outlined,
                      label: 'จัดการผู้ดูแล',
                      sub: '8 คน · 3 ระดับ',
                      hue: 25,
                    ),
                    _RowItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'สิทธิ์ & บทบาท',
                      sub: 'Roles · Permissions',
                      hue: 280,
                    ),
                    _RowItem(
                      icon: Icons.history_outlined,
                      label: 'Activity Logs',
                      sub: '1,284 events',
                      hue: 200,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _sectionLabel('ระบบ'),
                  _section([
                    _RowItem(
                      icon: Icons.notifications_none,
                      label: 'การแจ้งเตือน',
                      sub: 'Push · Email · SMS',
                      hue: 35,
                      toggle: _notifications,
                      onToggle: (v) => setState(() => _notifications = v),
                    ),
                    _RowItem(
                      icon: Icons.dark_mode_outlined,
                      label: 'โหมดมืด',
                      sub: 'อัตโนมัติตามระบบ',
                      hue: 220,
                      toggle: _darkMode,
                      onToggle: (v) => setState(() => _darkMode = v),
                    ),
                    _RowItem(
                      icon: Icons.system_update_outlined,
                      label: 'ตรวจสอบอัปเดต',
                      sub: versionAsync.maybeWhen(
                          data: (v) => 'v$v', orElse: () => '...'),
                      hue: 280,
                      onTap: () => _checkUpdate(),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _logoutButton(),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      versionAsync.maybeWhen(
                          data: (v) => 'Thaiprompt Admin v$v',
                          orElse: () => 'Thaiprompt Admin'),
                      style: const TextStyle(
                          color: Color(0x66FFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Sections
  // ────────────────────────────────────────────────────────────

  Widget _heroSection(AdminUser? admin) {
    final name = admin?.name ?? 'Admin';
    final email = admin?.email ?? '—';
    final role = admin?.role ?? 'admin';
    final isSuper = admin?.isSuperAdmin ?? false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF4338CA), Color(0xFF7C3AED)],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment(-1, -1),
          end: Alignment(1, 1),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Glow orb top-right
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purpleStart.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.65],
                  ),
                ),
              ),
            ),
            // Glow orb bottom-left
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.cyanStart.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.65],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'โปรไฟล์ & ตั้งค่า',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _doLogout,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.logout,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClayBall(
                          size: 78,
                          hue: 45,
                          saturation: 0.95,
                          lightness: 0.65,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7C2D12),
                            ),
                          ),
                        ),
                        if (isSuper)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.goldStart,
                                    Color(0xFFF97316)
                                  ],
                                ),
                                border: Border.all(
                                    color: const Color(0xFF1E293B), width: 3),
                              ),
                              child: const Icon(Icons.workspace_premium,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            email,
                            style: const TextStyle(
                                color: Color(0xCCFFFFFF), fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          if (isSuper)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.goldStart,
                                    Color(0xFFF97316)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.workspace_premium,
                                      color: Color(0xFF7C2D12), size: 10),
                                  SizedBox(width: 4),
                                  Text(
                                    'SUPER ADMIN',
                                    style: TextStyle(
                                      color: Color(0xFF7C2D12),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.purpleStart
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _floatingStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _statColumn('2,847', 'การกระทำ', const Color(0xFF6366F1)),
          _statDivider(),
          _statColumn('1,294', 'อนุมัติ', AppColors.success),
          _statDivider(),
          _statColumn('24', 'เซสชัน', AppColors.pinkStart),
        ],
      ),
    );
  }

  Widget _statColumn(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 30,
        color: const Color(0xFFF1F5F9),
      );

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _section(List<_RowItem> items) {
    return GlassCard(
      fillOpacity: 0.06,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _renderRow(items[i]),
            if (i != items.length - 1)
              Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 1,
                indent: 60,
              ),
          ],
        ],
      ),
    );
  }

  Widget _renderRow(_RowItem it) {
    return InkWell(
      onTap: it.onTap ??
          (it.onToggle == null
              ? () {}
              : () => it.onToggle!(!(it.toggle ?? false))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: HSLColor.fromAHSL(1, it.hue, 0.85, 0.6)
                    .toColor()
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                it.icon,
                color: HSLColor.fromAHSL(1, it.hue, 0.85, 0.7).toColor(),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    it.sub,
                    style: const TextStyle(
                        color: Color(0x99FFFFFF), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (it.badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  it.badge!,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (it.toggle != null)
              _Toggle(value: it.toggle!, onChanged: it.onToggle!)
            else
              const Icon(Icons.chevron_right,
                  color: Color(0x66FFFFFF), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return GestureDetector(
      onTap: _doLogout,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.error.withValues(alpha: 0.3),
              AppColors.error.withValues(alpha: 0.18),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppColors.error, size: 16),
            SizedBox(width: 8),
            Text(
              'ออกจากระบบ',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title: const Text('ออกจากระบบ?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'คุณต้องการออกจากระบบใช่หรือไม่?',
          style: TextStyle(color: Color(0xD9FFFFFF)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออกจากระบบ',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _checkUpdate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await ref.read(updateCheckerProvider).check();
    if (!mounted) return;
    Navigator.of(context).pop();

    if (result.hasUpdate && result.release != null) {
      await showUpdateAvailableDialog(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('คุณใช้เวอร์ชันล่าสุดแล้ว (${result.current})'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

// ────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────

class _RowItem {
  _RowItem({
    required this.icon,
    required this.label,
    required this.sub,
    required this.hue,
    this.badge,
    this.toggle,
    this.onToggle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final double hue;
  final String? badge;
  final bool? toggle;
  final void Function(bool)? onToggle;
  final VoidCallback? onTap;
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          gradient: value
              ? const LinearGradient(
                  colors: [AppColors.purpleStart, AppColors.pinkStart],
                )
              : null,
          color: value ? null : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              top: 2,
              left: value ? 20 : 2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
