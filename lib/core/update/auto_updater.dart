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
        // androidProviderAuthority: <package>.ota_update_provider (default)
        // ต้องตรงกับ <provider> ใน AndroidManifest.xml
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
          case 'INSTALLATION_ERROR':
            yield OtaUpdateState.error(installErrorMessage(event.value));
            break;
          case 'CANCELED':
            yield OtaUpdateState.error('ยกเลิกการดาวน์โหลดแล้ว');
            break;
          case 'ALREADY_RUNNING_ERROR':
            yield OtaUpdateState.error('การติดตั้งก่อนหน้ายังทำงานอยู่');
            break;
          case 'PERMISSION_NOT_GRANTED_ERROR':
            yield OtaUpdateState.error('ไม่ได้รับ permission ติดตั้ง APK');
            break;
          case 'INTERNAL_ERROR':
            yield OtaUpdateState.error(
                'เตรียมไฟล์ติดตั้งไม่สำเร็จ ลองใหม่ หรือดาวน์โหลดจากหน้าเว็บ');
            break;
          case 'DOWNLOAD_ERROR':
            yield OtaUpdateState.error(
                'ดาวน์โหลด APK ไม่สำเร็จ ตรวจอินเทอร์เน็ตแล้วลองใหม่');
            break;
          case 'CHECKSUM_ERROR':
            yield OtaUpdateState.error('ไฟล์ APK เสียระหว่างดาวน์โหลด ลองใหม่');
            break;
          default:
            // unknown status — log silently
            break;
        }
      }
    } catch (_) {
      yield OtaUpdateState.error('อัปเดตไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  /// แปลข้อความ PackageInstaller ดิบเป็นไทย — ลายเซ็นไม่ตรงคือเคสที่เจอบ่อยสุด
  static String installErrorMessage(String? raw) {
    final r = (raw ?? '').toUpperCase();
    if (r.contains('INCOMPATIBLE') || r.contains('SIGNATURE')) {
      return 'ติดตั้งทับไม่ได้ เพราะลายเซ็นแอปไม่ตรงกับตัวที่ลงอยู่ '
          '· ถอนแอปเดิมแล้วติดตั้งจากหน้าดาวน์โหลด';
    }
    if (r.contains('STORAGE') || r.contains('SPACE')) {
      return 'พื้นที่เครื่องไม่พอสำหรับติดตั้ง';
    }
    if (r.contains('ABORT') || r.contains('CANCEL')) {
      return 'ยกเลิกการติดตั้งแล้ว';
    }
    return 'ติดตั้งไม่สำเร็จ ลองใหม่ หรือดาวน์โหลดจากหน้าเว็บ';
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

  /// 'downloading' · 'installing' · 'handed_off' · 'error'
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

  /// ส่งต่อให้ตัวติดตั้งของ Android แล้ว — แอปไม่รู้ผลต่อ (ถ้าสำเร็จ Android จะปิดแอปเอง)
  factory OtaUpdateState.handedOff() =>
      OtaUpdateState._(phase: 'handed_off', progress: 100);

  bool get isError => phase == 'error';
  bool get isDownloading => phase == 'downloading';
  bool get isInstalling => phase == 'installing';
  bool get isHandedOff => phase == 'handed_off';
}

final autoUpdaterProvider = Provider<AutoUpdater>((ref) => AutoUpdater());
