import 'row_definition.dart';
import 'row_generator.dart';

/// The 50 rows of the orchard, in five seasons of uneven length.
///
/// Tutorials (which teach the season's one new rule) and finales are written
/// by hand. The rows between them come from [RowGenerator] along each season's
/// difficulty curve. Timing windows are FULL widths in ms: a tap within
/// ±window/2 of the band centre counts.
final List<RowDefinition> orchardRows = List.unmodifiable(_buildRows());

/// Rows per season, in order. Uneven on purpose (see docs/IMPROVEMENT_PLAN.md).
const seasonLengths = {
  Season.springBloom: 9,
  Season.summerSun: 12,
  Season.autumnGold: 11,
  Season.winterQuiet: 10,
  Season.harvestMoon: 8,
};

List<RowDefinition> rowsInSeason(Season s) =>
    orchardRows.where((r) => r.season == s).toList();

RowDefinition? rowById(int id) {
  if (id < 1 || id > orchardRows.length) return null;
  return orchardRows[id - 1];
}

List<RowDefinition> _buildRows() {
  final rows = <RowDefinition>[];
  var id = 0;

  void season(Season s, List<RowDefinition Function(int id, int inSeason)> hand,
      {required int length, required RowDefinition Function(int id, int inSeason) finale}) {
    final tutorials = hand.length;
    for (var i = 1; i <= length; i++) {
      id++;
      if (i <= tutorials) {
        rows.add(hand[i - 1](id, i));
      } else if (i == length) {
        rows.add(finale(id, i));
      } else {
        // Generated rows climb to 85% of the curve; the hand-made finale is
        // always the season's peak.
        final span = length - tutorials - 1;
        final t = span <= 1 ? 0.5 : (i - tutorials - 1) / (span - 1) * 0.85;
        rows.add(RowGenerator.generate(
          id: id,
          season: s,
          rowInSeason: i,
          t: t,
        ));
      }
    }
  }

  // ── Spring Bloom: one pulse ─────────────────────────────────────────────
  season(Season.springBloom, length: 9, [
    (id, n) => RowDefinition(
          id: id,
          season: Season.springBloom,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'First Pulse',
          teach: 'Watch the ring grow. Tap the tree as it touches the golden band.',
          trees: const [TreeDefinition(bpm: 50, fruitCount: 18, fruitType: FruitType.apple)],
          quota: 14,
          goodWindowMs: 600,
          perfectWindowMs: 280,
        ),
    (id, n) => RowDefinition(
          id: id,
          season: Season.springBloom,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'Two for One',
          teach: 'Tap right on the band for a perfect: two fruit instead of one.',
          trees: const [TreeDefinition(bpm: 54, fruitCount: 22, fruitType: FruitType.pear)],
          quota: 18,
          goodWindowMs: 560,
          perfectWindowMs: 260,
        ),
  ], finale: (id, n) => RowDefinition(
        id: id,
        season: Season.springBloom,
        rowInSeason: n,
        kind: RowKind.finale,
        name: 'First Basket',
        trees: const [TreeDefinition(bpm: 78, fruitCount: 64, fruitType: FruitType.apple)],
        quota: 56,
        goodWindowMs: 340,
        perfectWindowMs: 150,
      ));

  // ── Summer Sun: many tempos ─────────────────────────────────────────────
  season(Season.summerSun, length: 12, [
    (id, n) => RowDefinition(
          id: id,
          season: Season.summerSun,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'Two Trees',
          teach: 'Two trees, two rings. Answer each one when its own band glows.',
          trees: const [
            TreeDefinition(bpm: 56, fruitCount: 20, fruitType: FruitType.pear),
            TreeDefinition(bpm: 56, fruitCount: 20, fruitType: FruitType.apple, startBeat: 0.5),
          ],
          quota: 34,
          goodWindowMs: 500,
          perfectWindowMs: 230,
        ),
    (id, n) => RowDefinition(
          id: id,
          season: Season.summerSun,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'Quick and Slow',
          teach: 'One tree is quicker. Let each ring keep its own time.',
          trees: const [
            TreeDefinition(bpm: 54, fruitCount: 18, fruitType: FruitType.plum),
            TreeDefinition(bpm: 81, fruitCount: 26, fruitType: FruitType.pear, startBeat: 0.4),
          ],
          quota: 36,
          goodWindowMs: 480,
          perfectWindowMs: 220,
        ),
  ], finale: (id, n) => RowDefinition(
        id: id,
        season: Season.summerSun,
        rowInSeason: n,
        kind: RowKind.finale,
        name: 'Midsummer Chorus',
        trees: const [
          TreeDefinition(bpm: 76, fruitCount: 34, fruitType: FruitType.pear),
          TreeDefinition(bpm: 101, fruitCount: 45, fruitType: FruitType.apple, startBeat: 0.35),
          TreeDefinition(bpm: 114, fruitCount: 50, fruitType: FruitType.plum, startBeat: 0.7),
        ],
        quota: 120,
        goodWindowMs: 290,
        perfectWindowMs: 125,
      ));

  // ── Autumn Gold: rest beats ─────────────────────────────────────────────
  season(Season.autumnGold, length: 11, [
    (id, n) => RowDefinition(
          id: id,
          season: Season.autumnGold,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'A Rest Beat',
          teach: 'When the band withers, that beat is a rest. Let it pass.',
          trees: const [
            TreeDefinition(bpm: 60, fruitCount: 20, fruitType: FruitType.apple, restPattern: 'xx-'),
          ],
          quota: 16,
          goodWindowMs: 480,
          perfectWindowMs: 220,
        ),
    (id, n) => RowDefinition(
          id: id,
          season: Season.autumnGold,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'Tap and Wait',
          teach: 'Here every second beat rests. Tap, wait, tap.',
          trees: const [
            TreeDefinition(bpm: 66, fruitCount: 18, fruitType: FruitType.plum, restPattern: 'x-'),
          ],
          quota: 14,
          goodWindowMs: 460,
          perfectWindowMs: 210,
        ),
    (id, n) => RowDefinition(
          id: id,
          season: Season.autumnGold,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'Two Waltzes',
          teach: 'Both trees rest, but never together. Watch each band.',
          trees: const [
            TreeDefinition(bpm: 60, fruitCount: 16, fruitType: FruitType.apple, restPattern: 'xx-'),
            TreeDefinition(
                bpm: 60, fruitCount: 16, fruitType: FruitType.pear, restPattern: 'xx-', startBeat: 1.5),
          ],
          quota: 27,
          goodWindowMs: 440,
          perfectWindowMs: 200,
        ),
  ], finale: (id, n) => RowDefinition(
        id: id,
        season: Season.autumnGold,
        rowInSeason: n,
        kind: RowKind.finale,
        name: 'Leaf-Fall Waltz',
        trees: const [
          TreeDefinition(bpm: 78, fruitCount: 30, fruitType: FruitType.apple, restPattern: 'xx-'),
          TreeDefinition(
              bpm: 104, fruitCount: 44, fruitType: FruitType.plum, restPattern: 'xxx-', startBeat: 0.45),
        ],
        quota: 66,
        goodWindowMs: 285,
        perfectWindowMs: 125,
      ));

  // ── Winter Quiet: wind gusts ────────────────────────────────────────────
  season(Season.winterQuiet, length: 10, [
    (id, n) => RowDefinition(
          id: id,
          season: Season.winterQuiet,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'First Gust',
          teach: 'A gust nudges the ring early or late. Follow the ring, not the count.',
          trees: const [TreeDefinition(bpm: 60, fruitCount: 30, fruitType: FruitType.pear)],
          quota: 24,
          goodWindowMs: 460,
          perfectWindowMs: 210,
          wind: const WindDefinition(enabled: true, intervalSec: 7, shiftMs: 90),
        ),
  ], finale: (id, n) => RowDefinition(
        id: id,
        season: Season.winterQuiet,
        rowInSeason: n,
        kind: RowKind.finale,
        name: 'First Frost',
        trees: const [
          TreeDefinition(bpm: 82, fruitCount: 49, fruitType: FruitType.pear),
          TreeDefinition(
              bpm: 108, fruitCount: 55, fruitType: FruitType.plum, restPattern: 'xxx-', startBeat: 0.5),
        ],
        quota: 96,
        goodWindowMs: 280,
        perfectWindowMs: 120,
        wind: const WindDefinition(enabled: true, intervalSec: 8, shiftMs: 150),
      ));

  // ── Harvest Moon: fading echo ───────────────────────────────────────────
  season(Season.harvestMoon, length: 8, [
    (id, n) => RowDefinition(
          id: id,
          season: Season.harvestMoon,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'Fading Echo',
          teach: 'The ring fades for two beats. Keep tapping in time: the band stays.',
          trees: const [
            TreeDefinition(bpm: 60, fruitCount: 30, fruitType: FruitType.peach, echoShow: 4, echoHide: 2),
          ],
          quota: 24,
          goodWindowMs: 460,
          perfectWindowMs: 210,
        ),
    (id, n) => RowDefinition(
          id: id,
          season: Season.harvestMoon,
          rowInSeason: n,
          kind: RowKind.tutorial,
          name: 'Moon Memory',
          teach: 'Longer quiet now. Feel the pulse you have already seen.',
          trees: const [
            TreeDefinition(bpm: 66, fruitCount: 35, fruitType: FruitType.peach, echoShow: 3, echoHide: 3),
          ],
          quota: 29,
          goodWindowMs: 440,
          perfectWindowMs: 200,
        ),
  ], finale: (id, n) => RowDefinition(
        id: id,
        season: Season.harvestMoon,
        rowInSeason: n,
        kind: RowKind.finale,
        name: 'Moonlit Basket',
        trees: const [
          TreeDefinition(bpm: 84, fruitCount: 44, fruitType: FruitType.peach, echoShow: 3, echoHide: 2),
          TreeDefinition(
              bpm: 104, fruitCount: 42, fruitType: FruitType.plum, restPattern: 'xxx-', startBeat: 0.4),
          TreeDefinition(bpm: 112, fruitCount: 62, fruitType: FruitType.apple, startBeat: 0.75),
        ],
        quota: 132,
        goodWindowMs: 270,
        perfectWindowMs: 110,
        wind: const WindDefinition(enabled: true, intervalSec: 9, shiftMs: 130),
      ));

  return rows;
}

/// The Long Row: endless, the tempo rises as you harvest.
const longRowDefinition = RowDefinition(
  id: 900,
  season: Season.summerSun,
  rowInSeason: 0,
  name: 'The Long Row',
  trees: [
    TreeDefinition(bpm: 60, fruitCount: 5, fruitType: FruitType.pear),
    TreeDefinition(bpm: 80, fruitCount: 5, fruitType: FruitType.apple, startBeat: 0.4),
  ],
  quota: 1 << 30,
  goodWindowMs: 400,
  perfectWindowMs: 180,
);
