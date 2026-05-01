import 'package:flutter/material.dart';

/// Design tokens สำหรับ Thaiprompt Admin (อ้างอิงจาก design handoff README)
///
/// ใช้ dark theme เป็นหลัก — ทุก screen อิงพื้นหลังเข้ม + glass cards
class AppColors {
  AppColors._();

  // ── Background ──
  static const bgRoot = Color(0xFF0A0A0F);
  static const bgPanel = Color(0xFF15151F);

  // ── Glass / borders ──
  static const glassCard = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const glassBorder = Color(0x24FFFFFF); // rgba(255,255,255,0.14)

  // ── Brand gradients ──
  static const pinkStart = Color(0xFFEC4899);
  static const pinkEnd = Color(0xFFBE185D);
  static const purpleStart = Color(0xFFA855F7);
  static const purpleEnd = Color(0xFF7C3AED);
  static const cyanStart = Color(0xFF22D3EE);
  static const cyanEnd = Color(0xFF0891B2);
  static const goldStart = Color(0xFFFBBF24);
  static const goldEnd = Color(0xFFF59E0B);

  // ── Status ──
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);

  // ── Text ──
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xCCFFFFFF);
  static const textTertiary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);

  // ── Module hue accents (สำหรับ Clay icons) ──
  static const moduleFinance = goldStart;
  static const moduleMembers = success;
  static const moduleMarketplace = pinkStart;
  static const moduleAi = purpleStart;
  static const moduleFortune = Color(0xFFA855F7);
  static const moduleSystem = info;

  // ── Common gradients ──
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFEC4899)],
    begin: Alignment(-1, -1),
    end: Alignment(1, 1),
  );

  static const cosmicGradient = LinearGradient(
    colors: [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFFDB2777)],
    begin: Alignment(-1, -1),
    end: Alignment(1, 1),
  );

  static const goldGradient = LinearGradient(
    colors: [goldStart, Color(0xFFF97316), pinkStart],
    begin: Alignment(-1, 0),
    end: Alignment(1, 0),
  );

  static const purplePinkGradient = LinearGradient(
    colors: [purpleStart, pinkStart],
    begin: Alignment(-1, -1),
    end: Alignment(1, 1),
  );
}
