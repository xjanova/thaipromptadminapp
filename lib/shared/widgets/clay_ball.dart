import 'package:flutter/material.dart';

/// 3D Clay Ball — สร้างจาก Container + RadialGradient + box shadow
///
/// อ้างอิงจาก design handoff ([source/app.jsx Clay component])
/// Pseudo:
///   radial-gradient(circle at 30% 25%, hsl(h s l+18%) 0%, hsl(h s l) 45%, hsl(h s l-18%) 100%)
///   inset shadows (top-left light, bottom-right dark)
///   drop shadow with hue-based glow
class ClayBall extends StatelessWidget {
  const ClayBall({
    super.key,
    this.size = 56,
    this.hue = 240,
    this.saturation = 0.8,
    this.lightness = 0.6,
    this.child,
  });

  final double size;
  final double hue;
  final double saturation;
  final double lightness;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final base = HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
    final light = HSLColor.fromAHSL(1, hue, saturation, (lightness + 0.18).clamp(0.0, 1.0)).toColor();
    final dark = HSLColor.fromAHSL(1, hue, saturation, (lightness - 0.18).clamp(0.0, 1.0)).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.9,
          colors: [light, base, dark],
          stops: const [0.0, 0.45, 1.0],
        ),
        boxShadow: [
          // Outer glow (hue-based)
          BoxShadow(
            color: base.withValues(alpha: 0.55),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.18),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inset highlight (top-left)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.45, -0.5),
                  radius: 0.7,
                  colors: [Colors.white.withValues(alpha: 0.55), Colors.transparent],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
