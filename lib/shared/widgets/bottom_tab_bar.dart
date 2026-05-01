import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Floating bottom tab bar — 5 tabs + center "+" FAB (per design)
///
/// active = 'home' | 'modules' | 'analytics' | 'profile' (no key for center plus)
class AppBottomTabBar extends StatelessWidget {
  const AppBottomTabBar({
    super.key,
    required this.active,
    required this.onTap,
    required this.onPlus,
  });

  final String active;
  final void Function(String key) onTap;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      _TabItem('home', Icons.home_outlined, 'หน้าหลัก'),
      _TabItem('modules', Icons.grid_view_outlined, 'โมดูล'),
      _TabItem('plus', Icons.add, ''),
      _TabItem('analytics', Icons.bar_chart_outlined, 'รายงาน'),
      _TabItem('profile', Icons.person_outline, 'โปรไฟล์'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tabs.map((t) {
                if (t.key == 'plus') {
                  return Transform.translate(
                    offset: const Offset(0, -12),
                    child: GestureDetector(
                      onTap: onPlus,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppColors.purplePinkGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.pinkStart.withValues(alpha: 0.5),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  );
                }
                final isActive = active == t.key;
                final color =
                    isActive ? AppColors.purpleStart : const Color(0xFF94A3B8);
                return InkWell(
                  onTap: () => onTap(t.key),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.icon, color: color, size: 22),
                        const SizedBox(height: 2),
                        Text(
                          t.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem(this.key, this.icon, this.label);
  final String key;
  final IconData icon;
  final String label;
}
