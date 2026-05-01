import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 3D Coin (เหรียญทอง 3 มิติ) — design handoff Coin3D
class Coin3D extends StatelessWidget {
  const Coin3D({
    super.key,
    this.size = 70,
    this.symbol = '฿',
  });

  final double size;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.0,
          colors: const [
            Color(0xFFFFF7D6),
            AppColors.goldStart,
            AppColors.goldEnd,
            Color(0xFF92400E),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldEnd.withValues(alpha: 0.7),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.goldEnd,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: size * 0.48,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF92400E),
            shadows: [
              Shadow(
                color: Colors.white.withValues(alpha: 0.4),
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
