import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pin_manager.dart';

/// AppLockController — ดูแล PIN gate ระดับแอพ
///
/// Logic:
/// - state `unlocked = true` = ผ่าน PIN แล้ว (หรือไม่ตั้ง PIN)
/// - เมื่อแอพถูก background นานเกิน `lockTimeout` → set unlocked=false
/// - PIN screen subscribes provider แล้ว block หน้าจอ admin app
class AppLockState {
  AppLockState({required this.hasPin, required this.unlocked});

  /// User ตั้ง PIN ไหม
  final bool hasPin;

  /// ผ่าน PIN แล้ว (auto true ถ้า hasPin = false)
  final bool unlocked;

  AppLockState copyWith({bool? hasPin, bool? unlocked}) => AppLockState(
        hasPin: hasPin ?? this.hasPin,
        unlocked: unlocked ?? this.unlocked,
      );

  /// ควรแสดง PIN screen หรือไม่
  bool get needsUnlock => hasPin && !unlocked;
}

class AppLockController extends StateNotifier<AppLockState>
    with WidgetsBindingObserver {
  AppLockController(this._pin)
      : super(AppLockState(hasPin: false, unlocked: true)) {
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  final PinManager _pin;

  /// ถ้า app background นานกว่านี้ → lock ใหม่
  static const _lockTimeout = Duration(minutes: 5);

  DateTime? _backgroundedAt;

  Future<void> _bootstrap() async {
    final has = await _pin.hasPin();
    state = AppLockState(hasPin: has, unlocked: !has);
  }

  /// เรียกหลัง user ตั้ง PIN ครั้งแรก (จาก Settings)
  Future<void> refresh() async {
    final has = await _pin.hasPin();
    state = state.copyWith(hasPin: has, unlocked: has ? state.unlocked : true);
  }

  /// User ปลด PIN ผ่านแล้ว
  void markUnlocked() {
    state = state.copyWith(unlocked: true);
    _backgroundedAt = null;
  }

  /// บังคับ lock — เรียกตอน user logout
  void lock() {
    state = state.copyWith(unlocked: false);
  }

  /// User ลบ PIN ใน Settings
  void onPinCleared() {
    state = AppLockState(hasPin: false, unlocked: true);
  }

  /// User ตั้ง PIN ใหม่ใน Settings → still considered unlocked เพราะเพิ่งพิสูจน์ตัวตน
  void onPinSet() {
    state = AppLockState(hasPin: true, unlocked: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!this.state.hasPin) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _backgroundedAt ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        if (_backgroundedAt != null) {
          final elapsed = DateTime.now().difference(_backgroundedAt!);
          if (elapsed > _lockTimeout) {
            this.state = this.state.copyWith(unlocked: false);
          }
          _backgroundedAt = null;
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(ref.watch(pinManagerProvider));
});
