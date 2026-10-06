import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/api_envelope.dart';
import '../../core/theme/tp_palette.dart';
import '../../core/theme/tp_theme.dart';
import 'tp_kit.dart';

/// แปลง error ทุกแบบเป็นข้อความไทยที่แอดมินอ่านเข้าใจ — ห้ามโชว์ "Exception:" ดิบ
String tpErrorText(Object? e) {
  if (e is ActionError) return e.message;
  if (e is ApiException) {
    if (e.statusCode == 401) return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่';
    if (e.statusCode == 403) return 'บัญชีนี้ไม่มีสิทธิ์ทำรายการนี้';
    if (e.statusCode == 404) {
      return 'ไม่พบข้อมูลนี้ในระบบ (อาจถูกลบหรือเปลี่ยนสถานะไปแล้ว)';
    }
    if (e.statusCode == 422) {
      final first = e.errors?.values
          .expand((v) => v is List ? v : [v])
          .map((v) => v.toString())
          .firstOrNull;
      return first ?? (e.message.isNotEmpty ? e.message : 'ข้อมูลไม่ถูกต้อง');
    }
    if (e.statusCode == 429) return 'ทำรายการถี่เกินไป รอสักครู่แล้วลองใหม่';
    return e.message.isNotEmpty
        ? e.message
        : 'เซิร์ฟเวอร์ตอบกลับผิดปกติ (${e.statusCode})';
  }
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'เซิร์ฟเวอร์ตอบช้าเกินไป ลองใหม่อีกครั้ง';
      case DioExceptionType.connectionError:
        return 'เชื่อมต่ออินเทอร์เน็ตไม่ได้';
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        final msg = data is Map ? data['message']?.toString() : null;
        final code = e.response?.statusCode ?? 0;
        if (msg != null && msg.isNotEmpty) return msg;
        return code >= 500
            ? 'เซิร์ฟเวอร์ขัดข้องชั่วคราว ($code)'
            : 'คำขอไม่สำเร็จ ($code)';
      case DioExceptionType.cancel:
        return 'ยกเลิกคำขอแล้ว';
      default:
        return 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ';
    }
  }
  if (e is TimeoutException) return 'รอนานเกินไป ลองใหม่อีกครั้ง';
  if (e is FormatException) return 'ข้อมูลจากเซิร์ฟเวอร์อ่านไม่ได้';
  return 'เกิดข้อผิดพลาดที่ไม่คาดคิด';
}

bool tpIsOffline(Object? e) =>
    e is DioException &&
    (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout);

/// แถบกระพริบตอนโหลดครั้งแรก
class TpSkeleton extends StatefulWidget {
  const TpSkeleton({super.key, this.height = 16, this.width, this.radius = 10});
  final double height;
  final double? width;
  final double radius;

  @override
  State<TpSkeleton> createState() => _TpSkeletonState();
}

class _TpSkeletonState extends State<TpSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final base = p.isDark ? const Color(0x14FFFFFF) : const Color(0x0F10223F);
    final hi = p.isDark ? const Color(0x24FFFFFF) : const Color(0x1C10223F);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + _c.value * 3, 0),
            end: Alignment(-0.5 + _c.value * 3, 0),
            colors: [base, hi, base],
          ),
        ),
      ),
    );
  }
}

/// รายการโครงกระพริบ (แทนสปินเนอร์เต็มจอ)
class TpSkeletonList extends StatelessWidget {
  const TpSkeletonList(
      {super.key,
      this.count = 5,
      this.itemHeight = 74,
      this.padding = EdgeInsets.zero});
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: List.generate(
          count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TpCard(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                height: itemHeight - 28,
                child: Row(children: [
                  const TpSkeleton(width: 42, height: 42, radius: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TpSkeleton(height: 13, width: 120 + (i % 3) * 30.0),
                          const SizedBox(height: 8),
                          TpSkeleton(height: 10, width: 80 + (i % 2) * 40.0),
                        ]),
                  ),
                  const TpSkeleton(width: 46, height: 18),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// หน้าว่าง/ไม่มีข้อมูล (ภาพ 3D + ข้อความ + ปุ่ม)
class TpEmpty extends StatelessWidget {
  const TpEmpty({
    super.key,
    this.art = TpArt.emptyInbox,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });
  final TpArt art;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: 28, vertical: compact ? 18 : 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Tp3D(art, size: compact ? 84 : 128),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center, style: TpType.h(16.5, p.textStrong)),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(message!,
              textAlign: TextAlign.center, style: TpType.body(13.5, p.muted)),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          TpButton(actionLabel!,
              onPressed: onAction, expand: false, height: 44),
        ],
      ]),
    );
  }
}

/// มุมมอง error พร้อมปุ่มลองใหม่
class TpErrorView extends StatelessWidget {
  const TpErrorView(
      {super.key, required this.error, this.onRetry, this.compact = false});
  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final offline = tpIsOffline(error);
    return TpEmpty(
      art: offline ? TpArt.emptyOffline : TpArt.shield,
      title: offline ? 'ออฟไลน์อยู่' : 'โหลดข้อมูลไม่สำเร็จ',
      message: tpErrorText(error),
      actionLabel: onRetry == null ? null : 'ลองใหม่',
      onAction: onRetry,
      compact: compact,
    );
  }
}

/// ตัวแสดง AsyncValue มาตรฐาน:
/// - โหลดครั้งแรก = โครงกระพริบ
/// - รีเฟรช = คงข้อมูลเดิมไว้ (ไม่กระพริบเต็มจอ — กับดัก "Loading state flash")
/// - error ครั้งแรก = TpErrorView · error ตอนรีเฟรช = คงข้อมูลเดิม
class TpAsync<T> extends StatelessWidget {
  const TpAsync(
      {super.key,
      required this.value,
      required this.data,
      this.loading,
      this.onRetry,
      this.compactError = false});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool compactError;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return data(value.requireValue);
    if (value.hasError) {
      return TpErrorView(
          error: value.error, onRetry: onRetry, compact: compactError);
    }
    return loading ?? const TpSkeletonList();
  }
}

enum TpToastKind { success, error, info }

/// แจ้งผลสั้น ๆ ด้านล่างจอ
void tpToast(BuildContext context, String message,
    {TpToastKind kind = TpToastKind.info}) {
  final icon = switch (kind) {
    TpToastKind.success => PhosphorIconsFill.checkCircle,
    TpToastKind.error => PhosphorIconsFill.warningCircle,
    TpToastKind.info => PhosphorIconsFill.info,
  };
  final color = switch (kind) {
    TpToastKind.success => const Color(0xFF3DDC84),
    TpToastKind.error => const Color(0xFFFF7A6B),
    TpToastKind.info => const Color(0xFFF0C96A),
  };
  if (kind == TpToastKind.error) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.lightImpact();
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    duration: Duration(milliseconds: kind == TpToastKind.error ? 4200 : 2600),
    content: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message)),
    ]),
  ));
}

/// กล่องยืนยันก่อนทำรายการที่ย้อนกลับไม่ได้ — คืน true เมื่อกดยืนยัน
Future<bool> tpConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'ยืนยัน',
  String cancelLabel = 'ยกเลิก',
  bool danger = false,
}) async {
  final p = context.tp;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(children: [
          Expanded(
              child: TpButton.outline(cancelLabel,
                  height: 46, onPressed: () => Navigator.pop(ctx, false))),
          const SizedBox(width: 10),
          Expanded(
            child: danger
                ? TpButton.danger(confirmLabel,
                    height: 46, onPressed: () => Navigator.pop(ctx, true))
                : TpButton(confirmLabel,
                    height: 46, onPressed: () => Navigator.pop(ctx, true)),
          ),
        ]),
      ],
      backgroundColor: p.sheet,
    ),
  );
  return ok ?? false;
}

/// ถามข้อความ (เช่น เหตุผลที่ปฏิเสธ) — คืน null ถ้ายกเลิก
Future<String?> tpPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String hint = '',
  String confirmLabel = 'ยืนยัน',
  bool required = true,
  bool danger = false,
  int maxLines = 3,
}) async {
  final ctrl = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final ok = !required || ctrl.text.trim().isNotEmpty;
        return AlertDialog(
          title: Text(title),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message != null) ...[
                  Text(message),
                  const SizedBox(height: 12)
                ],
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: maxLines,
                  minLines: 1,
                  decoration: InputDecoration(hintText: hint),
                  onChanged: (_) => setLocal(() {}),
                ),
              ]),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(children: [
              Expanded(
                  child: TpButton.outline('ยกเลิก',
                      height: 46, onPressed: () => Navigator.pop(ctx))),
              const SizedBox(width: 10),
              Expanded(
                child: danger
                    ? TpButton.danger(confirmLabel,
                        height: 46,
                        onPressed: ok
                            ? () => Navigator.pop(ctx, ctrl.text.trim())
                            : null)
                    : TpButton(confirmLabel,
                        height: 46,
                        onPressed: ok
                            ? () => Navigator.pop(ctx, ctrl.text.trim())
                            : null),
              ),
            ]),
          ],
        );
      }),
    );
  } finally {
    // ปล่อย controller หลังกล่องปิด (หน่วงหนึ่งเฟรมให้แอนิเมชันปิดจบก่อน)
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  }
}

/// เปิดแผ่นเลื่อนจากล่าง (ลากขึ้นลงได้) สไตล์เดียวกันทั้งแอป
Future<R?> tpShowSheet<R>(
  BuildContext context, {
  required Widget Function(BuildContext context, ScrollController scroll)
      builder,
  double initial = 0.86,
  double min = 0.5,
  double max = 0.95,
}) {
  final p = context.tp;
  return showModalBottomSheet<R>(
    context: context,
    // เปิดบน root navigator — แผ่นต้องทับแท็บบาร์ ไม่ใช่ถูกแท็บบาร์บัง
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xA603060C),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initial,
      minChildSize: min,
      maxChildSize: max,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: p.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: p.borderGold)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66000000),
                blurRadius: 40,
                offset: Offset(0, -10))
          ],
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
                color: p.faint.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 6),
          Expanded(child: builder(ctx, scroll)),
        ]),
      ),
    ),
  );
}

/// ปุ่ม "เลื่อนเพื่อยืนยัน" — กันกดพลาดสำหรับรายการเงิน/ย้อนกลับไม่ได้
///
/// [onConfirmed] เป็น async: ระหว่างทำงานจะล็อกไว้ (กันกดซ้ำ) แล้วเด้งกลับถ้าล้มเหลว
class TpSlideToConfirm extends StatefulWidget {
  const TpSlideToConfirm(
      {super.key,
      required this.label,
      required this.onConfirmed,
      this.enabled = true});
  final String label;
  final Future<bool> Function() onConfirmed;
  final bool enabled;

  @override
  State<TpSlideToConfirm> createState() => _TpSlideToConfirmState();
}

class _TpSlideToConfirmState extends State<TpSlideToConfirm>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  bool _busy = false;
  bool _done = false;
  late final AnimationController _back = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  Animation<double>? _backAnim;

  static const _knob = 50.0;
  static const _pad = 5.0;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _springBack() {
    _backAnim = Tween<double>(begin: _dx, end: 0)
        .animate(CurvedAnimation(parent: _back, curve: Curves.easeOutBack))
      ..addListener(() {
        if (mounted) setState(() => _dx = _backAnim!.value);
      });
    _back.forward(from: 0);
  }

  Future<void> _fire(double maxDx) async {
    setState(() {
      _busy = true;
      _dx = maxDx;
    });
    HapticFeedback.heavyImpact();
    bool ok = false;
    try {
      ok = await widget.onConfirmed();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = ok;
    });
    if (!ok) _springBack();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return LayoutBuilder(builder: (context, c) {
      final maxDx = c.maxWidth - _knob - _pad * 2;
      final progress = maxDx <= 0 ? 0.0 : (_dx / maxDx).clamp(0.0, 1.0);
      final locked = !widget.enabled || _busy || _done;
      return Opacity(
        opacity: widget.enabled ? 1 : 0.45,
        child: Container(
          height: _knob + _pad * 2,
          decoration: BoxDecoration(
            color: p.inset,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.borderGold),
          ),
          child: Stack(alignment: Alignment.centerLeft, children: [
            // แสงทองไล่ตามระยะที่ลาก
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (0.25 + progress * 0.75).clamp(0, 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: [
                      const Color(0xFFF0C96A).withValues(alpha: 0.30),
                      const Color(0xFFF0C96A).withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: _knob),
                child: Opacity(
                  opacity: (1 - progress * 1.4).clamp(0, 1),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TpType.h(15, p.goldText)),
                    ),
                    const SizedBox(width: 6),
                    Icon(PhosphorIconsBold.caretDoubleRight,
                        size: 15, color: p.goldText.withValues(alpha: 0.55)),
                  ]),
                ),
              ),
            ),
            Positioned(
              left: _pad + _dx,
              child: GestureDetector(
                onHorizontalDragUpdate: locked
                    ? null
                    : (d) => setState(
                        () => _dx = (_dx + d.delta.dx).clamp(0, maxDx)),
                onHorizontalDragEnd: locked
                    ? null
                    : (_) {
                        if (_dx >= maxDx * 0.86) {
                          _fire(maxDx);
                        } else {
                          _springBack();
                        }
                      },
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: TpPalette.goldButton),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFFCFA349).withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: -4),
                    ],
                  ),
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(15),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: TpPalette.onGold))
                      : Icon(
                          _done
                              ? PhosphorIconsBold.check
                              : PhosphorIconsBold.arrowRight,
                          color: TpPalette.onGold,
                          size: 22),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}
