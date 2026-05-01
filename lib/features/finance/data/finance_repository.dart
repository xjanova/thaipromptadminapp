import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Wallet record from /api/admin/finance/wallets
class AdminWallet {
  AdminWallet({
    required this.id,
    required this.address,
    required this.balance,
    required this.totalIncome,
    required this.totalExpense,
    required this.status,
    required this.userName,
    required this.userEmail,
    this.userAvatarUrl,
    required this.isActive,
    required this.isLocked,
  });

  final int id;
  final String address;
  final double balance;
  final double totalIncome;
  final double totalExpense;
  final String status;
  final String userName;
  final String userEmail;
  final String? userAvatarUrl;
  final bool isActive;
  final bool isLocked;

  factory AdminWallet.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AdminWallet(
      id: (json['id'] as num).toInt(),
      address: (json['wallet_address'] as String?) ?? '',
      balance: ((json['balance'] as num?) ?? 0).toDouble(),
      totalIncome: ((json['total_income'] as num?) ?? 0).toDouble(),
      totalExpense: ((json['total_expense'] as num?) ?? 0).toDouble(),
      status: (json['status'] as String?) ?? 'unknown',
      userName: (user['name'] as String?) ?? '—',
      userEmail: (user['email'] as String?) ?? '',
      userAvatarUrl: user['avatar_url'] as String?,
      isActive: (json['is_active'] as bool?) ?? false,
      isLocked: (json['is_locked'] as bool?) ?? false,
    );
  }
}

/// Withdrawal record from /api/admin/finance/withdrawals
class AdminWithdrawal {
  AdminWithdrawal({
    required this.id,
    required this.requestId,
    required this.userName,
    required this.userEmail,
    required this.amount,
    required this.netAmount,
    required this.fee,
    required this.status,
    required this.paymentType,
    this.createdAt,
  });

  final int id;
  final String requestId;
  final String userName;
  final String userEmail;
  final double amount;
  final double netAmount;
  final double fee;
  final String status;
  final String paymentType;
  final DateTime? createdAt;

  factory AdminWithdrawal.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AdminWithdrawal(
      id: (json['id'] as num).toInt(),
      requestId: (json['request_id'] as String?) ?? '',
      userName: (user['name'] as String?) ?? '—',
      userEmail: (user['email'] as String?) ?? '',
      amount: ((json['amount'] as num?) ?? 0).toDouble(),
      netAmount: ((json['net_amount'] as num?) ?? 0).toDouble(),
      fee: ((json['fee'] as num?) ?? 0).toDouble(),
      status: (json['status'] as String?) ?? 'unknown',
      paymentType: (json['payment_type'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

/// Page envelope for Laravel pagination
class PagedResult<T> {
  PagedResult(
      {required this.items,
      required this.currentPage,
      required this.lastPage,
      required this.total});
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  static PagedResult<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final list = (json['data'] as List?) ?? const [];
    return PagedResult<T>(
      items: list
          .whereType<Map>()
          .map((e) => itemParser(e.cast<String, dynamic>()))
          .toList(),
      currentPage: ((json['current_page'] as num?) ?? 1).toInt(),
      lastPage: ((json['last_page'] as num?) ?? 1).toInt(),
      total: ((json['total'] as num?) ?? list.length).toInt(),
    );
  }
}

class FinanceRepository {
  FinanceRepository(this._api);
  final ApiClient _api;

  Future<PagedResult<AdminWallet>> wallets(
      {int page = 1, String? search}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/finance/wallets',
      query: {
        'page': page,
        if (search != null && search.isNotEmpty) 'search': search,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return PagedResult.fromJson<AdminWallet>(json, AdminWallet.fromJson);
  }

  Future<PagedResult<AdminWithdrawal>> withdrawals(
      {int page = 1, String? status}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/finance/withdrawals',
      query: {
        'page': page,
        if (status != null) 'status': status,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return PagedResult.fromJson<AdminWithdrawal>(
        json, AdminWithdrawal.fromJson);
  }

  Future<void> approveWithdrawal(int id) async {
    await _api.post<dynamic>('/finance/withdrawals/$id/approve');
  }

  Future<void> rejectWithdrawal(int id, String reason) async {
    await _api.post<dynamic>('/finance/withdrawals/$id/reject',
        data: {'reason': reason});
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return FinanceRepository(api);
});

final walletsProvider = FutureProvider<PagedResult<AdminWallet>>((ref) {
  return ref.watch(financeRepositoryProvider).wallets(page: 1);
});

final withdrawalsProvider =
    FutureProvider.family<PagedResult<AdminWithdrawal>, String?>(
  (ref, status) =>
      ref.watch(financeRepositoryProvider).withdrawals(page: 1, status: status),
);
