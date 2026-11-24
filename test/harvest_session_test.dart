import 'package:echo_orchard/constants.dart';
import 'package:echo_orchard/data/row_definition.dart';
import 'package:echo_orchard/data/rows.dart';
import 'package:echo_orchard/game/harvest_session.dart';
import 'package:echo_orchard/game/rhythm/tap_quality.dart';
import 'package:flutter_test/flutter_test.dart';

const _tiny = RowDefinition(
  id: 99,
  season: Season.springBloom,
  rowInSeason: 1,
  trees: [TreeDefinition(bpm: 60, fruitCount: 4, fruitType: FruitType.apple)],
  quota: 6,
  goodWindowMs: 400,
  perfectWindowMs: 200,
);

void main() {
  test('win when the basket reaches the quota', () {
    final s = HarvestSession(row: orchardRows.first);
    while (!s.isComplete) {
      s.applyTap(treeIndex: 0, quality: TapQuality.perfect);
    }
    expect(s.isWin, isTrue);
    expect(s.end, RowEnd.basketFull);
    expect(s.computeStars(), 3);
  });

  test('three bruises end the row', () {
    final s = HarvestSession(row: orchardRows.first);
    for (var i = 0; i < 3; i++) {
      s.applyTap(treeIndex: 0, quality: TapQuality.miss);
    }
    expect(s.isLose, isTrue);
    expect(s.end, RowEnd.outOfLeaves);
    expect(s.computeStars(), 0);
  });

  test('perfect = 2, good = 1, every third perfect in a row adds a bonus', () {
    final s = HarvestSession(row: orchardRows[8]);
    s.applyTap(treeIndex: 0, quality: TapQuality.good);
    expect(s.basketCount, 1);
    s.applyTap(treeIndex: 0, quality: TapQuality.perfect);
    s.applyTap(treeIndex: 0, quality: TapQuality.perfect);
    expect(s.basketCount, 5);
    final third = s.applyTap(treeIndex: 0, quality: TapQuality.perfect);
    expect(third.bonus, isTrue);
    expect(s.basketCount, 8);
  });

  test('tapping a rest beat bruises even if the timing was perfect', () {
    final s = HarvestSession(row: orchardRows.first);
    final r = s.applyTap(treeIndex: 0, quality: TapQuality.perfect, isRest: true);
    expect(r.quality, TapQuality.miss);
    expect(s.lives, OrchardConstants.maxLives - 1);
    expect(s.basketCount, 0);
  });

  test('bare branches end the row when fruit runs out below quota', () {
    final s = HarvestSession(row: _tiny);
    for (var i = 0; i < 4; i++) {
      s.applyTap(treeIndex: 0, quality: TapQuality.good);
    }
    expect(s.basketCount, 4);
    expect(s.isComplete, isTrue);
    expect(s.end, RowEnd.bareBranches);
    expect(s.isWin, isFalse);
  });

  test('a dewdrop absorbs one bruise instead of a leaf', () {
    final s = HarvestSession(row: orchardRows.first, dewdrops: 1);
    final r = s.applyTap(treeIndex: 0, quality: TapQuality.miss);
    expect(r.shielded, isTrue);
    expect(s.lives, OrchardConstants.maxLives);
    expect(s.dewdropsUsed, 1);
    s.applyTap(treeIndex: 0, quality: TapQuality.miss);
    expect(s.lives, OrchardConstants.maxLives - 1);
  });

  test('ten clean harvests regrow a lost leaf', () {
    final s = HarvestSession(row: orchardRows[8]);
    s.applyTap(treeIndex: 0, quality: TapQuality.miss);
    expect(s.lives, 2);
    HarvestTapResult? last;
    for (var i = 0; i < OrchardConstants.harvestsToRegrowLeaf; i++) {
      last = s.applyTap(treeIndex: 0, quality: TapQuality.good);
    }
    expect(last!.regrewLeaf, isTrue);
    expect(s.lives, 3);
  });

  test('the Long Row never runs out of fruit and steps the tempo', () {
    final s = HarvestSession(row: longRowDefinition, mode: PlayMode.longRow);
    var steps = 0;
    for (var i = 0; i < 40; i++) {
      s.applyTap(treeIndex: i % 2, quality: TapQuality.good);
      if (s.consumeTempoStep()) steps++;
    }
    expect(s.isComplete, isFalse);
    expect(s.basketCount, 40);
    expect(steps, 40 ~/ OrchardConstants.longRowTempoStep);
    for (var i = 0; i < 3; i++) {
      s.applyTap(treeIndex: 0, quality: TapQuality.miss);
    }
    expect(s.end, RowEnd.outOfLeaves);
  });

  test('two stars with one bruise, three need lives and 60% perfect', () {
    final s = HarvestSession(row: orchardRows.first);
    s.applyTap(treeIndex: 0, quality: TapQuality.miss);
    while (!s.isComplete) {
      s.applyTap(treeIndex: 0, quality: TapQuality.good);
    }
    expect(s.computeStars(), 2);
  });
}
