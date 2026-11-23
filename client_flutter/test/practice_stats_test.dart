import 'package:flutter_test/flutter_test.dart';
import 'package:kolom_fight/models/practice_stats.dart';

void main() {
  test('a new practice record is empty', () {
    const stats = PracticeStats();
    expect(stats.matches, 0);
    expect(stats.winRate, 0.0);
    expect(stats.streak, 0);
    expect(stats.bestStreak, 0);
  });

  test('wins build a streak and track the best run', () {
    var stats = const PracticeStats();
    stats = stats.recordWin();
    stats = stats.recordWin();
    stats = stats.recordLoss();
    stats = stats.recordWin();

    expect(stats.wins, 3);
    expect(stats.losses, 1);
    expect(stats.streak, 1);
    expect(stats.bestStreak, 2);
    expect(stats.matches, 4);
    expect(stats.winRate, closeTo(0.75, 1e-9));
  });

  test('a loss resets the active streak but keeps the record', () {
    var stats = const PracticeStats().recordWin().recordWin();
    stats = stats.recordLoss();

    expect(stats.wins, 2);
    expect(stats.losses, 1);
    expect(stats.streak, 0);
    expect(stats.bestStreak, 2);
  });

  test('JSON round-trips every field', () {
    final stats = const PracticeStats()
        .recordWin()
        .recordWin()
        .recordWin()
        .recordLoss();
    final restored = PracticeStats.fromJson(stats.toJson());

    expect(restored.wins, stats.wins);
    expect(restored.losses, stats.losses);
    expect(restored.streak, stats.streak);
    expect(restored.bestStreak, stats.bestStreak);
  });

  test('missing JSON fields default to zero', () {
    final stats = PracticeStats.fromJson(const {});
    expect(stats.matches, 0);
    expect(stats.bestStreak, 0);
  });
}
