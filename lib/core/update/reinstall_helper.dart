import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// SHA-256 ของใบรับรองที่ CI ใช้เซ็น APK ทุก release
/// (upload-keystore.jks · CN=Thaiprompt Admin, O=Thaiprompt)
/// อ่านจาก `apksigner verify --print-certs thaipromptadmin-0.4.1+6-arm64-v8a.apk`
/// ถ้าเปลี่ยน keystore ต้องแก้ค่านี้ หรือส่ง --dart-define=RELEASE_CERT_SHA256=...
const String kReleaseCertSha256 = String.fromEnvironment(
  'RELEASE_CERT_SHA256',
  defaultValue:
      '6c4750bb162ffbbcb57ad95b228ef516adf698c862556e39e961513973cff93b',
);

/// ผลตรวจลายเซ็นของแอปที่ติดตั้งอยู่
enum InstalledSigner {
  /// เซ็นด้วยคีย์ release ของ CI — อัปเดตทับในแอปได้
  release,

  /// เซ็นด้วยคีย์อื่น (เช่น debug จาก `flutter run`) — Android ไม่ยอมให้ติดตั้งทับ ต้องถอนก่อน
  foreign,

  /// อ่านไม่ได้ (ไม่ใช่ Android / ปลั๊กอินพัง) — ใช้ทางปกติ ไม่ขวาง
  unknown,
}

/// ReinstallHelper — ทางออกเวลา "อัปเดตแล้วเด้ง เพราะลายเซ็นไม่ตรง"
///
/// Android ไม่ยอมให้แอปถอนตัวเองเงียบ ๆ แล้วติดตั้งใหม่ (ต้องเป็น device owner เท่านั้น)
/// สิ่งที่ทำได้มากสุดคือ: เก็บ APK ใหม่ไว้ใน Download สาธารณะ (อยู่รอดหลังถอนแอป) →
/// เปิดหน้าถอนแอปของระบบให้ → ผู้ใช้แตะไฟล์ใน Download เพื่อติดตั้ง (3 แตะ)
class ReinstallHelper {
  ReinstallHelper({Dio? dio, MethodChannel? channel})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 5),
        )),
        _ch = channel ?? const MethodChannel('online.thaiprompt.admin/installer');

  final Dio _dio;
  final MethodChannel _ch;

  /// ตัดสินจากรายการลายนิ้วมือที่ native ส่งมา — pure, ทดสอบได้
  static InstalledSigner decide(List<String>? fingerprints,
      {String expected = kReleaseCertSha256}) {
    if (fingerprints == null || fingerprints.isEmpty) {
      return InstalledSigner.unknown;
    }
    final want = normalizeFingerprint(expected);
    if (want.isEmpty) return InstalledSigner.unknown;
    for (final f in fingerprints) {
      if (normalizeFingerprint(f) == want) return InstalledSigner.release;
    }
    return InstalledSigner.foreign;
  }

  /// "6C:47:50:BB…" / "6c4750bb…" / มีช่องว่าง → hex ตัวเล็กล้วน
  static String normalizeFingerprint(String s) =>
      s.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();

  /// ตัวที่ลงอยู่เซ็นด้วยคีย์ไหน
  Future<InstalledSigner> installedSigner() async {
    if (!Platform.isAndroid) return InstalledSigner.unknown;
    try {
      final list = await _ch.invokeListMethod<String>('signingSha256s');
      return decide(list);
    } catch (_) {
      return InstalledSigner.unknown;
    }
  }

  /// ดาวน์โหลด APK แล้วย้ายไป Download สาธารณะ — คืนชื่อไฟล์ที่ได้จริง
  /// (MediaStore อาจต่อ " (1)" ถ้าชื่อซ้ำ) · โยน [ReinstallException] พร้อมข้อความไทย
  Future<String> saveApkToDownloads(
    String url,
    String fileName, {
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!Platform.isAndroid) {
      throw const ReinstallException('ใช้ได้เฉพาะ Android');
    }
    if (!await _ensureStoragePermission()) {
      throw const ReinstallException(
          'ไม่ได้รับอนุญาตเขียนไฟล์ลง Download · เปิดสิทธิ์พื้นที่เก็บข้อมูลให้แอปแล้วลองใหม่');
    }

    String cacheDir = '';
    try {
      cacheDir = (await _ch.invokeMethod<String>('cacheDir')) ?? '';
    } on PlatformException {
      cacheDir = '';
    }
    if (cacheDir.isEmpty) {
      throw const ReinstallException('เตรียมที่เก็บไฟล์ชั่วคราวไม่สำเร็จ');
    }
    final tmpPath = '$cacheDir/$fileName.part';
    final tmp = File(tmpPath);

    try {
      await _dio.download(
        url,
        tmpPath,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (got, total) {
          if (onProgress == null) return;
          // GitHub ส่ง Content-Length เสมอ แต่กันไว้ถ้า proxy ตัดทิ้ง
          onProgress(total > 0 ? (got * 100 ~/ total).clamp(0, 99) : -1);
        },
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const ReinstallException('ยกเลิกการดาวน์โหลดแล้ว');
      }
      throw const ReinstallException(
          'ดาวน์โหลด APK ไม่สำเร็จ ตรวจอินเทอร์เน็ตแล้วลองใหม่');
    }

    try {
      final saved = await _ch.invokeMethod<String>(
          'saveToDownloads', {'path': tmpPath, 'name': fileName});
      if (saved == null || saved.isEmpty) {
        throw const ReinstallException('บันทึกไฟล์ลง Download ไม่สำเร็จ');
      }
      onProgress?.call(100);
      return saved;
    } on PlatformException {
      throw const ReinstallException(
          'บันทึกไฟล์ลง Download ไม่สำเร็จ · พื้นที่เครื่องอาจไม่พอ หรือใช้ "เปิดหน้าดาวน์โหลด" แทน');
    } finally {
      // ไฟล์ชั่วคราวใน cache ไม่จำเป็นแล้ว (ล้มเหลวหรือสำเร็จก็ตาม)
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  /// เปิดหน้าถอนการติดตั้งของ Android — ระบบถามยืนยันเอง ถ้าผู้ใช้กดยืนยัน แอปจะถูกปิดทันที
  Future<void> uninstallSelf() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod<bool>('uninstallSelf');
    } on PlatformException {
      throw const ReinstallException(
          'เปิดหน้าถอนแอปไม่สำเร็จ · ถอนเองได้ที่ ตั้งค่า → แอป → ไทยพร้อม แอดมิน');
    }
  }

  /// Android 10+ เขียนผ่าน MediaStore ไม่ต้องขอสิทธิ์ · ต่ำกว่านั้นต้องขอ storage
  Future<bool> _ensureStoragePermission() async {
    try {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdk >= 29) return true;
    } catch (_) {
      return true; // อ่าน SDK ไม่ได้ → ให้ native ลองเอง
    }
    final st = await Permission.storage.status;
    if (st.isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }
}

class ReinstallException implements Exception {
  const ReinstallException(this.message);
  final String message;
  @override
  String toString() => message;
}

final reinstallHelperProvider =
    Provider<ReinstallHelper>((ref) => ReinstallHelper());
