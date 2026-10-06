import 'package:intl/intl.dart';

/// รูปแบบตัวเลข/เวลาภาษาไทยที่ใช้ทั้งแอป
class TpFmt {
  TpFmt._();

  static final _baht = NumberFormat('#,##0', 'en_US');
  static final _baht2 = NumberFormat('#,##0.00', 'en_US');
  static final _int = NumberFormat('#,##0', 'en_US');

  /// ฿48,920 (ทศนิยมแสดงเมื่อมีเศษสตางค์ หรือบังคับด้วย [decimals])
  static String baht(num? v, {bool decimals = false}) {
    final n = v ?? 0;
    final hasCents = (n * 100).round() % 100 != 0;
    return '฿${(decimals || hasCents) ? _baht2.format(n) : _baht.format(n)}';
  }

  /// ฿12.8M / ฿48.9K สำหรับพื้นที่แคบ
  static String bahtCompact(num? v) {
    final n = (v ?? 0).toDouble();
    if (n.abs() >= 1000000) {
      return '฿${(n / 1000000).toStringAsFixed(n.abs() >= 10000000 ? 1 : 2)}M';
    }
    if (n.abs() >= 10000) return '฿${(n / 1000).toStringAsFixed(1)}K';
    return baht(n);
  }

  static String count(num? v) => _int.format(v ?? 0);

  static String compact(num? v) {
    final n = (v ?? 0).toDouble();
    if (n.abs() >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n.abs() >= 1000) {
      return '${(n / 1000).toStringAsFixed(n.abs() >= 10000 ? 0 : 1)}K';
    }
    return _int.format(n);
  }

  /// เปอร์เซ็นต์พร้อมเครื่องหมาย (+12.4%)
  static String pct(num? v, {int digits = 1}) {
    final n = (v ?? 0).toDouble();
    final s = n.abs().toStringAsFixed(digits);
    return n > 0 ? '+$s%' : (n < 0 ? '-$s%' : '$s%');
  }

  static const _thMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  static const _thMonthsFull = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  static const _thDays = [
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์'
  ];

  /// อังคาร 6 ตุลาคม 2569
  static String longDate(DateTime d) =>
      '${_thDays[d.weekday - 1]} ${d.day} ${_thMonthsFull[d.month - 1]} ${d.year + 543}';

  /// 6 ต.ค. 69
  static String shortDate(DateTime d) =>
      '${d.day} ${_thMonths[d.month - 1]} ${(d.year + 543) % 100}';

  /// 14:08
  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// 6 ต.ค. 14:08 (ถ้าเป็นวันนี้แสดงแค่เวลา)
  static String dateTime(DateTime d) {
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    return sameDay ? time(d) : '${d.day} ${_thMonths[d.month - 1]} ${time(d)}';
  }

  /// "2 นาทีที่แล้ว" / "เมื่อสักครู่"
  static String ago(DateTime? d) {
    if (d == null) return '-';
    final diff = DateTime.now().difference(d);
    if (diff.isNegative || diff.inSeconds < 45) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return shortDate(d);
  }

  /// ระยะเวลา "3 นาที" / "1 ชม. 5 นาที"
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes นาที';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h ชม.' : '$h ชม. $m นาที';
  }

  /// อ่าน DateTime จาก JSON (ISO / null) แบบไม่ throw
  static DateTime? parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  /// อ่านตัวเลขจาก JSON ที่อาจเป็น string ("99.00") หรือ num
  static double toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ??
        double.tryParse(v.toString())?.toInt() ??
        0;
  }

  /// อักษรแรกของชื่อ (ข้ามคำนำหน้า "คุณ")
  static String initial(String? name) {
    var n = (name ?? '').trim();
    if (n.startsWith('คุณ')) n = n.substring(3).trim();
    if (n.isEmpty) return '?';
    // สระหน้า (เ แ โ ใ ไ) ไม่ใช่ตัวอักษรต้น — ข้ามไปเอาพยัญชนะตัวถัดไป
    final runes = n.runes.toList();
    const leading = [0x0E40, 0x0E41, 0x0E42, 0x0E43, 0x0E44];
    final pick = (leading.contains(runes.first) && runes.length > 1)
        ? runes[1]
        : runes.first;
    return String.fromCharCode(pick).toUpperCase();
  }
}
