import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolom_fight/game/bot/offline_bot_ai.dart';
import 'package:kolom_fight/game/shot_predictor.dart';
import 'package:kolom_fight/models/kolom_spec.dart';

void main() {
  final bench = Rect.fromCenter(center: Offset.zero, width: 22.0, height: 13.0);
  final spec = KolomSpec.catalog[KolomModel.hiSchoolClassic]!;

  BotShotDecision shoot(BotDifficulty difficulty, {math.Random? random}) {
    return OfflineBotAI(difficulty: difficulty, random: random).calculateShot(
      botPosition: Vector2(-6.8, 2.5),
      targetPosition: Vector2(6.8, -2.5),
      benchBounds: bench,
      botSpec: spec,
    );
  }

  test('every difficulty stays inside the legal impulse envelope', () {
    for (final difficulty in BotDifficulty.values) {
      for (int i = 0; i < 40; i++) {
        final decision = shoot(difficulty);
        expect(
          decision.impulse.length,
          lessThanOrEqualTo(ShotPredictor.maxImpulse + 1e-6),
          reason: '$difficulty produced an overpowered shot',
        );
        expect(decision.impulse.length, greaterThanOrEqualTo(12.0 - 1e-6));
        expect(decision.strikeOffset.abs(), lessThanOrEqualTo(0.85));
        expect(decision.thinkDelay.inMilliseconds, isNonNegative);
      }
    }
  });

  test('pro bot presses a target that is already near the edge', () {
    final nearEdge = OfflineBotAI(difficulty: BotDifficulty.pro).calculateShot(
      botPosition: Vector2(-4.0, 0.0),
      targetPosition: Vector2(8.5, 0.0),
      benchBounds: bench,
      botSpec: spec,
    );
    expect(
      nearEdge.impulse.length,
      greaterThan(ShotPredictor.maxImpulse * 0.85),
    );
  });

  test('self-preservation caps force and reverses the strike point', () {
    final teetering = OfflineBotAI(difficulty: BotDifficulty.pro).calculateShot(
      botPosition: Vector2(-10.2, 0.0),
      targetPosition: Vector2(4.0, 0.0),
      benchBounds: bench,
      botSpec: spec,
    );
    expect(teetering.impulse.length, lessThanOrEqualTo(32.0 + 1e-6));
    expect(teetering.strikeOffset, lessThan(0.0));
  });

  test('seeded bots are deterministic for replayable practice', () {
    final first = shoot(BotDifficulty.pro, random: math.Random(42));
    final second = shoot(BotDifficulty.pro, random: math.Random(42));
    expect(first.impulse.x, closeTo(second.impulse.x, 1e-12));
    expect(first.impulse.y, closeTo(second.impulse.y, 1e-12));
    expect(first.strikeOffset, closeTo(second.strikeOffset, 1e-12));
  });

  test('easy bot adds visible human error instead of perfect aim', () {
    final angles = <String>{};
    for (int i = 0; i < 30; i++) {
      final decision = shoot(BotDifficulty.easy);
      angles.add((decision.impulse.y / decision.impulse.x).toStringAsFixed(3));
    }
    expect(angles.length, greaterThan(1));
  });
}
