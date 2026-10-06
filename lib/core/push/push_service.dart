import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import '../storage/secure_storage.dart';

/// สถานะแจ้งเตือนของเครื่องนี้ (แสดงในหน้าบัญชี)
enum PushStatus { unavailable, denied, enabled }

/// แจ้งเตือนเข้ามือถือ (FCM โปรเจกต์ plptdb) — งานด่วนเด้งแม้ปิดแอปอยู่
///
/// - เซิร์ฟเวอร์ส่งเมื่อคิวงานเพิ่ม (ลูกค้าขอคุย / บิลรอตรวจ / ถอนเงิน / SMS / งานค้าง) พร้อม data.route
/// - แตะแจ้งเตือน → เปิดหน้าตาม route (เช่น /chat, /work?tab=bills)
/// - ไม่มี google-services.json ตอน build = ทำงานต่อได้ แต่สถานะเป็น unavailable
class PushService {
  PushService(this._api);
  final ApiClient _api;

  static const channelId = 'admin_alerts';
  final _local = FlutterLocalNotificationsPlugin();
  final _routes = StreamController<String>.broadcast();
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _openSub;
  bool _ready = false;
  String? _token;

  /// route ที่ผู้ใช้แตะจากแจ้งเตือน — router ฟังแล้วเปิดหน้า
  Stream<String> get routes => _routes.stream;

  Future<bool> _ensureFirebase() async {
    if (_ready) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      await _local.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('@drawable/ic_stat_tp')),
        onDidReceiveNotificationResponse: (r) {
          final route = r.payload;
          if (route != null && route.startsWith('/')) _routes.add(route);
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            channelId,
            'งานด่วนของแอดมิน',
            description: 'ลูกค้าขอคุยกับแอดมิน บิลรอตรวจ ถอนเงิน และงานค้าง',
            importance: Importance.high,
          ));
      _ready = true;
      return true;
    } catch (e) {
      debugPrint('push: firebase unavailable');
      return false;
    }
  }

  /// เรียกหลังเข้าสู่ระบบสำเร็จ / เปิดแอปโดยมี session อยู่แล้ว
  Future<PushStatus> start() async {
    if (!await _ensureFirebase()) return PushStatus.unavailable;
    final fm = FirebaseMessaging.instance;
    final perm = await fm.requestPermission();
    if (perm.authorizationStatus == AuthorizationStatus.denied) {
      return PushStatus.denied;
    }

    _token = await fm.getToken();
    if (_token != null) await _register(_token!);
    await _tokenSub?.cancel();
    _tokenSub = fm.onTokenRefresh.listen((t) {
      _token = t;
      _register(t);
    });

    // แอปเปิดอยู่: แสดงแจ้งเตือนเองผ่าน local notification (FCM ไม่แสดงให้ตอน foreground)
    await _fgSub?.cancel();
    _fgSub = FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      _local.show(
        id: m.messageId.hashCode & 0x7fffffff,
        title: n.title,
        body: n.body,
        payload: m.data['route']?.toString(),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'งานด่วนของแอดมิน',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFFF0C96A),
            icon: '@drawable/ic_stat_tp',
          ),
        ),
      );
    });

    // แตะแจ้งเตือนตอนแอปอยู่เบื้องหลัง / ตอนแอปปิดอยู่
    await _openSub?.cancel();
    _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_openFrom);
    final initial = await fm.getInitialMessage();
    if (initial != null) _openFrom(initial);
    return PushStatus.enabled;
  }

  void _openFrom(RemoteMessage m) {
    final route = m.data['route']?.toString();
    if (route != null && route.startsWith('/')) _routes.add(route);
  }

  Future<void> _register(String token) async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      await _api.post<dynamic>('/devices/push-token', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'device_id': await SecureStorage.readDeviceId(),
        'app_version': '${pkg.version}+${pkg.buildNumber}',
      });
    } catch (_) {
      // เซิร์ฟเวอร์ยังไม่รองรับ / ออฟไลน์ — ลองใหม่รอบหน้าที่เปิดแอป
    }
  }

  /// ออกจากระบบ: ถอนโทเคนจากเซิร์ฟเวอร์ + ลบโทเคนในเครื่อง (ไม่ให้แจ้งเตือนหลุดไปเครื่องที่ออกแล้ว)
  Future<void> stop() async {
    final t = _token;
    _token = null;
    await _tokenSub?.cancel();
    await _fgSub?.cancel();
    await _openSub?.cancel();
    if (!_ready) return;
    try {
      if (t != null) {
        await _api.delete<dynamic>('/devices/push-token', data: {'token': t});
      }
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<PushStatus> status() async {
    if (!await _ensureFirebase()) return PushStatus.unavailable;
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    return s.authorizationStatus == AuthorizationStatus.denied
        ? PushStatus.denied
        : PushStatus.enabled;
  }
}

final pushServiceProvider =
    Provider<PushService>((ref) => PushService(ref.watch(apiClientProvider)));
