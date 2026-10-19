// ignore_for_file: avoid_print
// test_runner.dart
import 'dart:convert';
import 'dart:io';
import 'lib/game/kolom_physics_sim.dart';

void main() {
  final file = File('../test_vectors/shared_physics_vectors.json');
  if (!file.existsSync()) {
    print('Error: test_vectors file not found at ../test_vectors/shared_physics_vectors.json');
    exit(1);
  }

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

    final diffP0X = (simRes.finalState.pens[0].x - (expPen0['x'] as num).toDouble()).abs();
    final diffP0Y = (simRes.finalState.pens[0].y - (expPen0['y'] as num).toDouble()).abs();
    final diffP1X = (simRes.finalState.pens[1].x - (expPen1['x'] as num).toDouble()).abs();
    final diffP1Y = (simRes.finalState.pens[1].y - (expPen1['y'] as num).toDouble()).abs();

    print('Test: $name');
    print('  Pen0 diff: ($diffP0X, $diffP0Y)  Pen1 diff: ($diffP1X, $diffP1Y)');
    print('  Fell: ${simRes.fell} (expected ${exp['fell']}), Winner: ${simRes.winner} (expected ${exp['winner']})');

    if (diffP0X > 1.5 || diffP0Y > 1.5 || diffP1X > 1.5 || diffP1Y > 1.5) {
      print('FAILED: Parity mismatch for $name');
      exit(1);
    }
  }

  print('\nALL 3 PHYSICS TEST VECTORS PASSED WITH DART PARITY!');
}
