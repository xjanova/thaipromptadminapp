import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/security/biometric_service.dart';
import '../../../core/security/pin_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/starfield.dart';

/// PIN entry screen — 3 modes:
/// - `unlock`: ยืนยัน PIN เพื่อเข้าใช้แอพ (เสนอ biometric เสริม)
/// - `setup`: ตั้ง PIN ครั้งแรก (กรอก 2 รอบเพื่อยืนยัน)
/// - `change`: เปลี่ยน PIN (ต้องกรอกตัวเก่า → ใหม่ → ยืนยันใหม่)
enum PinScreenMode { unlock, setup, change }

class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({
    super.key,
    required this.mode,
    this.onSuccess,
    this.canCancel = false,
  });

  final PinScreenMode mode;
  final VoidCallback? onSuccess;
  final bool canCancel;

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  static const _pinLength = 6;
  String _entry = '';
  String _firstEntry = ''; // setup/change: เก็บ PIN รอบแรกก่อน confirm
  String? _oldVerified; // change: PIN เก่าที่ verify แล้ว
  String _phase = 'enter'; // enter | confirm | error
  String? _errorMsg;
  int _failedAttempts = 0;
  bool _busy = false;
  bool _biometricAvailable = false;
  List<BiometricType> _biometricTypes = const [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == PinScreenMode.unlock) {
      _checkBiometric();
    }
  }

  Future<void> _checkBiometric() async {
    final bio = ref.read(biometricServiceProvider);
    final enabled = await bio.isEnabled();
    final supported = await bio.isSupported();
    if (!enabled || !supported) return;
    final types = await bio.availableBiometrics();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = true;
      _biometricTypes = types;
    });
    // Auto-prompt biometric on screen open (1 attempt)
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bio = ref.read(biometricServiceProvider);
    final ok = await bio.authenticate(
      reason: 'ปลดล็อก Thaiprompt Admin',
      biometricOnly: true,
    );
    if (!mounted) return;
    if (ok) {
      _success();
    } else {
      setState(() => _busy = false);
    }
  }

  String get _title => switch (widget.mode) {
        PinScreenMode.unlock => 'ปลดล็อกแอพ',
        PinScreenMode.setup => _phase == 'confirm'
            ? 'ยืนยัน PIN ของคุณอีกครั้ง'
            : 'ตั้ง PIN ป้องกัน',
        PinScreenMode.change => _oldVerified == null
            ? 'กรอก PIN เดิม'
            : (_phase == 'confirm' ? 'ยืนยัน PIN ใหม่' : 'ตั้ง PIN ใหม่'),
      };

  String get _subtitle => switch (widget.mode) {
        PinScreenMode.unlock => 'เพื่อรักษาความปลอดภัยของบัญชี Super Admin',
        PinScreenMode.setup =>
          _phase == 'confirm' ? '' : 'PIN 6 หลัก · ใช้ทุกครั้งที่เปิดแอพ',
        PinScreenMode.change => _oldVerified == null ? '' : '',
      };

  Future<void> _onDigit(String d) async {
    if (_busy) return;
    if (_entry.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _entry += d;
      _errorMsg = null;
    });
    if (_entry.length == _pinLength) {
      await Future.delayed(const Duration(milliseconds: 120));
      _submit();
    }
  }

  void _onBackspace() {
    if (_busy || _entry.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entry = _entry.substring(0, _entry.length - 1);
      _errorMsg = null;
    });
  }

  Future<void> _submit() async {
    final pin = _entry;
    final pinManager = ref.read(pinManagerProvider);

    setState(() => _busy = true);

    if (widget.mode == PinScreenMode.unlock) {
      final ok = await pinManager.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        HapticFeedback.heavyImpact();
        _success();
      } else {
        _failedAttempts++;
        await _shakeAndClear('PIN ไม่ถูกต้อง · ลองอีกครั้ง');
        if (_failedAttempts >= 5) {
          await _shakeAndClear('ลองผิดเกิน 5 ครั้ง · รอ 30 วินาที',
              cooldown: const Duration(seconds: 30));
          _failedAttempts = 0;
        }
      }
      return;
    }

    if (widget.mode == PinScreenMode.change && _oldVerified == null) {
      final ok = await pinManager.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _oldVerified = pin;
          _entry = '';
          _phase = 'enter';
          _busy = false;
        });
        HapticFeedback.mediumImpact();
      } else {
        await _shakeAndClear('PIN เดิมไม่ถูกต้อง');
      }
      return;
    }

    // setup OR change(new) flow
    if (_phase == 'enter') {
      setState(() {
        _firstEntry = pin;
        _entry = '';
        _phase = 'confirm';
        _busy = false;
      });
      HapticFeedback.mediumImpact();
      return;
    }

    // _phase == 'confirm' — เทียบกับ _firstEntry
    if (pin != _firstEntry) {
      await _shakeAndClear('PIN ไม่ตรงกัน · ลองใหม่');
      setState(() {
        _firstEntry = '';
        _phase = 'enter';
      });
      return;
    }

    // Save
    try {
      await pinManager.setPin(pin);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _success();
    } catch (e) {
      if (!mounted) return;
      await _shakeAndClear('ตั้ง PIN ไม่สำเร็จ: $e');
    }
  }

  Future<void> _shakeAndClear(String msg, {Duration? cooldown}) async {
    setState(() {
      _errorMsg = msg;
      _phase = 'error';
      _entry = '';
    });
    HapticFeedback.vibrate();
    if (cooldown != null) {
      await Future.delayed(cooldown);
    } else {
      await Future.delayed(const Duration(milliseconds: 600));
    }
    if (!mounted) return;
    setState(() {
      _phase = widget.mode == PinScreenMode.unlock ? 'enter' : _phase;
      _busy = false;
    });
  }

  void _success() {
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canCancel,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0A1F),
        body: Stack(
          children: [
            // Cosmic bg
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.6),
                    radius: 1.4,
                    colors: [
                      Color(0xFF4C1D95),
                      Color(0xFF1E1B4B),
                      Color(0xFF0F0A1F),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: Starfield(starCount: 50)),

            SafeArea(
              child: Column(
                children: [
                  // Top bar with cancel
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        if (widget.canCancel)
                          IconButton(
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            icon: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Lock icon
                  ClayBall(
                    size: 70,
                    hue: 280,
                    saturation: 0.85,
                    lightness: 0.65,
                    child: Icon(
                      widget.mode == PinScreenMode.unlock
                          ? Icons.lock_outline
                          : Icons.lock_reset,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Title
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (_subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // 6 dots
                  _pinDots(),

                  const SizedBox(height: 14),

                  // Error / phase hint
                  SizedBox(
                    height: 24,
                    child: _errorMsg != null
                        ? Text(
                            _errorMsg!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ).animate().shakeX(
                              duration: const Duration(milliseconds: 400),
                              hz: 6,
                              amount: 6)
                        : const SizedBox.shrink(),
                  ),

                  const Spacer(),

                  // Number pad
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: _numpad(),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // UI parts
  // ────────────────────────────────────────────────────────────

  Widget _pinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < _entry.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: filled ? 14 : 12,
          height: filled ? 14 : 12,
          decoration: BoxDecoration(
            color: filled ? AppColors.purpleStart : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: filled
                  ? AppColors.purpleStart
                  : Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: AppColors.purpleStart.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _numpad() {
    // 3x4 grid: 1-9, then biometric/0/backspace
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['bio', '0', 'back'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map(_keyButton).toList(),
            ),
          ),
      ],
    );
  }

  Widget _keyButton(String key) {
    if (key == 'bio') {
      final show = widget.mode == PinScreenMode.unlock && _biometricAvailable;
      if (!show) return const SizedBox(width: 68, height: 68);
      final icon = _biometricTypes.contains(BiometricType.face)
          ? Icons.face_outlined
          : Icons.fingerprint;
      return _keyTile(
        onTap: _busy ? null : _tryBiometric,
        child: Icon(icon, color: AppColors.cyanStart, size: 30),
      );
    }
    if (key == 'back') {
      return _keyTile(
        onTap: _busy ? null : _onBackspace,
        child: const Icon(Icons.backspace_outlined,
            color: Colors.white, size: 22),
      );
    }
    return _keyTile(
      onTap: _busy ? null : () => _onDigit(key),
      child: Text(
        key,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _keyTile({required Widget child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}
