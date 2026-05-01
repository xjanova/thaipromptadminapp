import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 3D Orb (glowing ball) — สำหรับ AI Brain card ในหน้า AI Management
///
/// Design handoff (screens-4.jsx):
///   radial-gradient(circle, white, #f0abfc, #a855f7, #4c1d95)
///   box-shadow: 0 0 40px rgba(hue, 0.7) — glow
///   pulse 2s infinite ease-in-out (glow 0.6 → 1.0)
class Orb3D extends StatelessWidget {
  const Orb3D({
    super.key,
    this.size = 130,
    this.hue = 270,
    this.pulse = true,
  });

  final double size;
  final double hue; // 270 = purple (default for AI Brain)
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final base = HSLColor.fromAHSL(1, hue, 0.85, 0.5).toColor();
    final mid = HSLColor.fromAHSL(1, hue, 0.7, 0.7).toColor();
    final dark = HSLColor.fromAHSL(1, hue, 0.9, 0.3).toColor();

    Widget orb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 0.95,
          colors: [Colors.white, mid, base, dark],
          stops: const [0.0, 0.28, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.7),
            blurRadius: 40,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: dark.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );

    if (pulse) {
      orb = orb
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            duration: const Duration(milliseconds: 2000),
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.05, 1.05),
            curve: Curves.easeInOut,
          )
          .then()
          .fadeIn(duration: const Duration(milliseconds: 0));
    }

    return orb;
  }
}
