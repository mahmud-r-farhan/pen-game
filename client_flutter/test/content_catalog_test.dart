import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolom_fight/models/arena_room.dart';
import 'package:kolom_fight/models/kolom_spec.dart';

void main() {
  Map<String, dynamic> readContract() {
    final file = File('../test_vectors/content_catalog.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'The shared content contract must exist at test_vectors/.',
    );
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  test('client pen IDs match the shared content contract', () {
    final contract = readContract();
    final expected = (contract['pens'] as List<dynamic>).cast<String>().toSet();
    final actual = KolomSpec.catalog.values.map((pen) => pen.id).toSet();

    expect(actual, expected);
    expect(actual, contains('titaniumStriker'));
  });

  test('client arena IDs match the shared content contract', () {
    final contract = readContract();
    final expected = (contract['arenas'] as List<dynamic>)
        .cast<String>()
        .toSet();
    final actual = ArenaRoom.rooms.map((room) => room.id).toSet();

    expect(actual, expected);
    expect(actual, contains('coaching_center'));
  });

  test('every pen has internally consistent gameplay stats', () {
    for (final pen in KolomSpec.catalog.values) {
      expect(pen.length, greaterThan(0), reason: pen.id);
      expect(pen.radius, greaterThan(0), reason: pen.id);
      expect(pen.density, greaterThan(0), reason: pen.id);
      expect(pen.linearDamping, greaterThan(0), reason: pen.id);
      expect(pen.angularDamping, greaterThan(0), reason: pen.id);
      expect(pen.restitution, greaterThan(0), reason: pen.id);
      expect(pen.restitution, lessThan(1), reason: pen.id);
      expect(pen.unlockPrice, greaterThanOrEqualTo(0), reason: pen.id);
      expect(pen.minLevel, greaterThanOrEqualTo(1), reason: pen.id);
      expect(
        pen.comOffsetX.abs(),
        lessThanOrEqualTo(pen.length / 2),
        reason: pen.id,
      );
    }
  });

  test('every arena pays out its advertised pot', () {
    for (final room in ArenaRoom.rooms) {
      expect(room.entryCoins, greaterThan(0), reason: room.id);
      expect(room.potCoins, room.entryCoins * 2, reason: room.id);
      expect(
        room.payoutCoins,
        room.potCoins - (room.potCoins * 0.05).floor(),
        reason: room.id,
      );
      expect(room.friction, greaterThan(0), reason: room.id);
      expect(room.angularDamping, greaterThan(0), reason: room.id);
      expect(room.bounce, greaterThan(0), reason: room.id);
      expect(room.bounce, lessThan(1), reason: room.id);
    }
  });
}
