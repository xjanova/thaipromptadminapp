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
      expect(AutoUpdater.installErrorMessage(null), contains('ติดตั้งไม่สำเร็จ'));
      expect(AutoUpdater.installErrorMessage('weird'), isNot(contains('weird')));
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
}
