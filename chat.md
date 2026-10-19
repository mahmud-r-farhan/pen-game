This complete, production-ready code implementation covers your **Flutter + Flame (`flame_forge2d`)** client, **procedural 2D Bangladeshi Pen (কলম) renderer** (zero external PNG assets required!), and **Deno + Deno KV** authoritative multiplayer & Ghost Bot backend.

---

## Part 1: 2D Kolom Design Architecture (Zero-PNG Procedural Canvas)

Instead of hiring an illustrator or bundling heavy PNG sprites that blur when zoomed in, you can draw **vector-sharp 2D pens directly on the Flutter `Canvas**`. Every pen is built on a modular **6-Layer Top-Down Anatomy** centered at `(0, 0)` along the local X-axis (`-L/2` to `+L/2`):

1. **Dynamic Drop Shadow:** Offset by `(3, 5)` with `MaskFilter.blur`—As a pen teeters on the edge of the bench, increasing the shadow offset makes it look like it is lifting into the air before falling!
2. **Main Barrel:** Drawn with a vertical `LinearGradient` (`white -> baseColor -> darkShade`) so a flat 2D rectangle looks like a 3D cylindrical plastic or metal tube.
3. **Inner Ink Refill Tube:** For transparent pens like *Matador Hi-School* or *Linc Ocean Gel*, draw a thin dark-blue line down the center of the translucent barrel.
4. **Textured Rubber Grip:** Ribbed rings near the front nose cone for grip-heavy pens.
5. **Conical Nib & Ballpoint Tip:** Tapered polygon on the right end (`+L/2`) with a metallic silver tip.
6. **Detachable Cap & Clip:** Placed on the back (`-L/2`), front, or both ends (for the legendary *Double-Cap Mod*).

```dart
// lib/models/kolom_skin.dart
import 'package:flutter/material.dart';

enum KolomModel {
  hiSchoolClassic, // Matador Hi-School vibe: White barrel, blue cap, lightweight speedster
  econoStriker,    // Econo DX vibe: Clear yellow-tinted barrel, red cap, visible ink tube
  oceanGelPro,     // Linc Ocean Gel vibe: Translucent sky blue, ribbed rubber grip
  hectorMetalTank, // Metallic charcoal/gold executive pen, heavy mass, low recoil
  doubleCapMod,    // Classroom illegal mod: Two caps + internal screw weight!
}

class KolomSpec {
  final KolomModel model;
  final String name;
  final double length;         // Physics meters (e.g., 2.2m in Forge2D world)
  final double radius;         // Half-thickness in meters (e.g., 0.13m)
  final double density;        // Controls mass (Heavy pens = 2.0+, Light = 0.8)
  final double linearDamping;  // Sliding friction on wooden bench
  final double angularDamping; // Spin resistance (Rubber grips stop spinning faster)
  final double restitution;    // Bounciness on collision
  final double comOffsetX;     // Center-of-mass shift toward the capped end!
  final Color barrelColor;
  final Color capColor;
  final Color gripColor;
  final bool isTransparent;
  final bool hasRubberGrip;
  final bool isDoubleCapped;

  const KolomSpec({
    required this.model,
    required this.name,
    required this.length,
    required this.radius,
    required this.density,
    required this.linearDamping,
    required this.angularDamping,
    required this.restitution,
    required this.comOffsetX,
    required this.barrelColor,
    required this.capColor,
    required this.gripColor,
    this.isTransparent = false,
    this.hasRubberGrip = false,
    this.isDoubleCapped = false,
  });

  static const Map<KolomModel, KolomSpec> catalog = {
    KolomModel.hiSchoolClassic: KolomSpec(
      model: KolomModel.hiSchoolClassic,
      name: 'Hi-School Classic',
      length: 4.2,
      radius: 0.22,
      density: 0.85,
      linearDamping: 2.3,
      angularDamping: 1.7,
      restitution: 0.65,
      comOffsetX: -0.35, // Cap posted on back shifts weight backward
      barrelColor: Color(0xFFF5F7FA),
      capColor: Color(0xFF1565C0),
      gripColor: Color(0xFF1565C0),
    ),
    KolomModel.econoStriker: KolomSpec(
      model: KolomModel.econoStriker,
      name: 'Econo DX Striker',
      length: 4.4,
      radius: 0.23,
      density: 0.95,
      linearDamping: 2.5,
      angularDamping: 1.9,
      restitution: 0.60,
      comOffsetX: -0.25,
      barrelColor: Color(0x99FFF59D),
      capColor: Color(0xFFD32F2F),
      gripColor: Color(0xFFD32F2F),
      isTransparent: true,
    ),
    KolomModel.oceanGelPro: KolomSpec(
      model: KolomModel.oceanGelPro,
      name: 'Ocean Gel Grip',
      length: 4.4,
      radius: 0.26,
      density: 1.35,
      linearDamping: 3.1,
      angularDamping: 2.8, // Rubber grip prevents rolling off the edge
      restitution: 0.50,
      comOffsetX: -0.30,
      barrelColor: Color(0xAA4FC3F7),
      capColor: Color(0xFF0277BD),
      gripColor: Color(0xFF01579B),
      isTransparent: true,
      hasRubberGrip: true,
    ),
    KolomModel.hectorMetalTank: KolomSpec(
      model: KolomModel.hectorMetalTank,
      name: 'Hector Metal Tank',
      length: 4.5,
      radius: 0.28,
      density: 2.10, // Heavyweight tank!
      linearDamping: 3.5,
      angularDamping: 3.1,
      restitution: 0.38,
      comOffsetX: 0.0,
      barrelColor: Color(0xFF37474F),
      capColor: Color(0xFFFFD54F), // Gold metallic trim
      gripColor: Color(0xFF263238),
      hasRubberGrip: true,
    ),
    KolomModel.doubleCapMod: KolomSpec(
      model: KolomModel.doubleCapMod,
      name: 'Double-Cap Boss (Mod)',
      length: 4.8,
      radius: 0.28,
      density: 2.45, // Stuffed with paper & dual caps
      linearDamping: 3.7,
      angularDamping: 3.4,
      restitution: 0.45,
      comOffsetX: 0.0, // Perfectly balanced symmetrical battering ram
      barrelColor: Color(0xFF212121),
      capColor: Color(0xFF00E676),
      gripColor: Color(0xFF00C853),
      hasRubberGrip: true,
      isDoubleCapped: true,
    ),
  };
}

```

### The 2D Procedural Kolom Painter (`kolom_painter.dart`)

You can use this single class both **inside your Flame `BodyComponent.render(Canvas)**` and inside **Flutter UI `CustomPaint` cards** in the Pen Garage/Shop!

```dart
// lib/game/rendering/kolom_painter.dart
import 'package:flutter/material.dart';
import '../../models/kolom_skin.dart';

class KolomRenderer {
  /// Renders a detailed 2D top-down Bangladeshi pen centered at (0,0).
  /// In Flame Forge2D, 1 meter = 1 unit on Canvas.
  static void drawKolom(
    Canvas canvas,
    KolomSpec spec, {
    double fallScale = 1.0,
    double strikeOffsetMarker = 0.0,
    bool showStrikeMarker = false,
  }) {
    canvas.save();
    canvas.scale(fallScale, fallScale);

    final double halfL = spec.length / 2;
    final double r = spec.radius;

    // 1. DROP SHADOW (Gives 3D depth on the wooden bench)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-halfL + 0.08, -r + 0.12, halfL + 0.08, r + 0.12),
        Radius.circular(r),
      ),
      shadowPaint,
    );

    // 2. TRANSPARENT INNER INK REFILL TUBE (For Econo DX / Ocean Gel)
    if (spec.isTransparent) {
      final refillPaint = Paint()
        ..color = const Color(0xFF0D47A1)
        ..strokeWidth = r * 0.45
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(-halfL * 0.65, 0),
        Offset(halfL * 0.72, 0),
        refillPaint,
      );
    }

    // 3. MAIN CYLINDRICAL BARREL (3D Metallic/Plastic Gradient)
    final barrelRect = Rect.fromLTRB(-halfL * 0.75, -r, halfL * 0.68, r);
    final barrelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(spec.barrelColor, Colors.white, 0.45)!,
          spec.barrelColor,
          Color.lerp(spec.barrelColor, Colors.black, 0.35)!,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(barrelRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(barrelRect, Radius.circular(r * 0.4)),
      barrelPaint,
    );

    // 4. RUBBERIZED GRIP & RIBBED RINGS (Near the front)
    if (spec.hasRubberGrip) {
      final gripRect = Rect.fromLTRB(halfL * 0.22, -r * 1.05, halfL * 0.65, r * 1.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(gripRect, Radius.circular(r * 0.2)),
        Paint()..color = spec.gripColor,
      );
      // Draw tactile grip grooves
      final groovePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 0.04;
      for (double x = halfL * 0.28; x < halfL * 0.60; x += 0.10) {
        canvas.drawLine(Offset(x, -r * 0.95), Offset(x, r * 0.95), groovePaint);
      }
    }

    // 5. FRONT CONE & BALLPOINT TIP (Or Second Cap for Double-Cap Mod)
    if (spec.isDoubleCapped) {
      _drawCap(canvas, spec, isBackCap: false);
    } else {
      final conePath = Path()
        ..moveTo(halfL * 0.68, -r * 0.92)
        ..lineTo(halfL * 0.95, -r * 0.22)
        ..lineTo(halfL * 0.95, r * 0.22)
        ..lineTo(halfL * 0.68, r * 0.92)
        ..close();
      canvas.drawPath(conePath, Paint()..color = spec.capColor);

      // Silver steel ballpoint tip
      canvas.drawCircle(
        Offset(halfL * 0.97, 0),
        r * 0.20,
        Paint()..color = const Color(0xFFCFD8DC),
      );
    }

    // 6. BACK POSTED CAP + POCKET CLIP
    _drawCap(canvas, spec, isBackCap: true);

    // 7. SPECULAR HIGHLIGHT STRIP (Makes it look glossy like real plastic)
    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = r * 0.25
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-halfL * 0.55, -r * 0.52),
      Offset(halfL * 0.55, -r * 0.52),
      glossPaint,
    );

    // 8. STRIKE POINT INDICATOR (Shows where the finger will flick the pen)
    if (showStrikeMarker) {
      final double strikeX = halfL * strikeOffsetMarker;
      final markerPaint = Paint()
        ..color = const Color(0xFFFF1744)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(strikeX, 0), r * 0.55, markerPaint);
      canvas.drawCircle(
        Offset(strikeX, 0),
        r * 0.85,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05,
      );
    }

    canvas.restore();
  }

  static void _drawCap(Canvas canvas, KolomSpec spec, {required bool isBackCap}) {
    final double halfL = spec.length / 2;
    final double r = spec.radius * 1.18; // Cap is slightly wider than barrel
    final Rect capRect = isBackCap
        ? Rect.fromLTRB(-halfL, -r, -halfL * 0.42, r)
        : Rect.fromLTRB(halfL * 0.42, -r, halfL, r);

    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, Radius.circular(r * 0.45)),
      Paint()..color = spec.capColor,
    );

    // Pocket Clip protruding slightly on the side
    final double clipStart = isBackCap ? -halfL * 0.90 : halfL * 0.90;
    final double clipEnd = isBackCap ? -halfL * 0.30 : halfL * 0.30;
    final clipPaint = Paint()
      ..color = Color.lerp(spec.capColor, Colors.white, 0.25)!
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(clipStart, -r * 1.15), Offset(clipEnd, -r * 1.15), clipPaint);
  }
}

```

---

## Part 2: Flutter + Flame (`flame_forge2d`) Real-World Game Code

> **Important 2026 Version Note:** `flame_forge2d: ^0.20.0` (built on Forge2D `0.15` / Box2D v3) uses `Forge2DGame` with zero gravity for top-down table physics.

### `pubspec.yaml`

```yaml
name: kolom_fight
description: Bangladeshi Classroom Pen Fight Game
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.6.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flame: ^1.35.0
  flame_forge2d: ^0.20.0
  web_socket_channel: ^3.0.1

```

### Complete Playable Game Engine (`lib/game/kolom_fight_game.dart`)

This file includes:

* The **Wooden School Bench Arena** with wood-grain procedural lines and drop-off edges.
* **Asymmetric Center of Mass** on each `PenBody` so flicking the tip creates a realistic helicopter whip-spin.
* **Drag-and-Release Slingshot** + **Strike Offset control** (`-0.8` back cap to `+0.8` front tip).
* **Edge Knockout Detection** with a smooth falling scale-down animation when a pen's center of mass crosses the bench edge.

```dart
// lib/game/kolom_fight_game.dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../models/kolom_skin.dart';
import 'rendering/kolom_painter.dart';

class KolomFightGame extends Forge2DGame with DragCallbacks {
  // Zero gravity because we are looking top-down at a flat school bench!
  KolomFightGame() : super(gravity: Vector2.zero(), zoom: 28.0);

  // Wooden bench bounds in physics meters (22m wide x 13m tall)
  static final Rect benchBounds = Rect.fromCenter(
    center: Offset.zero,
    width: 22.0,
    height: 13.0,
  );

  late PenBodyComponent playerPen;
  late PenBodyComponent opponentPen;

  bool isPlayerTurn = true;
  double strikeOffset = 0.65; // +0.65 = Hit near the front tip for whip-spin!
  Vector2? dragStartWorld;
  Vector2? dragCurrentWorld;

  final ValueNotifier<String> statusBanner = ValueNotifier('Your Turn! Drag to Flick');

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;

    // 1. Add Wooden School Bench Background
    world.add(WoodenBenchComponent(benchBounds));

    // 2. Spawn Player & Opponent Pens
    _spawnMatchPens();
  }

  void _spawnMatchPens() {
    playerPen = PenBodyComponent(
      spec: KolomSpec.catalog[KolomModel.oceanGelPro]!,
      initialPosition: Vector2(-6.5, 2.5),
      initialAngle: -0.15,
      isPlayer: true,
      onKnockedOut: () => _handleKnockout(isPlayerEliminated: true),
    );

    opponentPen = PenBodyComponent(
      spec: KolomSpec.catalog[KolomModel.hectorMetalTank]!,
      initialPosition: Vector2(6.5, -2.5),
      initialAngle: math.pi - 0.15,
      isPlayer: false,
      onKnockedOut: () => _handleKnockout(isPlayerEliminated: false),
    );

    world.addAll([playerPen, opponentPen]);
  }

  bool get areAllPensStopped => playerPen.isStopped && opponentPen.isStopped;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!isPlayerTurn || !areAllPensStopped || playerPen.isEliminated) return;
    dragStartWorld = screenToWorld(event.localPosition);
    dragCurrentWorld = dragStartWorld;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (dragStartWorld == null) return;
    dragCurrentWorld = screenToWorld(event.localPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (dragStartWorld != null && dragCurrentWorld != null) {
      // Slingshot vector (pull back to shoot forward)
      final Vector2 pullVector = dragStartWorld! - dragCurrentWorld!;
      if (pullVector.length > 0.4) {
        final Vector2 clampedImpulse = pullVector.normalized() *
            math.min(pullVector.length * 6.5, 42.0);

        playerPen.flick(
          impulse: clampedImpulse,
          strikeOffsetNormalized: strikeOffset,
        );

        isPlayerTurn = false;
        statusBanner.value = 'Opponent Thinking...';
        _scheduleBotCounterAttack();
      }
    }
    dragStartWorld = null;
    dragCurrentWorld = null;
  }

  void _scheduleBotCounterAttack() async {
    // Wait until pens come to rest
    while (!areAllPensStopped) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (playerPen.isEliminated || opponentPen.isEliminated) return;

    await Future.delayed(const Duration(milliseconds: 900));

    // AI Bot calculates vector toward Player's Pen + adds whip spin
    final Vector2 toPlayer = playerPen.body.position - opponentPen.body.position;
    final double distance = toPlayer.length;
    final Vector2 botImpulse = toPlayer.normalized() * math.min(distance * 2.8, 38.0);

    opponentPen.flick(
      impulse: botImpulse,
      strikeOffsetNormalized: 0.55, // Bot uses a spin-strike!
    );

    isPlayerTurn = true;
    statusBanner.value = 'Your Turn! Adjust Strike Point & Flick';
  }

  void _handleKnockout({required bool isPlayerEliminated}) {
    if (isPlayerEliminated) {
      statusBanner.value = 'OUT! Your Kolom fell off the bench!';
    } else {
      statusBanner.value = 'VICTORY! You knocked out the opponent (+900 Coins)!';
    }
  }

  void resetRound() {
    world.removeAll([playerPen, opponentPen]);
    isPlayerTurn = true;
    statusBanner.value = 'New Round! Drag to Flick';
    _spawnMatchPens();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw Slingshot Aiming Arrow when dragging
    if (dragStartWorld != null && dragCurrentWorld != null && !playerPen.isEliminated) {
      final Vector2 pull = dragStartWorld! - dragCurrentWorld!;
      final Offset penStrikeScreen = worldToScreen(
        playerPen.getStrikeWorldPoint(strikeOffset),
      ).toOffset();
      final Offset targetScreen = worldToScreen(
        playerPen.getStrikeWorldPoint(strikeOffset) + pull * 1.5,
      ).toOffset();

      final aimPaint = Paint()
        ..color = Colors.amberAccent
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(penStrikeScreen, targetScreen, aimPaint);
    }
  }
}

/// Renders the Bangladeshi Wooden School Bench & Drop-Off Floor
class WoodenBenchComponent extends Component {
  final Rect bounds;
  WoodenBenchComponent(this.bounds);

  @override
  void render(Canvas canvas) {
    // Dark classroom floor outside the bench
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 60, height: 40),
      Paint()..color = const Color(0xFF14181D),
    );

    // Bench Drop Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.shift(const Offset(0.4, 0.6)), const Radius.circular(0.4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );

    // Main Teakwood Bench Surface
    final woodPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8D5524), Color(0xFF6E3F19), Color(0xFF583111)],
      ).createShader(bounds);

    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(0.35)),
      woodPaint,
    );

    // Subtle wooden plank divider line down the middle of the bench
    canvas.drawLine(
      Offset(bounds.left, 0),
      Offset(bounds.right, 0),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..strokeWidth = 0.08,
    );
  }
}

/// Rigid-Body Physics Component for each Kolom
class PenBodyComponent extends BodyComponent {
  final KolomSpec spec;
  final Vector2 initialPosition;
  final double initialAngle;
  final bool isPlayer;
  final VoidCallback onKnockedOut;

  bool isEliminated = false;
  double fallScale = 1.0;

  PenBodyComponent({
    required this.spec,
    required this.initialPosition,
    required this.initialAngle,
    required this.isPlayer,
    required this.onKnockedOut,
  }) : super(renderBody: false); // We use our custom KolomRenderer instead of debug wireframe

  bool get isStopped =>
      body.linearVelocity.length < 0.12 && body.angularVelocity.abs() < 0.18;

  @override
  Body createBody() {
    final shape = PolygonShape()
      ..setAsBox(
        spec.length / 2,
        spec.radius,
        Vector2(spec.comOffsetX, 0), // Shifts center of mass toward the cap!
        0.0,
      );

    final fixtureDef = FixtureDef(
      shape,
      density: spec.density,
      friction: 0.35,
      restitution: spec.restitution,
    );

    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: initialPosition,
      angle: initialAngle,
      linearDamping: spec.linearDamping,
      angularDamping: spec.angularDamping,
      bullet: true, // Continuous Collision Detection (CCD) so fast pens never tunnel!
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  Vector2 getStrikeWorldPoint(double strikeOffsetNormalized) {
    final localPoint = Vector2((spec.length / 2) * strikeOffsetNormalized, 0);
    return body.getWorldPoint(localPoint);
  }

  void flick({required Vector2 impulse, required double strikeOffsetNormalized}) {
    if (isEliminated) return;
    final worldStrikePoint = getStrikeWorldPoint(strikeOffsetNormalized);
    // Applying impulse at an offset point generates BOTH linear velocity and rotational whip torque!
    body.applyLinearImpulse(impulse, point: worldStrikePoint, wake: true);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isEliminated) {
      // Animate falling off the bench into the abyss
      if (fallScale > 0.25) {
        fallScale = math.max(0.25, fallScale - dt * 1.8);
      }
      return;
    }

    // Snap micro-creep to full stop so turns finish crisply
    if (isStopped) {
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0.0;
    }

    // Check if the Pen's Center of Mass crossed outside the Wooden Bench
    final pos = body.worldCenter;
    if (!KolomFightGame.benchBounds.contains(Offset(pos.x, pos.y))) {
      isEliminated = true;
      body.linearVelocity = body.linearVelocity * 0.3;
      onKnockedOut();
    }
  }

  @override
  void render(Canvas canvas) {
    final gameRef = findParent<KolomFightGame>();
    KolomRenderer.drawKolom(
      canvas,
      spec,
      fallScale: fallScale,
      strikeOffsetMarker: gameRef?.strikeOffset ?? 0.0,
      showStrikeMarker: isPlayer && (gameRef?.isPlayerTurn ?? false) && isStopped,
    );
  }
}

```

---

## Part 3: HUD Overlay & Strike-Point Selector (`lib/main.dart`)

To give players the authentic "Tip Flick vs. Center Push" control, overlay a clean HUD slider at the bottom of the screen:

```dart
// lib/main.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/kolom_fight_game.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: KolomFightScreen(),
  ));
}

class KolomFightScreen extends StatefulWidget {
  const KolomFightScreen({super.key});

  @override
  State<KolomFightScreen> createState() => _KolomFightScreenState();
}

class _KolomFightScreenState extends State<KolomFightScreen> {
  late final KolomFightGame _game = KolomFightGame();
  double _strikeOffset = 0.65;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      body: Stack(
        children: [
          // 1. Flame 2D Physics Arena
          GameWidget(game: _game),

          // 2. Top Status Banner & Reset Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: _game.statusBanner,
                    builder: (_, status, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _game.resetRound,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rematch'),
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Strike-Point Selector (Controls Spin vs Straight Push)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              width: 420,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Finger Strike Point: ${_strikeOffset > 0.3 ? "Tip Whip-Spin" : _strikeOffset < -0.3 ? "Back Cap Spin" : "Center Straight Push"}',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _strikeOffset,
                    min: -0.85,
                    max: 0.85,
                    activeColor: Colors.redAccent,
                    onChanged: (val) {
                      setState(() => _strikeOffset = val);
                      _game.strikeOffset = val;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

```

---

## Part 4: Deno + Deno KV Backend (Multiplayer, Coin Escrow & Ghost Bot)

Save this as `server.ts` and run it with `deno run --unstable-kv -A server.ts`.
It handles:

1. **Atomic Coin Escrow (`kv.atomic()`):** Deducts the stake (`500` coins) from both players when a match starts and awards `900` coins (`10%` platform sink) to the winner.
2. **4.5-Second Ghost Bot Fallback:** If a player waits in the matchmaking queue for `4.5s` without a human opponent, the server spawns an authoritative **Bangladeshi Ghost Bot** (*"Tanvir_Bogura"*, *"Sabbir_X"*, *"Nafis_07"*) so matchmaking never feels dead.
3. **Turn Validation & Broadcast:** Relays validated flick vectors (`impulseX`, `impulseY`, `strikeOffset`) between players.

```typescript
// server_deno/server.ts
/// <reference lib="deno.unstable" />

const kv = await Deno.openKv();

interface PlayerSession {
  userId: string;
  username: string;
  stake: number;
  penModel: string;
  socket: WebSocket;
  roomId?: string;
}

interface MatchRoom {
  roomId: string;
  stake: number;
  pot: number;
  p1: PlayerSession;
  p2: PlayerSession | null; // null if playing against Server Ghost Bot
  isGhostBotMatch: boolean;
  currentTurnUserId: string;
}

const waitingQueue = new Map<number, PlayerSession>(); // stake -> waiting player
const activeRooms = new Map<string, MatchRoom>();

const GHOST_BOT_NAMES = ["Tanvir_Bogura", "Sabbir_07", "Rifat_HSC", "Mehedi_X", "Fahim_Pro"];

// Ensure user has a starter wallet of 1,500 coins in Deno KV
async function ensureUserWallet(userId: string): Promise<number> {
  const key = ["wallet", userId];
  const res = await kv.get<number>(key);
  if (res.value === null) {
    await kv.set(key, 1500);
    return 1500;
  }
  return res.value;
}

// Atomic Coin Escrow Deduction
async function deductStakeAtomic(userId: string, stake: number): Promise<boolean> {
  const key = ["wallet", userId];
  const res = await kv.get<number>(key);
  const currentCoins = res.value ?? 0;
  if (currentCoins < stake) return false;

  const tx = await kv.atomic()
    .check(res)
    .set(key, currentCoins - stake)
    .commit();
  return tx.ok;
}

// Atomic Winner Payout (90% of Pot, 10% Economy Rake)
async function payoutWinnerAtomic(roomId: string, winnerId: string, pot: number) {
  const matchKey = ["match_settled", roomId];
  const walletKey = ["wallet", winnerId];

  const [matchCheck, walletRes] = await kv.getMany<[boolean, number]>([matchKey, walletKey]);
  if (matchCheck.value === true) return; // Prevent double-payout exploit!

  const reward = Math.floor(pot * 0.90);
  const currentCoins = walletRes.value ?? 0;

  await kv.atomic()
    .check(matchCheck)
    .set(matchKey, true)
    .set(walletKey, currentCoins + reward)
    .commit();
}

Deno.serve({ port: 8080 }, (req) => {
  if (req.headers.get("upgrade") !== "websocket") {
    return new Response("Kolom Fight Deno Server Running", { status: 200 });
  }

  const url = new URL(req.url);
  const userId = url.searchParams.get("uid") ?? crypto.randomUUID();
  const username = url.searchParams.get("name") ?? "Player";
  const stake = Number(url.searchParams.get("stake") ?? "500");
  const penModel = url.searchParams.get("pen") ?? "oceanGelPro";

  const { socket, response } = Deno.upgradeWebSocket(req);
  const session: PlayerSession = { userId, username, stake, penModel, socket };

  socket.onopen = async () => {
    const balance = await ensureUserWallet(userId);
    socket.send(JSON.stringify({ type: "WALLET_SYNC", coins: balance }));

    // Check if someone is already waiting at this Coin Stake tier
    const opponent = waitingQueue.get(stake);
    if (opponent && opponent.userId !== userId && opponent.socket.readyState === WebSocket.OPEN) {
      waitingQueue.delete(stake);
      await startPvPMatch(opponent, session, stake);
    } else {
      waitingQueue.set(stake, session);
      // 4.5-Second Timer -> Fallback to Seamless Ghost Bot if queue is empty!
      setTimeout(async () => {
        if (waitingQueue.get(stake)?.userId === userId) {
          waitingQueue.delete(stake);
          await startGhostBotMatch(session, stake);
        }
      }, 4500);
    }
  };

  socket.onmessage = async (event) => {
    const data = JSON.parse(event.data);
    if (!session.roomId) return;
    const room = activeRooms.get(session.roomId);
    if (!room) return;

    // 1. Handle Player Flick Turn
    if (data.type === "FLICK_SUBMIT" && room.currentTurnUserId === session.userId) {
      const clampedImpulseX = Math.max(-42, Math.min(42, Number(data.impulseX)));
      const clampedImpulseY = Math.max(-42, Math.min(42, Number(data.impulseY)));
      const clampedOffset = Math.max(-0.85, Math.min(0.85, Number(data.strikeOffset)));

      const payload = JSON.stringify({
        type: "FLICK_EXECUTE",
        actorId: session.userId,
        impulseX: clampedImpulseX,
        impulseY: clampedImpulseY,
        strikeOffset: clampedOffset,
      });

      room.p1.socket.send(payload);
      room.p2?.socket.send(payload);

      // Switch turn
      if (room.isGhostBotMatch) {
        room.currentTurnUserId = "GHOST_BOT";
        scheduleGhostBotTurn(room);
      } else if (room.p2) {
        room.currentTurnUserId =
          session.userId === room.p1.userId ? room.p2.userId : room.p1.userId;
      }
    }

    // 2. Handle Knockout Report & Coin Settlement
    if (data.type === "MATCH_KNOCKOUT") {
      const winnerId = data.winnerId;
      if (winnerId !== "GHOST_BOT") {
        await payoutWinnerAtomic(room.roomId, winnerId, room.pot);
      }
      const resultMsg = JSON.stringify({
        type: "MATCH_OVER",
        winnerId,
        payout: Math.floor(room.pot * 0.90),
      });
      room.p1.socket.send(resultMsg);
      room.p2?.socket.send(resultMsg);
      activeRooms.delete(room.roomId);
    }
  };

  socket.onclose = () => {
    if (waitingQueue.get(stake)?.userId === userId) {
      waitingQueue.delete(stake);
    }
  };

  return response;
});

async function startPvPMatch(p1: PlayerSession, p2: PlayerSession, stake: number) {
  const ok1 = await deductStakeAtomic(p1.userId, stake);
  const ok2 = await deductStakeAtomic(p2.userId, stake);
  if (!ok1 || !ok2) return;

  const roomId = crypto.randomUUID();
  p1.roomId = roomId;
  p2.roomId = roomId;

  const room: MatchRoom = {
    roomId,
    stake,
    pot: stake * 2,
    p1,
    p2,
    isGhostBotMatch: false,
    currentTurnUserId: p1.userId,
  };
  activeRooms.set(roomId, room);

  const startPayload = JSON.stringify({
    type: "MATCH_START",
    roomId,
    pot: room.pot,
    firstTurn: p1.userId,
    p1: { id: p1.userId, name: p1.username, pen: p1.penModel },
    p2: { id: p2.userId, name: p2.username, pen: p2.penModel },
  });
  p1.socket.send(startPayload);
  p2.socket.send(startPayload);
}

async function startGhostBotMatch(p1: PlayerSession, stake: number) {
  const ok = await deductStakeAtomic(p1.userId, stake);
  if (!ok) return;

  const roomId = crypto.randomUUID();
  p1.roomId = roomId;
  const botName = GHOST_BOT_NAMES[Math.floor(Math.random() * GHOST_BOT_NAMES.length)];

  const room: MatchRoom = {
    roomId,
    stake,
    pot: stake * 2,
    p1,
    p2: null,
    isGhostBotMatch: true,
    currentTurnUserId: p1.userId,
  };
  activeRooms.set(roomId, room);

  p1.socket.send(JSON.stringify({
    type: "MATCH_START",
    roomId,
    pot: room.pot,
    firstTurn: p1.userId,
    p1: { id: p1.userId, name: p1.username, pen: p1.penModel },
    p2: { id: "GHOST_BOT", name: botName, pen: "hectorMetalTank" },
  }));
}

function scheduleGhostBotTurn(room: MatchRoom) {
  // Wait 3.2 seconds for physics to settle + simulated human aiming delay
  setTimeout(() => {
    if (!activeRooms.has(room.roomId)) return;
    const botFlick = JSON.stringify({
      type: "FLICK_EXECUTE",
      actorId: "GHOST_BOT",
      impulseX: -22.5 + (Math.random() * 6 - 3),
      impulseY: 11.0 + (Math.random() * 4 - 2),
      strikeOffset: 0.60,
    });
    room.p1.socket.send(botFlick);
    room.currentTurnUserId = room.p1.userId;
  }, 3200);
}

```

---

## Part 5: Real-World Production Checklist for Google Play (BD Market)

1. **Landscape Lock (`AndroidManifest.xml`):**
School benches are wide (`22m x 13m`). Lock your activity to `android:screenOrientation="sensorLandscape"` so players have maximum horizontal room to pull back their slingshot without their thumb going off-screen.
2. **Collision Audio Pitch Randomization:**
When two pens collide (`onBeginContact` in `BodyComponent`), play `clack_plastic.wav` or `clack_metal.wav` using `FlameAudio`, and randomize the playback rate between `0.92` and `1.08` proportional to collision impact speed. That subtle detail prevents ear fatigue and makes heavy impacts feel crunchy.
3. **Parody Branding (Play Store IP Safety):**
Never use real registered trademarks like *"Matador"* or *"Linc"* in your Play Store text or on the pen barrel texture. Use recognizable classroom parodies (*"Matador Hi-School"* $\rightarrow$ *"Metador Hi-Bench"*, *"Econo DX"* $\rightarrow$ *"Econo FX"*, *"Linc Ocean"* $\rightarrow$ *"Binc Ocean"*). Bangladeshi players will immediately get the joke and share screenshots on Facebook groups.