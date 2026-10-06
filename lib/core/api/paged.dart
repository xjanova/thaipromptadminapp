/// ผลลัพธ์แบบแบ่งหน้า — อ่านได้ทั้ง 3 รูปแบบที่ backend ส่งมา:
/// 1) `{data:[...], current_page, last_page, total}` (แบบแบน)
/// 2) `{data:[...], meta:{current_page, last_page, total}}` (Laravel Resource collection)
/// 3) `[...]` (ไม่แบ่งหน้า)
class Paged<T> {
  Paged({required this.items, this.page = 1, this.lastPage = 1, this.total = 0, this.perPage = 0});

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;
  final int perPage;

  bool get hasMore => page < lastPage;

  static Paged<T> parse<T>(dynamic raw, T Function(Map<String, dynamic>) item) {
    List<dynamic> list = const [];
    Map<String, dynamic> meta = const {};
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      final inner = m['data'];
      if (inner is List) {
        list = inner;
      } else if (inner is Map && inner['data'] is List) {
        // ซ้อนสองชั้น {data:{data:[...], ...}}
        return parse<T>(inner, item);
      }
      meta = (m['meta'] is Map) ? (m['meta'] as Map).cast<String, dynamic>() : m;
    }
    int n(dynamic v, int d) => v is num ? v.toInt() : int.tryParse('$v') ?? d;
    final items = list.whereType<Map>().map((e) => item(e.cast<String, dynamic>())).toList();
    return Paged<T>(
      items: items,
      page: n(meta['current_page'], 1),
      lastPage: n(meta['last_page'], 1),
      total: n(meta['total'], items.length),
      perPage: n(meta['per_page'], items.length),
    );
  }
}
