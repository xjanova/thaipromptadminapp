import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/security/app_lock_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/update/update_checker.dart';
import 'core/update/update_dialog.dart';
import 'features/auth/providers/auth_controller.dart';
import 'features/auth/ui/pin_entry_screen.dart';
import 'gen/l10n/app_localizations.dart';

/// Global navigator key — ใช้สำหรับ show update dialog จาก background flow
final rootNavKey = GlobalKey<NavigatorState>();

/// Splash ที่แสดงระหว่าง bootstrap AppLockController (กัน flash content
/// ก่อน PIN gate ตอน cold start)
class _BootSplash extends StatelessWidget {
  const _BootSplash();
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0A0A0F),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFA855F7),
        ),
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  runApp(const ProviderScope(child: ThaipromptAdminApp()));
}

class ThaipromptAdminApp extends ConsumerStatefulWidget {
  const ThaipromptAdminApp({super.key});

  @override
  ConsumerState<ThaipromptAdminApp> createState() => _ThaipromptAdminAppState();
}

class _ThaipromptAdminAppState extends ConsumerState<ThaipromptAdminApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. ลอง resume session ถ้ามี token
      await ref.read(authControllerProvider.notifier).bootstrap();
      // 2. เช็ค update เงียบๆ (ใช้ throttle ภายใน — เช็คซ้ำไม่บ่อยกว่า 6 ชม.)
      _silentCheckForUpdate();
    });
  }

  Future<void> _silentCheckForUpdate() async {
    try {
      final result =
          await ref.read(updateCheckerProvider).checkIfShouldPrompt();
      if (result == null) return;
      // หน่วงเวลาเล็กน้อยให้หน้า initial render เสร็จก่อน
      await Future.delayed(const Duration(seconds: 2));
      final ctx = rootNavKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await showUpdateAvailableDialog(ctx, result);
      }
    } catch (_) {
      // เงียบ — ห้าม fail boot เพราะ update check
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Thaiprompt Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      // PIN gate overlay — ถ้า user ตั้ง PIN และยังไม่ปลด → block หน้าจอทั้งแอพ
      builder: (context, child) {
        final lockState = ref.watch(appLockControllerProvider);
        // ระหว่าง bootstrap → splash (กัน security gap ตอน cold start)
        if (!lockState.bootstrapped) {
          return const _BootSplash();
        }
        if (!lockState.needsUnlock) {
          return child ?? const SizedBox();
        }
        // PIN gate — full-screen overlay (cannot dismiss)
        return PinEntryScreen(
          mode: PinScreenMode.unlock,
          canCancel: false,
          onSuccess: () =>
              ref.read(appLockControllerProvider.notifier).markUnlocked(),
        );
      },
      // ใช้ rootNavKey ผ่าน GoRouter delegate (set ใน app_router.dart)
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('th'), Locale('en')],
      locale: const Locale('th'),
    );
  }
}
