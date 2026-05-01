import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/finance_repository.dart';

/// หน้า Finance — มี 3 แท็บ: Wallets, Withdrawals, Bills (placeholder)
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
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
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.financeTitle),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0x99FFFFFF),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.goldStart, width: 3),
          ),
          tabs: [
            Tab(text: l10n.financeWalletsTab),
            Tab(text: l10n.financeWithdrawalsTab),
            Tab(text: l10n.financeBillsTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _WalletsTab(),
          _WithdrawalsTab(),
          _ComingSoon(label: 'ระบบบิลกำลังพัฒนา'),
        ],
      ),
    );
  }
}

class _WalletsTab extends ConsumerWidget {
  const _WalletsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final async = ref.watch(walletsProvider);
    final money =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(walletsProvider);
        await ref.read(walletsProvider.future);
      },
      child: async.when(
        data: (page) {
          if (page.items.isEmpty) {
            return _emptyState(l10n.walletsListEmpty);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: page.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final w = page.items[i];
              return GlassCard(
                fillOpacity: 0.06,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          AppColors.purpleStart.withValues(alpha: 0.3),
                      backgroundImage: (w.userAvatarUrl?.isNotEmpty == true)
                          ? NetworkImage(w.userAvatarUrl!)
                          : null,
                      child: (w.userAvatarUrl?.isEmpty != false)
                          ? Text(
                              w.userName.isNotEmpty
                                  ? w.userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            w.address,
                            style: const TextStyle(
                                color: Color(0x99FFFFFF), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money.format(w.balance),
                          style: const TextStyle(
                            color: AppColors.goldStart,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _statusChip(w.status, w.isLocked),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorState(e),
      ),
    );
  }
}

class _WithdrawalsTab extends ConsumerStatefulWidget {
  const _WithdrawalsTab();
  @override
  ConsumerState<_WithdrawalsTab> createState() => _WithdrawalsTabState();
}

class _WithdrawalsTabState extends ConsumerState<_WithdrawalsTab> {
  String? _status = 'pending';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final async = ref.watch(withdrawalsProvider(_status));
    final money =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2);

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              for (final s in const [
                null,
                'pending',
                'approved',
                'completed',
                'rejected'
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_statusLabel(s, l10n)),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                    selectedColor: AppColors.purpleStart,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(withdrawalsProvider(_status));
              await ref.read(withdrawalsProvider(_status).future);
            },
            child: async.when(
              data: (page) {
                if (page.items.isEmpty) {
                  return _emptyState(l10n.withdrawalsListEmpty);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final w = page.items[i];
                    return GlassCard(
                      fillOpacity: 0.06,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      w.userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      w.requestId,
                                      style: const TextStyle(
                                          color: Color(0x99FFFFFF),
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    money.format(w.amount),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'สุทธิ ${money.format(w.netAmount)}',
                                    style: const TextStyle(
                                        color: Color(0xCCFFFFFF), fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _statusChip(w.status, false),
                              const Spacer(),
                              if (w.status == 'pending') ...[
                                _smallButton(
                                  label: l10n.withdrawalApprove,
                                  color: AppColors.success,
                                  onTap: () => _approve(w),
                                ),
                                const SizedBox(width: 6),
                                _smallButton(
                                  label: l10n.withdrawalReject,
                                  color: AppColors.error,
                                  onTap: () => _reject(w),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _errorState(e),
            ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(String? s, AppL10n l10n) {
    switch (s) {
      case null:
        return 'ทั้งหมด';
      case 'pending':
        return l10n.withdrawalStatusPending;
      case 'approved':
        return l10n.withdrawalStatusApproved;
      case 'completed':
        return l10n.withdrawalStatusCompleted;
      case 'rejected':
        return l10n.withdrawalStatusRejected;
      default:
        return s;
    }
  }

  Widget _smallButton(
      {required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _approve(AdminWithdrawal w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title: const Text('ยืนยันการอนุมัติ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'อนุมัติคำขอ ${w.requestId} ของ ${w.userName}?',
          style: const TextStyle(color: Color(0xD9FFFFFF)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('อนุมัติ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(financeRepositoryProvider).approveWithdrawal(w.id);
      ref.invalidate(withdrawalsProvider(_status));
      _toast('อนุมัติสำเร็จ');
    } on ApiException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  Future<void> _reject(AdminWithdrawal w) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title: const Text('ปฏิเสธคำขอ', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'เหตุผล...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await ref.read(financeRepositoryProvider).rejectWithdrawal(w.id, reason);
      ref.invalidate(withdrawalsProvider(_status));
      _toast('ปฏิเสธสำเร็จ');
    } on ApiException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label,
          style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 16)),
    );
  }
}

Widget _emptyState(String label) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.inbox_outlined, size: 48, color: Color(0x66FFFFFF)),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Color(0x99FFFFFF))),
      ],
    ),
  );
}

Widget _errorState(Object e) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            e is ApiException ? e.message : 'โหลดข้อมูลไม่สำเร็จ',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

Widget _statusChip(String status, bool isLocked) {
  final color = switch (status) {
    'active' => AppColors.success,
    'pending' => AppColors.warning,
    'approved' => AppColors.info,
    'completed' => AppColors.success,
    'rejected' => AppColors.error,
    'locked' || 'suspended' => AppColors.error,
    _ => Colors.grey,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      isLocked ? 'locked' : status,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}
