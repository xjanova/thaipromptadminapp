import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// โทนหน้าตาของแอป — เจ้าของเลือก (2026-10-06) "มิดไนท์โกลด์เป็นหลัก สลับรอยัลงาช้างได้"
enum TpLook {
  /// แบบ A — พื้นดำน้ำเงินลึก ทองเรือง (เข้าชุดเว็บโนวา + แอป POS)
  midnight,

  /// แบบ B — หัวน้ำเงินกรมท่าลายกนก เนื้อหาพื้นงาช้าง (เข้าชุดแอปลูกค้า)
  royal,
}

/// ชุดสีของแอปแอดมิน — ทุกหน้าอ่านสีจาก `context.tp` เท่านั้น ห้ามพิมพ์ hex ในหน้าจอ
///
/// หลักการเดียวกับเว็บ/แอปลูกค้า: ทองใช้ "น้อยแต่ชัด" (ปุ่มหลัก ตัวเลขเงิน ไอคอนเน้น)
/// พื้นที่ส่วนใหญ่เป็นสีกลาง
@immutable
class TpPalette extends ThemeExtension<TpPalette> {
  const TpPalette({
    required this.look,
    required this.bg,
    required this.cardTop,
    required this.cardBottom,
    required this.cardSolid,
    required this.inset,
    required this.border,
    required this.borderGold,
    required this.divider,
    required this.textStrong,
    required this.text,
    required this.muted,
    required this.faint,
    required this.gold,
    required this.goldText,
    required this.goldSoft,
    required this.navyIcon,
    required this.navySoft,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.header,
    required this.headerGlow,
    required this.onHeader,
    required this.onHeaderMuted,
    required this.glass,
    required this.glassBorder,
    required this.tabBar,
    required this.sheet,
    required this.bubbleIn,
    required this.bubbleBot,
    required this.bubbleAdmin,
    required this.onBubbleAdmin,
    required this.shadow,
    required this.kanokOpacity,
    required this.bodyOverlap,
  });

  final TpLook look;
  bool get isDark => look == TpLook.midnight;

  /// พื้นหน้าจอ
  final Color bg;

  /// การ์ด (ไล่เฉดบน→ล่าง) · cardSolid = สีทึบของการ์ดเมื่อไล่เฉดไม่ได้
  final Color cardTop;
  final Color cardBottom;
  final Color cardSolid;

  /// ช่องกรอก / กล่องยุบลง
  final Color inset;
  final Color border;
  final Color borderGold;
  final Color divider;

  /// ตัวอักษร 4 ระดับ
  final Color textStrong;
  final Color text;
  final Color muted;
  final Color faint;

  /// ทอง: gold = เส้น/ไอคอน · goldText = ตัวอักษรทองที่อ่านออกบนพื้นโหมดนั้น · goldSoft = พื้นป้าย
  final Color gold;
  final Color goldText;
  final Color goldSoft;

  /// น้ำเงินสำหรับไอคอน/ตัวอักษร (โหมดมืดเป็นฟ้าอ่อนให้อ่านออก) + พื้นอ่อน
  final Color navyIcon;
  final Color navySoft;

  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;
  final Color info;
  final Color infoSoft;

  /// หัวหน้าจอ (ไล่เฉดแนวตั้ง — ขอบล่างสีเดียวทั้งแถว เพื่อต่อกับฝาครอบเนื้อหาของแบบ B)
  final List<Color> header;

  /// แสงเรืองมุมขวาบนของหัวหน้าจอ
  final Color headerGlow;
  final Color onHeader;
  final Color onHeaderMuted;

  /// ปุ่มกระจกบนหัวหน้าจอ
  final Color glass;
  final Color glassBorder;

  final Color tabBar;
  final Color sheet;

  /// ฟองแชท: ลูกค้า / บอท / แอดมิน (ไล่เฉด)
  final Color bubbleIn;
  final Color bubbleBot;
  final List<Color> bubbleAdmin;
  final Color onBubbleAdmin;

  final List<BoxShadow> shadow;

  /// ความเข้มลายกนกบนหัวหน้าจอ
  final double kanokOpacity;

  /// เนื้อหาซ้อนขึ้นบนหัวกี่ px (แบบ B = แผ่นงาช้างมุมโค้ง · แบบ A = 0)
  final double bodyOverlap;

  // ───────────── ค่าคงที่ร่วมทั้งสองโหมด ─────────────

  /// ทองไล่เฉดของปุ่มหลัก
  static const goldButton = [
    Color(0xFFF8E7B0),
    Color(0xFFE6C36F),
    Color(0xFFC99A40)
  ];

  /// ทองฟอยล์สำหรับตัวเลข/หัวเรื่องเด่น
  static const foil = [
    Color(0xFFF6E6B8),
    Color(0xFFE4C06B),
    Color(0xFFC99A40),
    Color(0xFFF3DC9B)
  ];

  /// ตัวอักษรบนพื้นทอง (น้ำตาลเข้ม contrast ≥ 7:1)
  static const onGold = Color(0xFF2A1D05);

  /// การ์ดฮีโร่น้ำเงินเข้ม (ใช้ทั้งสองโหมด ตัวอักษรบนการ์ดเป็นสีอ่อนเสมอ)
  static const heroCard = [
    Color(0xFF1B2A47),
    Color(0xFF0F1A30),
    Color(0xFF081224)
  ];
  static const heroText = Color(0xFFF3F5F9);
  static const heroMuted = Color(0xB3FFFFFF);
  static const heroGold = Color(0xFFF0C96A);

  /// สีประจำแพลตฟอร์มแชท
  static const facebook = Color(0xFF1877F2);
  static const line = Color(0xFF06C755);
  static const telegram = Color(0xFF2AABEE);

  static const midnight = TpPalette(
    look: TpLook.midnight,
    bg: Color(0xFF05070C),
    cardTop: Color(0xFF151B28),
    cardBottom: Color(0xFF10141E),
    cardSolid: Color(0xFF121722),
    inset: Color(0xFF0A0D14),
    border: Color(0x11FFFFFF),
    borderGold: Color(0x38F0C96A),
    divider: Color(0x0FFFFFFF),
    textStrong: Color(0xFFF3F5F9),
    text: Color(0xFFD5DAE3),
    muted: Color(0xFF8A93A3),
    faint: Color(0xFF5E6778),
    gold: Color(0xFFF0C96A),
    goldText: Color(0xFFF0C96A),
    goldSoft: Color(0x1FF0C96A),
    navyIcon: Color(0xFF8DB4FF),
    navySoft: Color(0x1F6FA3FF),
    success: Color(0xFF3DDC84),
    successSoft: Color(0x1F3DDC84),
    danger: Color(0xFFFF7A6B),
    dangerSoft: Color(0x21FF7A6B),
    warning: Color(0xFFF5B454),
    warningSoft: Color(0x21F5B454),
    info: Color(0xFF6FA3FF),
    infoSoft: Color(0x216FA3FF),
    header: [Color(0xFF05070C), Color(0xFF05070C)],
    headerGlow: Color(0x8C22427A),
    onHeader: Color(0xFFF3F5F9),
    onHeaderMuted: Color(0xFF8A93A3),
    glass: Color(0x0FFFFFFF),
    glassBorder: Color(0x1AFFFFFF),
    tabBar: Color(0xE00C0F16),
    sheet: Color(0xFF0D1119),
    bubbleIn: Color(0xFF151B28),
    bubbleBot: Color(0x1A6FA3FF),
    bubbleAdmin: [Color(0xFFF3DC9B), Color(0xFFD9B25C)],
    onBubbleAdmin: Color(0xFF2A1D05),
    shadow: [
      BoxShadow(
          color: Color(0x80000000),
          blurRadius: 34,
          offset: Offset(0, 14),
          spreadRadius: -6),
    ],
    kanokOpacity: 0.20,
    bodyOverlap: 0,
  );

  static const royal = TpPalette(
    look: TpLook.royal,
    bg: Color(0xFFF4F0E7),
    cardTop: Color(0xFFFFFFFF),
    cardBottom: Color(0xFFFFFFFF),
    cardSolid: Color(0xFFFFFFFF),
    inset: Color(0xFFF1ECE1),
    border: Color(0x1210223F),
    borderGold: Color(0x59CFA349),
    divider: Color(0x1210223F),
    textStrong: Color(0xFF0E1626),
    text: Color(0xFF1A2233),
    muted: Color(0xFF5E6778),
    faint: Color(0xFF8A93A3),
    gold: Color(0xFFCFA349),
    goldText: Color(0xFF8A6420),
    goldSoft: Color(0xFFFBF3DD),
    navyIcon: Color(0xFF173059),
    navySoft: Color(0xFFE3E9F3),
    success: Color(0xFF1F8A5B),
    successSoft: Color(0xFFE2F4EA),
    danger: Color(0xFFD6493A),
    dangerSoft: Color(0xFFFBE6E3),
    warning: Color(0xFFC77A12),
    warningSoft: Color(0xFFFCEFD9),
    info: Color(0xFF2F5FA8),
    infoSoft: Color(0xFFE3ECFA),
    header: [Color(0xFF22427A), Color(0xFF10223F), Color(0xFF081224)],
    headerGlow: Color(0x553A5C96),
    onHeader: Color(0xFFFFFFFF),
    onHeaderMuted: Color(0xADFFFFFF),
    glass: Color(0x1AFFFFFF),
    glassBorder: Color(0x2EFFFFFF),
    tabBar: Color(0xF0FFFFFF),
    sheet: Color(0xFFFBF8F2),
    bubbleIn: Color(0xFFFFFFFF),
    bubbleBot: Color(0xFFE3E9F3),
    bubbleAdmin: [Color(0xFF22427A), Color(0xFF10223F)],
    onBubbleAdmin: Color(0xFFFFFFFF),
    shadow: [
      BoxShadow(color: Color(0x0F10223F), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
          color: Color(0x1710223F),
          blurRadius: 28,
          offset: Offset(0, 10),
          spreadRadius: -4),
    ],
    kanokOpacity: 0.34,
    bodyOverlap: 24,
  );

  static TpPalette of(TpLook look) => look == TpLook.royal ? royal : midnight;

  @override
  TpPalette copyWith() => this;

  @override
  TpPalette lerp(ThemeExtension<TpPalette>? other, double t) {
    if (other is! TpPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> l(List<Color> a, List<Color> b) {
      final n = a.length > b.length ? a.length : b.length;
      return List.generate(n,
          (i) => c(a[i.clamp(0, a.length - 1)], b[i.clamp(0, b.length - 1)]));
    }

    return TpPalette(
      look: t < 0.5 ? look : other.look,
      bg: c(bg, other.bg),
      cardTop: c(cardTop, other.cardTop),
      cardBottom: c(cardBottom, other.cardBottom),
      cardSolid: c(cardSolid, other.cardSolid),
      inset: c(inset, other.inset),
      border: c(border, other.border),
      borderGold: c(borderGold, other.borderGold),
      divider: c(divider, other.divider),
      textStrong: c(textStrong, other.textStrong),
      text: c(text, other.text),
      muted: c(muted, other.muted),
      faint: c(faint, other.faint),
      gold: c(gold, other.gold),
      goldText: c(goldText, other.goldText),
      goldSoft: c(goldSoft, other.goldSoft),
      navyIcon: c(navyIcon, other.navyIcon),
      navySoft: c(navySoft, other.navySoft),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      info: c(info, other.info),
      infoSoft: c(infoSoft, other.infoSoft),
      header: l(header, other.header),
      headerGlow: c(headerGlow, other.headerGlow),
      onHeader: c(onHeader, other.onHeader),
      onHeaderMuted: c(onHeaderMuted, other.onHeaderMuted),
      glass: c(glass, other.glass),
      glassBorder: c(glassBorder, other.glassBorder),
      tabBar: c(tabBar, other.tabBar),
      sheet: c(sheet, other.sheet),
      bubbleIn: c(bubbleIn, other.bubbleIn),
      bubbleBot: c(bubbleBot, other.bubbleBot),
      bubbleAdmin: l(bubbleAdmin, other.bubbleAdmin),
      onBubbleAdmin: c(onBubbleAdmin, other.onBubbleAdmin),
      shadow: t < 0.5 ? shadow : other.shadow,
      kanokOpacity: lerpDouble(kanokOpacity, other.kanokOpacity, t)!,
      bodyOverlap: lerpDouble(bodyOverlap, other.bodyOverlap, t)!,
    );
  }
}

/// ทางลัด `context.tp` อ่านชุดสีปัจจุบัน
extension TpContext on BuildContext {
  TpPalette get tp =>
      Theme.of(this).extension<TpPalette>() ?? TpPalette.midnight;
}

/// ระดับสีของป้าย/ตัวนับ
enum TpTone { gold, success, danger, warning, info, navy, neutral }

extension TpToneColors on TpPalette {
  Color fg(TpTone t) => switch (t) {
        TpTone.gold => goldText,
        TpTone.success => success,
        TpTone.danger => danger,
        TpTone.warning => warning,
        TpTone.info => info,
        TpTone.navy => navyIcon,
        TpTone.neutral => muted,
      };

  Color soft(TpTone t) => switch (t) {
        TpTone.gold => goldSoft,
        TpTone.success => successSoft,
        TpTone.danger => dangerSoft,
        TpTone.warning => warningSoft,
        TpTone.info => infoSoft,
        TpTone.navy => navySoft,
        TpTone.neutral => inset,
      };
}
