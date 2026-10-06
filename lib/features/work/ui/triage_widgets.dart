import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/work_repository.dart';

/// แท็บ "ลูกค้าต้องดูแล" — เคสอารมณ์ลบ / ทวงเงิน / เริ่มดูดวงแล้วยังไม่จ่าย (ชุดเดียวกับ Warroom triage)
class TriageSliver extends ConsumerStatefulWidget {
  const TriageSliver({super.key, required this.reloadKey});
  final int reloadKey;

  @override
  ConsumerState<TriageSliver> createState() => _TriageSliverState();
}

class _TriageSliverState extends ConsumerState<TriageSliver> {
  @override
  void didUpdateWidget(covariant TriageSliver old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) ref.invalidate(triageProvider);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
              'ลูกค้าที่อารมณ์ไม่ดี ทวงเงิน หรือเริ่มดูดวงแล้วยังไม่จ่าย ใน 3 ชม.ล่าสุด — แตะเพื่อเปิดแชท',
              style: TpType.body(12.5, p.muted)),
        ),
        TpAsync<List<TriageCase>>(
          value: ref.watch(triageProvider),
          compactError: true,
          onRetry: () => ref.invalidate(triageProvider),
          data: (cases) {
            if (cases.isEmpty) {
              return const TpEmpty(
                  art: TpArt.emptyDone,
                  title: 'ไม่มีลูกค้าที่ต้องดูแลเป็นพิเศษ',
                  compact: true);
            }
            final sorted = [...cases]..sort(
                (a, b) => (b.critical ? 1 : 0).compareTo(a.critical ? 1 : 0));
            return Column(children: [
              for (final c in sorted)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TriageCard(c: c)),
            ]);
          },
        ),
      ]),
    );
  }
}

class _TriageCard extends StatelessWidget {
  const _TriageCard({required this.c});
  final TriageCase c;

  /// แปลงรหัสเหตุผลจาก backend เป็นคำไทย (ไม่รู้จัก = แสดงแบบอ่านได้)
  static String _reason(String r) {
    final k = r.contains(':') ? r.split(':').first : r;
    return switch (k) {
      'started-not-paid' => 'เริ่มแต่ยังไม่จ่าย',
      'refund' => 'ขอเงินคืน',
      'paid-no-reading' => 'โอนแล้วยังไม่ได้คำทำนาย',
      'angry' || 'anger' => 'โกรธ',
      'complaint' => 'ร้องเรียน',
      'scam' => 'กล่าวหาว่าโกง',
      _ => r.replaceAll('_', ' ').replaceAll('-', ' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return TpCard(
      accent: c.critical ? p.danger : p.warning,
      onTap: c.readingId == null
          ? null
          : () => context.push('/chat/${c.readingId}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TpAvatar(name: c.kindLabel, platform: c.platform, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.kindLabel,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text(
                  [
                    if (c.readingId != null) 'บิล #${c.readingId}',
                    TpFmt.ago(c.at)
                  ].join(' · '),
                  style: TpType.body(12, p.muted)),
            ]),
          ),
          if (c.critical)
            const TpPill('ด่วน',
                tone: TpTone.danger,
                icon: PhosphorIconsFill.warning,
                dense: true)
          else if (c.mood != null)
            TpPill('อารมณ์ ${c.mood}/5', tone: TpTone.warning, dense: true),
        ]),
        if ((c.preview ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('“${c.preview}”',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TpType.body(13.5, p.text, height: 1.5)),
        ],
        if (c.reasons.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in c.reasons.take(4))
              TpPill(_reason(r), tone: TpTone.neutral, dense: true),
          ]),
        ],
      ]),
    );
  }
}
