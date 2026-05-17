import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_envelope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/clay_ball.dart';
import '../../data/fortune_repository.dart';
import '../../data/models/fortune_models.dart';

/// Bottom sheet for bill detail — preview slip + 4 actions
///
/// Actions (per brain pattern):
/// 1. Approve  → setBillStatus('confirmed'), customer's reading starts
/// 2. Reject   → setBillStatus('rejected') + reason
/// 3. Refund   → setBillStatus('refunded') + reason
/// 4. Resend image → POST resend last card image (recovery from LINE message lost)
class BillDetailSheet extends ConsumerStatefulWidget {
  const BillDetailSheet({super.key, required this.bill});
  final FortuneBill bill;

  @override
  ConsumerState<BillDetailSheet> createState() => _BillDetailSheetState();
}

class _BillDetailSheetState extends ConsumerState<BillDetailSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2);
    // ใช้ default (en_US) เพื่อไม่ต้อง initializeDateFormatting('th_TH') —
    // จะแสดง month เป็น Eng (May/Jun/...) ซึ่ง OK สำหรับ technical timestamp
    final time = DateFormat('d MMM y · HH:mm');
    final b = widget.bill;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A0F2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
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
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  children: [
                    // ── Header ──
                    Row(
                      children: [
                        ClayBall(
                          size: 52,
                          hue: b.tierHue,
                          saturation: 0.85,
                          lightness: 0.62,
                          child: Icon(
                            b.platform == 'line'
                                ? Icons.chat_bubble
                                : Icons.facebook,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.billNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _tierBadge(b.tier, b.tierLabel),
                                  const SizedBox(width: 6),
                                  _statusChip(b.status),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── Customer ──
                    _section(
                      'ลูกค้า',
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppColors.purpleStart.withValues(alpha: 0.3),
                            child: Text(
                              b.customerName.isNotEmpty
                                  ? b.customerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.customerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (b.platformUserId != null)
                                  Text(
                                    '${b.platform.toUpperCase()} · ${b.platformUserId!.length > 16 ? '${b.platformUserId!.substring(0, 16)}...' : b.platformUserId!}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0x99FFFFFF),
                                      fontSize: 11,
                                    ),
                                  )
                                else
                                  Text(
                                    b.platform.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0x99FFFFFF),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Payment info ──
                    _section(
                      'การชำระเงิน',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kvRow('ยอดบิล', money.format(b.amountThb),
                              valueColor: AppColors.goldStart, valueBig: true),
                          if (b.feeThb > 0)
                            _kvRow('ค่าธรรมเนียม', money.format(b.feeThb)),
                          _kvRow('สุทธิ', money.format(b.netThb)),
                          if (b.paymentMethod != null)
                            _kvRow('วิธีจ่าย', _paymentMethodLabel(b.paymentMethod!)),
                          if (b.createdAt != null)
                            _kvRow('สร้างบิล', time.format(b.createdAt!)),
                          if (b.paidAt != null)
                            _kvRow('ลูกค้าจ่าย', time.format(b.paidAt!),
                                valueColor: AppColors.cyanStart),
                          if (b.confirmedAt != null)
                            _kvRow('Confirmed', time.format(b.confirmedAt!),
                                valueColor: AppColors.success),
                        ],
                      ),
                    ),

                    // ── Slip image ──
                    if (b.slipImageUrl != null) ...[
                      const SizedBox(height: 14),
                      _section(
                        'หลักฐานการโอน',
                        Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.cyanStart
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.receipt_long,
                                    color: AppColors.cyanStart, size: 32),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'PromptPay Slip',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                b.slipImageUrl!.split('/').last,
                                style: const TextStyle(
                                  color: Color(0x99FFFFFF),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ── Question ──
                    if (b.questionPreview != null) ...[
                      const SizedBox(height: 14),
                      _section(
                        'คำถามของลูกค้า',
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Text(
                            '“${b.questionPreview}”',
                            style: const TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 13,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ── Reject/Refund reason ──
                    if (b.rejectReason != null) ...[
                      const SizedBox(height: 14),
                      _section(
                        b.isRefunded ? 'เหตุผล Refund' : 'เหตุผลที่ปฏิเสธ',
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: AppColors.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  b.rejectReason!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    _actions(b),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────

  Widget _actions(FortuneBill b) {
    if (b.isRefunded) {
      return _passiveBanner('บิลนี้ถูก refund แล้ว', AppColors.warning);
    }
    if (b.isRejected) {
      return _passiveBanner('บิลนี้ถูกปฏิเสธแล้ว', AppColors.error);
    }
    if (b.isConfirmed) {
      // confirmed/reading_done — can still refund + resend image
      return Column(
        children: [
          _passiveBanner('บิลนี้อนุมัติแล้ว', AppColors.success),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _outlineBtn(
                  icon: Icons.image_outlined,
                  label: 'ส่งภาพไพ่ซ้ำ',
                  color: AppColors.cyanStart,
                  onTap: () => _resendImage(b),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlineBtn(
                  icon: Icons.replay,
                  label: 'Refund',
                  color: AppColors.warning,
                  onTap: () => _refund(b),
                ),
              ),
            ],
          ),
        ],
      );
    }
    // Pending or Paid → can approve / reject
    return Column(
      children: [
        if (b.isPaid)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ลูกค้าจ่ายแล้ว — รอ admin confirm',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _primaryBtn(
          icon: Icons.check_circle,
          label: b.isPaid ? 'ยืนยันการจ่าย & เริ่มทำนาย' : 'อนุมัติบิล',
          gradient: const LinearGradient(
            colors: [AppColors.success, Color(0xFF15803D)],
          ),
          onTap: () => _approve(b),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _outlineBtn(
                icon: Icons.cancel_outlined,
                label: 'ปฏิเสธ',
                color: AppColors.error,
                onTap: () => _reject(b),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _outlineBtn(
                icon: Icons.image_outlined,
                label: 'ส่งภาพไพ่ซ้ำ',
                color: AppColors.cyanStart,
                onTap: () => _resendImage(b),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _approve(FortuneBill b) async {
    final ok = await _confirm(
      title: 'อนุมัติบิล?',
      body:
          'อนุมัติบิล ${b.billNumber} จำนวน ${b.amountThb.toStringAsFixed(0)}฿ ของ ${b.customerName}?',
      confirmLabel: 'อนุมัติ',
      confirmColor: AppColors.success,
    );
    if (ok != true) return;
    await _run(() => ref.read(fortuneRepositoryProvider).approveBill(b.id),
        success: 'อนุมัติบิลสำเร็จ');
  }

  Future<void> _reject(FortuneBill b) async {
    final reason = await _askReason(
      title: 'ปฏิเสธบิล',
      hint: 'เหตุผล (เช่น สลิปปลอม / ยอดไม่ตรง)',
    );
    if (reason == null || reason.isEmpty) return;
    await _run(() => ref.read(fortuneRepositoryProvider).rejectBill(b.id, reason),
        success: 'ปฏิเสธบิลแล้ว');
  }

  Future<void> _refund(FortuneBill b) async {
    final reason = await _askReason(
      title: 'Refund บิล',
      hint: 'เหตุผล (เช่น AI ตอบไม่ครบ / ลูกค้าไม่พอใจ)',
    );
    if (reason == null || reason.isEmpty) return;
    await _run(() => ref.read(fortuneRepositoryProvider).refundBill(b.id, reason),
        success: 'Refund สำเร็จ');
  }

  Future<void> _resendImage(FortuneBill b) async {
    await _run(() => ref.read(fortuneRepositoryProvider).resendLastImage(b.id),
        success: 'ส่งภาพไพ่ใบล่าสุดให้ลูกค้าแล้ว');
  }

  Future<void> _run(Future<void> Function() action, {required String success}) async {
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

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content:
            Text(body, style: const TextStyle(color: Color(0xD9FFFFFF))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: TextStyle(color: confirmColor)),
          ),
        ],
      ),
    );
  }

  Future<String?> _askReason({required String title, required String hint}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgPanel,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0x99FFFFFF)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
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

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _kvRow(String k, String v,
      {Color valueColor = Colors.white, bool valueBig = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style:
                  const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: valueBig ? 16 : 12,
                fontWeight: valueBig ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: valueBig ? -0.3 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierBadge(String tier, String label) {
    final color = switch (tier) {
      'celtic' => AppColors.pinkStart,
      'deep' => AppColors.purpleStart,
      'tarot_chat' => AppColors.cyanStart,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'pending_payment' => ('รอจ่าย', AppColors.cyanStart),
      'paid' => ('รอ Confirm', AppColors.warning),
      'confirmed' => ('Confirmed', AppColors.success),
      'reading_started' => ('กำลังอ่าน', AppColors.success),
      'reading_done' => ('เสร็จแล้ว', AppColors.success),
      'rejected' => ('ปฏิเสธ', AppColors.error),
      'refunded' => ('Refund', Colors.grey),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _primaryBtn({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _busy ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _busy
              ? const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _outlineBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passiveBanner(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String pm) => switch (pm) {
        'promptpay' => 'PromptPay',
        'bank' => 'โอนผ่านธนาคาร',
        'stripe' => 'Stripe Checkout',
        _ => pm,
      };
}
