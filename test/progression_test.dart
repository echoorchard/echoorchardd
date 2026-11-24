import 'package:echo_orchard/constants.dart';
import 'package:echo_orchard/data/daily.dart';
import 'package:echo_orchard/data/market.dart';
import 'package:echo_orchard/data/progress_repository.dart';
import 'package:echo_orchard/data/progression_service.dart';
import 'package:echo_orchard/data/row_definition.dart';
import 'package:echo_orchard/data/rows.dart';
import 'package:echo_orchard/game/harvest_session.dart';
import 'package:echo_orchard/game/rhythm/harvest_simulator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProgressRepository repo;
  late ProgressionService prog;
  var now = DateTime(2026, 11, 12, 9);

  setUp(() async {
    now = DateTime(2026, 11, 12, 9);
    SharedPreferences.setMockInitialValues({});
    repo = ProgressRepository(await SharedPreferences.getInstance());
    prog = ProgressionService(repo, clock: () => now);
  });

  RowResult play(RowDefinition row, {PlayMode mode = PlayMode.row, bool perfect = true}) {
    final p = perfect ? SimPlayer.perfect(row) : SimPlayer.steady(row);
    final r = simulateRow(row, p).result;
    return RowResult(
      row: r.row,
      mode: mode,
      stars: r.stars,
      perfectPct: r.perfectPct,
      livesLeft: r.livesLeft,
      won: r.won,
      end: r.end,
      score: r.score,
      perfectTaps: r.perfectTaps,
      goodTaps: r.goodTaps,
      bruises: r.bruises,
      bestStreak: r.bestStreak,
      fruitPicked: r.fruitPicked,
      dewdropsUsed: r.dewdropsUsed,
    );
  }

  test('first clear: unlock next row, seeds for clear + stars, first seal', () async {
    final reward = await prog.recordResult(play(orchardRows.first));
    expect(prog.isRowUnlocked(2), isTrue);
    expect(reward.firstClear, isTrue);
    expect(reward.newStars, 3);
    expect(reward.achievements.map((a) => a.id), contains('first_row'));
    expect(repo.seeds, reward.seeds);
    expect(
      reward.seeds,
      OrchardConstants.seedsFirstClear +
          3 * OrchardConstants.seedsPerNewStar +
          reward.achievements.length * OrchardConstants.seedsAchievement,
    );
  });

  test('replaying a cleared row only pays for new stars', () async {
    await prog.recordResult(play(orchardRows.first, perfect: false)); // 2 stars
    final seedsBefore = repo.seeds;
    final again = await prog.recordResult(play(orchardRows.first));
    expect(again.firstClear, isFalse);
    expect(again.newStars, 1);
    expect(repo.seeds - seedsBefore, again.seeds);
  });

  test('clearing a finale opens the next season', () async {
    await repo.setUnlockedRowId(9);
    final reward = await prog.recordResult(play(orchardRows[8]));
    expect(reward.seasonUnlocked, Season.summerSun);
    expect(prog.highestSeason, Season.summerSun);
    expect(reward.achievements.map((a) => a.id), containsAll(['spring', 'flawless_finale']));
  });

  test('daily row pays once per day and builds a streak', () async {
    final daily = prog.todaysDaily;
    expect(daily.season, Season.springBloom); // only Spring reached so far
    final first = await prog.recordResult(play(daily, mode: PlayMode.daily, perfect: false));
    expect(first.dailyCleared, isTrue);
    expect(first.dewdropsEarned, greaterThanOrEqualTo(1));
    final second = await prog.recordResult(play(daily, mode: PlayMode.daily, perfect: false));
    expect(second.dailyCleared, isFalse);
    expect(prog.dailyStreak, 1);

    now = now.add(const Duration(days: 1));
    await prog.recordResult(play(prog.todaysDaily, mode: PlayMode.daily, perfect: false));
    expect(prog.dailyStreak, 2);
  });

  test('daily rows are date-seeded and always winnable', () {
    for (var d = 0; d < 60; d++) {
      final date = DateTime(2026, 11, 1).add(Duration(days: d));
      final a = DailyRow.forDate(date, highestSeason: Season.harvestMoon);
      final b = DailyRow.forDate(date, highestSeason: Season.harvestMoon);
      expect(a.quota, b.quota);
      expect(isWinnableBySteadyPlayer(a), isTrue, reason: DailyRow.dateKey(date));
    }
  });

  test('Long Row keeps the best score and pays seeds per 10 points', () async {
    final r = RowResult(
      row: longRowDefinition,
      mode: PlayMode.longRow,
      stars: 0,
      perfectPct: 0.5,
      livesLeft: 0,
      won: false,
      end: RowEnd.outOfLeaves,
      score: 73,
      perfectTaps: 20,
      goodTaps: 33,
      bruises: 3,
      bestStreak: 6,
      fruitPicked: 53,
      dewdropsUsed: 0,
    );
    final reward = await prog.recordResult(r);
    expect(repo.longRowBest, 73);
    expect(reward.newBest, isTrue);
    expect(reward.achievements.map((a) => a.id), contains('long_60'));
    expect(reward.seeds, 7 + OrchardConstants.seedsAchievement);
  });

  test('market: fixed prices, earned seeds only, no double buys', () async {
    final rush = marketItemById('rush')!;
    expect(await prog.buy(rush), isFalse); // 0 seeds
    await repo.addSeeds(rush.price);
    expect(await prog.buy(rush), isTrue);
    expect(repo.seeds, 0);
    expect(repo.equippedBasket, 'rush');
    await repo.addSeeds(500);
    expect(await prog.buy(rush), isFalse);
    expect(repo.seeds, 500);
  });

  test('owning every keepsake earns the collection seal once', () async {
    for (final k in keepsakes) {
      await repo.addOwnedItem(k.id);
    }
    expect((await prog.checkCollection()).single.id, 'keepsakes');
    expect(await prog.checkCollection(), isEmpty);
  });

  test('reset clears progress but keeps comfort settings', () async {
    await repo.setReduceMotion(true);
    await prog.recordResult(play(orchardRows.first));
    await repo.resetProgress();
    expect(repo.seeds, 0);
    expect(repo.getUnlockedRowId(), 1);
    expect(repo.achievements, isEmpty);
    expect(repo.reduceMotion, isTrue);
  });
}
