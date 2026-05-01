import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Build แบบ dark-only theme สำหรับ Admin App
///
/// ใช้ Plus Jakarta Sans + Noto Sans Thai (ตาม design handoff)
ThemeData buildAppTheme() {
  // Combined font family — ภาษาอังกฤษใช้ Plus Jakarta Sans, ไทยใช้ Noto Sans Thai
  // Flutter จะเลือกอัตโนมัติตาม Unicode range ใน TextStyle.fontFamilyFallback
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgRoot,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.purpleStart,
      secondary: AppColors.pinkStart,
      tertiary: AppColors.cyanStart,
      surface: AppColors.bgRoot,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    ),
  );

  final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  // Apply Thai fallback to every style
  final thaiFallback = GoogleFonts.notoSansThai().fontFamily;
  TextStyle withFallback(TextStyle? style) => (style ?? const TextStyle())
      .copyWith(fontFamilyFallback: [thaiFallback ?? '']);

  return base.copyWith(
    textTheme: textTheme.copyWith(
      displayLarge: withFallback(textTheme.displayLarge),
      displayMedium: withFallback(textTheme.displayMedium),
      displaySmall: withFallback(textTheme.displaySmall),
      headlineLarge: withFallback(textTheme.headlineLarge),
      headlineMedium: withFallback(textTheme.headlineMedium),
      headlineSmall: withFallback(textTheme.headlineSmall),
      titleLarge: withFallback(textTheme.titleLarge),
      titleMedium: withFallback(textTheme.titleMedium),
      titleSmall: withFallback(textTheme.titleSmall),
      bodyLarge: withFallback(textTheme.bodyLarge),
      bodyMedium: withFallback(textTheme.bodyMedium),
      bodySmall: withFallback(textTheme.bodySmall),
      labelLarge: withFallback(textTheme.labelLarge),
      labelMedium: withFallback(textTheme.labelMedium),
      labelSmall: withFallback(textTheme.labelSmall),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.glassCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.purpleStart, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textTertiary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.glassCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.purpleStart,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
