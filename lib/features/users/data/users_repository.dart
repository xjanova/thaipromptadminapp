import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../finance/data/finance_repository.dart' show PagedResult;
import 'models/user_models.dart';

class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  Future<PagedResult<AdminListUser>> users({
    int page = 1,
    String? search,
    bool? blocked,
    int? rankId,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/users',
      query: {
        'page': page,
        if (search != null && search.isNotEmpty) 'search': search,
        if (blocked != null) 'blocked': blocked ? 1 : 0,
        if (rankId != null) 'rank_id': rankId,
      },
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return PagedResult.fromJson<AdminListUser>(json, AdminListUser.fromJson);
  }

  Future<UsersStats> stats() async {
    final json = await _api.get<Map<String, dynamic>>(
      '/users/stats',
      parser: (d) => (d as Map).cast<String, dynamic>(),
    );
    return UsersStats.fromJson(json);
  }

  Future<List<AdminRank>> ranks() async {
    final list = await _api.get<List<dynamic>>(
      '/ranks',
      parser: (d) => (d as List).toList(),
    );
    return list
        .whereType<Map>()
        .map((m) => AdminRank.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(apiClientProvider));
});

final usersListProvider = FutureProvider<PagedResult<AdminListUser>>((ref) {
  return ref.watch(usersRepositoryProvider).users();
});

final usersStatsProvider = FutureProvider<UsersStats>((ref) {
  return ref.watch(usersRepositoryProvider).stats();
});

final ranksListProvider = FutureProvider<List<AdminRank>>((ref) {
  return ref.watch(usersRepositoryProvider).ranks();
});
