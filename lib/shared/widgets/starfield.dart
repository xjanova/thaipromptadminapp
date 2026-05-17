import 'dart:math';

import 'package:flutter/material.dart';

/// Starfield — พื้นหลังดาวสำหรับ Fortune screen (cosmic theme)
///
/// อ้างอิง design handoff: 60 dots, sizes 0.5–2px, opacity 0.4–1.0
/// + twinkle animation (3s loop, opacity wobble) ตามที่ระบุใน Interactions section
class Starfield extends StatefulWidget {
  const Starfield({
    super.key,
    this.starCount = 80,
    this.seed = 42,
    this.twinkle = true,
  });

  final int starCount;
  final int seed;

  /// เปิด/ปิด twinkle animation. ถ้าปิด stars จะค้างที่ opacity เริ่มต้น
  final bool twinkle;

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.seed);
    _stars = [
      for (int i = 0; i < widget.starCount; i++)
        _Star(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          radius: 0.5 + rng.nextDouble() * 1.5,
          baseOpacity: 0.4 + rng.nextDouble() * 0.6,
          phase: rng.nextDouble(), // 0..1 — เหลื่อมเฟส twinkle
        ),
    ];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.twinkle) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          painter: _StarfieldPainter(
            stars: _stars,
            t: _controller.value,
            twinkle: widget.twinkle,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.baseOpacity,
    required this.phase,
  });
  final double x;
  final double y;
  final double radius;
  final double baseOpacity;
  final double phase;
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({
    required this.stars,
    required this.t,
    required this.twinkle,
  });

  final List<_Star> stars;
  final double t;
  final bool twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      // wobble opacity ±0.25 with per-star phase offset, smooth sine
      final wobble = twinkle
          ? 0.25 * sin((t + s.phase) * 2 * pi)
          : 0.0;
      final opacity = (s.baseOpacity + wobble).clamp(0.15, 1.0);
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) =>
      old.t != t || old.twinkle != twinkle;
}
