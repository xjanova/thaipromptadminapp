import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../data/analytics_repository.dart';

/// ตัวชี้วัดที่กราฟแนวโน้มแสดงอยู่
enum _Metric { commission, members }

const _thDaysShort = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
const _thDays = [
  'จันทร์',
  'อังคาร',
  'พุธ',
  'พฤหัสบดี',
  'ศุกร์',
  'เสาร์',
  'อาทิตย์'
];
const _thMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.'
];

String _dayMonth(DateTime d) => '${d.day} ${_thMonths[d.month - 1]}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// หน้า "รายงาน & วิเคราะห์" — ยอดขายร้านค้า · ค่าคอมมิชชั่นที่จ่าย · สมาชิกใหม่
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.month;
  _Metric _metric = _Metric.commission;
  int? _selected;
  bool _showAllDays = false;

  /// กราฟแนวโน้มใช้ข้อมูลย้อนหลังแบบเลื่อน — "วันนี้" ดึงชุด 7 วันมาแสดงแทนให้เห็นแนวโน้ม
  AnalyticsPeriod get _trendPeriod => _period == AnalyticsPeriod.month
      ? AnalyticsPeriod.month
      : AnalyticsPeriod.week;

  Future<void> _refresh() async {
    ref.invalidate(analyticsOverviewProvider(_period));
    ref.invalidate(analyticsOverviewProvider(_trendPeriod));
    try {
      await Future.wait([
        ref.read(analyticsOverviewProvider(_period).future),
        ref.read(analyticsOverviewProvider(_trendPeriod).future),
      ]);
    } catch (_) {
      // error แสดงผ่าน TpAsync อยู่แล้ว
    }
  }

  void _setPeriod(AnalyticsPeriod p) => setState(() {
        _period = p;
        _selected = null;
        _showAllDays = false;
      });

  void _setMetric(_Metric m) {
    if (m == _metric) return;
    HapticFeedback.selectionClick();
    setState(() {
      _metric = m;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ov = ref.watch(analyticsOverviewProvider(_period));
    final trend = ref.watch(analyticsOverviewProvider(_trendPeriod));
    final fetched = ov.valueOrNull?.fetchedAt;

    return TpPage(
      title: 'รายงาน & วิเคราะห์',
      subtitle: fetched == null
          ? 'ยอดขาย สมาชิก และค่าคอมมิชชั่น'
          : 'อัปเดต ${TpFmt.time(fetched)} · ดึงลงเพื่อรีเฟรช',
      back: true,
      bottomSpace: 32,
      onRefresh: _refresh,
      headerBottom: TpChips<AnalyticsPeriod>(
        onHeader: true,
        padding: EdgeInsets.zero,
        value: _period,
        onChanged: _setPeriod,
        items: [for (final p in AnalyticsPeriod.values) TpChipItem(p, p.label)],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: TpAsync<AnalyticsOverview>(
            value: ov,
            onRetry: () => ref.invalidate(analyticsOverviewProvider(_period)),
            loading: const _HeroSkeleton(),
            data: (o) => _SalesHero(o: o),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildTrend(trend, mainFailed: ov.hasError && !ov.hasValue),
        ),
        if (ov.hasValue) const SliverToBoxAdapter(child: _Notes()),
      ],
    );
  }

  Widget _buildTrend(AsyncValue<AnalyticsOverview> trend,
      {required bool mainFailed}) {
    // หัวหน้าโหลดไม่ได้อยู่แล้ว — ไม่ซ้อนกล่อง error อันที่สอง
    if (mainFailed && !trend.hasValue) return const SizedBox.shrink();
    if (!trend.hasValue && trend.hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TpCard(
          padding: EdgeInsets.zero,
          child: TpErrorView(
            error: trend.error,
            compact: true,
            onRetry: () =>
                ref.invalidate(analyticsOverviewProvider(_trendPeriod)),
          ),
        ),
      );
    }
    if (!trend.hasValue) {
      return const Padding(
        padding: EdgeInsets.only(top: 22),
        child: Column(children: [
          Row(children: [
            Expanded(child: TpSkeleton(height: 92, radius: 20)),
            SizedBox(width: 10),
            Expanded(child: TpSkeleton(height: 92, radius: 20)),
          ]),
          SizedBox(height: 12),
          TpSkeleton(height: 230, radius: 22),
        ]),
      );
    }

    final t = trend.requireValue;
    final days = _trendPeriod.trendDays;
    final comm = t.commissionsDaily(days);
    final mem = t.membersDaily(days);
    final commTotal = comm.fold<double>(0, (a, b) => a + b.value);
    final memTotal = mem.fold<double>(0, (a, b) => a + b.value);
    final series = _metric == _Metric.commission ? comm : mem;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TpSection('แนวโน้ม $days วันล่าสุด',
          trailing: _period == AnalyticsPeriod.today
              ? TpPill('แสดงย้อนหลัง 7 วัน', tone: TpTone.neutral, dense: true)
              : null),
      Row(children: [
        Expanded(
          child: _MetricTile(
            art: TpArt.payout,
            label: 'ค่าคอมฯ ที่จ่าย',
            value: TpFmt.bahtCompact(commTotal),
            sub: 'รวม $days วันล่าสุด',
            selected: _metric == _Metric.commission,
            onTap: () => _setMetric(_Metric.commission),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            art: TpArt.members,
            label: 'สมาชิกใหม่',
            value: '${TpFmt.count(memTotal)} คน',
            sub: 'รวม $days วันล่าสุด',
            selected: _metric == _Metric.members,
            onTap: () => _setMetric(_Metric.members),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      _TrendCard(
        points: series,
        money: _metric == _Metric.commission,
        selected: _selected,
        onSelect: (i) => setState(() => _selected = i),
      ),
      TpSection('รายวัน',
          action: days > 7 ? (_showAllDays ? 'ย่อ' : 'ดูครบ $days วัน') : null,
          onAction: () => setState(() => _showAllDays = !_showAllDays)),
      _DailyList(
        comm: comm,
        mem: mem,
        limit: _showAllDays ? days : 7,
      ),
    ]);
  }
}

// ═════════════════════ ฮีโร่ยอดขาย ═════════════════════

class _SalesHero extends StatelessWidget {
  const _SalesHero({required this.o});
  final AnalyticsOverview o;

  @override
  Widget build(BuildContext context) {
    final empty = o.ordersCount == 0 && o.ordersPaidThb <= 0;
    return TpHeroCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('ยอดขายที่ชำระแล้ว',
                style:
                    TpType.body(13.5, TpPalette.heroMuted, w: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          _HeroPill(
              icon: PhosphorIconsBold.calendarBlank, label: o.period.label),
        ]),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: TpFoilText(TpFmt.baht(o.ordersPaidThb),
              style: TpType.money(40, Colors.white)),
        ),
        Text(
          empty
              ? 'ยังไม่มีออเดอร์ร้านค้า${o.period.since}'
              : 'ออเดอร์ร้านค้า · ${o.period.since}',
          style: TpType.body(12, const Color(0x8CFFFFFF)),
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: const Color(0x14FFFFFF)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _HeroSplit(
              label: 'ออเดอร์',
              value: TpFmt.count(o.ordersCount),
              icon: PhosphorIconsRegular.receipt),
          _HeroSplit(
              label: 'ผู้ซื้อ',
              value: TpFmt.count(o.uniqueBuyers),
              icon: PhosphorIconsRegular.users,
              divider: true),
          _HeroSplit(
              label: 'เฉลี่ย/ออเดอร์',
              value: TpFmt.bahtCompact(o.avgOrderThb),
              icon: PhosphorIconsRegular.scales,
              divider: true),
        ]),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: TpPalette.heroGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: TpPalette.heroGold.withValues(alpha: 0.28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: TpPalette.heroGold),
          const SizedBox(width: 5),
          Text(label,
              style: TpType.body(12, TpPalette.heroGold,
                  w: FontWeight.w600, height: 1.1)),
        ]),
      );
}

class _HeroSplit extends StatelessWidget {
  const _HeroSplit(
      {required this.label,
      required this.value,
      required this.icon,
      this.divider = false});
  final String label;
  final String value;
  final IconData icon;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.only(left: divider ? 12 : 0, right: 6),
        decoration: divider
            ? const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0x14FFFFFF))))
            : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 12, color: const Color(0x8CFFFFFF)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(11.5, const Color(0x8CFFFFFF),
                      w: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TpType.money(16, TpPalette.heroText)),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════ ตัวชี้วัด + กราฟ ═════════════════════

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.art,
    required this.label,
    required this.value,
    required this.sub,
    required this.selected,
    required this.onTap,
  });
  final TpArt art;
  final String label;
  final String value;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return TpCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      goldBorder: selected,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Tp3D(art, size: 34),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: selected ? 1 : 0,
            child:
                Icon(PhosphorIconsFill.chartBar, size: 16, color: p.goldText),
          ),
        ]),
        const SizedBox(height: 8),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TpType.body(12, p.muted, w: FontWeight.w500)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TpType.money(19, selected ? p.goldText : p.textStrong)),
        ),
        Text(sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TpType.body(11, p.faint)),
      ]),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard(
      {required this.points,
      required this.money,
      required this.selected,
      required this.onSelect});
  final List<DayPoint> points;
  final bool money;
  final int? selected;
  final ValueChanged<int?> onSelect;

  String _fmt(double v) => money ? TpFmt.baht(v) : '${TpFmt.count(v)} คน';

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    if (points.isEmpty) return const SizedBox.shrink();
    final total = points.fold<double>(0, (a, b) => a + b.value);
    final avg = total / points.length;
    final maxV = points.map((e) => e.value).fold<double>(0, math.max);
    final sel = (selected != null && selected! < points.length)
        ? points[selected!]
        : null;
    final allZero = maxV <= 0;
    final today = DateTime.now();

    final heading = sel == null
        ? 'รวม ${points.length} วันล่าสุด'
        : '${_thDays[sel.day.weekday - 1]} ${_dayMonth(sel.day)}${_sameDay(sel.day, today) ? ' (วันนี้)' : ''}';

    return TpCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Text(heading,
                    key: ValueKey(heading),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TpType.body(12.5, p.muted, w: FontWeight.w500)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_fmt(sel?.value ?? total),
                    style: TpType.money(24, p.goldText)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('เฉลี่ย/วัน', style: TpType.body(11, p.faint)),
            Text(
                money
                    ? TpFmt.bahtCompact(avg)
                    : avg.toStringAsFixed(avg >= 10 ? 0 : 1),
                style: TpType.money(13.5, p.text)),
          ]),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 128,
          child: Stack(children: [
            Positioned.fill(
              child: _BarChart(
                values: [for (final e in points) e.value],
                selected: selected,
                onSelect: onSelect,
                bar: p.gold,
                barSoft: p.gold.withValues(alpha: p.isDark ? 0.28 : 0.30),
                grid: p.divider,
              ),
            ),
            if (allZero)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: p.cardSolid,
                      borderRadius: BorderRadius.circular(99)),
                  child: Text(
                      money
                          ? 'ยังไม่มีการจ่ายคอมมิชชั่นในช่วงนี้'
                          : 'ยังไม่มีสมาชิกสมัครใหม่ในช่วงนี้',
                      style: TpType.body(12, p.muted)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text(_dayMonth(points.first.day),
              style: TpType.body(10.5, p.faint, w: FontWeight.w500)),
          const Spacer(),
          Text(_dayMonth(points[points.length ~/ 2].day),
              style: TpType.body(10.5, p.faint, w: FontWeight.w500)),
          const Spacer(),
          Text('วันนี้',
              style: TpType.body(10.5, p.goldText, w: FontWeight.w600)),
        ]),
        if (!allZero) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(PhosphorIconsRegular.handTap, size: 13, color: p.faint),
            const SizedBox(width: 5),
            Expanded(
              child: Text('แตะหรือลากบนกราฟเพื่อดูยอดแต่ละวัน',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(11, p.faint)),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// กราฟแท่งรายวัน (วาดเอง) — แตะ/ลากเพื่อเลือกวัน · แท่งที่เลือก (หรือวันนี้) เป็นทองเข้ม
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.selected,
    required this.onSelect,
    required this.bar,
    required this.barSoft,
    required this.grid,
  });
  final List<double> values;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final Color bar;
  final Color barSoft;
  final Color grid;

  int _indexAt(double dx, double width) => values.isEmpty
      ? 0
      : (dx / width * values.length).floor().clamp(0, values.length - 1);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      void pick(double dx, {bool toggle = false}) {
        final i = _indexAt(dx, c.maxWidth);
        if (toggle && i == selected) {
          onSelect(null);
          return;
        }
        if (i != selected) {
          HapticFeedback.selectionClick();
          onSelect(i);
        }
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => pick(d.localPosition.dx, toggle: true),
        onHorizontalDragStart: (d) => pick(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
        child: CustomPaint(
          size: Size(c.maxWidth, c.maxHeight),
          painter: _BarPainter(values, selected, bar, barSoft, grid),
        ),
      );
    });
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.values, this.selected, this.bar, this.barSoft, this.grid);
  final List<double> values;
  final int? selected;
  final Color bar;
  final Color barSoft;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    // เส้นประแนวนอน 3 เส้น + เส้นฐาน
    for (final f in [0.0, 0.33, 0.66]) {
      final y = size.height * f + 0.5;
      for (double x = 0; x < size.width; x += 7) {
        canvas.drawLine(
            Offset(x, y), Offset(math.min(x + 3, size.width), y), gridPaint);
      }
    }
    canvas.drawLine(Offset(0, size.height - 0.5),
        Offset(size.width, size.height - 0.5), gridPaint);
    if (values.isEmpty) return;

    final n = values.length;
    final maxV = values.fold<double>(0, math.max);
    final top = maxV <= 0 ? 1.0 : maxV * 1.08;
    final slot = size.width / n;
    final gap = n > 14 ? slot * 0.28 : slot * 0.34;
    final w = math.max(2.0, slot - gap);
    final focus = selected ?? n - 1;

    for (var i = 0; i < n; i++) {
      final v = values[i];
      final hRaw = (v / top) * (size.height - 4);
      final h = v > 0 ? math.max(3.0, hRaw) : 2.0;
      final x = i * slot + gap / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, size.height - h, w, h),
        topLeft: Radius.circular(math.min(5, w / 2)),
        topRight: Radius.circular(math.min(5, w / 2)),
      );
      final on = i == focus;
      final paint = Paint();
      if (on && v > 0) {
        paint.shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: TpPalette.goldButton,
        ).createShader(rect.outerRect);
      } else {
        paint.color = v > 0 ? barSoft : grid;
      }
      canvas.drawRRect(rect, paint);
      if (on && selected != null) {
        // ขีดบอกตำแหน่งวันที่เลือก
        canvas.drawLine(
          Offset(x + w / 2, 0),
          Offset(x + w / 2, size.height - h - 4),
          Paint()
            ..color = bar.withValues(alpha: 0.35)
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.selected != selected ||
      old.bar != bar ||
      old.barSoft != barSoft ||
      old.grid != grid ||
      !_listEq(old.values, values);

  static bool _listEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ═════════════════════ รายวัน ═════════════════════

class _DailyList extends StatelessWidget {
  const _DailyList(
      {required this.comm, required this.mem, required this.limit});
  final List<DayPoint> comm;
  final List<DayPoint> mem;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final rows = <Widget>[];
    // ล่าสุดก่อน
    for (var i = comm.length - 1; i >= 0 && rows.length < limit; i--) {
      final d = comm[i].day;
      final c = comm[i].value;
      final m = i < mem.length ? mem[i].value : 0.0;
      final isToday = _sameDay(d, now);
      final isYesterday = _sameDay(d, yesterday);
      rows.add(TpRow(
        dense: true,
        leading: _DateBlock(day: d, highlight: isToday),
        title: isToday
            ? 'วันนี้'
            : (isYesterday ? 'เมื่อวาน' : 'วัน${_thDays[d.weekday - 1]}'),
        subtitle:
            m > 0 ? 'สมาชิกใหม่ ${TpFmt.count(m)} คน' : 'ไม่มีสมาชิกสมัครใหม่',
        chevron: false,
        trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c > 0 ? TpFmt.baht(c) : '-',
                  style: TpType.money(14.5, c > 0 ? p.goldText : p.faint)),
              Text('ค่าคอมฯ ที่จ่าย', style: TpType.body(10.5, p.faint)),
            ]),
      ));
    }
    return TpGroup(children: rows);
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.day, required this.highlight});
  final DateTime day;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: highlight ? p.goldSoft : p.inset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight ? p.borderGold : p.border),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${day.day}',
            style: TpType.money(16, highlight ? p.goldText : p.textStrong)
                .copyWith(height: 1.05)),
        Text('${_thDaysShort[day.weekday - 1]} ${_thMonths[day.month - 1]}',
            maxLines: 1,
            style: TpType.body(9.5, p.muted, w: FontWeight.w500, height: 1.1)),
      ]),
    );
  }
}

// ═════════════════════ หมายเหตุ ═════════════════════

class _Notes extends StatelessWidget {
  const _Notes();

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 14, color: p.faint)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TpType.body(12, p.muted))),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: TpCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(PhosphorIconsRegular.info, size: 16, color: p.goldText),
            const SizedBox(width: 6),
            Text('ที่มาของตัวเลข', style: TpType.h(13.5, p.textStrong)),
          ]),
          line(PhosphorIconsRegular.storefront,
              'ยอดขาย = ออเดอร์ร้านค้าที่ชำระแล้ว นับตามปฏิทิน (วันนี้ / ตั้งแต่วันจันทร์ / ตั้งแต่วันที่ 1) ไม่รวมรายได้ดูดวง — ดูได้ที่หน้าภาพรวม'),
          line(PhosphorIconsRegular.scales,
              'เฉลี่ย/ออเดอร์ = ยอดที่ชำระแล้ว ÷ ออเดอร์ทั้งหมด (รวมออเดอร์ที่ยังไม่จ่าย) จึงอาจต่ำกว่าราคาจริงต่อออเดอร์'),
          line(PhosphorIconsRegular.handCoins,
              'ค่าคอมฯ ที่จ่าย = คอมมิชชั่น MLM ที่จ่ายให้สมาชิกแล้ว (เงินออก) ไม่ใช่รายได้ของบริษัท · กราฟนับย้อนหลังแบบเลื่อน 7 หรือ 30 วัน'),
        ]),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const TpHeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TpSkeleton(width: 120, height: 12),
        SizedBox(height: 10),
        TpSkeleton(width: 190, height: 36),
        SizedBox(height: 8),
        TpSkeleton(width: 150, height: 10),
        SizedBox(height: 18),
        TpSkeleton(height: 34),
      ]),
    );
  }
}
