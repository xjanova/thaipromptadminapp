import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/models/user_models.dart';
import '../data/users_repository.dart';

/// Users + MLM Screen
///
/// Tabs: Members, Ranks, MLM Tree (placeholder)
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สมาชิก & MLM'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0x99FFFFFF),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.success, width: 3),
          ),
          tabs: const [
            Tab(text: 'สมาชิก'),
            Tab(text: 'Ranks'),
            Tab(text: 'MLM Tree'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _MembersTab(),
          _RanksTab(),
          _ComingSoon(label: 'MLM Tree (genealogy) จะเปิดใน Phase 5'),
        ],
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);
    final statsAsync = ref.watch(usersStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(usersListProvider);
        ref.invalidate(usersStatsProvider);
        await ref.read(usersListProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Stats bar
          statsAsync.when(
            data: (s) => Row(
              children: [
                _statCard('ทั้งหมด', s.total.toString(), AppColors.success),
                const SizedBox(width: 8),
                _statCard('Block', s.blocked.toString(), AppColors.error),
                const SizedBox(width: 8),
                _statCard('ใหม่วันนี้', s.newToday.toString(), AppColors.goldStart),
                const SizedBox(width: 8),
                _statCard('Admins', s.admins.toString(), AppColors.purpleStart),
              ],
            ),
            loading: () => const SizedBox(
              height: 70,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const SizedBox(),
          ),
          const SizedBox(height: 16),

          // Users list
          usersAsync.when(
            data: (page) {
              if (page.items.isEmpty) {
                return const _Empty(label: 'ยังไม่มีสมาชิก');
              }
              return Column(
                children: page.items.map(_userTile).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _Empty(label: e is ApiException ? e.message : 'โหลดไม่สำเร็จ'),
          ),
        ],
      ),
    );
  }

  Widget _userTile(AdminListUser u) {
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        fillOpacity: 0.05,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.purpleStart.withValues(alpha: 0.3),
              backgroundImage: (u.avatarUrl?.isNotEmpty == true) ? NetworkImage(u.avatarUrl!) : null,
              child: (u.avatarUrl?.isEmpty != false)
                  ? Text(
                      u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          u.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (u.isSuperAdmin)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: _Tag(label: 'SUPER', color: AppColors.error),
                        )
                      else if (u.role == 'admin')
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: _Tag(label: 'ADMIN', color: AppColors.purpleStart),
                        ),
                      if (u.isBlocked)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: _Tag(label: 'BLOCKED', color: AppColors.error),
                        ),
                    ],
                  ),
                  Text(
                    u.email,
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (u.rankName != null)
                        _Tag(
                          label: 'L${u.rankLevel} ${u.rankName!}',
                          color: _parseColorOrFallback(u.rankColor, AppColors.cyanStart),
                        ),
                      const SizedBox(width: 4),
                      if (u.phoneVerified)
                        const Icon(Icons.phone_android, color: AppColors.success, size: 12),
                      if (u.lineVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Icon(Icons.chat, color: Color(0xFF06C755), size: 12),
                        ),
                      if (u.facebookVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Icon(Icons.facebook, color: Color(0xFF1877F2), size: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (u.walletBalance != null && u.walletBalance! > 0)
              Text(
                money.format(u.walletBalance),
                style: const TextStyle(
                  color: AppColors.goldStart,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: GlassCard(
        fillOpacity: 0.06,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _RanksTab extends ConsumerWidget {
  const _RanksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ranksListProvider);
    return async.when(
      data: (ranks) {
        if (ranks.isEmpty) return const _Empty(label: 'ยังไม่มี ranks');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: ranks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final r = ranks[i];
            final color = _parseColorOrFallback(r.color, AppColors.cyanStart);
            return GlassCard(
              fillOpacity: 0.05,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'L${r.level}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Commission ${(r.commissionRate * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (r.isTopTier)
                    const Icon(Icons.workspace_premium, color: AppColors.goldStart, size: 18),
                  if (!r.isActive)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: _Tag(label: 'OFF', color: AppColors.error),
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _Empty(label: e is ApiException ? e.message : 'โหลดไม่สำเร็จ'),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(label, style: const TextStyle(color: Color(0x88FFFFFF))),
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
        ),
      );
}

Color _parseColorOrFallback(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  var c = hex.replaceAll('#', '');
  if (c.length == 6) c = 'FF$c';
  final v = int.tryParse(c, radix: 16);
  return v == null ? fallback : Color(v);
}
