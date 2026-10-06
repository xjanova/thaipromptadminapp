import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tp_palette.dart';

/// ตัวอักษรของแอป — Anuphan ทั้งหมด, Noto Serif Thai เฉพาะชื่อหน้า/คำทักทาย
///
/// ⚠️ ห้ามใส่ letterSpacing กับข้อความไทย (สระ/วรรณยุกต์หลุดตำแหน่ง)
class TpType {
  TpType._();

  static const ui = 'Anuphan';
  static const serif = 'NotoSerifThai';
  static const tnum = [FontFeature.tabularFigures()];

  static TextStyle title(double size, Color color) =>
      TextStyle(fontFamily: serif, fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.3);

  static TextStyle h(double size, Color color, {FontWeight w = FontWeight.w700}) =>
      TextStyle(fontFamily: ui, fontSize: size, fontWeight: w, color: color, height: 1.35);

  static TextStyle body(double size, Color color, {FontWeight w = FontWeight.w400, double height = 1.45}) =>
      TextStyle(fontFamily: ui, fontSize: size, fontWeight: w, color: color, height: height);

  /// ตัวเลขเงิน/จำนวน — tabular กันตัวเลขกระโดดตอนอัปเดต
  static TextStyle money(double size, Color color, {FontWeight w = FontWeight.w700}) =>
      TextStyle(fontFamily: ui, fontSize: size, fontWeight: w, color: color, fontFeatures: tnum, height: 1.25);
}

ThemeData buildTpTheme(TpPalette p) {
  final brightness = p.isDark ? Brightness.dark : Brightness.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: TpType.ui,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: p.gold,
      onPrimary: TpPalette.onGold,
      secondary: p.navyIcon,
      onSecondary: p.isDark ? const Color(0xFF05070C) : Colors.white,
      error: p.danger,
      onError: Colors.white,
      surface: p.cardSolid,
      onSurface: p.text,
    ),
    extensions: [p],
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: TpType.ui,
      bodyColor: p.text,
      displayColor: p.textStrong,
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: p.divider,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: p.onHeader,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.inset,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: border(p.border),
      enabledBorder: border(p.border),
      focusedBorder: border(p.gold, 1.5),
      errorBorder: border(p.danger),
      focusedErrorBorder: border(p.danger, 1.5),
      hintStyle: TpType.body(14.5, p.faint),
      labelStyle: TpType.body(14, p.muted),
      prefixIconColor: p.muted,
      suffixIconColor: p.muted,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.gold, circularTrackColor: p.divider),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.isDark ? const Color(0xFF1B2130) : const Color(0xFF10223F),
      contentTextStyle: TpType.body(14, Colors.white, w: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.sheet,
      modalBackgroundColor: p.sheet,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TpType.h(18, p.textStrong),
      contentTextStyle: TpType.body(14.5, p.text),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? TpPalette.onGold : p.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.gold : p.inset),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.gold : p.border),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.gold,
      selectionColor: p.gold.withValues(alpha: 0.3),
      selectionHandleColor: p.gold,
    ),
  );
}

/// ตัวคุมโทนหน้าตา (เก็บใน SharedPreferences — ค่าเริ่มต้น = มิดไนท์โกลด์)
class TpLookController extends Notifier<TpLook> {
  static const _key = 'tp_look';

  @override
  TpLook build() {
    _load();
    return TpLook.midnight;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == TpLook.royal.name) state = TpLook.royal;
    } catch (_) {
      // อ่านค่าไม่ได้ = ใช้ค่าเริ่มต้น
    }
  }

  Future<void> set(TpLook look) async {
    state = look;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, look.name);
    } catch (_) {}
  }
}

final tpLookProvider = NotifierProvider<TpLookController, TpLook>(TpLookController.new);
