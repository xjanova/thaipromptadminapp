import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// PackageInfo cached — ใช้แสดงเวอร์ชันบนหน้า Login + Settings
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

/// String "0.1.0 (build 1)" สำหรับโชว์
final appVersionStringProvider = FutureProvider<String>((ref) async {
  final p = await ref.watch(packageInfoProvider.future);
  return '${p.version} (build ${p.buildNumber})';
});
