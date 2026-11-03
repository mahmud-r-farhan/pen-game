// lib/game/kolom_game_engine.dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../core/audio/sound_effects.dart';
import '../core/localization/app_strings.dart';
import '../models/arena_room.dart';
import '../models/kolom_spec.dart';
import 'bot/offline_bot_ai.dart';
import 'components/pen_body_component.dart';
import 'components/table_bench_component.dart';
import 'kolom_physics_sim.dart';

enum GameMode { offlineBot, passAndPlay, onlineMultiplayer }

class SparkParticle {
  Vector2 position;
  Vector2 velocity;
  Color color;
  double age;
  final double maxAge;
  final double size;
  final bool isDust;

  SparkParticle({
    required this.position,
    required this.velocity,
    required this.color,
    this.age = 0.0,
    required this.maxAge,
    required this.size,
    this.isDust = false,
  });
}

class HitPopup {
  Vector2 worldPos;
  String text;
  Color color;
  double age;
  final double maxAge;
  final double size;

  HitPopup({
    required this.worldPos,
    required this.text,
    required this.color,
    this.age = 0.0,
    this.maxAge = 0.85,
    this.size = 28.0,
  });
}

class KolomGameEngine extends Forge2DGame with DragCallbacks {
  final ArenaRoom room;
  final KolomSpec playerSpec;
  final KolomSpec opponentSpec;
  final GameMode mode;
  final BotDifficulty botDifficulty;
  final void Function(bool isPlayerWinner)? onMatchEnd;
  final void Function(Vector2 impulse, double strikeOffset)? onOnlineFlickSubmit;
  final void Function(bool isAiming, double pullX, double pullY, double strikeOffset)? onOnlineAimingUpdate;
  final VoidCallback? onTurnPassed;
  final SimState? onlineInitialState;
  final int localSide;
  final bool onlinePlayerFirst;
  final bool onlineInputLocked;

  KolomGameEngine({
    required this.room,
    required this.playerSpec,
    required this.opponentSpec,
    this.mode = GameMode.offlineBot,
    this.botDifficulty = BotDifficulty.medium,
    this.onMatchEnd,
    this.onOnlineFlickSubmit,
    this.onOnlineAimingUpdate,
    this.onTurnPassed,
    this.onlineInitialState,
    this.localSide = 0,
    this.onlinePlayerFirst = true,
    this.onlineInputLocked = false,
  }) : super(world: Forge2DWorld(gravity: Vector2.zero()));

  // Table bounds in physics meters (22.0m wide x 13.0m tall)
  static final Rect benchBounds = Rect.fromCenter(
    center: Offset.zero,
    width: 22.0,
    height: 13.0,
  );

  late PenBodyComponent playerPen;
  late PenBodyComponent opponentPen;
  late OfflineBotAI botAI;

  bool isPlayerTurn = true;
  double strikeOffset = 0.65; // Default: tip whip-spin
  Vector2? dragStartWorld;
  Vector2? dragCurrentWorld;

  // Remote opponent aiming state
  bool isRemoteAiming = false;
  Vector2 remotePullVector = Vector2.zero();
  double remoteStrikeOffset = 0.0;

  final ValueNotifier<String> turnStatus = ValueNotifier(AppLocale.tr('your_turn'));
  bool matchEnded = false;

  // Dynamic Impact & Visual Juice State
  double shakeIntensity = 0.0;
  double hitStopTimer = 0.0;
  double timeScale = 1.0;
  double edgePulseTime = 0.0;
  final math.Random _random = math.Random();
  final List<SparkParticle> _sparks = [];
  final List<HitPopup> _hitPopups = [];

  SimState? _pendingOnlineState;
  KeyframeInterpolator? _onlinePlayback;
  double _onlinePlaybackTime = 0.0;
  bool _onlineNextPlayerTurn = false;
  final SimPen _framePen0 = SimPen(owner: 0, x: 0, y: 0, a: 0);
  final SimPen _framePen1 = SimPen(owner: 1, x: 0, y: 0, a: 0);

  bool get isOnlineShotPlaying => _onlinePlayback != null;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.center;
    _updateCameraView();

    botAI = OfflineBotAI(difficulty: botDifficulty);

    // 1. Add Arena Table Bench Component (priority 0)
    world.add(TableBenchComponent(bounds: benchBounds, room: room, priority: 0));

    // 2. Spawn Match Pens (priority 10)
    _spawnPens();
    if (mode == GameMode.onlineMultiplayer) {
      isPlayerTurn = onlinePlayerFirst && !onlineInputLocked;
      turnStatus.value = onlineInputLocked
          ? 'Restoring authoritative shot…'
          : isPlayerTurn
              ? AppLocale.tr('your_turn')
              : AppLocale.tr('opponent_turn');
      _pendingOnlineState = onlineInitialState;
    }
  }

  void _updateCameraView() {
    // 25.0m wide x 15.5m tall accommodates the 22m x 13m bench with comfortable margins
    camera.viewfinder.visibleGameSize = Vector2(25.0, 15.5);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x > 0 && size.y > 0) {
      _updateCameraView();
    }
  }

  void _spawnPens() {
    playerPen = PenBodyComponent(
      spec: playerSpec,
      room: room,
      initialPosition: Vector2(-6.8, 2.5),
      initialAngle: -0.12,
      isPlayer: true,
      onKnockedOut: () => _handleKnockout(isPlayerOut: true),
      priority: 10,
    );

    opponentPen = PenBodyComponent(
      spec: opponentSpec,
      room: room,
      initialPosition: Vector2(6.8, -2.5),
      initialAngle: math.pi - 0.12,
      isPlayer: false,
      onKnockedOut: () => _handleKnockout(isPlayerOut: false),
      priority: 10,
    );

    world.addAll([playerPen, opponentPen]);
  }

  bool get areAllPensStopped => mode == GameMode.onlineMultiplayer
      ? _onlinePlayback == null && _pendingOnlineState == null
      : playerPen.isStopped && opponentPen.isStopped;

  /// Trigger high-impact juice: screen shake, hit-stop, popups, and sparks
  void triggerImpact({
    required Vector2 worldPos,
    required double relVel,
    required bool isMetal,
  }) {
    final intensity = (relVel / 32.0).clamp(0.2, 1.0);
    SoundEffects().playCollision(isMetal: isMetal, intensity: intensity);

    // 1. Camera Screen Shake
    shakeIntensity = math.max(shakeIntensity, (relVel * 0.45).clamp(0.0, 14.0));

    // 2. Micro Hit-Stop Freeze on crushing hits
    if (relVel > 26.0) {
      hitStopTimer = 0.045;
    }

    // 3. Floating Comic Hit Text Popup
    String? popupText;
    Color popupColor = Colors.white;
    double popupSize = 22.0;

    if (relVel > 32.0) {
      popupText = 'SMASH!';
      popupColor = const Color(0xFFFFD700); // Gold
      popupSize = 36.0;
    } else if (relVel > 22.0) {
      popupText = 'CRACK!';
      popupColor = const Color(0xFFFF5252); // Coral Red
      popupSize = 30.0;
    } else if (relVel > 12.0) {
      popupText = 'WHACK!';
      popupColor = const Color(0xFF00E5FF); // Cyan
      popupSize = 24.0;
    } else if (relVel > 5.0) {
      popupText = 'CLACK';
      popupColor = const Color(0xFFEEEEEE);
      popupSize = 18.0;
    }

    if (popupText != null) {
      _hitPopups.add(HitPopup(
        worldPos: worldPos.clone(),
        text: popupText,
        color: popupColor,
        size: popupSize,
      ));
    }

    // 4. Luminous Sparks & Wood Dust Particles
    final numSparks = math.min(30, 8 + (relVel * 0.6).round());
    for (int i = 0; i < numSparks; i++) {
      final ang = _random.nextDouble() * math.pi * 2;
      final speed = 8.0 + _random.nextDouble() * (12.0 + relVel * 0.5);
      final isGold = _random.nextBool();

      _sparks.add(SparkParticle(
        position: worldPos.clone(),
        velocity: Vector2(math.cos(ang) * speed, math.sin(ang) * speed),
        color: isGold ? const Color(0xFFFFD54F) : Colors.white,
        maxAge: 0.25 + _random.nextDouble() * 0.35,
        size: 1.5 + _random.nextDouble() * 2.0,
        isDust: false,
      ));
    }

    // Wood dust puffs
    for (int i = 0; i < 5; i++) {
      final ang = _random.nextDouble() * math.pi * 2;
      final speed = 3.0 + _random.nextDouble() * 6.0;

      _sparks.add(SparkParticle(
        position: worldPos.clone(),
        velocity: Vector2(math.cos(ang) * speed, math.sin(ang) * speed),
        color: const Color(0xFFD7CCC8),
        maxAge: 0.40 + _random.nextDouble() * 0.30,
        size: 4.0 + _random.nextDouble() * 5.0,
        isDust: true,
      ));
    }
  }

  @override
  void update(double dt) {
    edgePulseTime += dt;

    // Hit-stop freeze frame
    if (hitStopTimer > 0.0) {
      hitStopTimer -= dt;
      return;
    }

    // Update screen shake
    if (shakeIntensity > 0.0) {
      shakeIntensity = math.max(0.0, shakeIntensity - dt * 32.0);
      camera.viewfinder.position = Vector2(
        (_random.nextDouble() - 0.5) * shakeIntensity * 0.12,
        (_random.nextDouble() - 0.5) * shakeIntensity * 0.12,
      );
    } else {
      camera.viewfinder.position = Vector2.zero();
    }

    // Update sparks & dust
    for (int i = _sparks.length - 1; i >= 0; i--) {
      final p = _sparks[i];
      p.age += dt;
      if (p.age >= p.maxAge) {
        _sparks.removeAt(i);
        continue;
      }
      p.velocity *= math.exp(-3.5 * dt);
      p.position += p.velocity * dt;
    }

    // Update hit popups
    for (int i = _hitPopups.length - 1; i >= 0; i--) {
      final q = _hitPopups[i];
      q.age += dt;
      q.worldPos.y -= dt * 1.8;
      if (q.age >= q.maxAge) {
        _hitPopups.removeAt(i);
      }
    }

    if (mode == GameMode.onlineMultiplayer) {
      _updateOnlinePlayback(dt);
      // Online bodies are transforms driven by authoritative keyframes, not a
      // second local physics simulation.
      super.update(0.0);
    } else {
      super.update(dt * timeScale);
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (matchEnded) return;
    if (!isPlayerTurn || !areAllPensStopped || playerPen.isEliminated) return;

    dragStartWorld = screenToWorld(event.canvasPosition);
    dragCurrentWorld = dragStartWorld;

    if (mode == GameMode.onlineMultiplayer && onOnlineAimingUpdate != null) {
      onOnlineAimingUpdate!(true, 0.0, 0.0, strikeOffset);
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (dragStartWorld == null || matchEnded) return;

    dragCurrentWorld = screenToWorld(event.canvasEndPosition);
    final pull = dragStartWorld! - dragCurrentWorld!;

    if (mode == GameMode.onlineMultiplayer && onOnlineAimingUpdate != null) {
      onOnlineAimingUpdate!(true, pull.x, pull.y, strikeOffset);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (dragStartWorld != null && dragCurrentWorld != null && !matchEnded) {
      final Vector2 pull = dragStartWorld! - dragCurrentWorld!;

      if (mode == GameMode.onlineMultiplayer && onOnlineAimingUpdate != null) {
        onOnlineAimingUpdate!(false, 0.0, 0.0, strikeOffset);
      }

      if (pull.length > 0.4) {
        final double force = math.min(pull.length * 7.4, 44.0);
        final Vector2 impulse = pull.normalized() * force;

        if (mode != GameMode.onlineMultiplayer) {
          SoundEffects().playFlick(pull.length / 4.0);
          playerPen.flick(
            impulse: impulse,
            strikeOffsetNormalized: strikeOffset,
          );
        }

        if (mode == GameMode.onlineMultiplayer) {
          isPlayerTurn = false;
          turnStatus.value = AppLocale.tr('opponent_turn');
          onOnlineFlickSubmit?.call(impulse, strikeOffset);
        } else if (mode == GameMode.offlineBot) {
          isPlayerTurn = false;
          turnStatus.value = AppLocale.tr('bot_turn');
          _scheduleOfflineBotTurn();
        } else if (mode == GameMode.passAndPlay) {
          isPlayerTurn = false;
          turnStatus.value = 'Player 2 Turn';
        }
      }
    }
    dragStartWorld = null;
    dragCurrentWorld = null;
  }

  void passTurnDueToTimeout() {
    if (matchEnded) return;
    if (mode == GameMode.onlineMultiplayer) {
      turnStatus.value = 'Waiting for server…';
      onTurnPassed?.call();
      return;
    }
    if (isPlayerTurn) {
      isPlayerTurn = false;
      turnStatus.value = AppLocale.tr('turn_passed');
      onTurnPassed?.call();
      if (mode == GameMode.offlineBot) {
        _scheduleOfflineBotTurn();
      }
    } else {
      isPlayerTurn = true;
      turnStatus.value = AppLocale.tr('your_turn');
    }
  }

  void executeRemoteFlick({
    required Vector2 impulse,
    required double strikeOffsetNormalized,
    required bool isNowPlayerTurn,
  }) {
    SoundEffects().playFlick();
    opponentPen.flick(
      impulse: impulse,
      strikeOffsetNormalized: strikeOffsetNormalized,
    );
    isPlayerTurn = isNowPlayerTurn;
    turnStatus.value = isNowPlayerTurn
        ? AppLocale.tr('your_turn')
        : AppLocale.tr('opponent_turn');
    isRemoteAiming = false;
  }

  void setRemoteAiming({
    required bool isAiming,
    required double pullX,
    required double pullY,
    required double strikeOffset,
  }) {
    isRemoteAiming = isAiming;
    // Both online clients render their own pen on the left. The opponent's
    // drag therefore arrives in a coordinate space rotated by 180 degrees.
    remotePullVector = mode == GameMode.onlineMultiplayer
        ? Vector2(-pullX, -pullY)
        : Vector2(pullX, pullY);
    remoteStrikeOffset = strikeOffset;
  }

  /// Plays only server-produced keyframes. [localSide] is the authoritative
  /// simulation index for the player holding this device (0 for p1, 1 for p2).
  void playOnlineShot(List<SimKeyframe> frames, {required bool isNowPlayerTurn}) {
    if (mode != GameMode.onlineMultiplayer || frames.isEmpty) return;
    SoundEffects().playFlick();
    _onlinePlaybackTime = 0.0;
    _onlineNextPlayerTurn = isNowPlayerTurn;
    _onlinePlayback = KeyframeInterpolator(frames);
    isPlayerTurn = false;
    turnStatus.value = 'Resolving shot…';
    isRemoteAiming = false;
  }

  void setOnlineTurn(bool playerTurn) {
    if (mode != GameMode.onlineMultiplayer || _onlinePlayback != null) return;
    isPlayerTurn = playerTurn;
    turnStatus.value = playerTurn ? AppLocale.tr('your_turn') : AppLocale.tr('opponent_turn');
  }

  void endOnlineMatch() {
    matchEnded = true;
    _onlinePlayback = null;
    dragStartWorld = null;
    dragCurrentWorld = null;
    isRemoteAiming = false;
  }

  Vector2 _onlineWorldPoint(double x, double y) {
    final mirror = localSide == 1 ? -1.0 : 1.0;
    return Vector2(
      (x - simW / 2.0) * (benchBounds.width / simW) * mirror,
      (y - simH / 2.0) * (benchBounds.height / simH) * mirror,
    );
  }

  void _applyOnlinePen(PenBodyComponent component, SimPen pen) {
    final position = _onlineWorldPoint(pen.x, pen.y);
    final angle = pen.a + (localSide == 1 ? math.pi : 0.0);
    component.body.setTransform(position, Rot.fromAngle(angle));
    component.body.linearVelocity = Vector2.zero();
    component.body.angularVelocity = 0.0;
    component.isEliminated = pen.fall > 0.0;
    component.fallScale = (1.0 - pen.fall * 0.8).clamp(0.2, 1.0);
  }

  void _applyOnlineFrame() {
    if (localSide == 0) {
      _applyOnlinePen(playerPen, _framePen0);
      _applyOnlinePen(opponentPen, _framePen1);
    } else {
      _applyOnlinePen(playerPen, _framePen1);
      _applyOnlinePen(opponentPen, _framePen0);
    }
  }

  void _updateOnlinePlayback(double dt) {
    final pending = _pendingOnlineState;
    if (pending != null && playerPen.isMounted && opponentPen.isMounted) {
      _framePen0.x = pending.pens[0].x;
      _framePen0.y = pending.pens[0].y;
      _framePen0.a = pending.pens[0].a;
      _framePen0.fall = pending.pens[0].fall;
      _framePen1.x = pending.pens[1].x;
      _framePen1.y = pending.pens[1].y;
      _framePen1.a = pending.pens[1].a;
      _framePen1.fall = pending.pens[1].fall;
      _applyOnlineFrame();
      _pendingOnlineState = null;
    }

    final playback = _onlinePlayback;
    if (playback == null) return;
    _onlinePlaybackTime += dt;
    playback.sample(_onlinePlaybackTime, _framePen0, _framePen1);
    _applyOnlineFrame();
    if (_onlinePlaybackTime >= playback.totalDuration) {
      playback.sample(playback.totalDuration, _framePen0, _framePen1);
      _applyOnlineFrame();
      _onlinePlayback = null;
      setOnlineTurn(_onlineNextPlayerTurn);
    }
  }

  void _scheduleOfflineBotTurn() async {
    while (!areAllPensStopped) {
      await Future.delayed(const Duration(milliseconds: 60));
    }
    if (playerPen.isEliminated || opponentPen.isEliminated || matchEnded) return;

    await Future.delayed(const Duration(milliseconds: 320));

    final decision = botAI.calculateShot(
      botPosition: opponentPen.body.position,
      targetPosition: playerPen.body.position,
      benchBounds: benchBounds,
      botSpec: opponentSpec,
    );

    SoundEffects().playFlick();
    opponentPen.flick(
      impulse: decision.impulse,
      strikeOffsetNormalized: decision.strikeOffset,
    );

    isPlayerTurn = true;
    turnStatus.value = AppLocale.tr('your_turn');
  }

  void _handleKnockout({required bool isPlayerOut}) {
    if (matchEnded) return;
    matchEnded = true;

    // Slow-motion knockout tumble!
    timeScale = 0.35;
    SoundEffects().playFallOff();

    if (isPlayerOut) {
      turnStatus.value = AppLocale.tr('knockout_lose');
      onMatchEnd?.call(false);
    } else {
      SoundEffects().playVictory();
      turnStatus.value = AppLocale.tr('knockout_win');
      onMatchEnd?.call(true);
    }
  }

  void resetRound() {
    world.removeAll([playerPen, opponentPen]);
    _onlinePlayback = null;
    _pendingOnlineState = null;
    matchEnded = false;
    timeScale = 1.0;
    isPlayerTurn = true;
    turnStatus.value = AppLocale.tr('your_turn');
    _sparks.clear();
    _hitPopups.clear();
    _spawnPens();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Table Edge Danger Warning Glow (illuminates when pen gets within 1.2m of edge)
    _drawEdgeDangerGlow(canvas);

    // 2. Flying Sparks & Wood Dust Particles
    _drawSparks(canvas);

    // 3. Player Slingshot Trajectory with Exact Travel Distance Arc
    if (dragStartWorld != null && dragCurrentWorld != null && !playerPen.isEliminated) {
      final Vector2 pull = dragStartWorld! - dragCurrentWorld!;
      if (pull.length > 0.3) {
        final strikeWorld = playerPen.getStrikeWorldPoint(strikeOffset);
        _drawTactileAimingHUD(
          canvas,
          strikeWorld: strikeWorld,
          penCenter: playerPen.body.position,
          pullVector: pull,
          isPlayer: true,
        );
      }
    }

    // 4. Remote Opponent Slingshot Trajectory
    if (isRemoteAiming && !opponentPen.isEliminated && remotePullVector.length > 0.3) {
      final strikeWorld = opponentPen.getStrikeWorldPoint(remoteStrikeOffset);
      _drawTactileAimingHUD(
        canvas,
        strikeWorld: strikeWorld,
        penCenter: opponentPen.body.position,
        pullVector: remotePullVector,
        isPlayer: false,
      );
    }

    // 5. Comic Hit Text Popups
    _drawHitPopups(canvas);
  }

  void _drawEdgeDangerGlow(Canvas canvas) {
    final pens = [playerPen, opponentPen];
    for (final pen in pens) {
      if (pen.isEliminated) continue;
      final pos = pen.body.position;

      final distLeft = (pos.x - benchBounds.left).abs();
      final distRight = (pos.x - benchBounds.right).abs();
      final distTop = (pos.y - benchBounds.top).abs();
      final distBottom = (pos.y - benchBounds.bottom).abs();
      final minDist = math.min(math.min(distLeft, distRight), math.min(distTop, distBottom));

      if (minDist < 1.25) {
        final pulse = 0.5 + 0.5 * math.sin(edgePulseTime * 9.0);
        final alpha = ((1.0 - minDist / 1.25) * 0.75 * pulse).clamp(0.0, 0.85);

        Offset hazardPos;
        if (minDist == distLeft) {
          hazardPos = Offset(benchBounds.left, pos.y);
        } else if (minDist == distRight) {
          hazardPos = Offset(benchBounds.right, pos.y);
        } else if (minDist == distTop) {
          hazardPos = Offset(pos.x, benchBounds.top);
        } else {
          hazardPos = Offset(pos.x, benchBounds.bottom);
        }

        final screenHazard = worldToScreen(Vector2(hazardPos.dx, hazardPos.dy)).toOffset();
        final hazardGlow = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF1744).withValues(alpha: alpha),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: screenHazard, radius: 90));

        canvas.drawCircle(screenHazard, 90, hazardGlow);
      }
    }
  }

  void _drawTactileAimingHUD(
    Canvas canvas, {
    required Vector2 strikeWorld,
    required Vector2 penCenter,
    required Vector2 pullVector,
    required bool isPlayer,
  }) {
    final double power = (pullVector.length / 4.5).clamp(0.0, 1.0);
    final Vector2 dir = pullVector.normalized();

    // Analytic stopping distance
    final double travelDistMeters = math.min(pullVector.length * 2.8, 16.0);
    final Vector2 targetWorld = penCenter + dir * travelDistMeters;

    final Offset startScreen = worldToScreen(strikeWorld).toOffset();
    final Offset targetScreen = worldToScreen(targetWorld).toOffset();
    final Offset centerScreen = worldToScreen(penCenter).toOffset();

    // Hue shifts from Emerald Green (0.33) -> Gold (0.12) -> Crimson Red (0.0)
    final Color powerColor = isPlayer
        ? (power < 0.5
            ? Color.lerp(const Color(0xFF00E676), const Color(0xFFFFD700), power * 2.0)!
            : Color.lerp(const Color(0xFFFFD700), const Color(0xFFFF1744), (power - 0.5) * 2.0)!)
        : const Color(0xFFFF1744);

    // 1. Dotted Trajectory Line
    final aimPaint = Paint()
      ..color = powerColor.withValues(alpha: 0.90)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double dist = (targetScreen - startScreen).distance;
    final Offset dirScreen = (targetScreen - startScreen) / dist;
    for (double d = 0; d < dist; d += 14.0) {
      final double endSeg = math.min(d + 8.0, dist);
      canvas.drawLine(startScreen + dirScreen * d, startScreen + dirScreen * endSeg, aimPaint);
    }

    // 2. Landing Reticle Circle
    final landingPaint = Paint()
      ..color = powerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(targetScreen, 12, landingPaint);
    canvas.drawCircle(
      targetScreen,
      12 + math.sin(edgePulseTime * 12.0) * 3.0,
      Paint()
        ..color = powerColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(targetScreen, 3, Paint()..color = powerColor);

    // 3. Power Meter Arc around Pen Center
    final powerArcPaint = Paint()
      ..color = powerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: centerScreen, radius: 46),
      -math.pi / 2,
      math.pi * 2 * power,
      false,
      powerArcPaint,
    );

    // Subtle background track for power gauge
    canvas.drawCircle(
      centerScreen,
      46,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // 4. Slingshot Pull Reticle
    final Offset dragScreen = worldToScreen(strikeWorld - pullVector * 0.45).toOffset();
    canvas.drawLine(
      startScreen,
      dragScreen,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(
      dragScreen,
      6.0,
      Paint()..color = powerColor,
    );

    // Contact Strike Reticle Marker
    canvas.drawCircle(
      startScreen,
      5.0,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawSparks(Canvas canvas) {
    for (final p in _sparks) {
      final screenPos = worldToScreen(p.position).toOffset();
      final alpha = (1.0 - p.age / p.maxAge).clamp(0.0, 1.0);

      if (p.isDust) {
        canvas.drawCircle(
          screenPos,
          p.size * (1.4 - alpha * 0.4),
          Paint()..color = p.color.withValues(alpha: 0.28 * alpha),
        );
      } else {
        final velScreen = p.velocity * 0.025;
        final start = screenPos;
        final end = screenPos - Offset(velScreen.x, velScreen.y);

        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = p.color.withValues(alpha: alpha)
            ..strokeWidth = p.size * alpha + 0.8
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _drawHitPopups(Canvas canvas) {
    for (final q in _hitPopups) {
      final screenPos = worldToScreen(q.worldPos).toOffset();
      final k = q.age / q.maxAge;
      final scale = k < 0.15 ? 0.6 + (k / 0.15) * 0.6 : 1.2 - (k - 0.15) * 0.25;
      final alpha = (1.0 - math.max(0.0, (k - 0.6) / 0.4)).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(screenPos.dx, screenPos.dy);
      canvas.scale(scale, scale);
      canvas.rotate(-0.06);

      final textSpan = TextSpan(
        text: q.text,
        style: TextStyle(
          color: q.color.withValues(alpha: alpha),
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          fontSize: q.size,
          letterSpacing: 1.2,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: alpha * 0.8),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
      );

      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      canvas.restore();
    }
  }
}
