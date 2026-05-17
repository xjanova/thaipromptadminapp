import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Donut chart — ringed arcs ตามดีไซน์ Analytics screen
///
/// แต่ละ [DonutSegment] = สีและสัดส่วน (0..1)
/// total ของทุก segment ไม่จำเป็นต้องเท่ากับ 1.0 — ส่วนที่เหลือจะเป็น track สีจาง
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    required this.centerLabel,
    required this.centerSub,
    this.size = 130,
    this.stroke = 14,
    this.trackColor = const Color(0x14FFFFFF),
  });

  final List<DonutSegment> segments;
  final String centerLabel;
  final String centerSub;
  final double size;
  final double stroke;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              segments: segments,
              stroke: stroke,
              trackColor: trackColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                centerSub,
                style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DonutSegment {
  const DonutSegment(this.fraction, this.color, this.label);
  final double fraction;
  final Color color;
  final String label;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.stroke,
    required this.trackColor,
  });

  final List<DonutSegment> segments;
  final double stroke;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - stroke) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    double startAngle = -math.pi / 2;
    const gap = 0.04; // small gap between segments

    for (final seg in segments) {
      final sweep = (seg.fraction * 2 * math.pi) - gap;
      if (sweep <= 0) {
        startAngle += seg.fraction * 2 * math.pi;
        continue;
      }
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += seg.fraction * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.stroke != stroke ||
      oldDelegate.trackColor != trackColor;
}
