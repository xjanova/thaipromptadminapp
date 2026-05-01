import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import 'update_checker.dart';
import 'update_models.dart';

/// Dialog แจ้งว่ามีเวอร์ชันใหม่ + ปุ่มอัปเดท
///
/// บน Android: เปิด APK download URL ใน browser → ติดตั้งเอง
/// บน iOS: เปิด GitHub release page (ไปต่อ App Store / TestFlight)
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  UpdateCheckResult result,
) async {
  final release = result.release;
  if (release == null) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: GlassCard(
        fillOpacity: 0.10,
        borderOpacity: 0.25,
        borderRadius: 28,
        padding: const EdgeInsets.all(22),
        tint: AppColors.purpleStart,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.purplePinkGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.system_update,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'มีเวอร์ชันใหม่!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${result.current} → ${result.latest}',
                        style: const TextStyle(
                            color: Color(0xCCFFFFFF), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (release.body.isNotEmpty) ...[
              const Text(
                'มีอะไรใหม่',
                style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    release.body,
                    style: const TextStyle(
                        color: Color(0xE6FFFFFF), fontSize: 13, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Download size hint (ถ้ามี APK asset)
            if (Platform.isAndroid && release.findAndroidApk() != null) ...[
              Row(
                children: [
                  const Icon(Icons.download,
                      size: 14, color: Color(0xCCFFFFFF)),
                  const SizedBox(width: 6),
                  Text(
                    'ขนาด ${release.findAndroidApk()!.sizeMb} MB',
                    style:
                        const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            GradientButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openDownloadUrl(release);
              },
              icon: Icons.download_for_offline_outlined,
              label: 'อัปเดทตอนนี้',
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await UpdateChecker.skipVersion(release.tagName);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text(
                      'ข้ามเวอร์ชันนี้',
                      style: TextStyle(color: Color(0xCCFFFFFF)),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'ภายหลัง',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// เปิด URL ดาวน์โหลด — ฝั่ง Android ใช้ APK URL ตรง (เบราเซอร์เปิด → user install)
/// ฝั่ง iOS ใช้ release page (จะไปต่อ TestFlight / App Store ตามที่ทีมตั้งไว้)
Future<void> _openDownloadUrl(GitHubRelease release) async {
  String url;
  if (Platform.isAndroid) {
    final apk = release.findAndroidApk();
    url = apk?.browserDownloadUrl ?? release.htmlUrl;
  } else {
    url = release.htmlUrl;
  }

  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
