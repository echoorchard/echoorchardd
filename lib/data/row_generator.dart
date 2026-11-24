import 'dart:math';

import 'row_definition.dart';

/// Deterministic row generator. The same inputs always give the same row, so
/// generated rows are as stable as hand-made ones and are covered by tests.
class RowGenerator {
  const RowGenerator._();

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static const _fruitBySeason = {
    Season.springBloom: [FruitType.apple, FruitType.pear],
    Season.summerSun: [FruitType.pear, FruitType.apple, FruitType.plum],
    Season.autumnGold: [FruitType.apple, FruitType.plum, FruitType.pear],
    Season.winterQuiet: [FruitType.pear, FruitType.plum],
    Season.harvestMoon: [FruitType.peach, FruitType.plum, FruitType.apple],
  };

  static const _restPatterns = ['xx-', 'xxx-', 'x-', 'xx-x-', 'xxx-x-'];

  /// Tempo ratios that sound musical against a base tree.
  static const _ratios = [4 / 3, 3 / 2, 5 / 4, 5 / 3];

  static const maxBpm = 120.0;

  /// Ripe (non-rest) beats per second for a tree.
  static double harvestRate(TreeDefinition t) {
    final ripe = 'x'.allMatches(t.restPattern).length / t.restPattern.length;
    return t.bpm / 60 * ripe;
  }

  /// Builds a standard row at progress [t] (0 = season start, 1 = season end).
  static RowDefinition generate({
    required int id,
    required Season season,
    required int rowInSeason,
    required double t,
    int? seed,
    RowKind kind = RowKind.standard,
    String? name,
  }) {
    final rng = Random(seed ?? id * 7919 + 13);
    final fruits = _fruitBySeason[season]!;
    FruitType fruit(int i) => fruits[(i + rng.nextInt(fruits.length)) % fruits.length];

    late int treeCount;
    late double baseBpm;
    late double good;
    late double perfect;
    var fruitPerTree = 6;
    var quotaRatio = _lerp(0.72, 0.92, t);
    var wind = const WindDefinition();
    var restChance = 0.0;
    var echoChance = 0.0;

    switch (season) {
      case Season.springBloom:
        treeCount = 1;
        baseBpm = _lerp(56, 72, t);
        good = _lerp(520, 380, t);
        perfect = _lerp(240, 170, t);
        fruitPerTree = _lerp(6, 9, t).round();
      case Season.summerSun:
        treeCount = t < 0.55 ? 2 : 3;
        baseBpm = _lerp(58, 74, t);
        good = _lerp(470, 320, t);
        perfect = _lerp(215, 145, t);
        fruitPerTree = treeCount == 2 ? 5 : 4;
      case Season.autumnGold:
        treeCount = t < 0.4 ? 1 : 2;
        baseBpm = _lerp(62, 78, t);
        good = _lerp(430, 310, t);
        perfect = _lerp(195, 135, t);
        fruitPerTree = treeCount == 1 ? 8 : 5;
        restChance = 1;
      case Season.winterQuiet:
        treeCount = t < 0.45 ? 1 : 2;
        baseBpm = _lerp(62, 80, t);
        good = _lerp(420, 290, t);
        perfect = _lerp(190, 125, t);
        fruitPerTree = treeCount == 1 ? 8 : 5;
        restChance = t < 0.5 ? 0 : 0.5;
        wind = WindDefinition(
          enabled: true,
          intervalSec: _lerp(13, 8.5, t),
          shiftMs: _lerp(80, 145, t),
        );
      case Season.harvestMoon:
        treeCount = 2;
        baseBpm = _lerp(66, 82, t);
        good = _lerp(360, 275, t);
        perfect = _lerp(160, 115, t);
        fruitPerTree = 5;
        restChance = 0.5;
        echoChance = 1;
        if (t > 0.5) {
          wind = WindDefinition(
            enabled: true,
            intervalSec: _lerp(11, 9, t),
            shiftMs: _lerp(100, 130, t),
          );
        }
    }

    final trees = <TreeDefinition>[];
    for (var i = 0; i < treeCount; i++) {
      var bpm = baseBpm;
      if (i > 0) {
        bpm = baseBpm * _ratios[rng.nextInt(_ratios.length)];
        if (bpm > maxBpm) bpm = bpm / 2 * 1.5;
        bpm = bpm.clamp(48, maxBpm);
      }
      var pattern = 'x';
      if (rng.nextDouble() < restChance) {
        // Gentler patterns early in the season, busier ones later.
        final span = max(1, (t * _restPatterns.length).ceil());
        pattern = _restPatterns[rng.nextInt(span)];
      }
      var show = 0;
      var hide = 0;
      if (rng.nextDouble() < echoChance && (i == 0 || t > 0.4)) {
        show = t < 0.5 ? 4 : 3;
        hide = t < 0.5 ? 2 : 3;
      }
      trees.add(TreeDefinition(
        bpm: double.parse(bpm.toStringAsFixed(1)),
        fruitCount: fruitPerTree,
        fruitType: fruit(i),
        restPattern: pattern,
        echoShow: show,
        echoHide: hide,
        startBeat: i == 0 ? 0 : 0.35 + i * 0.3,
      ));
    }

    // Size the row from a target duration: [targetSec] is roughly how long a
    // typical player (mostly "good", some "perfect") spends on it.
    final targetSec = _lerp(28, 46, t);
    final rates = [for (final tr in trees) harvestRate(tr)];
    final lead = rates.first;
    final spread = const [1.0, 1.45, 1.75][treeCount - 1];
    final quota = max(8, (targetSec * lead * spread).round());
    final totalFruit = (quota / quotaRatio).ceil();
    final rateSum = rates.fold<double>(0, (a, b) => a + b);
    final sized = <TreeDefinition>[
      for (var i = 0; i < trees.length; i++)
        TreeDefinition(
          bpm: trees[i].bpm,
          fruitCount: max(4, (totalFruit * rates[i] / rateSum).ceil()),
          fruitType: trees[i].fruitType,
          restPattern: trees[i].restPattern,
          echoShow: trees[i].echoShow,
          echoHide: trees[i].echoHide,
          startBeat: trees[i].startBeat,
        ),
    ];
    final total = sized.fold<int>(0, (s, tr) => s + tr.fruitCount);

    return RowDefinition(
      id: id,
      season: season,
      rowInSeason: rowInSeason,
      trees: sized,
      quota: min(quota, total),
      goodWindowMs: good.roundToDouble(),
      perfectWindowMs: perfect.roundToDouble(),
      wind: wind,
      kind: kind,
      name: name,
    );
  }
}
