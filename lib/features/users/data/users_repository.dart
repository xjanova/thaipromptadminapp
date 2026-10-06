import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/api/paged.dart';
import 'models/user_models.dart';

export 'models/user_models.dart';

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

/// ตัวกรองรายชื่อสมาชิก (ชิปบนหัวหน้าจอ)
enum UserFilter {
  all('ทั้งหมด'),
  active('ใช้งานปกติ'),
  blocked('ถูกระงับ'),
  admins('แอดมิน');

  const UserFilter(this.label);
  final String label;
}

/// อ่านข้อมูลสมาชิกจาก Admin API (`/api/admin/users*`, `/api/admin/ranks`) — อ่านอย่างเดียว
class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  /// `GET users?search=&blocked=&role=&rank_id=&page=&per_page=`
  Future<Paged<AdminListUser>> users({
    int page = 1,
    String? search,
    UserFilter filter = UserFilter.all,
    int? rankId,
    int perPage = 20,
  }) =>
      _guard(() async {
        final data = await _api.get<dynamic>('/users', query: {
          'page': page,
          'per_page': perPage,
          if (search != null && search.isNotEmpty) 'search': search,
          if (filter == UserFilter.blocked) 'blocked': 1,
          if (filter == UserFilter.active) 'blocked': 0,
          if (filter == UserFilter.admins) 'role': 'admin',
          if (rankId != null) 'rank_id': rankId,
        });
        return Paged.parse(data, AdminListUser.fromJson);
      });

  /// `GET users/stats`
  Future<UsersStats> stats() => _guard(() async {
        final data = await _api.get<dynamic>('/users/stats');
        return UsersStats.fromJson(_m(data));
      });

  /// `GET ranks` (ไม่แบ่งหน้า) — เรียงตามระดับ
  Future<List<AdminRank>> ranks() => _guard(() async {
        final data = await _api.get<dynamic>('/ranks');
        final list = Paged.parse(data, AdminRank.fromJson)
            .items
            .where((r) => r.id > 0)
            .toList()
          ..sort((a, b) => a.level.compareTo(b.level));
        return list;
      });

  /// `GET users/{id}`
  Future<AdminListUser> user(int id) => _guard(() async {
        final data = await _api.get<dynamic>('/users/$id');
        return AdminListUser.fromJson(_m(data));
      });

  /// `GET users/{id}/readings?per_page=` (สูงสุด 50 รายการล่าสุด ไม่แบ่งหน้า)
  Future<List<UserReading>> readings(int id, {int perPage = 30}) =>
      _guard(() async {
        final data = await _api
            .get<dynamic>('/users/$id/readings', query: {'per_page': perPage});
        return Paged.parse(data, UserReading.fromJson).items;
      });

  /// `GET users/admins/online` → map ตาม user id
  Future<Map<int, AdminPresence>> adminsOnline() => _guard(() async {
        final data = await _api.get<dynamic>('/users/admins/online');
        final list = Paged.parse(data, AdminPresence.fromJson).items;
        return {for (final a in list) a.id: a};
      });

  /// เซิร์ฟเวอร์ล่ม (5xx) มักส่งข้อความอังกฤษ — แปลงเป็นข้อความไทยก่อนถึงหน้าจอ
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (e.type == DioExceptionType.badResponse && code >= 500) {
        throw ActionError('เซิร์ฟเวอร์ขัดข้องชั่วคราว ($code) ลองใหม่อีกครั้ง');
      }
      rethrow;
    }
  }
}

final usersRepositoryProvider = Provider<UsersRepository>(
    (ref) => UsersRepository(ref.watch(apiClientProvider)));

final usersStatsProvider = FutureProvider.autoDispose<UsersStats>(
    (ref) => ref.watch(usersRepositoryProvider).stats());

final ranksListProvider = FutureProvider.autoDispose<List<AdminRank>>(
    (ref) => ref.watch(usersRepositoryProvider).ranks());

final userDetailProvider = FutureProvider.autoDispose
    .family<AdminListUser, int>(
        (ref, id) => ref.watch(usersRepositoryProvider).user(id));

final userReadingsProvider = FutureProvider.autoDispose
    .family<List<UserReading>, int>(
        (ref, id) => ref.watch(usersRepositoryProvider).readings(id));

final adminsOnlineProvider =
    FutureProvider.autoDispose<Map<int, AdminPresence>>(
        (ref) => ref.watch(usersRepositoryProvider).adminsOnline());
