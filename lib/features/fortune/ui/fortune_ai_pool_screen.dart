import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/fortune_repository.dart';
import '../data/models/ai_pool_models.dart';
import 'widgets/ai_key_edit_sheet.dart';

/// AI Pool config — control surface for `ai_api_keys` table
///
/// Per brain note
/// [[Session 2026-05-13 — Fortune AI Pool-first + Health Gate + Auto-Recovery]]:
/// - Pool = single source of truth (services declare purpose, Pool picks key)
/// - 6 rotation modes: priority / round_robin / least_used / smart / random / failover
/// - Health gate: `last_test_passed_at IS NOT NULL` required
/// - Cross-provider tier: priority เดียวกัน → vote ตาม global mode
class FortuneAiPoolScreen extends ConsumerStatefulWidget {
  const FortuneAiPoolScreen({super.key});

  @override
  ConsumerState<FortuneAiPoolScreen> createState() =>
      _FortuneAiPoolScreenState();
}

class _FortuneAiPoolScreenState extends ConsumerState<FortuneAiPoolScreen> {
  String? _purpose; // null = all

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(aiPoolSettingsProvider);
    final keysAsync = ref.watch(aiPoolKeysProvider(_purpose));

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // Dark radial bg (AI Management theme)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.7),
                  radius: 1.2,
                  colors: [Color(0xFF1E1B4B), Color(0xFF020617)],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            color: AppColors.purpleStart,
            onRefresh: () async {
              ref.invalidate(aiPoolSettingsProvider);
              ref.invalidate(aiPoolKeysProvider);
              await ref.read(aiPoolKeysProvider(_purpose).future);
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  floating: true,
                  centerTitle: false,
                  title: const Text(
                    'AI Pool',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),

                // Stats hero
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: _StatsHero(async: settingsAsync),
                  ),
                ),

                // Global mode selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _GlobalModeCard(async: settingsAsync),
                  ),
                ),

                // Purpose filter chips
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _filterChip(null, 'ทั้งหมด'),
                        for (final p in aiPoolPurposes)
                          _filterChip(p.key, p.label),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Keys list
                keysAsync.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Empty(),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _KeyTile(
                          keyData: list[i],
                          onTap: () => _openEdit(list[i]),
                          onToggle: () => _toggle(list[i]),
                          onTest: () => _test(list[i]),
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        e is ApiException ? e.message : 'โหลด keys ไม่สำเร็จ',
                        style: const TextStyle(color: Color(0xCCFFFFFF)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────

  Future<void> _openEdit(AiApiKey key) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiKeyEditSheet(keyData: key),
    );
    ref.invalidate(aiPoolKeysProvider);
    ref.invalidate(aiPoolSettingsProvider);
  }

  Future<void> _toggle(AiApiKey key) async {
    await ref.read(fortuneRepositoryProvider).toggleAiKey(key.id);
    ref.invalidate(aiPoolKeysProvider);
    ref.invalidate(aiPoolSettingsProvider);
  }

  Future<void> _test(AiApiKey key) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('กำลังทดสอบ ${key.displayName}...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    final ok = await ref.read(fortuneRepositoryProvider).testAiKey(key.id);
    if (!mounted) return;
    ref.invalidate(aiPoolKeysProvider);
    ref.invalidate(aiPoolSettingsProvider);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '✅ Test ผ่าน — key healthy' : '❌ Test ไม่ผ่าน'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _filterChip(String? key, String label) {
    final active = _purpose == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _purpose = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [AppColors.purpleStart, AppColors.pinkStart],
                  )
                : null,
            color: active ? null : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: active ? 0 : 0.18),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Stats hero
// ────────────────────────────────────────────────────────────

class _StatsHero extends StatelessWidget {
  const _StatsHero({required this.async});
  final AsyncValue<AiPoolSettings> async;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      fillOpacity: 0.1,
      borderOpacity: 0.22,
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      child: async.when(
        data: (s) => Row(
          children: [
            ClayBall(
              size: 48,
              hue: 270,
              saturation: 0.85,
              lightness: 0.62,
              child: const Icon(Icons.hub, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Pool · Keys ทั้งหมด',
                    style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        s.totalKeys.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'keys',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Healthy chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${s.healthyKeys} healthy',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 50,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          e is ApiException ? e.message : 'โหลดสถิติไม่สำเร็จ',
          style: const TextStyle(color: AppColors.error, fontSize: 12),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Global mode card (chip selector)
// ────────────────────────────────────────────────────────────

class _GlobalModeCard extends ConsumerWidget {
  const _GlobalModeCard({required this.async});
  final AsyncValue<AiPoolSettings> async;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      data: (s) {
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.settings_input_component,
                      color: AppColors.cyanStart, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Cross-Provider Rotation Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(left: 22, top: 2),
                child: Text(
                  'ตอนที่ keys หลาย provider มี priority เท่ากัน → vote ตามโหมดนี้',
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 10),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: aiPoolRotationModes
                    .map((m) => _modeChip(ref, m, s.globalMode == m.key))
                    .toList(),
              ),
              const SizedBox(height: 6),
              if (aiPoolRotationModes.any((m) => m.key == s.globalMode))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '• ${aiPoolRotationModes.firstWhere((m) => m.key == s.globalMode).description}',
                    style: const TextStyle(
                      color: AppColors.cyanStart,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _modeChip(WidgetRef ref, AiRotationMode m, bool active) {
    return InkWell(
      onTap: () async {
        await ref.read(fortuneRepositoryProvider).setAiPoolGlobalMode(m.key);
        ref.invalidate(aiPoolSettingsProvider);
        ref.invalidate(aiPoolKeysProvider);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [AppColors.cyanStart, AppColors.purpleStart],
                )
              : null,
          color: active ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          m.label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xCCFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Key tile
// ────────────────────────────────────────────────────────────

class _KeyTile extends StatelessWidget {
  const _KeyTile({
    required this.keyData,
    required this.onTap,
    required this.onToggle,
    required this.onTest,
  });
  final AiApiKey keyData;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.compactCurrency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    final brand = Color(keyData.brandColorHex);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: keyData.isActive ? 0.07 : 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: keyData.isHealthy
                  ? brand.withValues(alpha: 0.3)
                  : (!keyData.isActive
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.error.withValues(alpha: 0.4)),
            ),
          ),
          child: Opacity(
            opacity: keyData.isActive ? 1 : 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Brand color dot
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: brand,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: brand.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        keyData.providerLabel.isNotEmpty
                            ? keyData.providerLabel[0]
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  keyData.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _priorityBadge(keyData.priority),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            keyData.model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xCCFFFFFF), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: Switch.adaptive(
                        value: keyData.isActive,
                        activeThumbColor: AppColors.success,
                        onChanged: (_) => onToggle(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Purposes chips
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: keyData.purposes
                      .map((p) => _purposeChip(p))
                      .toList(),
                ),
                const SizedBox(height: 8),
                // Health + cost row
                Row(
                  children: [
                    _healthDot(keyData),
                    const SizedBox(width: 5),
                    Text(
                      keyData.isHealthy
                          ? 'Healthy${keyData.lastTestPassedAt != null ? " · ${_relative(keyData.lastTestPassedAt!)}" : ""}'
                          : (keyData.isActive ? 'Unhealthy' : 'Disabled'),
                      style: TextStyle(
                        color: keyData.isHealthy
                            ? AppColors.success
                            : (keyData.isActive
                                ? AppColors.error
                                : const Color(0x99FFFFFF)),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (keyData.costThbToday != null && keyData.costThbToday! > 0)
                      Text(
                        '${money.format(keyData.costThbToday)} วันนี้',
                        style: const TextStyle(
                          color: AppColors.goldStart,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onTest,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.cyanStart.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow,
                                color: AppColors.cyanStart, size: 11),
                            SizedBox(width: 3),
                            Text(
                              'Test',
                              style: TextStyle(
                                color: AppColors.cyanStart,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (keyData.quotaPct != null && keyData.quotaPct! > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (keyData.quotaPct! / 100).clamp(0, 1),
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(
                              keyData.quotaPct! > 80
                                  ? AppColors.error
                                  : (keyData.quotaPct! > 60
                                      ? AppColors.warning
                                      : brand),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${keyData.quotaPct!.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                if (keyData.note != null && keyData.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '· ${keyData.note}',
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _priorityBadge(int p) {
    final color = p == 1
        ? AppColors.success
        : (p == 2 ? AppColors.cyanStart : Colors.white.withValues(alpha: 0.5));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        'P$p',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _purposeChip(String purpose) {
    final p = aiPoolPurposes.firstWhere(
      (x) => x.key == purpose,
      orElse: () => AiPurpose(
          key: purpose, label: purpose, icon: '', description: ''),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        p.label,
        style: const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _healthDot(AiApiKey k) {
    final color = k.isHealthy
        ? AppColors.success
        : (k.isActive ? AppColors.error : const Color(0x66FFFFFF));
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: k.isHealthy
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
            : null,
      ),
    );
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub_outlined, color: Color(0x44FFFFFF), size: 56),
            SizedBox(height: 14),
            Text(
              'ไม่มี keys ในหมวดนี้',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
            ),
          ],
        ),
      );
}
