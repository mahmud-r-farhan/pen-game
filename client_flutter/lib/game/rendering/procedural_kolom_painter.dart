// lib/game/rendering/procedural_kolom_painter.dart
import 'package:flutter/material.dart';
import '../../models/kolom_spec.dart';

class ProceduralKolomPainter {
  /// Procedurally renders a top-down authentic Bangladeshi ballpoint pen centered at (0, 0).
  /// [scale]: physics zoom or UI preview multiplier
  /// [fallScale]: scaling down during knockout drop off the bench
  /// [strikeOffsetMarker]: -0.85 (back cap) to +0.85 (nib tip)
  /// [showStrikeMarker]: whether to render aiming target dot
  /// [isTeetering]: whether pen is hovering over the bench edge
  static void drawPen(
    Canvas canvas,
    KolomSpec spec, {
    double scale = 1.0,
    double fallScale = 1.0,
    double strikeOffsetMarker = 0.0,
    bool showStrikeMarker = false,
    bool isTeetering = false,
    double teeterAngle = 0.0,
  }) {
    canvas.save();
    canvas.scale(scale * fallScale, scale * fallScale);

    if (isTeetering && teeterAngle != 0.0) {
      canvas.rotate(teeterAngle);
    }

    final double halfL = spec.length / 2;
    final double r = spec.radius;

    // 0. Neon Glow Aura (for Cyberpunk Neon Spinner)
    if (spec.model == KolomModel.neonSpinner) {
      final neonGlow = Paint()
        ..color = spec.accentColor.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.50);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(-halfL * 0.95, -r * 2.4, halfL * 0.95, r * 2.4),
          Radius.circular(r * 2),
        ),
        neonGlow,
      );
    }

    // 1. DYNAMIC DROP SHADOW (3D height effect)
    final double shadowOffsetY = isTeetering ? 0.38 : 0.16;
    final double shadowOffsetX = isTeetering ? 0.22 : 0.09;
    final double shadowBlur = isTeetering ? 0.30 : 0.14;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isTeetering ? 0.55 : 0.40)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          -halfL + shadowOffsetX,
          -r + shadowOffsetY,
          halfL + shadowOffsetX,
          r + shadowOffsetY,
        ),
        Radius.circular(r * 0.8),
      ),
      shadowPaint,
    );

    // 2. INNER INK REFILL TUBE (Visible in translucent pens)
    if (spec.isTransparent) {
      final inkTubePaint = Paint()
        ..color = const Color(0xFF0D47A1)
        ..strokeWidth = r * 0.45
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(-halfL * 0.72, 0),
        Offset(halfL * 0.72, 0),
        inkTubePaint,
      );

      // Ink meniscus air bubble
      final airBubblePaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
      canvas.drawCircle(Offset(halfL * 0.45, 0), r * 0.18, airBubblePaint);
    }

    // 3. MAIN CYLINDRICAL BARREL
    final barrelRect = Rect.fromLTRB(-halfL * 0.78, -r, halfL * 0.72, r);
    final barrelGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(spec.barrelColor, Colors.white, 0.50)!,
        spec.barrelColor,
        Color.lerp(spec.barrelColor, Colors.black, 0.45)!,
      ],
      stops: const [0.0, 0.38, 1.0],
    );

    final barrelPaint = Paint()..shader = barrelGradient.createShader(barrelRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barrelRect, Radius.circular(r * 0.4)),
      barrelPaint,
    );

    // Decorative barrel rings / stripes
    if (spec.model == KolomModel.hiSchoolClassic) {
      final stripePaint = Paint()
        ..color = spec.capColor.withValues(alpha: 0.85)
        ..strokeWidth = 0.08;
      canvas.drawLine(Offset(-halfL * 0.25, -r), Offset(-halfL * 0.25, r), stripePaint);
      canvas.drawLine(Offset(-halfL * 0.15, -r), Offset(-halfL * 0.15, r), stripePaint);
    } else if (spec.model == KolomModel.goldParkerVIP) {
      final goldStripe = Paint()
        ..color = const Color(0xFFFFF8DC).withValues(alpha: 0.95)
        ..strokeWidth = 0.10;
      canvas.drawLine(Offset(-halfL * 0.40, -r), Offset(-halfL * 0.40, r), goldStripe);
      canvas.drawLine(Offset(halfL * 0.20, -r), Offset(halfL * 0.20, r), goldStripe);
    }

    // 4. RUBBER GRIP & RIBBED TACTILE GROOVES
    if (spec.hasRubberGrip) {
      final gripRect = Rect.fromLTRB(halfL * 0.25, -r * 1.08, halfL * 0.70, r * 1.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(gripRect, Radius.circular(r * 0.3)),
        Paint()..color = spec.gripColor,
      );

      // Ribbed tactile grip grooves
      final groovePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..strokeWidth = 0.05;
      for (double x = halfL * 0.30; x < halfL * 0.65; x += 0.08) {
        canvas.drawLine(Offset(x, -r * 1.0), Offset(x, r * 1.0), groovePaint);
      }
    }

    // 5. FRONT CONE & BALLPOINT NIB (OR DUAL CAP)
    if (spec.isDoubleCapped) {
      _drawCap(canvas, spec, isBackCap: false);
    } else {
      // Sleek nose cone
      final conePath = Path()
        ..moveTo(halfL * 0.72, -r * 0.92)
        ..lineTo(halfL * 0.96, -r * 0.26)
        ..lineTo(halfL * 0.96, r * 0.26)
        ..lineTo(halfL * 0.72, r * 0.92)
        ..close();
      canvas.drawPath(conePath, Paint()..color = spec.capColor);

      // Metallic silver ballpoint nib
      final nibPaint = Paint()..color = const Color(0xFFCFD8DC);
      canvas.drawCircle(Offset(halfL * 0.97, 0), r * 0.24, nibPaint);

      // Micro tungsten carbide ball
      canvas.drawCircle(
        Offset(halfL * 0.99, 0),
        r * 0.11,
        Paint()..color = const Color(0xFF263238),
      );
    }

    // 6. BACK POSTED CAP + POCKET CLIP
    _drawCap(canvas, spec, isBackCap: true);

    // 7. SPECULAR GLOSS HIGHLIGHT STRIP
    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = r * 0.30
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-halfL * 0.65, -r * 0.52),
      Offset(halfL * 0.65, -r * 0.52),
      glossPaint,
    );

    // 8. STRIKE POINT INDICATOR (Flick Contact Reticle)
    if (showStrikeMarker) {
      final double strikeX = halfL * strikeOffsetMarker;
      final markerOuter = Paint()
        ..color = const Color(0xFFFF1744)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(strikeX, 0), r * 0.62, markerOuter);

      final markerRing = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07;
      canvas.drawCircle(Offset(strikeX, 0), r * 0.95, markerRing);

      final crosshair = Paint()
        ..color = Colors.white
        ..strokeWidth = 0.05;
      canvas.drawLine(Offset(strikeX - r * 0.35, 0), Offset(strikeX + r * 0.35, 0), crosshair);
      canvas.drawLine(Offset(strikeX, -r * 0.35), Offset(strikeX, r * 0.35), crosshair);
    }

    canvas.restore();
  }

  static void _drawCap(Canvas canvas, KolomSpec spec, {required bool isBackCap}) {
    final double halfL = spec.length / 2;
    final double r = spec.radius * 1.20; // Cap is slightly thicker than barrel
    final Rect capRect = isBackCap
        ? Rect.fromLTRB(-halfL, -r, -halfL * 0.45, r)
        : Rect.fromLTRB(halfL * 0.45, -r, halfL, r);

    // Cap 3D shading
    final capShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(spec.capColor, Colors.white, 0.45)!,
        spec.capColor,
        Color.lerp(spec.capColor, Colors.black, 0.40)!,
      ],
    ).createShader(capRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, Radius.circular(r * 0.45)),
      Paint()..shader = capShader,
    );

    // Pocket Clip
    final double clipStart = isBackCap ? -halfL * 0.93 : halfL * 0.93;
    final double clipEnd = isBackCap ? -halfL * 0.35 : halfL * 0.35;
    final clipPaint = Paint()
      ..color = Color.lerp(spec.capColor, Colors.white, 0.40)!
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(clipStart, -r * 1.18), Offset(clipEnd, -r * 1.18), clipPaint);

    // Clip finial bump
    canvas.drawCircle(
      Offset(clipEnd, -r * 1.18),
      r * 0.22,
      Paint()..color = Color.lerp(spec.capColor, Colors.white, 0.55)!,
    );
  }
}
