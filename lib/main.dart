import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/update/update_checker.dart';
import 'core/update/update_dialog.dart';
import 'features/auth/providers/auth_controller.dart';
import 'gen/l10n/app_localizations.dart';

/// Global navigator key — ใช้สำหรับ show update dialog จาก background flow
final rootNavKey = GlobalKey<NavigatorState>();

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
      final result = await ref.read(updateCheckerProvider).checkIfShouldPrompt();
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
