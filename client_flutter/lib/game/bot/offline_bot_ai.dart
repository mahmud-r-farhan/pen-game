// lib/game/bot/offline_bot_ai.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flame_forge2d/flame_forge2d.dart';
import '../../models/kolom_spec.dart';
import '../shot_predictor.dart';

enum BotDifficulty { easy, medium, pro }

class BotShotDecision {
  final Vector2 impulse;
  final double strikeOffset;

  /// Human-like delay before the bot commits to a shot. It also gives the
  /// player time to read the opponent's aiming state instead of feeling rushed.
  final Duration thinkDelay;

  const BotShotDecision({
    required this.impulse,
    required this.strikeOffset,
    this.thinkDelay = const Duration(milliseconds: 500),
  });
}

/// Edge-aware, difficulty-scaled offline opponent.
///
/// The bot is deliberately held to the same impulse ceiling as the player
/// (`ShotPredictor.maxImpulse`) so practice is a fair training tool rather than
/// a demonstration of impossible physics.
class OfflineBotAI {
  final BotDifficulty difficulty;
  final math.Random _random;

  OfflineBotAI({this.difficulty = BotDifficulty.medium, math.Random? random})
    : _random = random ?? math.Random();

  double _distanceToNearestEdge(Vector2 point, Rect bounds) {
    return math.min(
      math.min((point.x - bounds.left).abs(), (point.x - bounds.right).abs()),
      math.min((point.y - bounds.top).abs(), (point.y - bounds.bottom).abs()),
    );
  }

  Vector2 _directionToNearestEdge(Vector2 point, Rect bounds) {
    final distToLeft = (point.x - bounds.left).abs();
    final distToRight = (point.x - bounds.right).abs();
    final distToTop = (point.y - bounds.top).abs();
    final distToBottom = (point.y - bounds.bottom).abs();
    final minDist = math.min(
      math.min(distToLeft, distToRight),
      math.min(distToTop, distToBottom),
    );

    if (minDist == distToLeft) return Vector2(-1.0, 0.0);
    if (minDist == distToRight) return Vector2(1.0, 0.0);
    if (minDist == distToTop) return Vector2(0.0, -1.0);
    return Vector2(0.0, 1.0);
  }

  /// Calculates a tactical flick impulse, strike point and think time.
  BotShotDecision calculateShot({
    required Vector2 botPosition,
    required Vector2 targetPosition,
    required Rect benchBounds,
    required KolomSpec botSpec,
  }) {
    final Vector2 toTarget = targetPosition - botPosition;
    final double distance = toTarget.length;
    final Vector2 aimDir = distance > 1e-6
        ? toTarget.normalized()
        : Vector2(1.0, 0.0);

    // Baseline: enough force to cross the table, tuned per difficulty. Heavier
    // barrels need more impulse for the same visual speed.
    final double massFactor = (botSpec.density / 1.35).clamp(0.85, 1.20);
    double force = ((distance * 4.2 + 14.0) * massFactor).clamp(
      16.0,
      ShotPredictor.maxImpulse,
    );
    double strikeOffset = 0.0;
    double angleNoise = 0.0;
    double powerNoise = 1.0;
    Duration thinkDelay = const Duration(milliseconds: 500);

    final double targetEdgeDistance = _distanceToNearestEdge(
      targetPosition,
      benchBounds,
    );
    final Vector2 edgeDirection = _directionToNearestEdge(
      targetPosition,
      benchBounds,
    );
    final double edgeAlignment = edgeDirection.dot(aimDir);

    switch (difficulty) {
      case BotDifficulty.easy:
        // Amateur classroom flick: obvious wind-up, generous error, soft power.
        angleNoise = (_random.nextDouble() - 0.5) * (math.pi / 15.0);
        powerNoise = 0.80 + _random.nextDouble() * 0.30;
        strikeOffset = (_random.nextDouble() - 0.5) * 0.80;
        thinkDelay = Duration(milliseconds: 700 + _random.nextInt(600));
        force = math.min(force, 38.0);
        break;

      case BotDifficulty.medium:
        // Competent classroom fighter: reliable contact with a human margin.
        angleNoise = (_random.nextDouble() - 0.5) * (math.pi / 40.0);
        powerNoise = 0.92 + _random.nextDouble() * 0.14;
        strikeOffset = 0.30 + _random.nextDouble() * 0.30;
        thinkDelay = Duration(milliseconds: 420 + _random.nextInt(380));
        if (targetEdgeDistance < 3.2) {
          force = math.min(force + 4.0, ShotPredictor.maxImpulse);
          strikeOffset = 0.62;
        }
        break;

      case BotDifficulty.pro:
        // Master tactician: tight accuracy, edge pressure, full legal power.
        angleNoise = (_random.nextDouble() - 0.5) * (math.pi / 150.0);
        powerNoise = 0.97 + _random.nextDouble() * 0.06;
        strikeOffset = 0.62;
        thinkDelay = Duration(milliseconds: 300 + _random.nextInt(280));
        if (targetEdgeDistance < 4.2) {
          force = ShotPredictor.maxImpulse;
          strikeOffset = 0.78;
        }
        break;
    }

    // If the target is near an edge and the direct line roughly points toward
    // that edge, bias the contact line slightly toward the precipice. This is a
    // carom hint, not a scripted outcome; the shot still has to physically
    // connect and travel.
    if (targetEdgeDistance < 4.0 && edgeAlignment > 0.45) {
      final Vector2 biased = (aimDir + edgeDirection * (0.12 * edgeAlignment))
          .normalized();
      final double biasAngle = math.atan2(biased.y, biased.x);
      final double directAngle = math.atan2(aimDir.y, aimDir.x);
      double diff = (biasAngle - directAngle) % (2 * math.pi);
      if (diff > math.pi) diff -= 2 * math.pi;
      if (diff < -math.pi) diff += 2 * math.pi;
      // Never let the carom hint turn into a wild miss.
      angleNoise += diff.clamp(-0.10, 0.10);
    }

    final double finalAngle = math.atan2(aimDir.y, aimDir.x) + angleNoise;
    Vector2 finalDir = Vector2(math.cos(finalAngle), math.sin(finalAngle));
    double finalForce = (force * powerNoise).clamp(
      12.0,
      ShotPredictor.maxImpulse,
    );

    // Self-preservation: when the bot is already teetering, do not follow
    // through with a full-power strike that could carry it off the bench.
    final double botEdgeDistance = _distanceToNearestEdge(
      botPosition,
      benchBounds,
    );
    if (botEdgeDistance < 2.0) {
      finalForce = math.min(finalForce, 32.0);
      strikeOffset = -0.55;
    }

    // A tiny normalization guard keeps the impulse inside the legal envelope.
    if (finalDir.length < 1e-6) finalDir = Vector2(1.0, 0.0);

    return BotShotDecision(
      impulse: finalDir.normalized() * finalForce,
      strikeOffset: strikeOffset.clamp(-0.85, 0.85),
      thinkDelay: thinkDelay,
    );
  }
}
