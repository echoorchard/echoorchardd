import '../constants.dart';
import '../game/harvest_session.dart';
import 'achievements.dart';
import 'daily.dart';
import 'market.dart';
import 'progress_repository.dart';
import 'row_definition.dart';
import 'rows.dart';

/// What a finished row earned, shown on the result screen.
class HarvestReward {
  HarvestReward();

  int seeds = 0;
  int newStars = 0;
  bool firstClear = false;
  bool newBest = false;
  bool dailyCleared = false;
  int dewdropsEarned = 0;
  Season? seasonUnlocked;
  final List<Achievement> achievements = [];
}

class ProgressionService {
  ProgressionService(this._repository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ProgressRepository _repository;
  final DateTime Function() _clock;

  ProgressRepository get repository => _repository;

  DateTime get today => _clock();

  bool isRowUnlocked(int rowId) => rowId <= _repository.getUnlockedRowId();

  int starsForRow(int rowId) => _repository.getStars(rowId);

  int get totalStars => _repository.totalStars(orchardRows.length);

  int get rowsCleared {
    var n = 0;
    for (final r in orchardRows) {
      if (_repository.getStars(r.id) > 0) n++;
    }
    return n;
  }

  bool isSeasonUnlocked(Season season) =>
      isRowUnlocked(rowsInSeason(season).first.id);

  /// The furthest season the player has reached.
  Season get highestSeason {
    var best = Season.springBloom;
    for (final s in Season.values) {
      if (isSeasonUnlocked(s)) best = s;
    }
    return best;
  }

  int nextPlayableRowId() =>
      _repository.getUnlockedRowId().clamp(1, orchardRows.length);

  bool get dailyDoneToday =>
      _repository.dailyDates.contains(DailyRow.dateKey(today));

  int get dailyStreak => DailyRow.streak(_repository.dailyDates, today);

  RowDefinition get todaysDaily =>
      DailyRow.forDate(today, highestSeason: highestSeason);

  Future<void> markPlayedToday() =>
      _repository.addPlayDate(DailyRow.dateKey(today));

  /// Records a finished row and returns everything it earned.
  Future<HarvestReward> recordResult(RowResult result) async {
    final reward = HarvestReward();
    final repo = _repository;
    await markPlayedToday();

    if (result.dewdropsUsed > 0) {
      await repo.setDewdrops(repo.dewdrops - result.dewdropsUsed);
    }

    // Lifetime stats.
    final stats = repo.stats;
    void add(String k, int v) => stats[k] = (stats[k] ?? 0) + v;
    add('fruit', result.fruitPicked);
    add('perfects', result.perfectTaps);
    add('goods', result.goodTaps);
    add('bruises', result.bruises);
    add('rows_played', 1);
    if (result.won) add('rows_won', 1);
    if (result.bestStreak > (stats['best_streak'] ?? 0)) {
      stats['best_streak'] = result.bestStreak;
    }
    await repo.saveStats(stats);

    switch (result.mode) {
      case PlayMode.row:
        if (result.won) await _recordRowWin(result, reward);
      case PlayMode.daily:
        if (result.won && !dailyDoneToday) {
          await repo.addDailyDate(DailyRow.dateKey(today));
          reward
            ..dailyCleared = true
            ..seeds += OrchardConstants.seedsDaily
            ..dewdropsEarned += 1;
        }
      case PlayMode.longRow:
        if (result.score > repo.longRowBest) {
          await repo.setLongRowBest(result.score);
          reward.newBest = true;
        }
        reward.seeds += result.score ~/ OrchardConstants.longRowPointsPerSeed;
    }

    for (final a in _checkAchievements(result)) {
      await repo.addAchievement(a.id);
      reward.achievements.add(a);
      reward.seeds += OrchardConstants.seedsAchievement;
      // Some achievements also give a dewdrop.
      if (a.id.startsWith('daily') || a.id.startsWith('streak')) {
        reward.dewdropsEarned += 1;
      }
    }

    if (reward.seeds > 0) await repo.addSeeds(reward.seeds);
    if (reward.dewdropsEarned > 0) {
      await repo.setDewdrops(repo.dewdrops + reward.dewdropsEarned);
    }
    return reward;
  }

  Future<void> _recordRowWin(RowResult result, HarvestReward reward) async {
    final repo = _repository;
    final rowId = result.row.id;
    final wasCleared = repo.getStars(rowId) > 0;
    reward.newStars = await repo.setStars(rowId, result.stars);
    reward.firstClear = !wasCleared;
    reward.seeds += reward.newStars * OrchardConstants.seedsPerNewStar;
    if (reward.firstClear) reward.seeds += OrchardConstants.seedsFirstClear;
    await repo.setLastPlayedRowId(rowId);

    final unlocked = repo.getUnlockedRowId();
    if (rowId >= unlocked && rowId < orchardRows.length) {
      final before = highestSeason;
      await repo.setUnlockedRowId(rowId + 1);
      if (highestSeason != before) reward.seasonUnlocked = highestSeason;
    }
  }

  /// Unlocks for owning every keepsake (called after a Market trade too).
  Future<List<Achievement>> checkCollection() async {
    final unlocked = <Achievement>[];
    final owned = _repository.ownedItems;
    if (!_repository.achievements.contains('keepsakes') &&
        keepsakes.every((k) => owned.contains(k.id))) {
      final a = achievementById('keepsakes')!;
      await _repository.addAchievement(a.id);
      await _repository.addSeeds(OrchardConstants.seedsAchievement);
      unlocked.add(a);
    }
    return unlocked;
  }

  List<Achievement> _checkAchievements(RowResult result) {
    final have = _repository.achievements;
    final earned = <Achievement>[];
    void check(String id, bool condition) {
      if (condition && !have.contains(id)) earned.add(achievementById(id)!);
    }

    final row = result.row;
    final isStory = result.mode == PlayMode.row;
    final stats = _repository.stats;
    final stars = totalStars;

    check('first_row', isStory && result.won);
    if (isStory && result.won && row.isSeasonFinale) {
      check(switch (row.season) {
        Season.springBloom => 'spring',
        Season.summerSun => 'summer',
        Season.autumnGold => 'autumn',
        Season.winterQuiet => 'winter',
        Season.harvestMoon => 'moon',
      }, true);
      check('flawless_finale', result.flawless);
    }
    check('stars_30', stars >= 30);
    check('stars_100', stars >= 100);
    check(
      'season_gold',
      Season.values.any(
        (s) => rowsInSeason(s).every((r) => _repository.getStars(r.id) == 3),
      ),
    );
    check('all_perfect', result.allPerfect);
    check('streak_12', result.bestStreak >= 12);
    check('streak_30', result.bestStreak >= 30);
    check('fruit_500', (stats['fruit'] ?? 0) >= 500);
    check('fruit_3000', (stats['fruit'] ?? 0) >= 3000);
    check('daily_1', _repository.dailyDates.isNotEmpty);
    check('daily_7', dailyStreak >= 7);
    check('long_60', _repository.longRowBest >= 60);
    check('long_200', _repository.longRowBest >= 200);
    return earned;
  }

  Future<bool> buy(MarketItem item) async {
    if (_repository.ownedItems.contains(item.id) || item.price == 0) {
      return false;
    }
    final ok = await _repository.spendSeeds(item.price);
    if (!ok) return false;
    await _repository.addOwnedItem(item.id);
    if (item.kind == MarketKind.basket) {
      await _repository.setEquippedBasket(item.id);
    }
    return true;
  }

  bool owns(MarketItem item) =>
      item.price == 0 || _repository.ownedItems.contains(item.id);
}
