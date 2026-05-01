import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../gen/l10n/app_localizations.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/glass_card.dart';

/// Hub แสดงโมดูลทั้งหมด — แต่ละหมวดมี gradient theme ของตัวเอง
class ModulesHubScreen extends StatelessWidget {
  const ModulesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final categories = [
      _Category(
        title: l10n.moduleCategoryFinance,
        hue: 25,
        items: [
          _ModuleItem('วอลเล็ต', '438', Icons.account_balance_wallet_outlined,
              '/finance'),
          _ModuleItem('ถอนเงิน', '12 รอ', Icons.upload_outlined, '/finance'),
          _ModuleItem('บิล', '8', Icons.receipt_long_outlined, '/finance'),
          _ModuleItem('แคชแบ็ค', '—', Icons.replay_outlined, '/finance'),
        ],
      ),
      _Category(
        title: l10n.moduleCategoryMembers,
        hue: 145,
        items: [
          _ModuleItem('สมาชิก', '2.8k', Icons.people_outline, '/users'),
          _ModuleItem(
              'Ranks', '12', Icons.workspace_premium_outlined, '/users'),
          _ModuleItem('MLM Tree', '—', Icons.account_tree_outlined, '/users'),
          _ModuleItem('Commissions', '—', Icons.payments_outlined, '/users'),
        ],
      ),
      _Category(
        title: l10n.moduleCategoryMarketplace,
        hue: 320,
        items: [
          _ModuleItem(
              'สินค้า', '—', Icons.inventory_2_outlined, '/marketplace'),
          _ModuleItem(
              'ออเดอร์', '—', Icons.shopping_bag_outlined, '/marketplace'),
          _ModuleItem(
              'ร้านค้า', '—', Icons.storefront_outlined, '/marketplace'),
          _ModuleItem('Featured', '—', Icons.star_outline, '/marketplace'),
        ],
      ),
      _Category(
        title: l10n.moduleCategoryAi,
        hue: 270,
        items: [
          _ModuleItem('Providers', '4', Icons.cloud_outlined, '/ai'),
          _ModuleItem('Bots', '—', Icons.smart_toy_outlined, '/ai'),
          _ModuleItem('Quotas', '—', Icons.speed_outlined, '/ai'),
          _ModuleItem('Analytics', '—', Icons.analytics_outlined, '/ai'),
        ],
      ),
      _Category(
        title: l10n.moduleCategoryFortune,
        hue: 290,
        items: [
          _ModuleItem('บริการ', '6', Icons.auto_awesome_outlined, '/fortune'),
          _ModuleItem('Readings', '—', Icons.menu_book_outlined, '/fortune'),
          _ModuleItem(
              'Commissions', '—', Icons.account_balance_outlined, '/fortune'),
          _ModuleItem('LINE OA', '—', Icons.chat_outlined, '/fortune'),
        ],
      ),
      _Category(
        title: l10n.moduleCategorySystem,
        hue: 220,
        items: [
          _ModuleItem('Settings', '—', Icons.settings_outlined, '/settings'),
          _ModuleItem(
              'Roles', '—', Icons.admin_panel_settings_outlined, '/settings'),
          _ModuleItem('KYC', '—', Icons.verified_user_outlined, '/settings'),
          _ModuleItem('Cache', '—', Icons.bolt_outlined, '/settings'),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.modulesHubTitle),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) {
          final cat = categories[i];
          return GlassCard(
            fillOpacity: 0.06,
            borderOpacity: 0.14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color:
                            HSLColor.fromAHSL(1, cat.hue, 0.85, 0.6).toColor(),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cat.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: cat.items.map((it) {
                    return GestureDetector(
                      onTap: () => context.go(it.route),
                      child: Column(
                        children: [
                          ClayBall(
                            size: 44,
                            hue: cat.hue,
                            saturation: 0.7,
                            lightness: 0.62,
                            child: Icon(it.icon, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            it.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            it.kpi,
                            style: const TextStyle(
                              color: Color(0x99FFFFFF),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Category {
  _Category({required this.title, required this.hue, required this.items});
  final String title;
  final double hue;
  final List<_ModuleItem> items;
}

class _ModuleItem {
  _ModuleItem(this.label, this.kpi, this.icon, this.route);
  final String label;
  final String kpi;
  final IconData icon;
  final String route;
}
