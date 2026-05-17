import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_controller.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/qr_scanner_screen.dart';
import '../../features/auth/ui/verify_2fa_screen.dart';
import '../../features/ai/ui/ai_management_screen.dart';
import '../../features/analytics/ui/analytics_screen.dart';
import '../../features/dashboard/ui/dashboard_screen.dart';
import '../../features/finance/ui/finance_screen.dart';
import '../../features/fortune/ui/fortune_bills_screen.dart';
import '../../features/fortune/ui/fortune_live_screen.dart';
import '../../features/fortune/ui/fortune_screen.dart';
import '../../features/marketplace/ui/marketplace_screen.dart';
import '../../features/modules/ui/modules_hub_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/users/ui/users_screen.dart';
import '../../main.dart' show rootNavKey;
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
          GoRoute(path: '/fortune', builder: (_, __) => const FortuneScreen()),
          GoRoute(
              path: '/fortune/bills',
              builder: (_, __) => const FortuneBillsScreen()),
          GoRoute(
              path: '/fortune/live',
              builder: (_, __) => const FortuneLiveScreen()),
          GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
          GoRoute(
              path: '/marketplace', builder: (_, __) => const MarketplaceScreen()),
          GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
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

