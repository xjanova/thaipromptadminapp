import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_controller.dart';
import 'gen/l10n/app_localizations.dart';

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
    // ลอง resume session ถ้ามี token เก็บไว้
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Thaiprompt Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
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
