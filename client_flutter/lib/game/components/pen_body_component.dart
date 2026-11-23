// lib/game/components/pen_body_component.dart
import 'dart:math' as math;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../../models/arena_room.dart';
import '../../models/kolom_spec.dart';
import '../kolom_game_engine.dart';
import '../rendering/procedural_kolom_painter.dart';

class PenBodyComponent extends BodyComponent<KolomGameEngine>
    with ContactCallbacks {
  final KolomSpec spec;
  final ArenaRoom room;
  final Vector2 initialPosition;
  final double initialAngle;
  final bool isPlayer;
  final VoidCallback onKnockedOut;

  bool isEliminated = false;
  double fallScale = 1.0;
  bool isTeetering = false;
  double teeterWobbleTime = 0.0;

  late double _combinedLinearDamping;
  late double _combinedAngularDamping;

  /// Effective surface damping after the arena multiplier is applied. Used by
  /// the aiming HUD to predict a physically honest stopping distance.
  double get effectiveLinearDamping => _combinedLinearDamping;

  /// Effective spin resistance after the arena multiplier is applied.
  double get effectiveAngularDamping => _combinedAngularDamping;

  /// Current rigid-body mass in kilograms.
  double get mass => body.mass;

  PenBodyComponent({
    required this.spec,
    required this.room,
    required this.initialPosition,
    required this.initialAngle,
    required this.isPlayer,
    required this.onKnockedOut,
    super.priority = 10,
  }) : super(renderBody: false);

  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);
    if (other is PenBodyComponent) {
      final isMetal =
          spec.model == KolomModel.hectorMetalTank ||
          spec.model == KolomModel.goldParkerVIP ||
          other.spec.model == KolomModel.hectorMetalTank ||
          other.spec.model == KolomModel.goldParkerVIP;

      final relVel = (body.linearVelocity - other.body.linearVelocity).length;
      final contactPos = (body.position + other.body.position) * 0.5;

      game.triggerImpact(
        worldPos: contactPos,
        relVel: relVel,
        isMetal: isMetal,
      );
    }
  }

  bool get isStopped =>
      body.linearVelocity.length < 0.12 && body.angularVelocity.abs() < 0.18;

  @override
  Body createBody() {
    _combinedLinearDamping = spec.linearDamping * (room.friction / 2.3);
    _combinedAngularDamping = spec.angularDamping * (room.angularDamping / 2.0);

    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: initialPosition,
      rotation: Rot(math.cos(initialAngle), math.sin(initialAngle)),
      linearDamping: _combinedLinearDamping,
      angularDamping: _combinedAngularDamping,
      isBullet: true, // Continuous Collision Detection
    );

    final body = world.createBody(bodyDef);

    final shapeDef = ShapeDef(
      density: spec.density,
      material: SurfaceMaterial(
        friction: 0.35,
        restitution: spec.restitution * room.bounce,
      ),
    );

    body.createShape(Polygon.box(spec.length / 2, spec.radius), shapeDef);

    // Apply custom asymmetric center of mass!
    body.massData = MassData(
      mass: body.mass,
      center: Vector2(spec.comOffsetX, 0.0),
      rotationalInertia: body.rotationalInertia,
    );

    return body;
  }

  Vector2 getStrikeWorldPoint(double strikeOffsetNormalized) {
    final localPoint = Vector2((spec.length / 2) * strikeOffsetNormalized, 0);
    return body.worldPoint(localPoint);
  }

  void flick({
    required Vector2 impulse,
    required double strikeOffsetNormalized,
  }) {
    if (isEliminated) return;
    final worldStrikePoint = getStrikeWorldPoint(strikeOffsetNormalized);
    // Applying force at worldStrikePoint generates linear velocity + rotational torque!
    body.applyLinearImpulse(impulse, point: worldStrikePoint, wake: true);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.mode == GameMode.onlineMultiplayer) return;

    if (isEliminated) {
      // Fall into the abyss animation
      if (fallScale > 0.20) {
        fallScale = math.max(0.20, fallScale - dt * 2.0);
        body.angularVelocity += dt * 3.5; // Spins while falling
      }
      return;
    }

    // Crisp sleep threshold snapping
    if (isStopped) {
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0.0;
      isTeetering = false;
    }

    final pos = body.worldCenterOfMass;
    final bench = KolomGameEngine.benchBounds;

    // 1. Edge Teetering Detection (near table boundary)
    final double distToLeft = (pos.x - bench.left).abs();
    final double distToRight = (pos.x - bench.right).abs();
    final double distToTop = (pos.y - bench.top).abs();
    final double distToBottom = (pos.y - bench.bottom).abs();
    final double minDist = math.min(
      math.min(distToLeft, distToRight),
      math.min(distToTop, distToBottom),
    );

    if (minDist < 0.65 && !isStopped) {
      isTeetering = true;
      teeterWobbleTime += dt * 12.0;
    } else {
      isTeetering = false;
    }

    // 2. Knockout Evaluation: Center of mass crossed outside bench
    if (!bench.contains(Offset(pos.x, pos.y))) {
      isEliminated = true;
      body.linearVelocity = body.linearVelocity * 0.35;
      onKnockedOut();
    }
  }

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    final double teeterAngle = isTeetering
        ? math.sin(teeterWobbleTime) * 0.08
        : 0.0;

    ProceduralKolomPainter.drawPen(
      canvas,
      spec,
      fallScale: fallScale,
      strikeOffsetMarker: gameRef.strikeOffset,
      showStrikeMarker:
          isPlayer && gameRef.isPlayerTurn && isStopped && !isEliminated,
      isTeetering: isTeetering,
      teeterAngle: teeterAngle,
    );
  }
}
