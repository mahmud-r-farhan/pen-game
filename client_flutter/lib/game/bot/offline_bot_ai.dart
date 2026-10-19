// lib/game/bot/offline_bot_ai.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flame_forge2d/flame_forge2d.dart';
import '../../models/kolom_spec.dart';

enum BotDifficulty { easy, medium, pro }

class OfflineBotAI {
  final BotDifficulty difficulty;
  final math.Random _random = math.Random();

  OfflineBotAI({this.difficulty = BotDifficulty.medium});

  /// Calculates the optimal tactical flick impulse and contact point.
  BotShotDecision calculateShot({
    required Vector2 botPosition,
    required Vector2 targetPosition,
    required Rect benchBounds,
    required KolomSpec botSpec,
  }) {
    final Vector2 toTarget = targetPosition - botPosition;
    final double distance = toTarget.length;

    // Direct aim towards target with power scaling
    Vector2 aimDir = toTarget.normalized();
    double force = (distance * 4.0 + 12.0).clamp(14.0, 50.0);
    double strikeOffset = 0.0;

    switch (difficulty) {
      case BotDifficulty.easy:
        // Amateur student flick: moderate spread
        final double angleNoise = (_random.nextDouble() - 0.5) * (math.pi / 9.0);
        final double forceNoise = 0.85 + _random.nextDouble() * 0.35;
        final double angle = math.atan2(aimDir.y, aimDir.x) + angleNoise;

        aimDir = Vector2(math.cos(angle), math.sin(angle));
        force = (force * forceNoise).clamp(12.0, 42.0);
        strikeOffset = (_random.nextDouble() - 0.5) * 0.45;
        break;

      case BotDifficulty.medium:
        // Competent classroom fighter: snappy high-power strike + targeted tip whip
        final double angleNoise = (_random.nextDouble() - 0.5) * (math.pi / 28.0);
        final double angle = math.atan2(aimDir.y, aimDir.x) + angleNoise;

        aimDir = Vector2(math.cos(angle), math.sin(angle));
        force = (distance * 4.2 + 15.0).clamp(18.0, 48.0);
        strikeOffset = 0.55;
        break;

      case BotDifficulty.pro:
        // MASTER TACTICIAN BOT (High Power & Deadly Knockouts):
        // 1. Analyze closest bench edge to target pen
        final double distToLeft = (targetPosition.x - benchBounds.left).abs();
        final double distToRight = (targetPosition.x - benchBounds.right).abs();
        final double distToTop = (targetPosition.y - benchBounds.top).abs();
        final double distToBottom = (targetPosition.y - benchBounds.bottom).abs();

        final double minTargetEdgeDist = math.min(
          math.min(distToLeft, distToRight),
          math.min(distToTop, distToBottom),
        );

        // 2. Identify knockout launch vector:
        // Push the target pen toward its closest precipice!
        Vector2 pushToEdgeVector = Vector2.zero();
        if (minTargetEdgeDist == distToLeft) {
          pushToEdgeVector = Vector2(-1.0, 0.0);
        } else if (minTargetEdgeDist == distToRight) {
          pushToEdgeVector = Vector2(1.0, 0.0);
        } else if (minTargetEdgeDist == distToTop) {
          pushToEdgeVector = Vector2(0.0, -1.0);
        } else {
          pushToEdgeVector = Vector2(0.0, 1.0);
        }

        // Blend direct line with edge vector for lethal carom angles
        final Vector2 tacticalAim = (aimDir * 0.60 + pushToEdgeVector * 0.40).normalized();
        aimDir = tacticalAim;

        if (minTargetEdgeDist < 3.8) {
          // Finish knockout blow! Maximum power whip-spin
          force = 55.0;
          strikeOffset = 0.78; // Extreme tip whip-spin for massive angular torque
        } else {
          // Mid-table aggressive push
          force = (distance * 4.6 + 18.0).clamp(24.0, 52.0);
          strikeOffset = 0.65;
        }

        // 3. Self-preservation check:
        // If bot is dangerously close to an edge, avoid full recoil forward
        final double botDistToLeft = (botPosition.x - benchBounds.left).abs();
        final double botDistToRight = (botPosition.x - benchBounds.right).abs();
        final double botDistToTop = (botPosition.y - benchBounds.top).abs();
        final double botDistToBottom = (botPosition.y - benchBounds.bottom).abs();
        final double minBotEdgeDist = math.min(
          math.min(botDistToLeft, botDistToRight),
          math.min(botDistToTop, botDistToBottom),
        );

        if (minBotEdgeDist < 2.0) {
          // Clamp force slightly to prevent sliding off after rebound
          force = math.min(force, 36.0);
          strikeOffset = -0.60; // Rotate safely using weighted back-cap
        }
        break;
    }

    return BotShotDecision(
      impulse: aimDir * force,
      strikeOffset: strikeOffset,
    );
  }
}

class BotShotDecision {
  final Vector2 impulse;
  final double strikeOffset;

  const BotShotDecision({
    required this.impulse,
    required this.strikeOffset,
  });
}
