import 'package:flutter_test/flutter_test.dart';
import 'package:kolom_fight/game/shot_predictor.dart';

void main() {
  group('ShotPredictor impulse mapping', () {
    test('rejects drags below the flick threshold', () {
      expect(ShotPredictor.impulseForPull(0.0), 0.0);
      expect(ShotPredictor.impulseForPull(ShotPredictor.minPull), 0.0);
      expect(ShotPredictor.impulseForPull(ShotPredictor.minPull - 0.01), 0.0);
      expect(ShotPredictor.impulseForPull(double.nan), 0.0);
    });

    test('scales a normal pull and clamps to the server limit', () {
      expect(ShotPredictor.impulseForPull(1.0), closeTo(7.4, 1e-9));
      expect(ShotPredictor.impulseForPull(100.0), ShotPredictor.maxImpulse);
      expect(
        ShotPredictor.impulseForPull(ShotPredictor.maxImpulse / 7.4),
        closeTo(ShotPredictor.maxImpulse, 1e-9),
      );
    });

    test('maps impulse to the same 0..1 power range as the server', () {
      expect(ShotPredictor.powerForImpulse(0.0), 0.0);
      expect(
        ShotPredictor.powerForImpulse(ShotPredictor.maxImpulse * 0.5),
        closeTo(0.5, 1e-9),
      );
      expect(ShotPredictor.powerForImpulse(ShotPredictor.maxImpulse), 1.0);
      expect(ShotPredictor.powerForImpulse(ShotPredictor.maxImpulse * 2), 1.0);
    });
  });

  group('ShotPredictor stopping distance', () {
    test('uses initial speed divided by surface damping', () {
      expect(
        ShotPredictor.travelDistance(
          impulse: 22.0,
          mass: 2.0,
          linearDamping: 2.0,
        ),
        closeTo(5.5, 1e-9),
      );
    });

    test('is zero for invalid or non-positive physics', () {
      expect(
        ShotPredictor.travelDistance(impulse: 0, mass: 2, linearDamping: 2),
        0.0,
      );
      expect(
        ShotPredictor.travelDistance(impulse: 10, mass: 0, linearDamping: 2),
        0.0,
      );
      expect(
        ShotPredictor.travelDistance(impulse: 10, mass: 2, linearDamping: 0),
        0.0,
      );
      expect(
        ShotPredictor.travelDistance(
          impulse: double.infinity,
          mass: 2,
          linearDamping: 2,
        ),
        0.0,
      );
    });
  });

  group('ShotPredictor edge ray cast', () {
    const left = -10.0;
    const top = -6.5;
    const right = 10.0;
    const bottom = 6.5;

    test('measures a straight horizontal path to the bench edge', () {
      expect(
        ShotPredictor.distanceToEdge(
          startX: 0,
          startY: 0,
          dirX: 1,
          dirY: 0,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
        closeTo(10.0, 1e-9),
      );
      expect(
        ShotPredictor.distanceToEdge(
          startX: 5,
          startY: 0,
          dirX: 1,
          dirY: 0,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
        closeTo(5.0, 1e-9),
      );
    });

    test('returns zero when the pen starts outside the bench', () {
      expect(
        ShotPredictor.distanceToEdge(
          startX: 12,
          startY: 0,
          dirX: 1,
          dirY: 0,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
        0.0,
      );
    });

    test('clips a diagonal ray against the nearest boundary', () {
      // Moving (+1, +1) from the center hits y = 6.5 before x = 10.
      expect(
        ShotPredictor.distanceToEdge(
          startX: 0,
          startY: 0,
          dirX: 1,
          dirY: 1,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
        closeTo(6.5, 1e-9),
      );
    });

    test('never exceeds the maximum travel distance', () {
      expect(
        ShotPredictor.distanceToEdge(
          startX: 0,
          startY: 0,
          dirX: 1,
          dirY: 0,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          maxDistance: 3.0,
        ),
        closeTo(3.0, 1e-9),
      );
    });
  });

  test('spin offset is normalized to -1..1', () {
    expect(ShotPredictor.spinForOffset(0.85), 1.0);
    expect(ShotPredictor.spinForOffset(-0.85), -1.0);
    expect(ShotPredictor.spinForOffset(-0.425), closeTo(-0.5, 1e-9));
    expect(ShotPredictor.spinForOffset(2.0), 1.0);
  });
}
