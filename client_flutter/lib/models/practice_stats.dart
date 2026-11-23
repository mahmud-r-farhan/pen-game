// lib/models/practice_stats.dart

/// Device-local record for offline bot practice.
///
/// Practice never touches the online economy, but keeping a local record gives
/// offline players a reason to keep training and lets the UI show meaningful
/// progression without pretending it is an online ranking.
class PracticeStats {
  final int wins;
  final int losses;
  final int streak;
  final int bestStreak;

  const PracticeStats({
    this.wins = 0,
    this.losses = 0,
    this.streak = 0,
    this.bestStreak = 0,
  });

  int get matches => wins + losses;

  double get winRate => matches == 0 ? 0 : wins / matches;

  PracticeStats recordWin() {
    final nextStreak = streak + 1;
    return PracticeStats(
      wins: wins + 1,
      losses: losses,
      streak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
    );
  }

  PracticeStats recordLoss() {
    return PracticeStats(
      wins: wins,
      losses: losses + 1,
      streak: 0,
      bestStreak: bestStreak,
    );
  }

  Map<String, dynamic> toJson() => {
    'wins': wins,
    'losses': losses,
    'streak': streak,
    'bestStreak': bestStreak,
  };

  factory PracticeStats.fromJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PracticeStats(
      wins: read('wins'),
      losses: read('losses'),
      streak: read('streak'),
      bestStreak: read('bestStreak'),
    );
  }
}
