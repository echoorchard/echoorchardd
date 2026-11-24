abstract final class OrchardConstants {
  static const maxLives = 3;

  /// Clean harvests in a row that regrow one lost leaf.
  static const harvestsToRegrowLeaf = 10;

  /// Every Nth perfect in a row adds one bonus fruit.
  static const perfectStreakTarget = 3;

  /// Beats of count-in before the first ripe band (taps then are ignored).
  static const countInBeats = 2.0;

  /// Long Row: tempo rises by [longRowTempoRise] BPM every N harvests.
  static const longRowTempoStep = 8;
  static const longRowTempoRise = 4.0;
  static const longRowMaxBpm = 132.0;

  // Seeds economy (earned only, fixed amounts).
  static const seedsFirstClear = 10;
  static const seedsPerNewStar = 5;
  static const seedsDaily = 15;
  static const seedsAchievement = 10;

  /// Long Row: one seed per this many basket points.
  static const longRowPointsPerSeed = 10;
}
