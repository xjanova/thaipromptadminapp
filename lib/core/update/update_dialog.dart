import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../theme/app_colors.dart';
import 'auto_updater.dart';
import 'update_checker.dart';
import 'update_models.dart';

/// Dialog แจ้งว่ามีเวอร์ชันใหม่ + ปุ่มอัปเดท
///
/// บน Android: ดาวน์โหลด APK + ติดตั้งใน-app ผ่าน `ota_update` plugin
///   (อ้างอิง pattern จาก
///   [[Session 2026-05-09 — POS Thaiprompt Flutter Android arm (M1 + auto-update)]])
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
    builder: (ctx) => _UpdateDialog(result: result),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.result});
  final UpdateCheckResult result;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  OtaUpdateState? _otaState;
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final release = result.release!;
    final apk = release.findAndroidApk();

    return Dialog(
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

            // Release notes
            if (release.body.isNotEmpty && !_downloading) ...[
              const Text(
                'มีอะไรใหม่',
                style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
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

            // Size hint
            if (apk != null && !_downloading) ...[
              Row(
                children: [
                  const Icon(Icons.download,
                      size: 14, color: Color(0xCCFFFFFF)),
                  const SizedBox(width: 6),
                  Text(
                    'ขนาด ${apk.sizeMb} MB',
                    style: const TextStyle(
                        color: Color(0xCCFFFFFF), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Download progress
            if (_downloading && _otaState != null) _progressView(),

            if (!_downloading) ...[
              GradientButton(
                onPressed: () => _startDownload(release),
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
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'ข้ามเวอร์ชันนี้',
                        style: TextStyle(color: Color(0xCCFFFFFF)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'ภายหลัง',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _progressView() {
    final state = _otaState!;
    if (state.isError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error ?? 'ดาวน์โหลดล้มเหลว',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ปิด',
                      style: TextStyle(color: Color(0xCCFFFFFF))),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _downloading = false;
                      _otaState = null;
                    });
                  },
                  child: const Text(
                    'ลองใหม่',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    final progress = state.progress / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              state.isInstalling
                  ? Icons.install_mobile
                  : Icons.cloud_download,
              color: AppColors.purpleStart,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.isInstalling
                    ? 'กำลังเปิด installer ของ Android...'
                    : 'กำลังดาวน์โหลด APK · ${state.progress}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: state.isInstalling ? null : progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor:
                const AlwaysStoppedAnimation(AppColors.purpleStart),
          ),
        ),
        const SizedBox(height: 12),
        if (state.isInstalling)
          const Text(
            'กดติดตั้งใน dialog ของระบบเพื่อยืนยัน',
            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
          )
        else
          const Text(
            'หลังดาวน์โหลดเสร็จ Android จะถามขออนุญาตติดตั้ง',
            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
          ),
      ],
    );
  }

  void _startDownload(GitHubRelease release) {
    if (Platform.isAndroid) {
      final apk = release.findAndroidApk();
      if (apk == null) {
        _openHtmlUrl(release.htmlUrl);
        return;
      }
      setState(() => _downloading = true);
      AutoUpdater().downloadAndInstall(apk.browserDownloadUrl).listen(
        (state) {
          if (!mounted) return;
          setState(() => _otaState = state);
        },
      );
    } else {
      // iOS / others: open release page
      _openHtmlUrl(release.htmlUrl);
      Navigator.of(context).pop();
    }
  }
}

Future<void> _openHtmlUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
