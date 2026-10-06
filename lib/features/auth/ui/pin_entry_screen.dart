import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/security/app_lock_controller.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/pin_manager.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/ui/tp.dart';
import '../providers/auth_controller.dart';

/// หน้า PIN — 3 โหมด:
/// - `unlock` ปลดล็อกแอป (เสนอลายนิ้วมือ/ใบหน้าอัตโนมัติ)
/// - `setup`  ตั้ง PIN ครั้งแรก (กรอก 2 รอบ)
/// - `change` เปลี่ยน PIN (เดิม → ใหม่ → ยืนยัน)
///
/// ⚠️ โหมด unlock ถูกวางใน MaterialApp.builder (เหนือ Navigator) — ห้ามใช้ showDialog/SnackBar ในหน้านี้
enum PinScreenMode { unlock, setup, change }

class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen(
      {super.key, required this.mode, this.onSuccess, this.canCancel = false});

  final PinScreenMode mode;
  final VoidCallback? onSuccess;
  final bool canCancel;

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 6;

  /// ผิดครบ 5 → พัก 30 วิ · ครบ 10 → พัก 5 นาที · ครบ 15 → ล้าง PIN + ออกจากระบบ
  static const _wipeAfter = 15;

  String _entry = '';
  String _firstEntry = '';
  String? _oldVerified;
  bool _confirming = false;
  String? _errorMsg;
  bool _busy = false;
  bool _bioAvailable = false;
  List<BiometricType> _bioTypes = const [];
  DateTime? _lockUntil;
  Timer? _lockTicker;
  bool _forgotArmed = false;
  Timer? _forgotTimer;

  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    if (widget.mode == PinScreenMode.unlock) {
      _loadLock();
      _checkBiometric();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _lockTicker?.cancel();
    _forgotTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLock() async {
    final until = await SecureStorage.readPinLockUntil();
    if (!mounted) return;
    if (until != null && until.isAfter(DateTime.now())) _startLock(until);
  }

  void _startLock(DateTime until) {
    _lockTicker?.cancel();
    setState(() => _lockUntil = until);
    _lockTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (DateTime.now().isAfter(until)) {
        t.cancel();
        setState(() {
          _lockUntil = null;
          _errorMsg = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  bool get _locked => _lockUntil != null && _lockUntil!.isAfter(DateTime.now());

  Future<void> _checkBiometric() async {
    final bio = ref.read(biometricServiceProvider);
    final enabled = await bio.isEnabled();
    final supported = await bio.isSupported();
    if (!enabled || !supported) return;
    final types = await bio.availableBiometrics();
    if (!mounted) return;
    setState(() {
      _bioAvailable = true;
      _bioTypes = types;
    });
    if (!_locked) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (_busy || _locked) return;
    setState(() => _busy = true);
    final ok = await ref.read(biometricServiceProvider).authenticate(
          reason: 'ปลดล็อกไทยพร้อม แอดมิน',
          biometricOnly: true,
        );
    if (!mounted) return;
    if (ok) {
      await SecureStorage.resetPinFails();
      _success();
    } else {
      setState(() => _busy = false);
    }
  }

  String get _title => switch (widget.mode) {
        PinScreenMode.unlock => 'ไทยพร้อม แอดมิน',
        PinScreenMode.setup =>
          _confirming ? 'ยืนยัน PIN อีกครั้ง' : 'ตั้งรหัส PIN',
        PinScreenMode.change => _oldVerified == null
            ? 'ใส่ PIN เดิม'
            : (_confirming ? 'ยืนยัน PIN ใหม่' : 'ตั้ง PIN ใหม่'),
      };

  String get _subtitle => switch (widget.mode) {
        PinScreenMode.unlock => 'ใส่รหัส PIN 6 หลักเพื่อเข้าใช้งาน',
        PinScreenMode.setup => _confirming
            ? 'กรอกรหัสเดิมอีกครั้งให้ตรงกัน'
            : 'PIN 6 หลัก ใช้ทุกครั้งที่เปิดแอป',
        PinScreenMode.change => _oldVerified == null
            ? 'ยืนยันตัวตนก่อนเปลี่ยนรหัส'
            : 'PIN 6 หลักชุดใหม่',
      };

  void _onDigit(String d) {
    if (_busy || _locked || _entry.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _entry += d;
      _errorMsg = null;
    });
    if (_entry.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 110), _submit);
    }
  }

  void _onBackspace() {
    if (_busy || _entry.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    if (!mounted) return;
    final pin = _entry;
    final pinManager = ref.read(pinManagerProvider);
    setState(() => _busy = true);

    if (widget.mode == PinScreenMode.unlock) {
      final ok = await pinManager.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        await SecureStorage.resetPinFails();
        HapticFeedback.heavyImpact();
        _success();
        return;
      }
      final fails = await SecureStorage.readPinFails() + 1;
      if (fails >= _wipeAfter) {
        await _wipeAndLogout();
        return;
      }
      DateTime? until;
      if (fails % 5 == 0) {
        until = DateTime.now().add(fails >= 10
            ? const Duration(minutes: 5)
            : const Duration(seconds: 30));
      }
      await SecureStorage.writePinFails(fails, lockUntil: until);
      if (until != null) _startLock(until);
      await _fail(until != null
          ? 'ผิดเกิน $fails ครั้ง · ระบบพักการกรอกชั่วคราว'
          : 'PIN ไม่ถูกต้อง · เหลืออีก ${_wipeAfter - fails} ครั้งก่อนล้างเครื่อง');
      return;
    }

    if (widget.mode == PinScreenMode.change && _oldVerified == null) {
      final ok = await pinManager.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _oldVerified = pin;
          _entry = '';
          _busy = false;
        });
        HapticFeedback.mediumImpact();
      } else {
        await _fail('PIN เดิมไม่ถูกต้อง');
      }
      return;
    }

    if (!_confirming) {
      if (RegExp(r'^(\d)\1{5}$').hasMatch(pin) ||
          pin == '123456' ||
          pin == '654321') {
        await _fail('PIN นี้เดาง่ายเกินไป เลือกชุดอื่น');
        return;
      }
      setState(() {
        _firstEntry = pin;
        _entry = '';
        _confirming = true;
        _busy = false;
      });
      HapticFeedback.mediumImpact();
      return;
    }

    if (pin != _firstEntry) {
      await _fail('PIN สองรอบไม่ตรงกัน เริ่มใหม่อีกครั้ง');
      if (mounted) {
        setState(() {
          _firstEntry = '';
          _confirming = false;
        });
      }
      return;
    }

    try {
      await pinManager.setPin(pin);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _success();
    } catch (_) {
      await _fail('บันทึก PIN ไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _fail(String msg) async {
    if (!mounted) return;
    setState(() {
      _errorMsg = msg;
      _entry = '';
    });
    HapticFeedback.vibrate();
    _shake.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) setState(() => _busy = false);
  }

  /// ลืม PIN / ผิดเกินกำหนด → ล้าง PIN + ลบ token → ต้องเข้าสู่ระบบใหม่ด้วยรหัสผ่านหรือ QR
  Future<void> _wipeAndLogout() async {
    await ref.read(pinManagerProvider).clearPin();
    await ref.read(biometricServiceProvider).setEnabled(false);
    await ref.read(authControllerProvider.notifier).logout();
    ref.read(appLockControllerProvider.notifier).onPinCleared();
  }

  void _onForgot() {
    if (!_forgotArmed) {
      HapticFeedback.mediumImpact();
      setState(() => _forgotArmed = true);
      _forgotTimer?.cancel();
      _forgotTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _forgotArmed = false);
      });
      return;
    }
    _forgotTimer?.cancel();
    _wipeAndLogout();
  }

  void _success() {
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  IconData get _bioIcon => _bioTypes.contains(BiometricType.face) &&
          !_bioTypes.contains(BiometricType.fingerprint)
      ? PhosphorIconsRegular.scanSmiley
      : PhosphorIconsRegular.fingerprint;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final h = size.height;
    // ภาพพื้นหลัง 2:3 แบบ cover ยึดความสูง → วงแหวนทองอยู่ที่ ~26.7% ของความสูง
    final ringY = h * 0.267;
    final keypadKey = math.min(
        72.0, math.max(54.0, (h - ringY - h * 0.15 - 210 - pad.bottom) / 4.6));
    final lockLeft =
        _locked ? _lockUntil!.difference(DateTime.now()).inSeconds + 1 : 0;

    return PopScope(
      canPop: widget.canCancel,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFF05070C),
        ),
        child: Material(
          color: const Color(0xFF05070C),
          child: Stack(children: [
            Positioned.fill(
              child: Image.asset('assets/images/brand/login_bg.webp',
                  fit: BoxFit.cover, alignment: Alignment.topCenter),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x0005070C),
                      Color(0x8C05070C),
                      Color(0xB305070C)
                    ],
                    stops: [0.42, 0.7, 1],
                  ),
                ),
              ),
            ),
            if (widget.canCancel)
              Positioned(
                top: pad.top + 8,
                left: 14,
                child: _GlassRound(
                  icon: PhosphorIconsRegular.x,
                  onTap: () => Navigator.of(context).maybePop(false),
                ),
              ),
            Positioned(
              top: ringY - 38,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset('assets/images/brand/tp-mark.webp',
                    width: 76, cacheWidth: 228),
              ),
            ),
            Positioned(
              top: ringY + h * 0.15,
              left: 0,
              right: 0,
              bottom: pad.bottom + 12,
              child: Column(children: [
                TpFoilText(_title,
                    style: TpType.title(26, Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(_subtitle,
                    style: TpType.body(13.5, const Color(0x9EFFFFFF)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (_, child) => Transform.translate(
                      offset: Offset(
                          math.sin(_shake.value * math.pi * 6) *
                              10 *
                              (1 - _shake.value),
                          0),
                      child: child),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) {
                      final filled = i < _entry.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? const Color(0xFFF0C96A)
                              : Colors.transparent,
                          border: filled
                              ? null
                              : Border.all(
                                  color: const Color(0x59FFFFFF), width: 1.5),
                          boxShadow: filled
                              ? const [
                                  BoxShadow(
                                      color: Color(0xB3F0C96A), blurRadius: 12)
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(
                  height: 30,
                  child: Center(
                    child: Text(
                      _locked
                          ? 'ลองใหม่ได้ใน $lockLeft วินาที'
                          : (_errorMsg ?? ''),
                      textAlign: TextAlign.center,
                      style: TpType.body(12.5, const Color(0xFFFF8A7A),
                          w: FontWeight.w500),
                    ),
                  ),
                ),
                const Spacer(),
                _Keypad(
                  size: keypadKey,
                  enabled: !_busy && !_locked,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  bioIcon: widget.mode == PinScreenMode.unlock && _bioAvailable
                      ? _bioIcon
                      : null,
                  onBio: _tryBiometric,
                ),
                if (widget.mode == PinScreenMode.unlock) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _onForgot,
                    child: Text(
                      _forgotArmed
                          ? 'แตะอีกครั้งเพื่อล้าง PIN และเข้าสู่ระบบใหม่'
                          : 'ลืม PIN?',
                      style: TpType.body(
                          13,
                          _forgotArmed
                              ? const Color(0xFFFF8A7A)
                              : const Color(0xFFF0C96A),
                          w: FontWeight.w600),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.size,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    this.bioIcon,
    this.onBio,
  });

  final double size;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final IconData? bioIcon;
  final VoidCallback? onBio;

  static const _sub = {
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ'
  };

  @override
  Widget build(BuildContext context) {
    Widget key(String k) {
      if (k == 'bio') {
        if (bioIcon == null) return SizedBox(width: size, height: size);
        return _RoundKey(
          size: size,
          gold: true,
          onTap: enabled ? onBio : null,
          child:
              Icon(bioIcon, color: const Color(0xFFF0C96A), size: size * 0.44),
        );
      }
      if (k == 'del') {
        return _RoundKey(
          size: size,
          bare: true,
          onTap: enabled ? onBackspace : null,
          child: Icon(PhosphorIconsRegular.backspace,
              color: const Color(0xA6FFFFFF), size: size * 0.38),
        );
      }
      return _RoundKey(
        size: size,
        onTap: enabled ? () => onDigit(k) : null,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(k,
              style: TpType.money(size * 0.38, Colors.white, w: FontWeight.w500)
                  .copyWith(height: 1)),
          if (_sub[k] != null)
            Text(_sub[k]!,
                style: TpType.body(size * 0.12, const Color(0x73FFFFFF),
                    w: FontWeight.w600, height: 1.3)),
        ]),
      );
    }

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['bio', '0', 'del'],
    ];
    return Column(
      children: rows
          .map((r) => Padding(
                padding: EdgeInsets.only(bottom: size * 0.18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    key(r[0]),
                    SizedBox(width: size * 0.42),
                    key(r[1]),
                    SizedBox(width: size * 0.42),
                    key(r[2])
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _RoundKey extends StatelessWidget {
  const _RoundKey(
      {required this.size,
      required this.child,
      this.onTap,
      this.gold = false,
      this.bare = false});
  final double size;
  final Widget child;
  final VoidCallback? onTap;
  final bool gold;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bare
          ? Colors.transparent
          : (gold ? const Color(0x1FF0C96A) : const Color(0x12FFFFFF)),
      shape: CircleBorder(
        side: bare
            ? BorderSide.none
            : BorderSide(
                color:
                    gold ? const Color(0x66F0C96A) : const Color(0x21FFFFFF)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: const Color(0x33F0C96A),
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Center(child: child)),
      ),
    );
  }
}

class _GlassRound extends StatelessWidget {
  const _GlassRound({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0x14FFFFFF),
        shape: const CircleBorder(side: BorderSide(color: Color(0x24FFFFFF))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: Colors.white, size: 20)),
        ),
      );
}
