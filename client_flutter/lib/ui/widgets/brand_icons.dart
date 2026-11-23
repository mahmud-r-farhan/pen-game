// lib/ui/widgets/brand_icons.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Sharp, pixel-perfect 4-color Google 'G' vector logo
class GoogleGLogo extends StatelessWidget {
  final double size;
  const GoogleGLogo({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _GoogleGPainter());
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    final double radius = w / 2;
    final double strokeWidth = w * 0.22;

    // Google Brand Colors
    const Color googleBlue = Color(0xFF4285F4);
    const Color googleGreen = Color(0xFF34A853);
    const Color googleYellow = Color(0xFFFBBC05);
    const Color googleRed = Color(0xFFEA4335);

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Rect arcRect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    // 1. Red Arc (Top left to top right: -220° to -135°)
    arcPaint.color = googleRed;
    canvas.drawArc(arcRect, -math.pi * 0.95, math.pi * 0.58, false, arcPaint);

    // 2. Yellow Arc (Bottom left: -140° to -60°)
    arcPaint.color = googleYellow;
    canvas.drawArc(arcRect, -math.pi * 1.45, math.pi * 0.52, false, arcPaint);

    // 3. Green Arc (Bottom: -60° to 30°)
    arcPaint.color = googleGreen;
    canvas.drawArc(arcRect, -math.pi * 1.95, math.pi * 0.54, false, arcPaint);

    // 4. Blue Arc (Right side)
    arcPaint.color = googleBlue;
    canvas.drawArc(arcRect, math.pi * 0.05, math.pi * 0.40, false, arcPaint);

    // 5. Blue Horizontal Crossbar
    final Paint barPaint = Paint()
      ..color = googleBlue
      ..style = PaintingStyle.fill;

    final Rect barRect = Rect.fromLTRB(
      center.dx - strokeWidth * 0.2,
      center.dy - strokeWidth / 2,
      w,
      center.dy + strokeWidth / 2,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sharp, authentic Facebook roundel logo with white 'f'
class FacebookLogo extends StatelessWidget {
  final double size;
  const FacebookLogo({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.72,
            fontFamily: 'sans-serif',
            height: 1.05,
          ),
        ),
      ),
    );
  }
}
