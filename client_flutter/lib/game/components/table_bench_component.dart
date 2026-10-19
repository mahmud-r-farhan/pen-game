// lib/game/components/table_bench_component.dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../models/arena_room.dart';

class TableBenchComponent extends Component {
  final Rect bounds;
  final ArenaRoom room;

  TableBenchComponent({
    required this.bounds,
    required this.room,
    super.priority = 0,
  });

  @override
  void render(Canvas canvas) {
    canvas.save();
    // 1. Dark Classroom Floor around the bench
    final floorPaint = Paint()..color = const Color(0xFF0A0C10);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 80, height: 60),
      floorPaint,
    );

    // Subtle classroom floor tile grid
    final tileGridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 0.06;
    for (double x = -40; x <= 40; x += 4.0) {
      canvas.drawLine(Offset(x, -30), Offset(x, 30), tileGridPaint);
    }
    for (double y = -30; y <= 30; y += 4.0) {
      canvas.drawLine(Offset(-40, y), Offset(40, y), tileGridPaint);
    }

    // 2. Table Bench Drop Shadow (Deep 3D perspective onto floor)
    final shadowBounds = bounds.shift(const Offset(0.4, 0.8));
    final dropShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowBounds, const Radius.circular(0.6)),
      dropShadowPaint,
    );

    // 3. 3D Front Desk Lip (Thickness perspective from HTML prototype)
    final lipRect = Rect.fromLTRB(bounds.left, bounds.bottom, bounds.right, bounds.bottom + 0.55);
    final lipGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        room.borderColor,
        Color.lerp(room.borderColor, Colors.black, 0.55)!,
        Colors.black,
      ],
    ).createShader(lipRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lipRect, const Radius.circular(0.2)),
      Paint()..shader = lipGradient,
    );
    // Bevel highlight line on lip edge
    canvas.drawLine(
      Offset(bounds.left, bounds.bottom),
      Offset(bounds.right, bounds.bottom),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = 0.08,
    );

    // 4. Beveled Table Outer Border / Trim
    final borderPaint = Paint()..color = room.borderColor;
    final outerBounds = bounds.inflate(0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerBounds, const Radius.circular(0.45)),
      borderPaint,
    );

    // 5. Main Table Surface
    final surfaceShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [room.tableColorStart, room.tableColorEnd],
    ).createShader(bounds);

    final surfacePaint = Paint()..shader = surfaceShader;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(0.35)),
      surfacePaint,
    );

    // 6. Classroom Nostalgia Details: Scratches, Graffiti, Compass Punctures, Ink Blots
    _renderNostalgiaDetails(canvas);

    // 7. Authentic Room-specific Texture
    _renderRoomTexture(canvas);

    // 8. Table Center Divider Line (Bengali Classroom Bench seam)
    final dividerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 0.08;
    canvas.drawLine(
      Offset(bounds.left + 0.5, 0),
      Offset(bounds.right - 0.5, 0),
      dividerPaint,
    );

    // Center circular table emblem / logo watermark
    final emblemRing = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12;
    canvas.drawCircle(Offset.zero, 2.8, emblemRing);
    canvas.drawCircle(Offset.zero, 1.4, emblemRing);

    // Center arena text watermark
    final tp = TextPainter(
      text: TextSpan(
        text: 'KOLOM KHELA',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.04),
          fontWeight: FontWeight.w900,
          fontSize: 1.6,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

    // 9. Ruler markings along the top desk border
    final rulerTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.04;
    for (double x = bounds.left + 0.8; x < bounds.right - 0.8; x += 0.4) {
      final isMajor = ((x - bounds.left) * 10).round() % 20 == 0;
      final tickLen = isMajor ? 0.35 : 0.18;
      canvas.drawLine(
        Offset(x, bounds.top + 0.08),
        Offset(x, bounds.top + 0.08 + tickLen),
        rulerTickPaint,
      );
    }

    canvas.restore();
  }

  void _renderNostalgiaDetails(Canvas canvas) {
    // 1. Carved student graffiti into the wood desk
    final carvePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.04;

    // Student love heart carve: "রাফি + সুমনা"
    final heartPath = Path();
    const hx = -6.5;
    const hy = -3.2;
    heartPath.moveTo(hx, hy);
    heartPath.cubicTo(hx - 0.6, hy - 0.8, hx - 1.2, hy + 0.4, hx, hy + 1.2);
    heartPath.cubicTo(hx + 1.2, hy + 0.4, hx + 0.6, hy - 0.8, hx, hy);
    canvas.drawPath(heartPath, carvePaint);

    // Carved graffiti text painter
    void drawCarvedText(String text, Offset pos, double size, [double angle = 0.0]) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      if (angle != 0.0) canvas.rotate(angle);
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.11),
            fontWeight: FontWeight.w900,
            fontSize: size,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, Offset.zero);
      canvas.restore();
    }

    drawCarvedText('রাফি + সুমনা', const Offset(-8.2, -2.8), 0.32, -0.06);
    drawCarvedText('ROLL-07', const Offset(4.8, 3.4), 0.34, 0.08);
    drawCarvedText('LAST BENCH 👑', const Offset(3.5, -4.2), 0.35, -0.04);
    drawCarvedText('SSC 24', const Offset(-7.8, 4.0), 0.30, 0.12);

    // 2. Tic-Tac-Toe carved into bench
    const tX = -3.8;
    const tY = 3.6;
    final tGrid = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.035;
    canvas.drawLine(const Offset(tX - 0.4, tY - 0.2), const Offset(tX + 0.8, tY - 0.2), tGrid);
    canvas.drawLine(const Offset(tX - 0.4, tY + 0.2), const Offset(tX + 0.8, tY + 0.2), tGrid);
    canvas.drawLine(const Offset(tX, tY - 0.5), const Offset(tX, tY + 0.5), tGrid);
    canvas.drawLine(const Offset(tX + 0.4, tY - 0.5), const Offset(tX + 0.4, tY + 0.5), tGrid);

    // 3. Compass puncture circular scratches
    final compassPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.03;
    canvas.drawCircle(const Offset(6.2, -1.8), 0.9, compassPaint);
    canvas.drawCircle(const Offset(6.2, -1.8), 0.04, Paint()..color = Colors.white.withValues(alpha: 0.18));

    // 4. Folklore Ink Leak Stains (Blue & Black Ink Blots)
    final blueInk = Paint()..color = const Color(0xFF0D47A1).withValues(alpha: 0.16);
    final blackInk = Paint()..color = Colors.black.withValues(alpha: 0.24);

    // Primary ink blot
    canvas.drawCircle(const Offset(-2.4, -3.8), 0.32, blueInk);
    canvas.drawCircle(const Offset(-2.2, -3.7), 0.18, blueInk);
    canvas.drawCircle(const Offset(-2.5, -3.5), 0.12, blueInk);

    // Secondary ink smudge
    canvas.drawCircle(const Offset(7.4, 2.8), 0.28, blackInk);
    canvas.drawCircle(const Offset(7.6, 2.9), 0.15, blackInk);
  }

  void _renderRoomTexture(Canvas canvas) {
    switch (room.textureType) {
      case TableTextureType.woodScratched:
        final scratchPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 0.05;
        // Compass arc
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(-5, -2), width: 3.5, height: 3.5),
          0.2,
          2.4,
          false,
          scratchPaint,
        );
        // Ruler scratches
        for (double i = -7; i < -2; i += 0.7) {
          canvas.drawLine(Offset(i, 2.0), Offset(i + 1.2, 3.2), scratchPaint);
        }
        break;

      case TableTextureType.varnishedTeak:
        final grainPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.10)
          ..strokeWidth = 0.06;
        for (double y = bounds.top + 1.0; y < bounds.bottom; y += 1.8) {
          canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y + 0.3), grainPaint);
        }
        final gloss = Paint()
          ..color = Colors.white.withValues(alpha: 0.07)
          ..strokeWidth = 0.40;
        canvas.drawLine(
          Offset(bounds.left + 1.5, bounds.top + 0.8),
          Offset(bounds.right - 1.5, bounds.top + 0.8),
          gloss,
        );
        break;

      case TableTextureType.draftingGreen:
        final gridPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.09)
          ..strokeWidth = 0.035;
        for (double x = bounds.left + 1.0; x < bounds.right; x += 1.5) {
          canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), gridPaint);
        }
        for (double y = bounds.top + 1.0; y < bounds.bottom; y += 1.5) {
          canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), gridPaint);
        }
        break;

      case TableTextureType.stainlessSteel:
        final metalSheen = Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..strokeWidth = 0.8;
        canvas.drawLine(
          Offset(bounds.left + 2, -1.5),
          Offset(bounds.right - 2, -1.0),
          metalSheen,
        );
        final labTint = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.15;
        canvas.drawRRect(RRect.fromRectAndRadius(bounds.deflate(0.3), const Radius.circular(0.2)), labTint);
        break;

      case TableTextureType.examMahogany:
        final chalkTextPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..strokeWidth = 0.06;
        canvas.drawRect(
          const Rect.fromLTWH(-7.5, -4.5, 3.2, 1.8),
          chalkTextPaint..style = PaintingStyle.stroke,
        );
        break;

      case TableTextureType.militaryCherry:
        final brassPaint = Paint()..color = const Color(0xFFFFD700);
        const cornerSize = 1.2;
        _drawLBracket(canvas, bounds.topLeft, cornerSize, 1, 1, brassPaint);
        _drawLBracket(canvas, bounds.topRight, cornerSize, -1, 1, brassPaint);
        _drawLBracket(canvas, bounds.bottomLeft, cornerSize, 1, -1, brassPaint);
        _drawLBracket(canvas, bounds.bottomRight, cornerSize, -1, -1, brassPaint);
        break;

      case TableTextureType.executiveGlass:
        final neonEdge = Paint()
          ..color = const Color(0xFF00F0FF).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.25);
        canvas.drawRRect(RRect.fromRectAndRadius(bounds, const Radius.circular(0.35)), neonEdge);

        final glassStreak = Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(bounds.left + 4, bounds.bottom - 1),
          Offset(bounds.right - 4, bounds.top + 1),
          glassStreak,
        );
        break;
    }
  }

  void _drawLBracket(
    Canvas canvas,
    Offset corner,
    double size,
    double dirX,
    double dirY,
    Paint paint,
  ) {
    final path = Path()
      ..moveTo(corner.dx, corner.dy)
      ..lineTo(corner.dx + size * dirX, corner.dy)
      ..lineTo(corner.dx + size * dirX, corner.dy + 0.25 * dirY)
      ..lineTo(corner.dx + 0.25 * dirX, corner.dy + 0.25 * dirY)
      ..lineTo(corner.dx + 0.25 * dirX, corner.dy + size * dirY)
      ..lineTo(corner.dx, corner.dy + size * dirY)
      ..close();
    canvas.drawPath(path, paint);
  }
}
