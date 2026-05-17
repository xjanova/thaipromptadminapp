import 'package:flutter/material.dart';

/// 3D Cube — กล่อง 3 มิติ (top + left + right face)
///
/// อ้างอิงดีไซน์ app.jsx Cube3D:
///   top face:   linear-gradient(135deg, faceC, faceA), diamond polygon (4 points)
///   left face:  linear-gradient(180deg, faceA, faceB), parallelogram
///   right face: linear-gradient(180deg, faceB, faceA) brightness 0.85, parallelogram (mirrored)
///
/// ใช้ CustomPaint แทน CSS clip-path เพื่อให้ rendering ตรงกัน
class Cube3D extends StatelessWidget {
  const Cube3D({
    super.key,
    this.size = 64,
    this.faceA = const Color(0xFF7C3AED),
    this.faceB = const Color(0xFFA855F7),
    this.faceC = const Color(0xFFC084FC),
    this.tilt = 0,
  });

  final double size;
  final Color faceA;
  final Color faceB;
  final Color faceC;

  /// องศาเอียงเพิ่มเติม (สำหรับ satellite ที่หมุนเล็กน้อย)
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt * 3.14159 / 180,
      child: SizedBox(
        width: size * 1.15,
        height: size * 1.25,
        child: CustomPaint(
          painter: _CubePainter(
            size: size,
            faceA: faceA,
            faceB: faceB,
            faceC: faceC,
          ),
        ),
      ),
    );
  }
}

class _CubePainter extends CustomPainter {
  _CubePainter({
    required this.size,
    required this.faceA,
    required this.faceB,
    required this.faceC,
  });

  final double size;
  final Color faceA;
  final Color faceB;
  final Color faceC;

  @override
  void paint(Canvas canvas, Size s) {
    final cx = size * 0.075;

    // ── Top face (diamond, brighter) ──
    final topPath = Path()
      ..moveTo(cx + size * 0.5, 0) // top point
      ..lineTo(cx + size, size * 0.3 * 0.55) // right point
      ..lineTo(cx + size * 0.5, size * 0.55) // bottom point
      ..lineTo(cx, size * 0.3 * 0.55) // left point
      ..close();
    final topPaint = Paint()
      ..shader = LinearGradient(
        colors: [faceC, faceA],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(cx, 0, size, size * 0.55));
    canvas.drawPath(topPath, topPaint);

    // ── Left face (parallelogram) ──
    final leftPath = Path()
      ..moveTo(cx, size * 0.27 + 0) // top-left
      ..lineTo(cx + size * 0.5, size * 0.55) // top-right (meets top bottom point)
      ..lineTo(cx + size * 0.5, size * 0.55 + size * 0.7) // bottom-right
      ..lineTo(cx, size * 0.27 + size * 0.7) // bottom-left
      ..close();
    final leftPaint = Paint()
      ..shader = LinearGradient(
        colors: [faceA, faceB],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(
          Rect.fromLTWH(cx, size * 0.27, size * 0.5, size * 0.7));
    canvas.drawPath(leftPath, leftPaint);

    // ── Right face (parallelogram, slightly darker) ──
    final rightPath = Path()
      ..moveTo(cx + size * 0.5, size * 0.55) // top-left (meets top bottom point)
      ..lineTo(cx + size, size * 0.27) // top-right
      ..lineTo(cx + size, size * 0.27 + size * 0.7) // bottom-right
      ..lineTo(cx + size * 0.5, size * 0.55 + size * 0.7) // bottom-left
      ..close();
    final rightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Color.lerp(faceB, Colors.black, 0.18)!,
          Color.lerp(faceA, Colors.black, 0.18)!,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(
          cx + size * 0.5, size * 0.27, size * 0.5, size * 0.7));
    canvas.drawPath(rightPath, rightPaint);

    // ── Subtle edge highlights ──
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // Top-front edge (from top bottom-point downward at center)
    canvas.drawLine(
      Offset(cx + size * 0.5, size * 0.55),
      Offset(cx + size * 0.5, size * 0.55 + size * 0.7),
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CubePainter old) =>
      old.size != size ||
      old.faceA != faceA ||
      old.faceB != faceB ||
      old.faceC != faceC;
}
