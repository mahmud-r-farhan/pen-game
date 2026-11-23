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
import 'shot_predictor.dart';

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
  KolomSpec opponentSpec;
  final GameMode mode;
  final BotDifficulty botDifficulty;
  final void Function(bool isPlayerWinner)? onMatchEnd;
  final void Function(Vector2 impulse, double strikeOffset)?
  onOnlineFlickSubmit;
  final void Function(
    bool isAiming,
    double pullX,
    double pullY,
    double strikeOffset,
  )?
  onOnlineAimingUpdate;
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

  bool _isPlayerTurn = true;

  /// Notifies the HUD when the active side changes. The HUD uses this to reset
  /// the local turn clock instead of letting a fast bot shot steal time from
  /// the player's next turn.
  final ValueNotifier<bool> playerTurn = ValueNotifier(true);

  bool get isPlayerTurn => _isPlayerTurn;

  set isPlayerTurn(bool value) {
    if (_isPlayerTurn == value) return;
    _isPlayerTurn = value;
    playerTurn.value = value;
  }

  double strikeOffset = 0.65; // Default: tip whip-spin
  Vector2? dragStartWorld;
  Vector2? dragCurrentWorld;

  // Incremented every time a practice round is reset. Asynchronous bot turns
  // capture this value and abort if a rematch has already started.
  int _roundGeneration = 0;
  bool _isRemoved = false;

  // Remote opponent aiming state
  bool isRemoteAiming = false;
  Vector2 remotePullVector = Vector2.zero();
  double remoteStrikeOffset = 0.0;

  final ValueNotifier<String> turnStatus = ValueNotifier(
    AppLocale.tr('your_turn'),
  );
  bool matchEnded = false;

  // Dynamic Impact & Visual Juice State
  double shakeIntensity = 0.0;
  double hitStopTimer = 0.0;
  double timeScale = 1.0;
  double edgePulseTime = 0.0;
  final math.Random _random = math.Random();
  final List<SparkParticle> _sparks = [];
  final List<HitPopup> _hitPopups = [];

  // Reused render resources. Allocating Paint/Gradient objects every frame is
  // measurable GC pressure on the low-end Android devices this game targets.
  final Paint _edgeGlowPaint = Paint()
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18.0);
  final Paint _aimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _landingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  final Paint _landingPulsePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _landingDotPaint = Paint()..style = PaintingStyle.fill;
  final Paint _powerArcPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round;
  final Paint _powerTrackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;
  final Paint _pullLinePaint = Paint()..strokeWidth = 2.0;
  final Paint _pullDotPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strikeMarkerPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.fill;
  final Paint _spinPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round;
  final Paint _edgeWarningRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;
  final Paint _edgeWarningFillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _sparkPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _dustPaint = Paint()..style = PaintingStyle.fill;
  final Path _spinArrowPath = Path();
  TextPainter? _edgeWarningText;

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
    _isRemoved = false;
    camera.viewfinder.anchor = Anchor.center;
    _updateCameraView();

    botAI = OfflineBotAI(difficulty: botDifficulty);

    // 1. Add Arena Table Bench Component (priority 0)
    world.add(
      TableBenchComponent(bounds: benchBounds, room: room, priority: 0),
    );

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
  void onRemove() {
    _isRemoved = true;
    super.onRemove();
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
      if (_hitPopups.length >= 6) _hitPopups.removeAt(0);
      _hitPopups.add(
        HitPopup(
          worldPos: worldPos.clone(),
          text: popupText,
          color: popupColor,
          size: popupSize,
        ),
      );
    }

    // 4. Luminous Sparks & Wood Dust Particles
    if (_sparks.length > 180) {
      _sparks.removeRange(0, _sparks.length - 180);
    }
    final numSparks = math.min(30, 8 + (relVel * 0.6).round());
    for (int i = 0; i < numSparks; i++) {
      final ang = _random.nextDouble() * math.pi * 2;
      final speed = 8.0 + _random.nextDouble() * (12.0 + relVel * 0.5);
      final isGold = _random.nextBool();

      _sparks.add(
        SparkParticle(
          position: worldPos.clone(),
          velocity: Vector2(math.cos(ang) * speed, math.sin(ang) * speed),
          color: isGold ? const Color(0xFFFFD54F) : Colors.white,
          maxAge: 0.25 + _random.nextDouble() * 0.35,
          size: 1.5 + _random.nextDouble() * 2.0,
          isDust: false,
        ),
      );
    }

    // Wood dust puffs
    for (int i = 0; i < 5; i++) {
      final ang = _random.nextDouble() * math.pi * 2;
      final speed = 3.0 + _random.nextDouble() * 6.0;

      _sparks.add(
        SparkParticle(
          position: worldPos.clone(),
          velocity: Vector2(math.cos(ang) * speed, math.sin(ang) * speed),
          color: const Color(0xFFD7CCC8),
          maxAge: 0.40 + _random.nextDouble() * 0.30,
          size: 4.0 + _random.nextDouble() * 5.0,
          isDust: true,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    if (_isRemoved) return;
    // Keep the long-running pulse angle bounded so hours of play do not
    // degrade floating-point precision in the sine/cosine glow.
    edgePulseTime = (edgePulseTime + dt) % 3600.0;

    // Hit-stop freeze frame. Online playback keeps advancing because it is
    // driven by authoritative server time, not local spectacle.
    if (hitStopTimer > 0.0) {
      hitStopTimer -= dt;
      if (mode != GameMode.onlineMultiplayer) return;
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
    if (matchEnded || _isRemoved) return;
    if (!isPlayerTurn || !areAllPensStopped || playerPen.isEliminated) return;
    if (mode == GameMode.onlineMultiplayer && onlineInputLocked) return;

    dragStartWorld = screenToWorld(event.canvasPosition);
    dragCurrentWorld = dragStartWorld;

    if (mode == GameMode.onlineMultiplayer && onOnlineAimingUpdate != null) {
      onOnlineAimingUpdate!(true, 0.0, 0.0, strikeOffset);
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (dragStartWorld == null || matchEnded || _isRemoved) return;
    if (!isPlayerTurn || playerPen.isEliminated) return;

    dragCurrentWorld = screenToWorld(event.canvasEndPosition);
    final pull = dragStartWorld! - dragCurrentWorld!;

    if (mode == GameMode.onlineMultiplayer && onOnlineAimingUpdate != null) {
      onOnlineAimingUpdate!(true, pull.x, pull.y, strikeOffset);
    }
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (mode == GameMode.onlineMultiplayer &&
        onOnlineAimingUpdate != null &&
        dragStartWorld != null) {
      onOnlineAimingUpdate!(false, 0.0, 0.0, strikeOffset);
    }
    dragStartWorld = null;
    dragCurrentWorld = null;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final Vector2? start = dragStartWorld;
    final Vector2? current = dragCurrentWorld;
    dragStartWorld = null;
    dragCurrentWorld = null;

    if (start == null || current == null) return;

    if (mode == GameMode.onlineMultiplayer && onOnlineAimingUpdate != null) {
      onOnlineAimingUpdate!(false, 0.0, 0.0, strikeOffset);
    }

    // A turn can expire (or a rematch can reset the board) while the finger is
    // still down. Never submit a shot that no longer belongs to this player.
    if (matchEnded ||
        _isRemoved ||
        !isPlayerTurn ||
        !areAllPensStopped ||
        playerPen.isEliminated) {
      return;
    }

    final Vector2 pull = start - current;
    final double force = ShotPredictor.impulseForPull(pull.length);
    if (force <= 0.0) return;

    final Vector2 impulse = pull.normalized() * force;

    if (mode != GameMode.onlineMultiplayer) {
      SoundEffects().playFlick(ShotPredictor.powerForImpulse(force));
      playerPen.flick(impulse: impulse, strikeOffsetNormalized: strikeOffset);
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
  void playOnlineShot(
    List<SimKeyframe> frames, {
    required bool isNowPlayerTurn,
  }) {
    if (mode != GameMode.onlineMultiplayer || frames.isEmpty) return;
    if (matchEnded || _isRemoved) return;
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
    if (matchEnded || _isRemoved) return;
    isPlayerTurn = playerTurn;
    turnStatus.value = playerTurn
        ? AppLocale.tr('your_turn')
        : AppLocale.tr('opponent_turn');
  }

  void endOnlineMatch() {
    matchEnded = true;
    _onlinePlayback = null;
    _pendingOnlineState = null;
    dragStartWorld = null;
    dragCurrentWorld = null;
    isRemoteAiming = false;
    isPlayerTurn = false;
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
    if (matchEnded) return;
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
    final int generation = _roundGeneration;

    while (!areAllPensStopped) {
      if (_isRemoved || generation != _roundGeneration) return;
      await Future.delayed(const Duration(milliseconds: 60));
    }
    if (_isRemoved || generation != _roundGeneration) return;
    if (playerPen.isEliminated || opponentPen.isEliminated || matchEnded) {
      return;
    }

    final decision = botAI.calculateShot(
      botPosition: opponentPen.body.position,
      targetPosition: playerPen.body.position,
      benchBounds: benchBounds,
      botSpec: opponentSpec,
    );

    await Future.delayed(decision.thinkDelay);
    if (_isRemoved || generation != _roundGeneration) return;
    if (playerPen.isEliminated || opponentPen.isEliminated || matchEnded) {
      return;
    }
    if (!areAllPensStopped) return;

    SoundEffects().playFlick(
      ShotPredictor.powerForImpulse(decision.impulse.length),
    );
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

  /// Replaces the opponent loadout before a practice rematch. The engine owns
  /// the authoritative spec used when the new bodies are spawned.
  void updateOpponentSpec(KolomSpec spec) {
    opponentSpec = spec;
  }

  void resetRound() {
    _roundGeneration++;
    world.removeAll([playerPen, opponentPen]);
    _onlinePlayback = null;
    _pendingOnlineState = null;
    _onlinePlaybackTime = 0.0;
    _onlineNextPlayerTurn = false;
    matchEnded = false;
    timeScale = 1.0;
    isPlayerTurn = true;
    playerTurn.value = true;
    turnStatus.value = AppLocale.tr('your_turn');
    isRemoteAiming = false;
    remotePullVector = Vector2.zero();
    remoteStrikeOffset = 0.0;
    dragStartWorld = null;
    dragCurrentWorld = null;
    shakeIntensity = 0.0;
    hitStopTimer = 0.0;
    edgePulseTime = 0.0;
    camera.viewfinder.position = Vector2.zero();
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
    if (!matchEnded &&
        dragStartWorld != null &&
        dragCurrentWorld != null &&
        !playerPen.isEliminated) {
      final Vector2 pull = dragStartWorld! - dragCurrentWorld!;
      if (pull.length > ShotPredictor.minPull) {
        final strikeWorld = playerPen.getStrikeWorldPoint(strikeOffset);
        _drawTactileAimingHUD(
          canvas,
          strikeWorld: strikeWorld,
          pen: playerPen,
          pullVector: pull,
          strikeOffset: strikeOffset,
          isPlayer: true,
        );
      }
    }

    // 4. Remote Opponent Slingshot Trajectory
    if (!matchEnded &&
        isRemoteAiming &&
        !opponentPen.isEliminated &&
        remotePullVector.length > ShotPredictor.minPull) {
      final strikeWorld = opponentPen.getStrikeWorldPoint(remoteStrikeOffset);
      _drawTactileAimingHUD(
        canvas,
        strikeWorld: strikeWorld,
        pen: opponentPen,
        pullVector: remotePullVector,
        strikeOffset: remoteStrikeOffset,
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
      final minDist = math.min(
        math.min(distLeft, distRight),
        math.min(distTop, distBottom),
      );

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

        final screenHazard = worldToScreen(
          Vector2(hazardPos.dx, hazardPos.dy),
        ).toOffset();
        _edgeGlowPaint.color = const Color(0xFFFF1744).withValues(alpha: alpha);
        canvas.drawCircle(screenHazard, 64, _edgeGlowPaint);
      }
    }
  }

  void _drawTactileAimingHUD(
    Canvas canvas, {
    required Vector2 strikeWorld,
    required PenBodyComponent pen,
    required Vector2 pullVector,
    required double strikeOffset,
    required bool isPlayer,
  }) {
    final double impulse = ShotPredictor.impulseForPull(pullVector.length);
    if (impulse <= 0.0) return;
    final double power = ShotPredictor.powerForImpulse(impulse);
    final Vector2 dir = pullVector.normalized();

    // Analytic stopping distance from the actual loadout and arena damping.
    final double travelDistMeters = math.min(
      ShotPredictor.travelDistance(
        impulse: impulse,
        mass: pen.mass,
        linearDamping: pen.effectiveLinearDamping,
      ),
      24.0,
    );
    final Vector2 targetWorld = pen.body.position + dir * travelDistMeters;

    // If the projected path leaves the bench before the pen stops, flag the
    // exact crossing point. This is a risk hint, not a scripted outcome.
    final double edgeDistance = ShotPredictor.distanceToEdge(
      startX: strikeWorld.x,
      startY: strikeWorld.y,
      dirX: dir.x,
      dirY: dir.y,
      left: benchBounds.left,
      top: benchBounds.top,
      right: benchBounds.right,
      bottom: benchBounds.bottom,
      maxDistance: travelDistMeters,
    );
    final bool edgeRisk = travelDistMeters > edgeDistance + 0.05;

    final Offset startScreen = worldToScreen(strikeWorld).toOffset();
    final Offset targetScreen = worldToScreen(targetWorld).toOffset();
    final Offset centerScreen = worldToScreen(pen.body.position).toOffset();

    // Hue shifts from Emerald Green -> Gold -> Crimson Red with power.
    final Color powerColor = isPlayer
        ? (power < 0.5
              ? Color.lerp(
                  const Color(0xFF00E676),
                  const Color(0xFFFFD700),
                  power * 2.0,
                )!
              : Color.lerp(
                  const Color(0xFFFFD700),
                  const Color(0xFFFF1744),
                  (power - 0.5) * 2.0,
                )!)
        : const Color(0xFFFF1744);

    // 1. Dotted Trajectory Line
    final double dist = (targetScreen - startScreen).distance;
    if (dist > 0.5) {
      final Offset dirScreen = (targetScreen - startScreen) / dist;
      final Paint aimPaint = _aimPaint
        ..color = powerColor.withValues(alpha: edgeRisk ? 0.65 : 0.90)
        ..strokeWidth = 3.5;
      for (double d = 0; d < dist; d += 14.0) {
        final double endSeg = math.min(d + 8.0, dist);
        canvas.drawLine(
          startScreen + dirScreen * d,
          startScreen + dirScreen * endSeg,
          aimPaint,
        );
      }
    }

    // 2. Landing Reticle Circle
    final Paint landingPaint = _landingPaint..color = powerColor;
    canvas.drawCircle(targetScreen, 12, landingPaint);
    final Paint pulsePaint = _landingPulsePaint
      ..color = powerColor.withValues(alpha: 0.35);
    canvas.drawCircle(
      targetScreen,
      12 + math.sin(edgePulseTime * 12.0) * 3.0,
      pulsePaint,
    );
    canvas.drawCircle(targetScreen, 3, _landingDotPaint..color = powerColor);

    // Spin preview: arc direction and sweep follow the strike-point offset.
    final double spin = ShotPredictor.spinForOffset(strikeOffset);
    if (spin.abs() > 0.08) {
      final double startAngle = -math.pi / 2.0;
      final double sweep = spin * 1.45;
      final Paint spinPaint = _spinPaint
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: targetScreen, radius: 23.0),
        startAngle,
        sweep,
        false,
        spinPaint,
      );

      final double endAngle = startAngle + sweep;
      final Offset arrowTip =
          targetScreen + Offset(math.cos(endAngle), math.sin(endAngle)) * 23.0;
      final double tangent =
          endAngle + (sweep >= 0 ? math.pi / 2.0 : -math.pi / 2.0);
      final Offset back =
          arrowTip - Offset(math.cos(tangent), math.sin(tangent)) * 5.0;
      final Offset left = Offset(-math.sin(tangent), math.cos(tangent)) * 3.5;
      final Path arrow = _spinArrowPath
        ..reset()
        ..moveTo(arrowTip.dx, arrowTip.dy)
        ..lineTo((back + left).dx, (back + left).dy)
        ..lineTo((back - left).dx, (back - left).dy)
        ..close();
      spinPaint.style = PaintingStyle.fill;
      canvas.drawPath(arrow, spinPaint);
    }

    // 3. Power Meter Arc around Pen Center
    final Paint trackPaint = _powerTrackPaint
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(centerScreen, 46, trackPaint);
    final Paint powerArcPaint = _powerArcPaint..color = powerColor;
    canvas.drawArc(
      Rect.fromCircle(center: centerScreen, radius: 46),
      -math.pi / 2,
      math.pi * 2 * power,
      false,
      powerArcPaint,
    );

    // 4. Slingshot Pull Reticle
    final Offset dragScreen = worldToScreen(
      strikeWorld - pullVector * 0.45,
    ).toOffset();
    canvas.drawLine(
      startScreen,
      dragScreen,
      _pullLinePaint..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.drawCircle(dragScreen, 6.0, _pullDotPaint..color = powerColor);

    // Contact Strike Reticle Marker
    canvas.drawCircle(startScreen, 5.0, _strikeMarkerPaint);

    // 5. Edge-risk warning at the exact point the path leaves the bench.
    if (edgeRisk) {
      final Vector2 edgeWorld = strikeWorld + dir * edgeDistance;
      final Offset edgeScreen = worldToScreen(edgeWorld).toOffset();
      final double pulse = 0.5 + 0.5 * math.sin(edgePulseTime * 14.0);
      _edgeWarningFillPaint.color = const Color(
        0xFFFF5252,
      ).withValues(alpha: 0.20);
      canvas.drawCircle(edgeScreen, 18.0, _edgeWarningFillPaint);
      _edgeWarningRingPaint
        ..color = const Color(0xFFFF5252).withValues(alpha: 0.55 + 0.35 * pulse)
        ..strokeWidth = 3.0;
      canvas.drawCircle(edgeScreen, 18.0 + pulse * 4.0, _edgeWarningRingPaint);

      final TextPainter warning = _edgeWarningText ??= (TextPainter(
        text: const TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout());
      warning.paint(
        canvas,
        edgeScreen - Offset(warning.width / 2, warning.height / 2),
      );
    }
  }

  void _drawSparks(Canvas canvas) {
    for (final p in _sparks) {
      final screenPos = worldToScreen(p.position).toOffset();
      final alpha = (1.0 - p.age / p.maxAge).clamp(0.0, 1.0);

      if (p.isDust) {
        _dustPaint.color = p.color.withValues(alpha: 0.28 * alpha);
        canvas.drawCircle(screenPos, p.size * (1.4 - alpha * 0.4), _dustPaint);
      } else {
        final velScreen = p.velocity * 0.025;
        final start = screenPos;
        final end = screenPos - Offset(velScreen.x, velScreen.y);

        _sparkPaint
          ..color = p.color.withValues(alpha: alpha)
          ..strokeWidth = p.size * alpha + 0.8;
        canvas.drawLine(start, end, _sparkPaint);
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

      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      canvas.restore();
    }
  }
}
