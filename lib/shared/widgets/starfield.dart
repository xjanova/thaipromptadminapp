import 'dart:math';

import 'package:flutter/material.dart';

/// Starfield — พื้นหลังดาวสำหรับ Fortune screen (cosmic theme)
///
/// อ้างอิง design handoff: 60 dots, sizes 0.5–2px, opacity 0.4–1.0
class Starfield extends StatelessWidget {
  const Starfield({super.key, this.starCount = 60, this.seed = 42});

  final int starCount;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarfieldPainter(starCount: starCount, seed: seed),
      size: Size.infinite,
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({required this.starCount, required this.seed});
  final int starCount;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < starCount; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final radius = 0.5 + rng.nextDouble() * 1.5; // 0.5–2px
      final opacity = 0.4 + rng.nextDouble() * 0.6; // 0.4–1.0
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
