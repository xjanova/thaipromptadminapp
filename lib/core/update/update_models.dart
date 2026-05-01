/// GitHub Release model — parse จาก api.github.com/repos/.../releases/latest
class GitHubRelease {
  GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.prerelease,
    required this.draft,
    required this.assets,
  });

  /// Tag e.g. "v0.1.0+1" — เราจะ parse เอา semver+build out
  final String tagName;
  final String name;
  final String body; // release notes (markdown)
  final String htmlUrl;
  final DateTime? publishedAt;
  final bool prerelease;
  final bool draft;
  final List<GitHubAsset> assets;

  /// Parse pubspec-style version จาก tag (e.g. "v0.1.0+1" → version="0.1.0", build=1)
  AppVersion? get parsedVersion => AppVersion.tryParse(tagName);

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final assetsJson = (json['assets'] as List?) ?? const [];
    return GitHubRelease(
      tagName: (json['tag_name'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      htmlUrl: (json['html_url'] as String?) ?? '',
      publishedAt: DateTime.tryParse((json['published_at'] as String?) ?? ''),
      prerelease: (json['prerelease'] as bool?) ?? false,
      draft: (json['draft'] as bool?) ?? false,
      assets: assetsJson
          .whereType<Map>()
          .map((m) => GitHubAsset.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }

  /// หา APK asset (สำหรับ Android download + install)
  GitHubAsset? findAndroidApk({String? abi}) {
    for (final a in assets) {
      final n = a.name.toLowerCase();
      if (!n.endsWith('.apk')) continue;
      if (abi != null && !n.contains(abi.toLowerCase())) continue;
      return a;
    }
    // fallback: APK ตัวแรก
    return assets.where((a) => a.name.toLowerCase().endsWith('.apk')).firstOrNull;
  }
}

class GitHubAsset {
  GitHubAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
    required this.contentType,
  });

  final String name;
  final String browserDownloadUrl;
  final int size; // bytes
  final String contentType;

  factory GitHubAsset.fromJson(Map<String, dynamic> json) => GitHubAsset(
        name: (json['name'] as String?) ?? '',
        browserDownloadUrl: (json['browser_download_url'] as String?) ?? '',
        size: ((json['size'] as num?) ?? 0).toInt(),
        contentType: (json['content_type'] as String?) ?? 'application/octet-stream',
      );

  String get sizeMb => (size / (1024 * 1024)).toStringAsFixed(1);
}

/// แทน semver-with-build (e.g. "0.1.0+1") — เปรียบเทียบได้
class AppVersion implements Comparable<AppVersion> {
  AppVersion(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;
  final int build;

  /// Parse string รูป "0.1.0+1" หรือ "v0.1.0+1" หรือ "0.1.0"
  static AppVersion? tryParse(String input) {
    if (input.isEmpty) return null;
    var s = input.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);

    final plusIdx = s.indexOf('+');
    final core = plusIdx >= 0 ? s.substring(0, plusIdx) : s;
    final buildStr = plusIdx >= 0 ? s.substring(plusIdx + 1) : '0';

    final parts = core.split('.');
    if (parts.length < 2) return null;

    try {
      final major = int.parse(parts[0]);
      final minor = int.parse(parts[1]);
      final patch = parts.length > 2 ? int.parse(parts[2]) : 0;
      final build = int.tryParse(buildStr) ?? 0;
      return AppVersion(major, minor, patch, build);
    } catch (_) {
      return null;
    }
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }

  bool operator >(AppVersion o) => compareTo(o) > 0;
  bool operator <(AppVersion o) => compareTo(o) < 0;
  bool operator >=(AppVersion o) => compareTo(o) >= 0;
  bool operator <=(AppVersion o) => compareTo(o) <= 0;
  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;
  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => '$major.$minor.$patch+$build';
}

/// State ของการเช็ค update
class UpdateCheckResult {
  UpdateCheckResult({
    required this.current,
    this.latest,
    this.release,
  });

  final AppVersion current;
  final AppVersion? latest;
  final GitHubRelease? release;

  bool get hasUpdate => latest != null && latest! > current;
}
