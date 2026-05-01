import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_controller.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/qr_scanner_screen.dart';
import '../../features/auth/ui/verify_2fa_screen.dart';
import '../../features/ai/ui/ai_management_screen.dart';
import '../../features/dashboard/ui/dashboard_screen.dart';
import '../../features/finance/ui/finance_screen.dart';
import '../../features/modules/ui/modules_hub_screen.dart';
import '../../main.dart' show rootNavKey;
import '../theme/app_colors.dart';
import '../update/app_version_provider.dart';
import '../update/update_checker.dart';
import '../update/update_dialog.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    navigatorKey: rootNavKey,
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final isAuth = auth.isAuthenticated;
      final loc = state.matchedLocation;

      final goingToAuth = loc.startsWith('/auth');

      if (!isAuth && !goingToAuth) return '/auth/login';
      if (isAuth && goingToAuth) return '/dashboard';
      return null;
    },
    routes: [
      // Auth (no shell)
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/qr', builder: (_, __) => const QrScannerScreen()),
      GoRoute(
        path: '/auth/2fa',
        builder: (_, state) =>
            Verify2FAScreen(challengeToken: state.extra as String),
      ),

      // Authenticated shell
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
              path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(
              path: '/modules', builder: (_, __) => const ModulesHubScreen()),
          GoRoute(path: '/finance', builder: (_, __) => const FinanceScreen()),
          GoRoute(path: '/ai', builder: (_, __) => const AiManagementScreen()),
          GoRoute(
              path: '/analytics',
              builder: (_, __) => const _ComingSoonPage(label: 'Analytics')),
          GoRoute(path: '/settings', builder: (_, __) => const _SettingsPage()),
        ],
      ),
    ],
  );
});

/// Bridge Riverpod → GoRouter via a Listenable
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(this._ref) {
    _sub = _ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }
  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(label)),
        body: Center(
            child: Text('$label — กำลังพัฒนา',
                style: const TextStyle(color: Colors.white))),
      );
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(authControllerProvider).admin;
    final versionAsync = ref.watch(appVersionStringProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          if (admin != null) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.purpleStart,
                child: Text(
                  admin.name.isNotEmpty ? admin.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              title:
                  Text(admin.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(admin.email,
                  style: const TextStyle(color: Color(0xCCFFFFFF))),
              trailing: admin.isSuperAdmin
                  ? const Chip(
                      label: Text('SUPER',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800)))
                  : null,
            ),
            const Divider(color: Color(0x33FFFFFF)),
          ],

          // ── เวอร์ชันแอป + เช็คอัปเดท ──
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white),
            title: const Text('เวอร์ชันแอป',
                style: TextStyle(color: Colors.white)),
            subtitle: Text(
              versionAsync.maybeWhen(
                  data: (v) => v, orElse: () => 'กำลังโหลด...'),
              style: const TextStyle(color: Color(0xCCFFFFFF)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update, color: Colors.white),
            title: const Text('ตรวจสอบอัปเดท',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'เช็ค GitHub Releases ตอนนี้',
              style: TextStyle(color: Color(0xCCFFFFFF)),
            ),
            onTap: () => _manualCheckUpdate(context, ref),
          ),

          const Divider(color: Color(0x33FFFFFF)),

          // ── ออกจากระบบ ──
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('ออกจากระบบ',
                style: TextStyle(color: AppColors.error)),
            onTap: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _manualCheckUpdate(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await ref.read(updateCheckerProvider).check();
    if (!context.mounted) return;
    Navigator.of(context).pop(); // close loader

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
