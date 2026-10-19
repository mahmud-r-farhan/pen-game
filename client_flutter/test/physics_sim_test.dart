// test/physics_sim_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolom_fight/game/kolom_physics_sim.dart';

void main() {
  test('Dart Physics Engine - Parity with Shared Vectors', () {
    // Read shared vectors file from parent test_vectors folder or local
    File file = File('../test_vectors/shared_physics_vectors.json');
    if (!file.existsSync()) {
      file = File('test_vectors/shared_physics_vectors.json');
    }
    expect(file.existsSync(), isTrue, reason: 'Test vectors file should exist');

    final jsonContent = file.readAsStringSync();
    final List<dynamic> cases = jsonDecode(jsonContent);

    for (final tc in cases) {
      final name = tc['name'] as String;
      final initialState = SimState.fromJson(tc['initialState'] as Map<String, dynamic>);
      final activeSide = tc['activeSide'] as int;
      final shot = SimShot.fromJson(tc['shot'] as Map<String, dynamic>);
      final exp = tc['expectedFinalState'] as Map<String, dynamic>;

      final simRes = simulateTurn(initialState, activeSide, shot, 5.0);

      final expPen0 = exp['pen0'] as Map<String, dynamic>;
      final expPen1 = exp['pen1'] as Map<String, dynamic>;

      expect(
        simRes.finalState.pens[0].x,
        closeTo((expPen0['x'] as num).toDouble(), 1.5),
        reason: '$name: pen0 x',
      );
      expect(
        simRes.finalState.pens[0].y,
        closeTo((expPen0['y'] as num).toDouble(), 1.5),
        reason: '$name: pen0 y',
      );
      expect(
        simRes.finalState.pens[1].x,
        closeTo((expPen1['x'] as num).toDouble(), 1.5),
        reason: '$name: pen1 x',
      );
      expect(
        simRes.finalState.pens[1].y,
        closeTo((expPen1['y'] as num).toDouble(), 1.5),
        reason: '$name: pen1 y',
      );
      expect(simRes.fell, equals(exp['fell']), reason: '$name: fell');
      expect(simRes.winner, equals(exp['winner']), reason: '$name: winner');
    }
  });
}
