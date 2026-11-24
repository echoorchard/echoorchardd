/// Pure data describing one harvest row (level). No Flutter imports, so the
/// rules can be tested and simulated headlessly.
library;

enum FruitType { apple, pear, plum, peach }

/// The five seasons (chapters). Each one introduces exactly one new rule.
enum Season { springBloom, summerSun, autumnGold, winterQuiet, harvestMoon }

extension SeasonX on Season {
  String get label => switch (this) {
        Season.springBloom => 'Spring Bloom',
        Season.summerSun => 'Summer Sun',
        Season.autumnGold => 'Autumn Gold',
        Season.winterQuiet => 'Winter Quiet',
        Season.harvestMoon => 'Harvest Moon',
      };

  /// The single rule this season adds.
  String get rule => switch (this) {
        Season.springBloom => 'One pulse',
        Season.summerSun => 'Many tempos',
        Season.autumnGold => 'Rest beats',
        Season.winterQuiet => 'Wind gusts',
        Season.harvestMoon => 'Fading echo',
      };

  String get ruleHint => switch (this) {
        Season.springBloom =>
          'Tap the tree when its echo ring meets the golden band.',
        Season.summerSun =>
          'Each tree keeps its own tempo. Watch one ring at a time.',
        Season.autumnGold =>
          'A withered band is a rest beat. Let it pass without tapping.',
        Season.winterQuiet =>
          'A gust nudges the ripe moment early or late. Follow the band.',
        Season.harvestMoon =>
          'The ring fades for a few beats. Keep the pulse from memory.',
      };

  /// Short key used for art file names: `bg_KEY.jpg`, `tree_KEY.png`.
  String get artKey => switch (this) {
        Season.springBloom => 'spring',
        Season.summerSun => 'summer',
        Season.autumnGold => 'autumn',
        Season.winterQuiet => 'winter',
        Season.harvestMoon => 'moon',
      };

  bool get isNight => this == Season.harvestMoon;
}

enum RowKind { tutorial, standard, finale }

class TreeDefinition {
  const TreeDefinition({
    required this.bpm,
    required this.fruitCount,
    required this.fruitType,
    this.restPattern = 'x',
    this.echoShow = 0,
    this.echoHide = 0,
    this.startBeat = 0,
  });

  final double bpm;
  final int fruitCount;
  final FruitType fruitType;

  /// Repeating beat pattern. `x` = ripe beat, `-` = rest beat (tapping a rest
  /// beat bruises fruit). Indexed by beat number modulo its length.
  final String restPattern;

  /// Fading echo: the ring is fully visible for [echoShow] beats, then only a
  /// faint ghost for [echoHide] beats. `0` means always visible.
  final int echoShow;
  final int echoHide;

  /// Beat position the tree's clock starts at. Values between 0 and 1 offset
  /// trees from each other so their bands don't all land together.
  final double startBeat;

  bool get hasRests => restPattern.contains('-');
  bool get hasFadingEcho => echoShow > 0 && echoHide > 0;

  bool isRestBeat(int beat) {
    if (!hasRests || beat < 0) return false;
    return restPattern[beat % restPattern.length] == '-';
  }

  bool isEchoVisible(int beat) {
    if (!hasFadingEcho || beat < 0) return true;
    return beat % (echoShow + echoHide) < echoShow;
  }
}

class WindDefinition {
  const WindDefinition({
    this.enabled = false,
    this.intervalSec = 12,
    this.shiftMs = 100,
  });

  final bool enabled;
  final double intervalSec;
  final double shiftMs;
}

class RowDefinition {
  const RowDefinition({
    required this.id,
    required this.season,
    required this.rowInSeason,
    required this.trees,
    required this.quota,
    required this.goodWindowMs,
    required this.perfectWindowMs,
    this.wind = const WindDefinition(),
    this.kind = RowKind.standard,
    this.name,
    this.teach,
    this.perfectPctForThreeStars = 0.6,
  });

  final int id;
  final Season season;
  final int rowInSeason;
  final List<TreeDefinition> trees;

  /// Basket points needed (perfect = 2, good = 1, streak bonus = +1).
  final int quota;
  final double goodWindowMs;
  final double perfectWindowMs;
  final WindDefinition wind;
  final RowKind kind;

  /// Named rows: tutorials and finales.
  final String? name;

  /// One-line lesson shown before a tutorial row starts.
  final String? teach;
  final double perfectPctForThreeStars;

  String get title => name ?? 'Row $id';

  String get label => '$title · ${season.label}';

  int get totalFruit =>
      trees.fold<int>(0, (sum, tree) => sum + tree.fruitCount);

  bool get isSeasonFinale => kind == RowKind.finale;

  bool get isTutorial => kind == RowKind.tutorial;

  /// A rough difficulty score used by tests to check that rows ramp up.
  double get difficulty {
    var score = 0.0;
    for (final t in trees) {
      score += t.bpm / 10;
    }
    score += (trees.length - 1) * 3;
    score += 600 / goodWindowMs * 4;
    score += 300 / perfectWindowMs * 2;
    if (trees.any((t) => t.hasRests)) score += 3;
    if (wind.enabled) score += wind.shiftMs / 40 + 12 / wind.intervalSec;
    if (trees.any((t) => t.hasFadingEcho)) score += 4;
    score += quota / totalFruit * 4;
    return score;
  }
}
