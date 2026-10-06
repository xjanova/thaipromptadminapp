import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../../home/data/ops_repository.dart';
import '../data/fortune_repository.dart';

/// คำทำนายสด — บิลจ่ายแล้วที่บอทกำลังทำนาย + ธงค้าง (อัปเดตเองทุก 20 วินาที)
class LiveReadingsScreen extends ConsumerStatefulWidget {
  const LiveReadingsScreen({super.key});

  @override
  ConsumerState<LiveReadingsScreen> createState() => _LiveReadingsScreenState();
}

class _LiveReadingsScreenState extends ConsumerState<LiveReadingsScreen> {
  static const _interval = Duration(seconds: 20);

  bool _stuckOnly = false;
  int _tick = 0;
  int? _total;
  int? _stuck;
  DateTime? _updatedAt;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(_interval, (_) => _autoRefresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// รีเฟรชอัตโนมัติเฉพาะตอนหน้านี้อยู่บนสุดและแอปเปิดอยู่ (กันยิง API ตอนเปิดแชททับ/พับแอป)
  void _autoRefresh() {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) return;
    setState(() => _tick++);
  }

  Future<void> _refresh() async {
    ref.invalidate(liveSummaryProvider);
    ref.invalidate(opsSummaryProvider);
    setState(() => _tick++);
  }

  Future<void> _open(LiveReading r) async {
    await context.push('/chat/${r.id}');
    if (!mounted) return;
    // กลับจากแชท — ดึงสถานะล่าสุดทันที (อาจเทคโอเวอร์/ตอบลูกค้าไปแล้ว)
    ref.invalidate(liveSummaryProvider);
    setState(() => _tick++);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final stuck = _stuck ?? 0;
    return TpPage(
      title: 'คำทำนายสด',
      subtitle: _updatedAt == null
          ? 'บิลจ่ายแล้วที่บอทกำลังทำนาย'
          : 'อัปเดต ${TpFmt.time(_updatedAt!)} · รีเฟรชเองทุก 20 วินาที',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom: TpChips<bool>(
        onHeader: true,
        padding: EdgeInsets.zero,
        value: _stuckOnly,
        onChanged: (v) => setState(() => _stuckOnly = v),
        items: [
          TpChipItem(false, 'ทั้งหมด', count: _total),
          TpChipItem(true, 'ค้าง', count: _stuck),
        ],
      ),
      slivers: [
        if (stuck > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TpCard(
                accent: p.danger,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  const Tp3D(TpArt.hourglass, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('คำทำนายค้าง $stuck รายการ',
                              style: TpType.h(14.5, p.textStrong)),
                          const SizedBox(height: 1),
                          Text(
                            'ระบบตรวจบิลค้างและลองส่งซ้ำเองเป็นระยะ ถ้ายังค้างนาน แตะรายการเพื่อเปิดแชทแจ้งลูกค้า หรือสั่งส่งซ้ำจากหน้าเว็บแอดมิน',
                            style: TpType.body(12.5, p.muted),
                          ),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        TpPagedSliver<LiveReading>(
          reloadKey: '$_stuckOnly-$_tick',
          fetch: (page) => ref
              .read(fortuneRepositoryProvider)
              .liveReadings(stuckOnly: _stuckOnly, page: page),
          onLoaded: (res) {
            if (!mounted) return;
            setState(() {
              if (res is LiveReadingsPage) {
                _total = res.summaryTotal;
                _stuck = res.summaryStuck;
              }
              _updatedAt = DateTime.now();
            });
          },
          empty: _stuckOnly
              ? const TpEmpty(
                  art: TpArt.emptyDone,
                  title: 'ไม่มีคำทำนายค้าง',
                  message: 'ทุกบิลที่จ่ายแล้วกำลังเดินตามปกติ',
                  compact: true,
                )
              : const TpEmpty(
                  art: TpArt.emptyDone,
                  title: 'ไม่มีคำทำนายที่กำลังทำ',
                  message:
                      'บิลที่จ่ายแล้วจะขึ้นที่นี่ระหว่างบอทแม่หมอกำลังทำนาย',
                  compact: true,
                ),
          itemBuilder: (context, r, _) =>
              _LiveCard(r: r, onTap: () => _open(r)),
        ),
      ],
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.r, required this.onTap});
  final LiveReading r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final accent = r.stuck ? p.danger : (r.takenOver ? p.gold : p.success);
    return TpCard(
      accent: accent,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TpAvatar(name: r.customerName, platform: r.platform),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.customerName ?? 'ลูกค้า',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.h(14.5, p.textStrong, w: FontWeight.w600)),
              Text('${r.billNumber} · ${r.packageLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12.5, p.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          _IdleBadge(r: r),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 56),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (r.stuck && r.stuckLabel != null)
                TpPill(r.stuckLabel!,
                    tone: TpTone.danger,
                    icon: PhosphorIconsBold.warningCircle,
                    dense: true),
              TpPill(r.stageLabel ?? 'กำลังทำนาย',
                  tone: r.stuck ? TpTone.neutral : TpTone.navy, dense: true),
              if (r.takenOver)
                const TpPill('แอดมินคุมอยู่',
                    tone: TpTone.gold,
                    icon: PhosphorIconsFill.headset,
                    dense: true),
            ]),
            if (r.stageDetail != null) ...[
              const SizedBox(height: 6),
              Text(r.stageDetail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(12.5, p.muted)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// เวลาที่เงียบไป (ค้าง = แดง · ปกติ = เวลาขยับล่าสุด)
class _IdleBadge extends StatelessWidget {
  const _IdleBadge({required this.r});
  final LiveReading r;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final m = r.minutesSinceActivity;
    // ข้อความสั้นพอสำหรับจอ 320 dp (ไม่เกิน ~"3 ชม. 20 นาที")
    final value = m == null
        ? '–'
        : r.stuck
            ? TpFmt.duration(m)
            : m < 1
                ? 'เมื่อสักครู่'
                : m < 60
                    ? '$m นาทีก่อน'
                    : '${m ~/ 60} ชม.ก่อน';
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(r.stuck ? 'ค้างมา' : 'ขยับล่าสุด',
          style: TpType.body(11, p.faint, height: 1.2)),
      Text(value, style: TpType.money(14, r.stuck ? p.danger : p.textStrong)),
    ]);
  }
}
