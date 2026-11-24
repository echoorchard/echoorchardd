/// The 20 local achievements. Each one awards seeds once.
library;

class Achievement {
  const Achievement(this.id, this.title, this.detail);

  final String id;
  final String title;
  final String detail;
}

const achievements = <Achievement>[
  Achievement('first_row', 'First Fruit', 'Clear your first row.'),
  Achievement('spring', 'First Basket', 'Clear the Spring Bloom finale.'),
  Achievement('summer', 'Midsummer Chorus', 'Clear the Summer Sun finale.'),
  Achievement('autumn', 'Leaf-Fall Waltz', 'Clear the Autumn Gold finale.'),
  Achievement('winter', 'First Frost', 'Clear the Winter Quiet finale.'),
  Achievement('moon', 'Moonlit Basket', 'Clear the Harvest Moon finale.'),
  Achievement('stars_30', 'Starry Rows', 'Collect 30 stars.'),
  Achievement('stars_100', 'Constellation', 'Collect 100 stars.'),
  Achievement('season_gold', 'Golden Season', 'Earn three stars on every row of one season.'),
  Achievement('all_perfect', 'Clear Note', 'Clear a row with only perfect harvests.'),
  Achievement('flawless_finale', 'Unbruised', 'Clear a finale without a single bruise.'),
  Achievement('streak_12', 'In the Pocket', 'Land 12 perfects in a row.'),
  Achievement('streak_30', 'Heartbeat', 'Land 30 perfects in a row.'),
  Achievement('fruit_500', 'Full Larder', 'Harvest 500 fruit.'),
  Achievement('fruit_3000', 'Orchard Keeper', 'Harvest 3,000 fruit.'),
  Achievement('daily_1', 'Morning Round', 'Clear a Daily Row.'),
  Achievement('daily_7', 'Seven Dawns', 'Clear the Daily Row seven days in a row.'),
  Achievement('long_60', 'Long Row', 'Score 60 in the Long Row.'),
  Achievement('long_200', 'Endless Orchard', 'Score 200 in the Long Row.'),
  Achievement('keepsakes', 'Well-Kept Hill', 'Place every keepsake on the hillside.'),
];

Achievement? achievementById(String id) {
  for (final a in achievements) {
    if (a.id == id) return a;
  }
  return null;
}
