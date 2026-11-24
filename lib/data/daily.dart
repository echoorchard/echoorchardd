import 'row_definition.dart';
import 'row_generator.dart';

/// Offline, date-seeded Daily Row: the same row for everyone on a given day,
/// built only from the seasons the player has reached.
class DailyRow {
  const DailyRow._();

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime parse(String key) {
    final p = key.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  /// Days since 2026-01-01; a stable seed per calendar day.
  static int dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day)
          .difference(DateTime.utc(2026, 1, 1))
          .inDays;

  static RowDefinition forDate(DateTime date, {required Season highestSeason}) {
    final day = dayNumber(date);
    final seed = day * 2654435 + 97;
    final pool = Season.values.sublist(0, highestSeason.index + 1);
    final season = pool[(seed ~/ 7).abs() % pool.length];
    final t = 0.35 + ((seed ~/ 13).abs() % 40) / 100;
    final base = RowGenerator.generate(
      id: 1000 + day,
      season: season,
      rowInSeason: 0,
      t: t,
      seed: seed,
    );
    return RowDefinition(
      id: base.id,
      season: base.season,
      rowInSeason: 0,
      trees: base.trees,
      quota: base.quota,
      goodWindowMs: base.goodWindowMs,
      perfectWindowMs: base.perfectWindowMs,
      wind: base.wind,
      name: 'Daily Row',
    );
  }

  /// Consecutive days up to [today] (or yesterday, if today isn't done yet).
  static int streak(List<String> dates, DateTime today) {
    final set = dates.toSet();
    var day = DateTime(today.year, today.month, today.day);
    if (!set.contains(dateKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (set.contains(dateKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }
}
