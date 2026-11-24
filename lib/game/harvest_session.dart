import '../constants.dart';
import '../data/row_definition.dart';
import 'rhythm/tap_quality.dart';

enum PlayMode { row, daily, longRow }

enum RowEnd { none, basketFull, outOfLeaves, bareBranches }

class RowResult {
  const RowResult({
    required this.row,
    required this.mode,
    required this.stars,
    required this.perfectPct,
    required this.livesLeft,
    required this.won,
    required this.end,
    required this.score,
    required this.perfectTaps,
    required this.goodTaps,
    required this.bruises,
    required this.bestStreak,
    required this.fruitPicked,
    required this.dewdropsUsed,
  });

  final RowDefinition row;
  final PlayMode mode;
  final int stars;
  final double perfectPct;
  final int livesLeft;
  final bool won;
  final RowEnd end;

  /// Basket points (the Long Row score).
  final int score;
  final int perfectTaps;
  final int goodTaps;
  final int bruises;
  final int bestStreak;
  final int fruitPicked;
  final int dewdropsUsed;

  bool get flawless => won && bruises == 0;
  bool get allPerfect => won && goodTaps == 0 && bruises == 0;
}

class HarvestTapResult {
  const HarvestTapResult({
    required this.quality,
    required this.message,
    this.fruitGained = 0,
    this.bonus = false,
    this.shielded = false,
    this.regrewLeaf = false,
    this.ended = false,
  });

  final TapQuality quality;
  final String message;
  final int fruitGained;
  final bool bonus;
  final bool regrewLeaf;

  /// A dewdrop absorbed this bruise.
  final bool shielded;
  final bool ended;
}

/// Pure rules for one row. No Flutter or Flame, so it is fully testable.
class HarvestSession {
  HarvestSession({
    required this.row,
    this.mode = PlayMode.row,
    this.dewdrops = 0,
  })  : quota = row.quota,
        _remainingFruit = [for (final t in row.trees) t.fruitCount];

  final RowDefinition row;
  final PlayMode mode;
  final int quota;

  /// Dewdrops carried into this row; each absorbs one bruise.
  int dewdrops;
  int dewdropsUsed = 0;

  int lives = OrchardConstants.maxLives;
  int basketCount = 0;
  int perfectTaps = 0;
  int goodTaps = 0;
  int bruises = 0;
  int perfectStreak = 0;
  int bestStreak = 0;
  int fruitPicked = 0;

  /// Harvests since the last bruise (or last regrown leaf).
  int cleanHarvests = 0;

  /// Harvests since the Long Row tempo last rose.
  int harvestsSinceTempo = 0;

  final List<int> _remainingFruit;

  bool get isEndless => mode == PlayMode.longRow;

  List<int> get remainingFruit => List.unmodifiable(_remainingFruit);

  int get totalTaps => perfectTaps + goodTaps + bruises;

  double get perfectPct => totalTaps == 0 ? 0 : perfectTaps / totalTaps;

  bool get _bare => !isEndless && _remainingFruit.every((f) => f <= 0);

  RowEnd get end {
    if (lives <= 0) return RowEnd.outOfLeaves;
    if (!isEndless && basketCount >= quota) return RowEnd.basketFull;
    if (_bare) return RowEnd.bareBranches;
    return RowEnd.none;
  }

  bool get isWin => end == RowEnd.basketFull;

  bool get isLose =>
      end == RowEnd.outOfLeaves || end == RowEnd.bareBranches;

  bool get isComplete => end != RowEnd.none;

  /// Long Row: true once per [OrchardConstants.longRowTempoStep] harvests.
  bool consumeTempoStep() {
    if (harvestsSinceTempo >= OrchardConstants.longRowTempoStep) {
      harvestsSinceTempo = 0;
      return true;
    }
    return false;
  }

  HarvestTapResult applyTap({
    required int treeIndex,
    required TapQuality quality,
    bool isRest = false,
  }) {
    if (isComplete) {
      return const HarvestTapResult(
        quality: TapQuality.miss,
        message: '',
        ended: true,
      );
    }

    final hasFruit = isEndless || _remainingFruit[treeIndex] > 0;
    if (isRest || quality == TapQuality.miss || !hasFruit) {
      return _bruise(
        isRest
            ? 'A rest beat. Let it pass'
            : hasFruit
                ? 'Bruised'
                : 'This tree is bare',
      );
    }

    var gained = 0;
    String message;
    if (quality == TapQuality.perfect) {
      perfectTaps++;
      perfectStreak++;
      if (perfectStreak > bestStreak) bestStreak = perfectStreak;
      gained = 2;
      message = 'Perfect';
    } else {
      goodTaps++;
      perfectStreak = 0;
      gained = 1;
      message = 'Good harvest';
    }

    if (!isEndless) _remainingFruit[treeIndex]--;
    fruitPicked++;
    harvestsSinceTempo++;

    // Gentle failure: a run of clean harvests regrows one lost leaf.
    cleanHarvests++;
    var regrew = false;
    if (cleanHarvests >= OrchardConstants.harvestsToRegrowLeaf &&
        lives < OrchardConstants.maxLives) {
      lives++;
      cleanHarvests = 0;
      regrew = true;
      message = 'A leaf regrows';
    }

    var bonus = false;
    if (quality == TapQuality.perfect &&
        perfectStreak > 0 &&
        perfectStreak % OrchardConstants.perfectStreakTarget == 0) {
      gained += 1;
      bonus = true;
      if (!regrew) message = 'Perfect streak +1';
    }
    basketCount += gained;

    return HarvestTapResult(
      quality: quality,
      message: message,
      fruitGained: gained,
      bonus: bonus,
      regrewLeaf: regrew,
      ended: isComplete,
    );
  }

  HarvestTapResult _bruise(String message) {
    perfectStreak = 0;
    cleanHarvests = 0;
    bruises++;
    if (dewdrops > 0) {
      dewdrops--;
      dewdropsUsed++;
      return HarvestTapResult(
        quality: TapQuality.miss,
        message: 'A dewdrop saved the fruit',
        shielded: true,
        ended: isComplete,
      );
    }
    lives--;
    return HarvestTapResult(
      quality: TapQuality.miss,
      message: message,
      ended: isComplete,
    );
  }

  int computeStars() {
    if (!isWin) return 0;
    var stars = 1;
    if (lives >= 2) stars = 2;
    if (lives >= 2 && perfectPct >= row.perfectPctForThreeStars) stars = 3;
    return stars;
  }

  RowResult toResult() => RowResult(
        row: row,
        mode: mode,
        stars: computeStars(),
        perfectPct: perfectPct,
        livesLeft: lives,
        won: isWin,
        end: end,
        score: basketCount,
        perfectTaps: perfectTaps,
        goodTaps: goodTaps,
        bruises: bruises,
        bestStreak: bestStreak,
        fruitPicked: fruitPicked,
        dewdropsUsed: dewdropsUsed,
      );
}
