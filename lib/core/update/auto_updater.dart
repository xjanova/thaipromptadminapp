import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:permission_handler/permission_handler.dart';

/// AutoUpdater — ดาวน์โหลด + ติดตั้ง APK ใน-app ผ่าน `ota_update` plugin
///
/// อ้างอิงจาก brain note
/// [[Session 2026-05-09 — POS Thaiprompt Flutter Android arm (M1 + auto-update)]]:
/// - Same signing key + same applicationId ทำให้ Android overwrite ทับได้สะอาด
///   user data preserved (SharedPreferences, secure storage, ฯลฯ)
/// - `requestInstallPackages` permission ต้องขอก่อน
/// - PackageInstaller intent ทำงานหลัง APK download เสร็จ
///
/// iOS ไม่รองรับ OTA install → fallback เปิด GitHub release page
class AutoUpdater {
  AutoUpdater();

  /// Stream ของ status + progress (0..100)
  Stream<OtaUpdateState> downloadAndInstall(
    String apkUrl, {
    String destinationFilename = 'thaipromptadmin-update.apk',
  }) async* {
    if (!Platform.isAndroid) {
      yield OtaUpdateState.error('OTA install ใช้ได้เฉพาะ Android');
      return;
    }

    // Step 1: ขอ permission install packages
    final ok = await _ensureInstallPermission();
    if (!ok) {
      yield OtaUpdateState.error(
          'ไม่ได้รับอนุญาตติดตั้ง APK · เปิด Settings → Install unknown apps');
      return;
    }

    // Step 2: stream the OTA download + install
    try {
      await for (final event in OtaUpdate().execute(
        apkUrl,
        destinationFilename: destinationFilename,
        // androidProviderAuthority: <package>.ota_update_file_provider (default)
      )) {
        // ใช้ string-name comparison (per brain note 1372d359d1fc) — robust
        // ต่อ enum case ใหม่ๆ ใน plugin versions ถัดไป
        final statusName = event.status.toString().split('.').last;
        switch (statusName) {
          case 'DOWNLOADING':
            final p = int.tryParse(event.value ?? '0') ?? 0;
            yield OtaUpdateState.downloading(p);
            break;
          case 'INSTALLING':
            yield OtaUpdateState.installing();
            break;
          case 'INSTALLATION_DONE':
            yield OtaUpdateState.installing();
            break;
          case 'ALREADY_RUNNING_ERROR':
            yield OtaUpdateState.error('การติดตั้งก่อนหน้ายังทำงานอยู่');
            break;
          case 'PERMISSION_NOT_GRANTED_ERROR':
            yield OtaUpdateState.error('ไม่ได้รับ permission ติดตั้ง APK');
            break;
          case 'INTERNAL_ERROR':
            yield OtaUpdateState.error(
                'ดาวน์โหลดล้มเหลว · ${event.value ?? ""}');
            break;
          case 'DOWNLOAD_ERROR':
            yield OtaUpdateState.error(
                'ดาวน์โหลด APK ไม่สำเร็จ · ${event.value ?? ""}');
            break;
          case 'CHECKSUM_ERROR':
            yield OtaUpdateState.error('APK checksum ไม่ผ่าน');
            break;
          default:
            // unknown status — log silently
            break;
        }
      }
    } catch (e) {
      yield OtaUpdateState.error('เกิดข้อผิดพลาด: $e');
    }
  }

  /// ขอ permission REQUEST_INSTALL_PACKAGES (Android 8+)
  Future<bool> _ensureInstallPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }
}

/// State machine ของ OTA update ที่ UI ใช้แสดง progress
class OtaUpdateState {
  OtaUpdateState._({
    required this.phase,
    this.progress = 0,
    this.error,
  });

  /// 'downloading' · 'installing' · 'error' · 'done'
  final String phase;

  /// 0..100 — เฉพาะตอน downloading
  final int progress;
  final String? error;

  factory OtaUpdateState.downloading(int p) =>
      OtaUpdateState._(phase: 'downloading', progress: p);
  factory OtaUpdateState.installing() =>
      OtaUpdateState._(phase: 'installing', progress: 100);
  factory OtaUpdateState.error(String msg) =>
      OtaUpdateState._(phase: 'error', error: msg);

  bool get isError => phase == 'error';
  bool get isDownloading => phase == 'downloading';
  bool get isInstalling => phase == 'installing';
}

final autoUpdaterProvider = Provider<AutoUpdater>((ref) => AutoUpdater());
