import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/bottom_tab_bar.dart';

/// Shell ที่ครอบหน้า main tabs (Home/Modules/Reports/Profile) พร้อม bottom nav
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final active = _resolveActive(location);
    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomTabBar(
          active: active,
          onTap: (key) {
            switch (key) {
              case 'home':
                context.go('/dashboard');
              case 'modules':
                context.go('/modules');
              case 'analytics':
                context.go('/analytics');
              case 'profile':
                context.go('/settings');
            }
          },
          onPlus: () {
            // Quick action: ไปหน้า Finance (default action)
            context.go('/finance');
          },
        ),
      ),
    );
  }

  String _resolveActive(String loc) {
    if (loc.startsWith('/dashboard')) return 'home';
    if (loc.startsWith('/modules')) return 'modules';
    if (loc.startsWith('/analytics')) return 'analytics';
    if (loc.startsWith('/settings') || loc.startsWith('/profile')) return 'profile';
    return 'home';
  }
}
