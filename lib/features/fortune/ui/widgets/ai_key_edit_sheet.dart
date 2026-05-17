import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_envelope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/fortune_repository.dart';
import '../../data/models/ai_pool_models.dart';

/// AI key edit sheet — toggle / change priority / test / view details
///
/// Notes from brain:
/// - priority 1 = highest · cross-provider tie broken by global mode
/// - "Test now" runs probe, sets last_test_passed_at OR last_test_error_at
class AiKeyEditSheet extends ConsumerStatefulWidget {
  const AiKeyEditSheet({super.key, required this.keyData});
  final AiApiKey keyData;

  @override
  ConsumerState<AiKeyEditSheet> createState() => _AiKeyEditSheetState();
}

class _AiKeyEditSheetState extends ConsumerState<AiKeyEditSheet> {
  late bool _isActive;
  late TextEditingController _priorityCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.keyData.isActive;
    _priorityCtrl =
        TextEditingController(text: widget.keyData.priority.toString());
  }

  @override
  void dispose() {
    _priorityCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final priorityChanged =
        _priorityCtrl.text.trim() != widget.keyData.priority.toString();
    return _isActive != widget.keyData.isActive || priorityChanged;
  }

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    final time = DateFormat('d MMM y · HH:mm');
    final k = widget.keyData;
    final brand = Color(k.brandColorHex);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1729),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: brand,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: brand.withValues(alpha: 0.5),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          k.providerLabel.isNotEmpty
                              ? k.providerLabel[0]
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              k.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '${k.providerLabel} · ${k.model}',
                              style: const TextStyle(
                                  color: Color(0xCCFFFFFF), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Health banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: k.isHealthy
                          ? AppColors.success.withValues(alpha: 0.12)
                          : (k.isActive
                              ? AppColors.error.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: k.isHealthy
                            ? AppColors.success.withValues(alpha: 0.3)
                            : (k.isActive
                                ? AppColors.error.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          k.isHealthy
                              ? Icons.check_circle
                              : (k.isActive
                                  ? Icons.warning_amber_rounded
                                  : Icons.pause_circle),
                          color: k.isHealthy
                              ? AppColors.success
                              : (k.isActive ? AppColors.error : Colors.white54),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                k.isHealthy
                                    ? 'Healthy · อยู่ใน available pool'
                                    : (k.isActive
                                        ? 'Unhealthy · จะถูกข้ามใน rotation'
                                        : 'Disabled · ไม่อยู่ใน pool'),
                                style: TextStyle(
                                  color: k.isHealthy
                                      ? AppColors.success
                                      : (k.isActive
                                          ? AppColors.error
                                          : Colors.white70),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (k.lastTestPassedAt != null)
                                Text(
                                  'ทดสอบล่าสุด ${time.format(k.lastTestPassedAt!)}',
                                  style: const TextStyle(
                                      color: Color(0xCCFFFFFF), fontSize: 10),
                                ),
                              if (k.lastTestErrorAt != null)
                                Text(
                                  'Error ครั้งล่าสุด ${time.format(k.lastTestErrorAt!)}',
                                  style: const TextStyle(
                                      color: AppColors.error, fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Active toggle
                  _section(
                    'Active',
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isActive
                                ? 'อยู่ใน Pool — รับโหลด'
                                : 'ปิด — ข้ามใน rotation',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _isActive,
                          activeThumbColor: AppColors.success,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ],
                    ),
                  ),

                  // Priority
                  _section(
                    'Priority (1 = สูงสุด)',
                    TextField(
                      controller: _priorityCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: const InputDecoration(
                        prefixText: 'P ',
                        prefixStyle: TextStyle(
                          color: AppColors.cyanStart,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                        hintText: '1',
                        hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                  // Purposes (read-only)
                  _section(
                    'Purposes',
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: k.purposes.map((purpose) {
                        final p = aiPoolPurposes.firstWhere(
                          (x) => x.key == purpose,
                          orElse: () => AiPurpose(
                              key: purpose,
                              label: purpose,
                              icon: '',
                              description: ''),
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.purpleStart.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppColors.purpleStart.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            p.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Usage today
                  _section(
                    'Usage วันนี้',
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt,
                                  color: AppColors.cyanStart, size: 14),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'จำนวน requests',
                                  style: TextStyle(
                                      color: Color(0xCCFFFFFF), fontSize: 11),
                                ),
                              ),
                              Text(
                                NumberFormat.compact()
                                    .format(k.usageCount ?? 0),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.payments,
                                  color: AppColors.goldStart, size: 14),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'ค่าใช้จ่าย',
                                  style: TextStyle(
                                      color: Color(0xCCFFFFFF), fontSize: 11),
                                ),
                              ),
                              Text(
                                money.format(k.costThbToday ?? 0),
                                style: const TextStyle(
                                  color: AppColors.goldStart,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          if (k.quotaPct != null && k.quotaPct! > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.donut_large,
                                    color: AppColors.purpleStart, size: 14),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Quota used',
                                    style: TextStyle(
                                        color: Color(0xCCFFFFFF), fontSize: 11),
                                  ),
                                ),
                                Text(
                                  '${k.quotaPct!.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: k.quotaPct! > 80
                                        ? AppColors.error
                                        : (k.quotaPct! > 60
                                            ? AppColors.warning
                                            : Colors.white),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (k.note != null && k.note!.isNotEmpty)
                    _section(
                      'Note',
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          k.note!,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Actions
                  InkWell(
                    onTap: _busy ? null : () => _test(k),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.cyanStart.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.cyanStart.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow,
                              color: AppColors.cyanStart, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Test Key Now',
                            style: TextStyle(
                              color: AppColors.cyanStart,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _busy ? null : () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Center(
                              child: Text(
                                'ยกเลิก',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: (_busy || !_hasChanges) ? null : _save,
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: (_busy || !_hasChanges) ? 0.5 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.purpleStart,
                                    AppColors.pinkStart
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _hasChanges
                                    ? [
                                        BoxShadow(
                                          color: AppColors.pinkStart
                                              .withValues(alpha: 0.4),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: _busy
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.save,
                                              color: Colors.white, size: 16),
                                          SizedBox(width: 8),
                                          Text(
                                            'บันทึก',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _test(AiApiKey k) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await ref.read(fortuneRepositoryProvider).testAiKey(k.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ Test ผ่าน' : '❌ Test ไม่ผ่าน'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Trigger rebuild via provider invalidation in caller; just pop sheet
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final priority = int.tryParse(_priorityCtrl.text.trim());
    final patch = AiKeyPatch(
      isActive: _isActive,
      priority: priority,
    );
    try {
      await ref
          .read(fortuneRepositoryProvider)
          .updateAiKey(widget.keyData.id, patch);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกการตั้งค่า key เรียบร้อย'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
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
      ),
    );
  }
}
