import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../shared/widgets/starfield.dart';
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

  /// แต่ละตัวอักษรของ code ที่ "พิมพ์" ออกมา (animation แบบ Tping)
  String _typedCode = '';
  bool _showSuccess = false;
  Timer? _typeTimer;

  @override
  void dispose() {
    _scannerController.dispose();
    _typeTimer?.cancel();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim() ?? '';
    final code = _extractPairCode(raw);
    if (code == null) return;

    setState(() => _processing = true);
    await _scannerController.stop();
    HapticFeedback.mediumImpact();

    // ── Tping-style typing animation: พิมพ์ code ทีละตัว ──
    await _typeAnimation(code);

    try {
      final result =
          await ref.read(authControllerProvider.notifier).claimPair(code);
      if (!mounted) return;
      if (result.requiresTwoFactor) {
        // ขอ 2FA — ขออีกครั้งพร้อม code
        final code2fa = await _ask2faCode();
        if (code2fa == null || !mounted) {
          setState(() {
            _processing = false;
            _typedCode = '';
          });
          await _scannerController.start();
          return;
        }
        await ref
            .read(authControllerProvider.notifier)
            .claimPair(code, twoFactorCode: code2fa);
        if (!mounted) return;
      }
      // success — flash green checkmark
      HapticFeedback.heavyImpact();
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 850));
      // router จะ redirect ไป dashboard เพราะ auth state เปลี่ยน
    } on ApiException catch (e) {
      _showError(e.message);
      setState(() {
        _processing = false;
        _typedCode = '';
      });
      await _scannerController.start();
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _processing = false;
        _typedCode = '';
      });
      await _scannerController.start();
    }
  }

  /// Type code char-by-char (Tping-style auto-typing UX)
  Future<void> _typeAnimation(String code) async {
    setState(() => _typedCode = '');
    for (var i = 0; i < code.length; i++) {
      await Future.delayed(const Duration(milliseconds: 75));
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _typedCode = code.substring(0, i + 1));
    }
    await Future.delayed(const Duration(milliseconds: 200));
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

  Widget _typingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Stack(
        children: [
          const Positioned.fill(child: Starfield(starCount: 40, seed: 99)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tping-style typed code with caret
                _showSuccess
                    ? _successCheck()
                    : _typedCodeView(),
                const SizedBox(height: 22),
                Text(
                  _showSuccess
                      ? '✨ จับคู่อุปกรณ์สำเร็จ'
                      : 'กำลังจับคู่กับเซิร์ฟเวอร์...',
                  style: TextStyle(
                    color: _showSuccess ? AppColors.success : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate(key: ValueKey(_showSuccess)).fadeIn(
                    duration: const Duration(milliseconds: 300)),
                if (!_showSuccess) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'รหัสถูกส่งให้ระบบแล้ว',
                    style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typedCodeView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.purpleStart, AppColors.pinkStart],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.pinkStart.withValues(alpha: 0.5),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _typedCode,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          // Blinking caret
          Container(
            width: 3,
            height: 32,
            margin: const EdgeInsets.only(left: 4),
            color: Colors.white,
          ).animate(
            onPlay: (c) => c.repeat(reverse: true),
          ).fadeIn(duration: const Duration(milliseconds: 380)),
        ],
      ),
    );
  }

  Widget _successCheck() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.success, Color(0xFF15803D)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.6),
            blurRadius: 26,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 56),
    ).animate().scale(
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
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

          if (_processing) _typingOverlay(),

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
