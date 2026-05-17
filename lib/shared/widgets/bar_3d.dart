import 'package:flutter/material.dart';

/// 3D Bar — แท่งกราฟ 3 มิติ (top-down gradient + side highlights)
///
/// อ้างอิงดีไซน์ screens-3.jsx Analytics:
///   linear-gradient(180deg, light, base, dark)
///   inset -3px 0 0 rgba(0,0,0,0.18) — right shadow
///   inset 3px 0 0 rgba(255,255,255,0.25) — left highlight
class Bar3D extends StatelessWidget {
  const Bar3D({
    super.key,
    required this.heightFraction,
    this.gradient,
    this.label,
    this.highlight = false,
  });

  /// 0.0 – 1.0
  final double heightFraction;
  final Gradient? gradient;
  final String? label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final gradientToUse = gradient ??
        const LinearGradient(
          colors: [Color(0xFF818CF8), Color(0xFF6366F1), Color(0xFF4338CA)],
          stops: [0.0, 0.7, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );

    return LayoutBuilder(builder: (_, c) {
      final h = (c.maxHeight * heightFraction).clamp(8.0, c.maxHeight);
      return Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: c.maxWidth,
            height: h,
            decoration: BoxDecoration(
              gradient: gradientToUse,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
                bottom: Radius.circular(4),
              ),
              border: const Border(
                left: BorderSide(color: Color(0x40FFFFFF), width: 1.5),
                right: BorderSide(color: Color(0x30000000), width: 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          if (highlight && label != null)
            Positioned(
              bottom: h + 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
