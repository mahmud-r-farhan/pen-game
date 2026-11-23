// lib/game/rendering/procedural_kolom_painter.dart
import 'package:flutter/material.dart';
import '../../models/kolom_spec.dart';

/// Reusable paint bundle for one pen model.
///
/// The painter runs every frame for both pens (plus shop/splash previews).
/// Creating gradients, paths and Paint objects per draw causes avoidable GC
/// churn on low-end devices, so everything that depends only on the pen model
/// is built once and reused.
class _PenPaints {
  final KolomSpec spec;

  final Paint neonGlow = Paint();
  final Paint shadow = Paint();
  final Paint shadowTeeter = Paint();
  final Paint inkTube = Paint();
  final Paint airBubble = Paint();
  final Paint barrel = Paint();
  final Paint stripe = Paint();
  final Paint grip = Paint();
  final Paint groove = Paint();
  final Paint cone = Paint();
  final Paint nib = Paint();
  final Paint ball = Paint();
  final Paint gloss = Paint();
  final Paint capBack = Paint();
  final Paint capFront = Paint();
  final Paint clipBack = Paint();
  final Paint clipFront = Paint();
  final Paint finialBack = Paint();
  final Paint finialFront = Paint();
  final Paint markerOuter = Paint();
  final Paint markerRing = Paint();
  final Paint markerCross = Paint();

  late final Path conePath;

  _PenPaints(this.spec) {
    final double halfL = spec.length / 2;
    final double r = spec.radius;

    if (spec.model == KolomModel.neonSpinner) {
      neonGlow
        ..color = spec.accentColor.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.50);
    }

    shadow
      ..color = Colors.black.withValues(alpha: 0.40)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.14);
    shadowTeeter
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.30);

    if (spec.isTransparent) {
      inkTube
        ..color = const Color(0xFF0D47A1)
        ..strokeWidth = r * 0.45
        ..strokeCap = StrokeCap.round;
      airBubble.color = Colors.white.withValues(alpha: 0.8);
    }

    final Rect barrelRect = Rect.fromLTRB(-halfL * 0.78, -r, halfL * 0.72, r);
    barrel.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(spec.barrelColor, Colors.white, 0.50)!,
        spec.barrelColor,
        Color.lerp(spec.barrelColor, Colors.black, 0.45)!,
      ],
      stops: const [0.0, 0.38, 1.0],
    ).createShader(barrelRect);

    if (spec.model == KolomModel.hiSchoolClassic) {
      stripe
        ..color = spec.capColor.withValues(alpha: 0.85)
        ..strokeWidth = 0.08;
    } else if (spec.model == KolomModel.goldParkerVIP) {
      stripe
        ..color = const Color(0xFFFFF8DC).withValues(alpha: 0.95)
        ..strokeWidth = 0.10;
    }

    if (spec.hasRubberGrip) {
      grip.color = spec.gripColor;
      groove
        ..color = Colors.black.withValues(alpha: 0.45)
        ..strokeWidth = 0.05;
    }

    if (!spec.isDoubleCapped) {
      conePath = Path()
        ..moveTo(halfL * 0.72, -r * 0.92)
        ..lineTo(halfL * 0.96, -r * 0.26)
        ..lineTo(halfL * 0.96, r * 0.26)
        ..lineTo(halfL * 0.72, r * 0.92)
        ..close();
      cone.color = spec.capColor;
      nib.color = const Color(0xFFCFD8DC);
      ball.color = const Color(0xFF263238);
    } else {
      conePath = Path();
    }

    gloss
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = r * 0.30
      ..strokeCap = StrokeCap.round;

    _buildCap(isBack: true);
    _buildCap(isBack: false);

    markerOuter
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.fill;
    markerRing
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.07;
    markerCross
      ..color = Colors.white
      ..strokeWidth = 0.05;
  }

  void _buildCap({required bool isBack}) {
    final double halfL = spec.length / 2;
    final double r = spec.radius * 1.20;
    final Rect capRect = isBack
        ? Rect.fromLTRB(-halfL, -r, -halfL * 0.45, r)
        : Rect.fromLTRB(halfL * 0.45, -r, halfL, r);

    final Paint capPaint = isBack ? capBack : capFront;
    capPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(spec.capColor, Colors.white, 0.45)!,
        spec.capColor,
        Color.lerp(spec.capColor, Colors.black, 0.40)!,
      ],
    ).createShader(capRect);

    final double clipStart = isBack ? -halfL * 0.93 : halfL * 0.93;
    final double clipEnd = isBack ? -halfL * 0.35 : halfL * 0.35;
    final Paint clipPaint = isBack ? clipBack : clipFront;
    clipPaint
      ..color = Color.lerp(spec.capColor, Colors.white, 0.40)!
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.round;

    final Paint finialPaint = isBack ? finialBack : finialFront;
    finialPaint.color = Color.lerp(spec.capColor, Colors.white, 0.55)!;

    // Clip geometry is constant per model, so it is stored once here.
    if (isBack) {
      _backClipStart = clipStart;
      _backClipEnd = clipEnd;
    } else {
      _frontClipStart = clipStart;
      _frontClipEnd = clipEnd;
    }
  }

  late double _backClipStart;
  late double _backClipEnd;
  late double _frontClipStart;
  late double _frontClipEnd;

  double clipStart(bool isBack) => isBack ? _backClipStart : _frontClipStart;
  double clipEnd(bool isBack) => isBack ? _backClipEnd : _frontClipEnd;
}

class ProceduralKolomPainter {
  static final Map<KolomModel, _PenPaints> _paints = {};

  /// Paints are keyed by [KolomModel]. `KolomSpec.catalog` is the single source
  /// of pen definitions, so one model always maps to one immutable spec.
  static _PenPaints _paintsFor(KolomSpec spec) {
    return _paints.putIfAbsent(spec.model, () => _PenPaints(spec));
  }

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
    final _PenPaints paints = _paintsFor(spec);
    final double halfL = spec.length / 2;
    final double r = spec.radius;

    canvas.save();
    canvas.scale(scale * fallScale, scale * fallScale);

    if (isTeetering && teeterAngle != 0.0) {
      canvas.rotate(teeterAngle);
    }

    // 0. Neon Glow Aura (for Cyberpunk Neon Spinner)
    if (spec.model == KolomModel.neonSpinner) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(-halfL * 0.95, -r * 2.4, halfL * 0.95, r * 2.4),
          Radius.circular(r * 2),
        ),
        paints.neonGlow,
      );
    }

    // 1. DYNAMIC DROP SHADOW (3D height effect)
    final double shadowOffsetY = isTeetering ? 0.38 : 0.16;
    final double shadowOffsetX = isTeetering ? 0.22 : 0.09;

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
      isTeetering ? paints.shadowTeeter : paints.shadow,
    );

    // 2. INNER INK REFILL TUBE (Visible in translucent pens)
    if (spec.isTransparent) {
      canvas.drawLine(
        Offset(-halfL * 0.72, 0),
        Offset(halfL * 0.72, 0),
        paints.inkTube,
      );
      canvas.drawCircle(Offset(halfL * 0.45, 0), r * 0.18, paints.airBubble);
    }

    // 3. MAIN CYLINDRICAL BARREL
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-halfL * 0.78, -r, halfL * 0.72, r),
        Radius.circular(r * 0.4),
      ),
      paints.barrel,
    );

    // Decorative barrel rings / stripes
    if (spec.model == KolomModel.hiSchoolClassic) {
      canvas.drawLine(
        Offset(-halfL * 0.25, -r),
        Offset(-halfL * 0.25, r),
        paints.stripe,
      );
      canvas.drawLine(
        Offset(-halfL * 0.15, -r),
        Offset(-halfL * 0.15, r),
        paints.stripe,
      );
    } else if (spec.model == KolomModel.goldParkerVIP) {
      canvas.drawLine(
        Offset(-halfL * 0.40, -r),
        Offset(-halfL * 0.40, r),
        paints.stripe,
      );
      canvas.drawLine(
        Offset(halfL * 0.20, -r),
        Offset(halfL * 0.20, r),
        paints.stripe,
      );
    }

    // 4. RUBBER GRIP & RIBBED TACTILE GROOVES
    if (spec.hasRubberGrip) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(halfL * 0.25, -r * 1.08, halfL * 0.70, r * 1.08),
          Radius.circular(r * 0.3),
        ),
        paints.grip,
      );

      for (double x = halfL * 0.30; x < halfL * 0.65; x += 0.08) {
        canvas.drawLine(Offset(x, -r * 1.0), Offset(x, r * 1.0), paints.groove);
      }
    }

    // 5. FRONT CONE & BALLPOINT NIB (OR DUAL CAP)
    if (spec.isDoubleCapped) {
      _drawCap(canvas, paints, isBackCap: false);
    } else {
      canvas.drawPath(paints.conePath, paints.cone);
      canvas.drawCircle(Offset(halfL * 0.97, 0), r * 0.24, paints.nib);
      canvas.drawCircle(Offset(halfL * 0.99, 0), r * 0.11, paints.ball);
    }

    // 6. BACK POSTED CAP + POCKET CLIP
    _drawCap(canvas, paints, isBackCap: true);

    // 7. SPECULAR GLOSS HIGHLIGHT STRIP
    canvas.drawLine(
      Offset(-halfL * 0.65, -r * 0.52),
      Offset(halfL * 0.65, -r * 0.52),
      paints.gloss,
    );

    // 8. STRIKE POINT INDICATOR (Flick Contact Reticle)
    if (showStrikeMarker) {
      final double strikeX = halfL * strikeOffsetMarker;
      canvas.drawCircle(Offset(strikeX, 0), r * 0.62, paints.markerOuter);
      canvas.drawCircle(Offset(strikeX, 0), r * 0.95, paints.markerRing);
      canvas.drawLine(
        Offset(strikeX - r * 0.35, 0),
        Offset(strikeX + r * 0.35, 0),
        paints.markerCross,
      );
      canvas.drawLine(
        Offset(strikeX, -r * 0.35),
        Offset(strikeX, r * 0.35),
        paints.markerCross,
      );
    }

    canvas.restore();
  }

  static void _drawCap(
    Canvas canvas,
    _PenPaints paints, {
    required bool isBackCap,
  }) {
    final KolomSpec spec = paints.spec;
    final double halfL = spec.length / 2;
    final double r = spec.radius * 1.20; // Cap is slightly thicker than barrel
    final Rect capRect = isBackCap
        ? Rect.fromLTRB(-halfL, -r, -halfL * 0.45, r)
        : Rect.fromLTRB(halfL * 0.45, -r, halfL, r);

    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, Radius.circular(r * 0.45)),
      isBackCap ? paints.capBack : paints.capFront,
    );

    // Pocket Clip
    final double clipStart = paints.clipStart(isBackCap);
    final double clipEnd = paints.clipEnd(isBackCap);
    canvas.drawLine(
      Offset(clipStart, -r * 1.18),
      Offset(clipEnd, -r * 1.18),
      isBackCap ? paints.clipBack : paints.clipFront,
    );

    // Clip finial bump
    canvas.drawCircle(
      Offset(clipEnd, -r * 1.18),
      r * 0.22,
      isBackCap ? paints.finialBack : paints.finialFront,
    );
  }
}
