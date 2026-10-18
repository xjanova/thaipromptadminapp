import 'package:flutter_test/flutter_test.dart';
import 'package:thaipromptadmin/core/update/auto_updater.dart';
import 'package:thaipromptadmin/core/update/reinstall_helper.dart';
import 'package:thaipromptadmin/core/update/update_models.dart';

void main() {
  group('ReinstallHelper.decide — ลายเซ็นตัวที่ลงอยู่', () {
    const release =
        '6c4750bb162ffbbcb57ad95b228ef516adf698c862556e39e961513973cff93b';
    const debug =
        'a40da80a59d170caa950cf15c18c454d47a39b26989d8b640ecd745ba71bf5dc';

    test('release key → release (ตัวพิมพ์ใหญ่/มี : ก็ต้องตรง)', () {
      expect(ReinstallHelper.decide([release]), InstalledSigner.release);
      final colon = release.toUpperCase().replaceAllMapped(
          RegExp(r'..'), (m) => '${m[0]}:');
      expect(ReinstallHelper.decide([colon]), InstalledSigner.release);
    });

    test('debug key จาก flutter run → foreign (ต้องถอนก่อน)', () {
      expect(ReinstallHelper.decide([debug]), InstalledSigner.foreign);
    });

    test('lineage ที่มี release อยู่ด้วย → release', () {
      expect(
          ReinstallHelper.decide([debug, release]), InstalledSigner.release);
    });

    test('อ่านไม่ได้ (null/ว่าง) → unknown ไม่ขวางทางปกติ', () {
      expect(ReinstallHelper.decide(null), InstalledSigner.unknown);
      expect(ReinstallHelper.decide(const []), InstalledSigner.unknown);
      expect(ReinstallHelper.decide([release], expected: ''),
          InstalledSigner.unknown);
    });

    test('ค่าคงที่ release cert เป็น sha256 hex 64 ตัว', () {
      expect(kReleaseCertSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  group('AutoUpdater.installErrorMessage', () {
    test('signature mismatch → tells user to uninstall first', () {
      final m = AutoUpdater.installErrorMessage(
          'INSTALL_FAILED_UPDATE_INCOMPATIBLE: Package signatures do not match');
      expect(m, contains('ลายเซ็น'));
      expect(m, isNot(contains('INSTALL_FAILED')));
    });

    test('null / unknown → generic Thai message, no raw text', () {
      expect(
          AutoUpdater.installErrorMessage(null), contains('ติดตั้งไม่สำเร็จ'));
      expect(
          AutoUpdater.installErrorMessage('weird'), isNot(contains('weird')));
    });
  });

  test('handedOff is not busy-looking error and not installing', () {
    final s = OtaUpdateState.handedOff();
    expect(s.isHandedOff, isTrue);
    expect(s.isError, isFalse);
    expect(s.isInstalling, isFalse);
  });

  test('build number alone makes a newer release', () {
    final cur = AppVersion.tryParse('0.4.0+5')!;
    expect(AppVersion.tryParse('v0.4.0+6')! > cur, isTrue);
    expect(AppVersion.tryParse('v0.4.0+5')! > cur, isFalse);
  });

  group('AppVersion.fromInstalled — split-per-abi versionCode', () {
    test('strips the ABI prefix (arm64 2006 → 6)', () {
      expect(AppVersion.fromInstalled('0.4.1', '2006'),
          equals(AppVersion(0, 4, 1, 6)));
      expect(AppVersion.fromInstalled('0.4.1', '1006'),
          equals(AppVersion(0, 4, 1, 6)));
      expect(AppVersion.fromInstalled('0.4.1', '4006'),
          equals(AppVersion(0, 4, 1, 6)));
    });

    test('universal APK (no prefix) is unchanged', () {
      expect(AppVersion.fromInstalled('0.4.1', '6'),
          equals(AppVersion(0, 4, 1, 6)));
    });

    test('a build-only bump is offered to an arm64 install', () {
      final installed = AppVersion.fromInstalled('0.4.1', '2006')!;
      final release = AppVersion.tryParse('v0.4.1+7')!;
      expect(release > installed, isTrue);
      // และตัวเดียวกันต้องไม่ถูกเสนอซ้ำ
      expect(AppVersion.tryParse('v0.4.1+6')! > installed, isFalse);
    });

    test('garbage build number falls back to 0', () {
      expect(AppVersion.fromInstalled('0.4.1', ''),
          equals(AppVersion(0, 4, 1, 0)));
    });
  });
}
