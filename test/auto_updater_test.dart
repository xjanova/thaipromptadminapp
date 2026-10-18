import 'package:flutter_test/flutter_test.dart';
import 'package:thaipromptadmin/core/update/auto_updater.dart';
import 'package:thaipromptadmin/core/update/update_models.dart';

void main() {
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
