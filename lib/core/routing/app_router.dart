import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_controller.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/qr_scanner_screen.dart';
import '../../features/auth/ui/verify_2fa_screen.dart';
import '../../features/dashboard/ui/dashboard_screen.dart';
import '../../features/finance/ui/finance_screen.dart';
import '../../features/modules/ui/modules_hub_screen.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
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
        builder: (_, state) => Verify2FAScreen(challengeToken: state.extra as String),
      ),

      // Authenticated shell
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/modules', builder: (_, __) => const ModulesHubScreen()),
          GoRoute(path: '/finance', builder: (_, __) => const FinanceScreen()),
          GoRoute(path: '/analytics', builder: (_, __) => const _ComingSoonPage(label: 'Analytics')),
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
        body: Center(child: Text('$label — กำลังพัฒนา', style: const TextStyle(color: Colors.white))),
      );
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(authControllerProvider).admin;
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (admin != null) ...[
            ListTile(
              leading: CircleAvatar(child: Text(admin.name.isNotEmpty ? admin.name[0] : '?')),
              title: Text(admin.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(admin.email, style: const TextStyle(color: Color(0xCCFFFFFF))),
              trailing: admin.isSuperAdmin
                  ? const Chip(
                      label: Text('SUPER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)))
                  : null,
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}
