import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../providers/auth_controller.dart';

/// หน้าสแกน QR จับคู่เครื่องกับเว็บแอดมิน (`/admin/mobile-pair`)
///
/// QR = "thaipromptadmin://pair/<รหัส 8 ตัว>" หรือรหัส 8 ตัวตรง ๆ
/// เมื่อสแกนติด รหัสจะ "พิมพ์" ออกมาทีละตัว (แบบ Tping) ก่อนส่งให้เซิร์ฟเวอร์
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back);
  bool _processing = false;
  bool _torch = false;
  String _typed = '';
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim() ?? '';
    final code = _extractPairCode(raw);
    if (code == null) return;
    await _pair(code);
  }

  Future<void> _pair(String code) async {
    setState(() {
      _processing = true;
      _error = null;
    });
    await _scanner.stop();
    HapticFeedback.mediumImpact();
    await _typeAnimation(code);
    if (!mounted) return;

    try {
      final notifier = ref.read(authControllerProvider.notifier);
      final result = await notifier.claimPair(code);
      if (!mounted) return;
      if (result.requiresTwoFactor) {
        final otp = await tpPrompt(
          context,
          title: 'ยืนยันรหัส 2FA',
          message:
              'บัญชีนี้เปิดยืนยันสองชั้น กรอกรหัส 6 หลักจากแอป Authenticator',
          hint: '123456',
          maxLines: 1,
        );
        if (!mounted) return;
        if (otp == null) return _reset();
        await notifier.claimPair(code, twoFactorCode: otp);
        if (!mounted) return;
      }
      HapticFeedback.heavyImpact();
      setState(() => _success = true);
      // router พาไปหน้าภาพรวมเองเมื่อสถานะเข้าสู่ระบบเปลี่ยน
    } catch (e) {
      if (!mounted) return;
      _reset(error: tpErrorText(e));
    }
  }

  Future<void> _reset({String? error}) async {
    setState(() {
      _processing = false;
      _typed = '';
      _error = error;
    });
    try {
      await _scanner.start();
    } catch (_) {}
  }

  Future<void> _typeAnimation(String code) async {
    setState(() => _typed = '');
    for (var i = 0; i < code.length; i++) {
      await Future.delayed(const Duration(milliseconds: 75));
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _typed = code.substring(0, i + 1));
    }
    await Future.delayed(const Duration(milliseconds: 220));
  }

  String? _extractPairCode(String raw) {
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'thaipromptadmin' && uri.host == 'pair') {
      final c = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (_valid(c)) return c.toUpperCase();
    }
    if (_valid(raw)) return raw.toUpperCase();
    return null;
  }

  bool _valid(String s) => RegExp(r'^[A-Z0-9]{8}$').hasMatch(s.toUpperCase());

  Future<void> _enterManually() async {
    final code = await tpPrompt(
      context,
      title: 'กรอกรหัสจับคู่',
      message: 'รหัส 8 ตัวที่แสดงใต้ QR บนหน้าเว็บ',
      hint: 'ABCD2345',
      maxLines: 1,
    );
    if (code == null || !mounted) return;
    if (!_valid(code)) {
      setState(() => _error = 'รหัสต้องเป็นตัวอักษร A-Z หรือตัวเลข 8 ตัว');
      return;
    }
    await _pair(code.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final box = w * 0.68;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scanner,
              onDetect: _onDetect,
              errorBuilder: (context, error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'ไม่ได้รับอนุญาตให้ใช้กล้อง\nเปิดสิทธิ์กล้องในการตั้งค่าเครื่อง หรือกรอกรหัสด้วยมือ'
                        : 'เปิดกล้องไม่ได้ · กรอกรหัสด้วยมือแทน',
                    textAlign: TextAlign.center,
                    style: TpType.body(14, Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          // ม่านมืดรอบกรอบสแกน
          Positioned.fill(
              child: CustomPaint(painter: _ScanMaskPainter(box: box))),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(children: [
                  _RoundBtn(
                      icon: PhosphorIconsRegular.caretLeft,
                      onTap: () => Navigator.maybePop(context)),
                  const Spacer(),
                  _RoundBtn(
                    icon: _torch
                        ? PhosphorIconsFill.flashlight
                        : PhosphorIconsRegular.flashlight,
                    gold: _torch,
                    onTap: () {
                      _scanner.toggleTorch();
                      setState(() => _torch = !_torch);
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Text('จับคู่เครื่องนี้', style: TpType.title(24, Colors.white)),
              const SizedBox(height: 4),
              Text('สแกน QR จากหน้า /admin/mobile-pair บนเว็บ',
                  style: TpType.body(13.5, const Color(0xB3FFFFFF))),
              const Spacer(),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x33FF7A6B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x66FF7A6B)),
                  ),
                  child: Row(children: [
                    const Icon(PhosphorIconsFill.warningCircle,
                        color: Color(0xFFFF8A7A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TpType.body(13, Colors.white))),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: TpButton.outline('กรอกรหัสด้วยมือ',
                    icon: PhosphorIconsRegular.keyboard,
                    onPressed: _processing ? null : _enterManually),
              ),
            ]),
          ),
          if (_processing) Positioned.fill(child: _typingOverlay()),
        ]),
      ),
    );
  }

  Widget _typingOverlay() {
    return Container(
      color: const Color(0xEB05070C),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _success
              ? const Tp3D(TpArt.emptyDone, size: 120, key: ValueKey('ok'))
              : Container(
                  key: const ValueKey('code'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x66F0C96A)),
                    color: const Color(0x14F0C96A),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_typed.padRight(8, '·'),
                        style: TpType.money(30, const Color(0xFFF0C96A),
                            w: FontWeight.w700)),
                    const _Caret(),
                  ]),
                ),
        ),
        const SizedBox(height: 20),
        Text(_success ? 'จับคู่สำเร็จ' : 'กำลังจับคู่กับเซิร์ฟเวอร์…',
            style: TpType.h(
                16, _success ? const Color(0xFF3DDC84) : Colors.white)),
      ]),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret();
  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(
            width: 2.5,
            height: 30,
            margin: const EdgeInsets.only(left: 4),
            color: const Color(0xFFF0C96A)),
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.gold = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) => Material(
        color: gold ? const Color(0x33F0C96A) : const Color(0x26000000),
        shape: CircleBorder(
            side: BorderSide(
                color:
                    gold ? const Color(0x99F0C96A) : const Color(0x33FFFFFF))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon,
                  color: gold ? const Color(0xFFF0C96A) : Colors.white,
                  size: 21)),
        ),
      );
}

/// ม่านมืดรอบกรอบสแกน + มุมทอง 4 มุม
class _ScanMaskPainter extends CustomPainter {
  _ScanMaskPainter({required this.box});
  final double box;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.47),
        width: box,
        height: box);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(26));
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rr)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = const Color(0xB305070C));

    final p = Paint()
      ..color = const Color(0xFFF0C96A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 34.0, r = 26.0;
    void corner(Offset o, double dx, double dy) {
      final path = Path()
        ..moveTo(o.dx, o.dy + dy * l)
        ..lineTo(o.dx, o.dy + dy * r)
        ..arcToPoint(Offset(o.dx + dx * r, o.dy),
            radius: const Radius.circular(r), clockwise: dx * dy > 0)
        ..lineTo(o.dx + dx * l, o.dy);
      canvas.drawPath(path, p);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ScanMaskPainter old) => old.box != box;
}
