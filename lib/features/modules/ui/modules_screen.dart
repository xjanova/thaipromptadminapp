import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/ui/tp.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../home/data/ops_repository.dart';

/// หน้า "โมดูล" — ทางเข้าทุกระบบหลังบ้าน เป็นกริดไอคอน 3D ประจำแบรนด์
class ModulesScreen extends ConsumerWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(opsSummaryProvider).valueOrNull;
    final d = ref.watch(dashboardDataProvider).valueOrNull;

    final daily = <_Mod>[
      _Mod(TpArt.tarot, 'ดูดวง', '/fortune',
          sub: s == null
              ? null
              : 'วันนี้ ${TpFmt.bahtCompact(s.revenueFortune.roundToDouble())}'),
      _Mod(TpArt.bill, 'ตรวจบิล', '/work?tab=bills',
          badge: s?.billsAwaiting.count, tone: TpTone.gold),
      _Mod(TpArt.headset, 'แชทลูกค้า', '/chat',
          badge: s?.customerRequests.count, tone: TpTone.danger, tab: true),
      _Mod(TpArt.wallet, 'กระเป๋าเงิน', '/finance/wallets'),
      _Mod(TpArt.payout, 'ถอนเงิน', '/work?tab=withdrawals',
          badge: s?.withdrawalsPending.count, tone: TpTone.info),
      _Mod(TpArt.sms, 'SMS ธนาคาร', '/work?tab=sms',
          badge: s?.smsUnmatched.count, tone: TpTone.warning),
    ];
    final business = <_Mod>[
      _Mod(TpArt.members, 'สมาชิก', '/users',
          sub: d == null ? null : '${TpFmt.compact(d.totalUsers)} คน'),
      _Mod(TpArt.store, 'ร้านค้า', '/marketplace',
          sub: d == null ? null : '${d.ordersPending} รอส่ง'),
      _Mod(TpArt.analytics, 'รายงาน', '/analytics', sub: '30 วัน'),
      _Mod(TpArt.ai, 'AI Pool', '/fortune/ai-pool',
          sub: s == null || s.aiTotal == 0
              ? null
              : '${s.aiHealthy}/${s.aiTotal} พร้อม'),
      _Mod(TpArt.server, 'บอท AI', '/ai', sub: 'ผู้ให้บริการ · บอท'),
      _Mod(TpArt.shield, 'ความปลอดภัย', '/moderation',
          sub: 'แบน · ผู้ต้องสงสัย'),
      _Mod(TpArt.broadcast, 'ระบบดูดวง', '/fortune/services',
          sub: 'เปิด/ปิดบริการ'),
      _Mod(TpArt.hourglass, 'คำทำนายสด', '/fortune/live',
          badge: s?.stuckReadings.count, tone: TpTone.warning),
      _Mod(TpArt.settings, 'บัญชี', '/me',
          tab: true, sub: 'PIN · ธีม · อัปเดต'),
    ];

    return TpPage(
      title: 'โมดูลทั้งหมด',
      subtitle: '${daily.length + business.length} ระบบ',
      showMark: true,
      onRefresh: () async {
        ref.invalidate(dashboardDataProvider);
        try {
          ref.invalidate(opsSummaryProvider);
          await ref.read(opsSummaryProvider.future);
        } catch (_) {}
      },
      slivers: [
        SliverToBoxAdapter(child: _Label('งานประจำวัน')),
        _grid(daily, big: true),
        SliverToBoxAdapter(child: _Label('ธุรกิจและระบบ')),
        _grid(business),
      ],
    );
  }

  Widget _grid(List<_Mod> mods, {bool big = false}) => SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          mainAxisExtent: big ? 132 : 124,
        ),
        delegate: SliverChildBuilderDelegate(
            (context, i) => _ModTile(mods[i], big: big),
            childCount: mods.length),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Text(text, style: TpType.h(13, context.tp.muted)),
      );
}

class _Mod {
  const _Mod(this.art, this.label, this.route,
      {this.sub, this.badge, this.tone = TpTone.gold, this.tab = false});
  final TpArt art;
  final String label;
  final String route;
  final String? sub;
  final int? badge;
  final TpTone tone;

  /// ปลายทางเป็นแท็บหลัก → ใช้ go (สลับแท็บ) แทน push
  final bool tab;
}

class _ModTile extends StatelessWidget {
  const _ModTile(this.m, {this.big = false});
  final _Mod m;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final hasBadge = (m.badge ?? 0) > 0;
    return TpCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
      onTap: () => (m.tab || m.route.startsWith('/work'))
          ? context.go(m.route)
          : context.push(m.route),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Tp3D(m.art, size: big ? 56 : 50),
        const SizedBox(height: 6),
        Text(m.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TpType.h(13.2, p.textStrong, w: FontWeight.w600)),
        const SizedBox(height: 3),
        SizedBox(
          height: 20,
          child: hasBadge
              ? TpPill('${m.badge} รอ', tone: m.tone, dense: true)
              : Text(m.sub ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(11.5, p.muted)),
        ),
      ]),
    );
  }
}
