import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tp_palette.dart';
import '../../core/theme/tp_theme.dart';

/// กราฟพื้นที่เส้นโค้งสีทอง (ใช้บนการ์ดฮีโร่) — วาดเองด้วย CustomPainter ให้ควบคุมหน้าตาได้ครบ
///
/// [values] ค่าตามลำดับเวลา · จุดสุดท้ายมีวงเรือง "ตอนนี้"
class TpAreaChart extends StatelessWidget {
  const TpAreaChart({
    super.key,
    required this.values,
    this.height = 92,
    this.color = TpPalette.heroGold,
    this.gridColor = const Color(0x0FFFFFFF),
    this.showNow = true,
    this.slots,
  });

  final List<double> values;
  final double height;
  final Color color;
  final Color gridColor;
  final bool showNow;

  /// จำนวนช่องแกน X ทั้งหมด (เช่น 24 ชั่วโมง) — ถ้าค่ามีน้อยกว่า เส้นจะหยุดกลางกราฟพร้อมเส้นประต่อ
  final int? slots;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
          painter: _AreaPainter(values, color, gridColor, showNow, slots)),
    );
  }
}

class _AreaPainter extends CustomPainter {
  _AreaPainter(this.values, this.color, this.grid, this.showNow, this.slots);
  final List<double> values;
  final Color color;
  final Color grid;
  final bool showNow;
  final int? slots;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = size.height * f;
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(
            Offset(x, y), Offset(math.min(x + 3, size.width), y), gridPaint);
      }
    }
    if (values.isEmpty) return;

    final n = math.max(values.length, 2);
    final total = math.max(slots ?? n, n);
    final maxV = values.fold<double>(0, math.max);
    final top = maxV <= 0 ? 1.0 : maxV * 1.12;
    final stepX = size.width / (total - 1);
    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(i * stepX,
            size.height - 6 - (values[i] / top) * (size.height - 14)),
    ];
    if (pts.length == 1) pts.add(Offset(stepX, pts.first.dy));

    // เส้นโค้งแบบ Catmull-Rom → Bezier
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      line.cubicTo(c1.dx, math.min(c1.dy, size.height), c2.dx,
          math.min(c2.dy, size.height), p2.dx, p2.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(colors: [
          Color(0xFFC99A40),
          Color(0xFFF0C96A),
          Color(0xFFF8E7B0)
        ]).createShader(Offset.zero & size),
    );

    final last = pts.last;
    // เส้นประต่อไปจนสุดแกน (ช่วงเวลาที่ยังมาไม่ถึง)
    if (last.dx < size.width - 4) {
      final dash = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 2;
      for (double x = last.dx + 6; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, last.dy),
            Offset(math.min(x + 3, size.width), last.dy), dash);
      }
    }
    if (showNow) {
      canvas.drawCircle(
          last, 9, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(last, 4.5, Paint()..color = const Color(0xFFF8E7B0));
      canvas.drawCircle(
          last,
          4.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFFC99A40));
    }
  }

  @override
  bool shouldRepaint(covariant _AreaPainter old) =>
      old.values != values || old.color != color || old.slots != slots;
}

/// แถบความคืบหน้าบาง ๆ (เช่น โควตา LINE push)
class TpMeter extends StatelessWidget {
  const TpMeter({super.key, required this.value, this.color, this.height = 5});
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(children: [
        Container(height: height, color: p.divider),
        FractionallySizedBox(
          widthFactor: value.clamp(0, 1),
          child: Container(height: height, color: color ?? p.gold),
        ),
      ]),
    );
  }
}

/// ตัวเลขใหญ่ + คำบรรยายเล็ก (ใช้ในกริดสถิติ)
class TpStat extends StatelessWidget {
  const TpStat(
      {super.key,
      required this.label,
      required this.value,
      this.color,
      this.align = CrossAxisAlignment.start});
  final String label;
  final String value;
  final Color? color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TpType.body(11.5, p.muted, w: FontWeight.w500)),
          const SizedBox(height: 1),
          Text(value, style: TpType.money(17, color ?? p.textStrong)),
        ]);
  }
}
