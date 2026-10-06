import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../home/data/ops_repository.dart';
import '../data/work_repository.dart';

/// ปุ่ม "สั่งทำนายซ้ำ" ของบิลที่ค้าง — เซิร์ฟเวอร์เลือกวิธีกู้เอง (ส่งซ้ำ / สร้างใหม่ / ขอวันเกิด / กู้ Celtic)
///
/// ด่านทั้งหมดอยู่ฝั่งเซิร์ฟเวอร์ (ห้ามสั่งตอนแอดมินคุมห้อง, งานยังวิ่งอยู่, กดซ้ำใน 2 นาที)
/// แอปแค่ยืนยันก่อนกด แล้วแสดงข้อความไทยที่เซิร์ฟเวอร์ตอบมา
class RetryReadingButton extends ConsumerStatefulWidget {
  const RetryReadingButton({super.key, required this.readingId, this.onDone});
  final int readingId;
  final VoidCallback? onDone;

  @override
  ConsumerState<RetryReadingButton> createState() => _RetryReadingButtonState();
}

class _RetryReadingButtonState extends ConsumerState<RetryReadingButton> {
  bool _busy = false;

  Future<void> _run() async {
    final yes = await tpConfirm(
      context,
      title: 'สั่งทำนายซ้ำ?',
      message:
          'ระบบจะเลือกวิธีกู้เอง (ส่งคำทำนายเดิมซ้ำ หรือสร้างใหม่) และลูกค้าจะได้รับข้อความ — ใช้เมื่อบิลค้างจริงเท่านั้น',
      confirmLabel: 'สั่งทำนายซ้ำ',
    );
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    try {
      final msg =
          await ref.read(workRepositoryProvider).retryReading(widget.readingId);
      if (!mounted) return;
      tpToast(context, msg, kind: TpToastKind.success);
      ref.invalidate(opsSummaryProvider);
      widget.onDone?.call();
    } catch (e) {
      if (mounted) tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TpButton.outline(
      'สั่งทำนายซ้ำ',
      icon: PhosphorIconsRegular.arrowCounterClockwise,
      height: 38,
      fontSize: 13,
      expand: false,
      loading: _busy,
      onPressed: _busy ? null : _run,
    );
  }
}
