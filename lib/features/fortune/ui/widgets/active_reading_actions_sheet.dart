import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_envelope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/clay_ball.dart';
import '../../data/fortune_repository.dart';
import '../../data/models/fortune_models.dart';

/// Action sheet for an active reading — 3 actions:
/// 1. Admin Ask AI (sync takeover — pattern from
///    [[2026-05-17-fortune-celtic-admin-ai-debug-tools-bill-race-lock]])
/// 2. Send Message (admin sends text directly to customer)
/// 3. Cancel Reading (with reason, destructive)
class ActiveReadingActionsSheet extends ConsumerStatefulWidget {
  const ActiveReadingActionsSheet({super.key, required this.reading});
  final FortuneActiveReading reading;

  @override
  ConsumerState<ActiveReadingActionsSheet> createState() =>
      _ActiveReadingActionsSheetState();
}

class _ActiveReadingActionsSheetState
    extends ConsumerState<ActiveReadingActionsSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.reading;
    final accent = switch (r.alertLevel) {
      'stuck' => AppColors.error,
      'slow' => AppColors.warning,
      _ => AppColors.success,
    };
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A0F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Row(
                children: [
                  ClayBall(
                    size: 48,
                    hue: r.tierHue,
                    saturation: 0.85,
                    lightness: 0.62,
                    child: Icon(
                      r.platform == 'line'
                          ? Icons.chat_bubble
                          : Icons.facebook,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.billNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          '${r.customerName} · ${r.tierLabel}',
                          style: const TextStyle(
                              color: Color(0xCCFFFFFF), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stage banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(
                    r.isStuck
                        ? Icons.error_outline
                        : (r.isSlow
                            ? Icons.warning_amber_rounded
                            : Icons.podcasts),
                    color: accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${r.stageLabel} · ${_formatElapsed(r.elapsed)}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Actions
            _actionTile(
              icon: Icons.smart_toy_outlined,
              color: AppColors.purpleStart,
              label: 'Admin Ask AI (Takeover)',
              sub: r.tier == 'celtic'
                  ? 'รัน AI ที่นี่ — ลูกค้าได้รับใน LINE/FB · 30-60s'
                  : 'ทำนายแทนลูกค้า — 30-60s',
              onTap: _askAi,
            ),
            _actionTile(
              icon: Icons.send_outlined,
              color: AppColors.cyanStart,
              label: 'ส่งข้อความหาลูกค้า',
              sub: 'พิมพ์ข้อความเอง · ส่งทันที',
              onTap: _sendMessage,
            ),
            _actionTile(
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              label: 'ยกเลิก & Refund',
              sub: 'ยกเลิกการทำนาย + คืนเงินลูกค้า',
              onTap: _cancel,
              destructive: true,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────

  Future<void> _askAi() async {
    final question = await _askText(
      title: 'Admin Ask AI',
      hint: 'คำถามที่ admin อยากให้ AI ตอบ (ถ้าว่าง = ใช้คำถามเดิมของลูกค้า)',
      submitLabel: 'รัน AI',
      icon: Icons.smart_toy_outlined,
      info:
          'AJAX sync · admin รอ 30-60s · ผลลัพธ์ถูกส่งให้ลูกค้าและแสดงในแอพ',
    );
    if (question == null) return;
    await _run(
      () => ref
          .read(fortuneRepositoryProvider)
          .adminAskAi(widget.reading.id, question),
      success: 'AI ทำนายเสร็จ · ส่งให้ลูกค้าแล้ว',
    );
  }

  Future<void> _sendMessage() async {
    final text = await _askText(
      title: 'ส่งข้อความ',
      hint: 'ข้อความถึงลูกค้า...',
      submitLabel: 'ส่ง',
      icon: Icons.send,
    );
    if (text == null || text.isEmpty) return;
    await _run(
      () => ref
          .read(fortuneRepositoryProvider)
          .sendAdminMessage(widget.reading.id, text),
      success: 'ส่งข้อความให้ลูกค้าแล้ว',
    );
  }

  Future<void> _cancel() async {
    final reason = await _askText(
      title: 'ยกเลิก & Refund',
      hint: 'เหตุผล (เช่น AI ค้าง · ลูกค้าไม่พอใจ)',
      submitLabel: 'ยืนยันยกเลิก',
      icon: Icons.cancel_outlined,
      destructive: true,
    );
    if (reason == null || reason.isEmpty) return;
    await _run(
      () => ref
          .read(fortuneRepositoryProvider)
          .cancelReading(widget.reading.id, reason),
      success: 'ยกเลิก & refund เรียบร้อย',
    );
  }

  Future<void> _run(Future<void> Function() action,
      {required String success}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _toast(success);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ────────────────────────────────────────────────────────────
  // Dialog helpers
  // ────────────────────────────────────────────────────────────

  Future<String?> _askText({
    required String title,
    required String hint,
    required String submitLabel,
    required IconData icon,
    String? info,
    bool destructive = false,
  }) {
    final ctrl = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          backgroundColor: AppColors.bgPanel,
          title: Row(
            children: [
              Icon(icon,
                  color: destructive
                      ? AppColors.error
                      : AppColors.purpleStart,
                  size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cyanStart.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.cyanStart, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          info,
                          style: const TextStyle(
                              color: Color(0xCCFFFFFF), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Color(0x99FFFFFF)),
                ),
                onChanged: (_) => setSt(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('ยกเลิก')),
            TextButton(
              onPressed: ctrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(
                submitLabel,
                style: TextStyle(
                  color: destructive ? AppColors.error : AppColors.purpleStart,
                ),
              ),
            ),
          ],
        );
      }),
    ).whenComplete(() => ctrl.dispose());
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Layout helpers
  // ────────────────────────────────────────────────────────────

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: destructive ? AppColors.error : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                        color: Color(0x99FFFFFF), fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0x66FFFFFF), size: 18),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final m = d.inMinutes;
    final s = d.inSeconds - (m * 60);
    return '${m}m ${s}s';
  }
}
