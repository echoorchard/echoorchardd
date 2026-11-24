import 'package:echo_orchard/data/row_definition.dart';
import 'package:echo_orchard/data/row_generator.dart';
import 'package:echo_orchard/data/rows.dart';
import 'package:echo_orchard/game/rhythm/harvest_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('50 rows in 5 seasons with sequential ids', () {
    expect(orchardRows.length, 50);
    for (var i = 0; i < orchardRows.length; i++) {
      expect(orchardRows[i].id, i + 1);
    }
    for (final entry in seasonLengths.entries) {
      expect(rowsInSeason(entry.key).length, entry.value, reason: '${entry.key}');
    }
    expect(seasonLengths.values.fold<int>(0, (a, b) => a + b), 50);
  });

  test('every season opens with 1–3 tutorials and ends with a named finale', () {
    for (final s in Season.values) {
      final rows = rowsInSeason(s);
      final tutorials = rows.takeWhile((r) => r.isTutorial).length;
      expect(tutorials, inInclusiveRange(1, 3), reason: s.label);
      for (final r in rows.take(tutorials)) {
        expect(r.teach, isNotNull, reason: r.label);
        expect(r.name, isNotNull, reason: r.label);
      }
      expect(rows.last.isSeasonFinale, isTrue, reason: s.label);
      expect(rows.last.name, isNotNull);
      expect(rows.where((r) => r.isSeasonFinale).length, 1);
    }
  });

  test('each season introduces exactly its one new rule', () {
    bool hasMany(RowDefinition r) => r.trees.length > 1;
    bool hasRest(RowDefinition r) => r.trees.any((t) => t.hasRests);
    bool hasWind(RowDefinition r) => r.wind.enabled;
    bool hasEcho(RowDefinition r) => r.trees.any((t) => t.hasFadingEcho);

    for (final r in rowsInSeason(Season.springBloom)) {
      expect(hasMany(r) || hasRest(r) || hasWind(r) || hasEcho(r), isFalse, reason: r.label);
    }
    for (final r in rowsInSeason(Season.summerSun)) {
      expect(hasMany(r), isTrue, reason: r.label);
      expect(hasRest(r) || hasWind(r) || hasEcho(r), isFalse, reason: r.label);
    }
    for (final r in rowsInSeason(Season.autumnGold)) {
      expect(hasRest(r), isTrue, reason: r.label);
      expect(hasWind(r) || hasEcho(r), isFalse, reason: r.label);
    }
    for (final r in rowsInSeason(Season.winterQuiet)) {
      expect(hasWind(r), isTrue, reason: r.label);
      expect(hasEcho(r), isFalse, reason: r.label);
    }
    for (final r in rowsInSeason(Season.harvestMoon)) {
      expect(hasEcho(r), isTrue, reason: r.label);
    }
  });

  test('rows are well formed', () {
    for (final r in orchardRows) {
      expect(r.trees, isNotEmpty, reason: r.label);
      expect(r.trees.length, lessThanOrEqualTo(3), reason: r.label);
      expect(r.quota, inInclusiveRange(1, r.totalFruit), reason: r.label);
      expect(r.perfectWindowMs, lessThan(r.goodWindowMs), reason: r.label);
      for (final t in r.trees) {
        expect(t.bpm, inInclusiveRange(48, RowGenerator.maxBpm), reason: r.label);
        expect(t.restPattern, matches(RegExp(r'^[x-]+$')), reason: r.label);
        expect(t.restPattern, contains('x'), reason: r.label);
        // Never so fast that a beat is shorter than the good window.
        expect(60000 / t.bpm, greaterThan(r.goodWindowMs), reason: r.label);
      }
    }
  });

  test('a perfect player three-stars every row', () {
    for (final r in orchardRows) {
      final out = simulateRow(r, SimPlayer.perfect(r)).result;
      expect(out.won, isTrue, reason: r.label);
      expect(out.stars, 3, reason: r.label);
      expect(out.bruises, 0, reason: r.label);
    }
  });

  test('a steady player (only "good" taps) still clears every row', () {
    for (final r in orchardRows) {
      final p = SimPlayer.steady(r);
      final out = simulateRow(r, p).result;
      expect(out.won, isTrue, reason: '${r.label} steady');
      expect(out.perfectTaps, 0, reason: r.label);
    }
  });

  test('ignoring rest beats fails every Autumn row', () {
    for (final r in rowsInSeason(Season.autumnGold)) {
      final careless = SimPlayer(
        errorMs: (r.perfectWindowMs / 2 + r.goodWindowMs / 2) / 2,
        respectsRests: false,
      );
      expect(simulateRow(r, careless).result.won, isFalse, reason: r.label);
    }
  });

  test('rows last long enough to matter but not too long', () {
    for (final r in orchardRows) {
      final secs = simulateRow(r, SimPlayer.steady(r)).seconds;
      expect(secs, inInclusiveRange(15, 75), reason: r.label);
    }
  });

  test('a player who taps far off the band never clears row 1', () {
    final r = orchardRows.first;
    final sloppy = SimPlayer(errorMs: r.goodWindowMs);
    final out = simulateRow(r, sloppy).result;
    expect(out.won, isFalse);
  });

  test('difficulty ramps inside each season and the finale is the peak', () {
    for (final s in Season.values) {
      final rows = rowsInSeason(s);
      final finale = rows.last.difficulty;
      for (final r in rows) {
        expect(r.difficulty, lessThanOrEqualTo(finale + 0.001), reason: r.label);
      }
      final standard = rows.where((r) => r.kind == RowKind.standard).toList();
      for (var i = 1; i < standard.length; i++) {
        expect(
          standard[i].difficulty,
          greaterThanOrEqualTo(standard[i - 1].difficulty - 1.5),
          reason: '${standard[i].label} vs ${standard[i - 1].label}',
        );
      }
    }
    // Finale timing windows tighten from season to season.
    final finales = Season.values.map((s) => rowsInSeason(s).last).toList();
    for (var i = 1; i < finales.length; i++) {
      expect(finales[i].goodWindowMs, lessThan(finales[i - 1].goodWindowMs));
      expect(finales[i].perfectWindowMs, lessThanOrEqualTo(finales[i - 1].perfectWindowMs));
    }
  });

  test('generator is deterministic', () {
    final a = RowGenerator.generate(id: 77, season: Season.winterQuiet, rowInSeason: 3, t: 0.4);
    final b = RowGenerator.generate(id: 77, season: Season.winterQuiet, rowInSeason: 3, t: 0.4);
    expect(a.trees.map((t) => t.bpm), b.trees.map((t) => t.bpm));
    expect(a.quota, b.quota);
  });
}
