import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Crystal Ball — ลูกแก้วทำนายสำหรับหน้า Fortune
///
/// อ้างอิง design handoff (screens-4.jsx):
/// - 110px ball: radial gradient (white → #f0abfc → #c084fc → #7c3aed → #1e1b4b)
/// - inset shadows
/// - gold base 70×18px (ฐานรอง)
class CrystalBall extends StatelessWidget {
  const CrystalBall({super.key, this.size = 110, this.pulse = true});

  final double size;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    Widget ball = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: [
            Colors.white,
            Color(0xFFF0ABFC),
            Color(0xFFC084FC),
            Color(0xFF7C3AED),
            Color(0xFF1E1B4B),
          ],
          stops: [0.0, 0.18, 0.45, 0.78, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC084FC).withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
    );

    if (pulse) {
      ball = ball
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.96, 0.96),
            end: const Offset(1.04, 1.04),
            duration: const Duration(milliseconds: 2400),
            curve: Curves.easeInOut,
          );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ball,
        const SizedBox(height: -2), // overlap base
        // Gold base
        Container(
          width: size * 0.6,
          height: size * 0.16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF92400E), Color(0xFFFBBF24), Color(0xFF92400E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.08),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
