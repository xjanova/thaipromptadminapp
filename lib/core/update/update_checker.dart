import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_models.dart';

/// Repo บน GitHub ที่จะใช้เช็ค release
const String _kGithubOwner =
    String.fromEnvironment('GH_REPO_OWNER', defaultValue: 'xjanova');
const String _kGithubRepo =
    String.fromEnvironment('GH_REPO_NAME', defaultValue: 'thaipromptadminapp');

/// Key สำหรับ cache "ผู้ใช้กด Skip version นี้"
const String _kSkippedTagKey = 'update_skipped_tag';

/// Key สำหรับ throttle ไม่ให้ถามถี่เกินไป
const String _kLastCheckKey = 'update_last_check_at';

/// UpdateChecker — เช็ค GitHub releases ว่ามีเวอร์ชันใหม่กว่าไหม
///
/// ใช้ GitHub public REST API (ไม่ต้อง token) — rate limit 60 req/IP/hour ก็เหลือเฟือ
class UpdateChecker {
  UpdateChecker({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.github.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
              },
              validateStatus: (s) => s != null && s < 500,
            ));

  final Dio _dio;

  /// ดึง latest release + เปรียบเทียบกับเวอร์ชันปัจจุบัน
  Future<UpdateCheckResult> check() async {
    final pkg = await PackageInfo.fromPlatform();
    final current = AppVersion.tryParse('${pkg.version}+${pkg.buildNumber}') ??
        AppVersion(0, 0, 0, 0);

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/repos/$_kGithubOwner/$_kGithubRepo/releases/latest',
      );

      if (res.statusCode == 404) {
        // ยังไม่มี release ตัวแรก — ไม่ใช่ error
        return UpdateCheckResult(current: current);
      }

      if (res.statusCode != 200 || res.data == null) {
        return UpdateCheckResult(current: current);
      }

      final release = GitHubRelease.fromJson(res.data!);
      final latest = release.parsedVersion;

      return UpdateCheckResult(
        current: current,
        latest: latest,
        release: release,
      );
    } catch (_) {
      // เงียบๆ — แค่ silent check ไม่ควรรบกวนผู้ใช้
      return UpdateCheckResult(current: current);
    }
  }

  /// Check + apply throttling + skip preference
  /// คืน null ถ้าไม่ควรแสดง dialog (ไม่มี update / skipped / throttled)
  Future<UpdateCheckResult?> checkIfShouldPrompt({
    Duration minInterval = const Duration(hours: 6),
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Throttle: เช็คซ้ำไม่บ่อยกว่า minInterval
    final lastCheckMs = prefs.getInt(_kLastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastCheckMs < minInterval.inMilliseconds) {
      return null;
    }
    await prefs.setInt(_kLastCheckKey, now);

    final result = await check();
    if (!result.hasUpdate) return null;

    // ผู้ใช้กด Skip เวอร์ชันนี้ไปแล้ว
    final skippedTag = prefs.getString(_kSkippedTagKey);
    if (skippedTag != null && skippedTag == result.release?.tagName) {
      return null;
    }

    return result;
  }

  /// บันทึก tag ที่ user กด Skip (จะไม่ถามอีกจนกว่าจะมีเวอร์ชันใหม่กว่า)
  static Future<void> skipVersion(String tagName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSkippedTagKey, tagName);
  }
}

final updateCheckerProvider = Provider<UpdateChecker>((ref) => UpdateChecker());
