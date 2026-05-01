import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../providers/auth_controller.dart';

/// หน้าสแกน QR สำหรับ pair กับเว็บ
///
/// QR ที่สแกนได้จะเป็น "thaipromptadmin://pair/<8-char-code>" หรือ string 8 ตัว
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _processing = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim() ?? '';
    final code = _extractPairCode(raw);
    if (code == null) return;

    setState(() => _processing = true);
    await _scannerController.stop();

    try {
      final result =
          await ref.read(authControllerProvider.notifier).claimPair(code);
      if (!mounted) return;
      if (result.requiresTwoFactor) {
        // ขอ 2FA — ขออีกครั้งพร้อม code
        final code2fa = await _ask2faCode();
        if (code2fa == null || !mounted) {
          setState(() => _processing = false);
          await _scannerController.start();
          return;
        }
        await ref
            .read(authControllerProvider.notifier)
            .claimPair(code, twoFactorCode: code2fa);
        if (!mounted) return;
        // router จะ redirect ไป dashboard
      }
    } on ApiException catch (e) {
      _showError(e.message);
      setState(() => _processing = false);
      await _scannerController.start();
    } catch (e) {
      _showError(e.toString());
      setState(() => _processing = false);
      await _scannerController.start();
    }
  }

  Future<String?> _ask2faCode() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title:
            const Text('ยืนยันรหัส 2FA', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          maxLength: 8,
          style: const TextStyle(
              color: Colors.white, letterSpacing: 6, fontSize: 20),
          decoration: const InputDecoration(
            hintText: '123456',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('ยืนยัน')),
        ],
      ),
    );
    return result;
  }

  /// แปลง raw QR เป็น pair_code 8 ตัว
  String? _extractPairCode(String raw) {
    if (raw.isEmpty) return null;

    // 1. ถ้าเป็น deep link "thaipromptadmin://pair/XXX"
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'thaipromptadmin' && uri.host == 'pair') {
      final code = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (_isValidCode(code)) return code.toUpperCase();
    }

    // 2. ถ้าเป็น string 8 ตัวตรงๆ
    if (_isValidCode(raw)) return raw.toUpperCase();

    return null;
  }

  bool _isValidCode(String s) {
    if (s.length != 8) return false;
    return RegExp(r'^[A-Z0-9]{8}$').hasMatch(s.toUpperCase());
  }

  Future<void> _enterManually() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title:
            const Text('กรอกรหัสจับคู่', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
          maxLength: 8,
          style: const TextStyle(
              color: Colors.white, letterSpacing: 8, fontSize: 22),
          decoration: const InputDecoration(hintText: 'ABCD2345'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (code != null && _isValidCode(code)) {
      await _onDetect(BarcodeCapture(barcodes: [
        Barcode(rawValue: code),
      ]));
    } else if (code != null) {
      _showError('รหัสต้องเป็น 8 ตัว A-Z 0-9');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgRoot,
      appBar: AppBar(
        title: Text(l10n.qrScannerTitle),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay frame
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7), width: 3),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purpleStart.withValues(alpha: 0.4),
                    blurRadius: 24,
                  ),
                ],
              ),
            ),
          ),

          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 14),
                    Text('กำลังจับคู่...',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),

          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.qrScannerHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _enterManually,
                      icon: const Icon(Icons.keyboard, color: Colors.white),
                      label: Text(l10n.qrScannerEnterManually,
                          style: const TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
