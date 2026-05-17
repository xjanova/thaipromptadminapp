import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_envelope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/clay_ball.dart';
import '../../data/fortune_repository.dart';
import '../../data/models/fortune_models.dart';

/// Service edit bottom sheet — control everything about a fortune service:
/// active toggle · price · pay-first · persona name · banner color · system prompt
///
/// AI provider/model is **read-only** (just shows ai_purpose) per brain note:
/// [[Session 2026-05-13 — Fortune AI Pool-first + Health Gate + Auto-Recovery]]
/// — Pool is single source of truth; services declare purpose, not provider.
class ServiceEditSheet extends ConsumerStatefulWidget {
  const ServiceEditSheet({super.key, required this.service});
  final FortuneService service;

  @override
  ConsumerState<ServiceEditSheet> createState() => _ServiceEditSheetState();
}

class _ServiceEditSheetState extends ConsumerState<ServiceEditSheet> {
  late bool _isActive;
  late bool _payFirst;
  late TextEditingController _priceCtrl;
  late TextEditingController _personaCtrl;
  late TextEditingController _promptCtrl;
  late String _colorHex;
  bool _busy = false;
  bool _expandPrompt = false;

  static const _colorPresets = [
    '#a855f7', // purple
    '#ec4899', // pink
    '#0ea5e9', // cyan
    '#f97316', // orange
    '#ef4444', // red
    '#22c55e', // green
    '#fbbf24', // gold
    '#6366f1', // indigo
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _isActive = s.isActive;
    _payFirst = s.payFirst;
    _priceCtrl =
        TextEditingController(text: s.priceThb?.toStringAsFixed(0) ?? '');
    _personaCtrl = TextEditingController(text: s.personaName ?? '');
    _promptCtrl = TextEditingController(text: s.systemPrompt ?? '');
    _colorHex = s.color;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _personaCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final s = widget.service;
    return _isActive != s.isActive ||
        _payFirst != s.payFirst ||
        _priceCtrl.text != (s.priceThb?.toStringAsFixed(0) ?? '') ||
        _personaCtrl.text != (s.personaName ?? '') ||
        _promptCtrl.text != (s.systemPrompt ?? '') ||
        _colorHex != s.color;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final money =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);
    final color = Color(int.parse('FF${_colorHex.replaceAll('#', '')}', radix: 16));
    final hsl = HSLColor.fromColor(color);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A0F2E),
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
                  // ── Header ──
                  Row(
                    children: [
                      ClayBall(
                          size: 54,
                          hue: hsl.hue,
                          saturation: 0.85,
                          lightness: 0.62),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${s.slug} · ${NumberFormat.compact().format(s.sessions)} sessions · ${money.format(s.revenueThb)}',
                              style: const TextStyle(
                                  color: Color(0xCCFFFFFF), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Active toggle (prominent) ──
                  _row(
                    icon: _isActive
                        ? Icons.toggle_on
                        : Icons.toggle_off_outlined,
                    iconColor:
                        _isActive ? AppColors.success : Colors.white54,
                    label: 'เปิดให้บริการ',
                    sub: _isActive
                        ? 'ลูกค้าเข้าใช้ได้'
                        : 'ปิด — ลูกค้าจะเห็นข้อความ "บริการนี้ปิดชั่วคราว"',
                    trailing: Switch.adaptive(
                      value: _isActive,
                      activeThumbColor: AppColors.success,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ),

                  // ── Pay-first ──
                  _row(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.goldStart,
                    label: 'บังคับจ่ายก่อน',
                    sub: _payFirst
                        ? 'ลูกค้าต้องโอนก่อน บอทถึงจะเริ่มทำนาย'
                        : 'อ่านก่อน — เก็บเงินทีหลัง',
                    trailing: Switch.adaptive(
                      value: _payFirst,
                      activeThumbColor: AppColors.goldStart,
                      onChanged: (v) => setState(() => _payFirst = v),
                    ),
                  ),

                  // ── Price ──
                  _section(
                    'ราคา (บาท)',
                    TextField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        color: AppColors.goldStart,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        prefixText: '฿ ',
                        prefixStyle: const TextStyle(
                          color: AppColors.goldStart,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                        hintText: 'ว่าง = ฟรี',
                        hintStyle: const TextStyle(color: Color(0x99FFFFFF)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                  // ── Persona name ──
                  _section(
                    'ชื่อผู้ทำนาย (Persona)',
                    TextField(
                      controller: _personaCtrl,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'เช่น แม่หมอลัคกี้',
                        hintStyle: TextStyle(color: Color(0x99FFFFFF)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                  // ── Banner color picker ──
                  _section(
                    'สีธีม',
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _colorPresets.map((hex) {
                        final selected = hex == _colorHex;
                        final c = Color(
                            int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                        return GestureDetector(
                          onTap: () => setState(() => _colorHex = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: selected ? 40 : 32,
                            height: selected ? 40 : 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: c.withValues(alpha: 0.6),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                              border: selected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // ── AI Pool purpose (read-only) ──
                  _section(
                    'AI Pool',
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cyanStart.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.cyanStart.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hub_outlined,
                              color: AppColors.cyanStart, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.aiPurpose ?? '—',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'Pool เลือก provider/model ให้อัตโนมัติ',
                                  style: TextStyle(
                                      color: Color(0x99FFFFFF), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.lock_outline,
                              color: Color(0x66FFFFFF), size: 14),
                        ],
                      ),
                    ),
                  ),

                  // ── System prompt (collapsible) ──
                  _section(
                    'System Prompt',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _expandPrompt = !_expandPrompt),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.psychology_outlined,
                                    color: Color(0xCCFFFFFF), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _expandPrompt
                                        ? 'ปิดการแก้ไข'
                                        : _promptCtrl.text.isEmpty
                                            ? 'ยังไม่ได้ตั้ง — แตะเพื่อตั้งค่า'
                                            : '${_promptCtrl.text.length} อักษร · แตะเพื่อแก้ไข',
                                    style: const TextStyle(
                                      color: Color(0xCCFFFFFF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _expandPrompt
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: const Color(0x99FFFFFF),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_expandPrompt) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _promptCtrl,
                            maxLines: 6,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.5),
                            decoration: const InputDecoration(
                              hintText:
                                  'คำสั่ง AI สำหรับบริการนี้ (เช่น tone, ภาษา, style)',
                              hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Save / Cancel ──
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
                                            color: Colors.white))
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

  Future<void> _save() async {
    setState(() => _busy = true);
    final priceText = _priceCtrl.text.trim();
    final priceParsed = priceText.isEmpty ? null : double.tryParse(priceText);
    final patch = FortuneServicePatch(
      isActive: _isActive,
      priceThb: priceParsed,
      payFirst: _payFirst,
      personaName: _personaCtrl.text.trim(),
      colorHex: _colorHex,
      systemPrompt: _promptCtrl.text.trim(),
    );
    try {
      await ref.read(fortuneRepositoryProvider).updateService(
            widget.service.id,
            patch,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกการตั้งค่าบริการเรียบร้อย'),
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

  Widget _row({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sub,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                      color: Color(0x99FFFFFF), fontSize: 11),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
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
