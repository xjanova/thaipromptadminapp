import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai/ui/ai_screen.dart';
import '../../features/analytics/ui/analytics_screen.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/qr_scanner_screen.dart';
import '../../features/auth/ui/verify_2fa_screen.dart';
import '../../features/chat/ui/chat_inbox_screen.dart';
import '../../features/chat/ui/chat_thread_screen.dart';
import '../../features/finance/ui/wallets_screen.dart';
import '../../features/fortune/ui/ai_pool_screen.dart';
import '../../features/fortune/ui/bills_search_screen.dart';
import '../../features/fortune/ui/fortune_hub_screen.dart';
import '../../features/fortune/ui/fortune_services_screen.dart';
import '../../features/fortune/ui/live_readings_screen.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/marketplace/ui/marketplace_screen.dart';
import '../../features/moderation/ui/moderation_screen.dart';
import '../../features/modules/ui/modules_screen.dart';
import '../../features/settings/ui/account_screen.dart';
import '../../features/users/ui/user_detail_screen.dart';
import '../../features/users/ui/users_screen.dart';
import '../../features/work/ui/work_screen.dart';
import '../../main.dart' show rootNavKey;
import 'app_shell.dart';

/// เส้นทางทั้งแอป
///
/// - 5 แท็บหลักอยู่ใน StatefulShellRoute (สลับแท็บแล้วสถานะ/ตำแหน่งเลื่อนยังอยู่)
/// - หน้าย่อย (แชท 1 ห้อง, โมดูลต่าง ๆ) อยู่บน root navigator → เปิดทับเต็มจอ ซ่อนแท็บบาร์
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    navigatorKey: rootNavKey,
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final isAuth = ref.read(authControllerProvider).isAuthenticated;
      final goingToAuth = state.matchedLocation.startsWith('/auth');
      if (!isAuth && !goingToAuth) return '/auth/login';
      if (isAuth && goingToAuth) return '/home';
      return null;
    },
    routes: [
      // ── เข้าสู่ระบบ ──
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/qr', builder: (_, __) => const QrScannerScreen()),
      GoRoute(
        path: '/auth/2fa',
        builder: (_, state) =>
            Verify2FAScreen(challengeToken: (state.extra as String?) ?? ''),
      ),

      // ── 5 แท็บหลัก ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/work',
              builder: (_, state) => WorkScreen(
                initialTab: state.uri.queryParameters['tab'],
                initialSub: state.uri.queryParameters['sub'],
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chat', builder: (_, __) => const ChatInboxScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/modules', builder: (_, __) => const ModulesScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/me', builder: (_, __) => const AccountScreen())
          ]),
        ],
      ),

      // ── หน้าย่อยเต็มจอ ──
      GoRoute(
        path: '/chat/:readingId',
        builder: (_, state) => ChatThreadScreen(
            readingId:
                int.tryParse(state.pathParameters['readingId'] ?? '') ?? 0),
      ),
      GoRoute(path: '/fortune', builder: (_, __) => const FortuneHubScreen()),
      GoRoute(
          path: '/fortune/ai-pool', builder: (_, __) => const AiPoolScreen()),
      GoRoute(
          path: '/fortune/services',
          builder: (_, __) => const FortuneServicesScreen()),
      GoRoute(
          path: '/fortune/live',
          builder: (_, __) => const LiveReadingsScreen()),
      GoRoute(
          path: '/fortune/bills',
          builder: (_, __) => const BillsSearchScreen()),
      GoRoute(
          path: '/finance/wallets', builder: (_, __) => const WalletsScreen()),
      GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
      GoRoute(
        path: '/users/:id',
        builder: (_, state) => UserDetailScreen(
            userId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
      ),
      GoRoute(
          path: '/marketplace', builder: (_, __) => const MarketplaceScreen()),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(path: '/ai', builder: (_, __) => const AiScreen()),
      GoRoute(
          path: '/moderation', builder: (_, __) => const ModerationScreen()),
    ],
  );
});

/// เชื่อม Riverpod → GoRouter (เปลี่ยนสถานะเข้าสู่ระบบแล้ว redirect ใหม่)
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(this._ref) {
    _sub = _ref.listen<AuthState>(
      authControllerProvider,
      (prev, next) {
        if (prev?.isAuthenticated != next.isAuthenticated) notifyListeners();
      },
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
