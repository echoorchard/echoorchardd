import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../constants.dart';
import '../data/progress_repository.dart';
import '../data/row_definition.dart';
import '../theme/orchard_colors.dart';
import 'components/basket_component.dart';
import 'components/flying_fruit.dart';
import 'components/harvest_burst.dart';
import 'components/playfield_background.dart';
import 'components/tree_component.dart';
import 'components/wind_ribbon_component.dart';
import 'feedback/orchard_feedback.dart';
import 'harvest_session.dart';
import 'rhythm/beat_judge.dart';
import 'rhythm/pulse_clock.dart';
import 'rhythm/tap_quality.dart';
import 'rhythm/wind_gust.dart';

/// Flame game for one harvest row. Rules live in [HarvestSession]; this
/// class only draws, times and routes input.
class HarvestGame extends FlameGame {
  HarvestGame({
    required this.row,
    required this.session,
    required this.repository,
    required this.basketAsset,
    required this.onSessionUpdated,
    required this.onRowComplete,
    this.reduceMotion = false,
    bool startPaused = false,
  })  : feedback = OrchardFeedback(repository),
        _paused = startPaused;

  final RowDefinition row;
  final HarvestSession session;
  final ProgressRepository repository;
  final String basketAsset;
  final void Function(HarvestSession session, HarvestTapResult? tap) onSessionUpdated;
  final void Function(RowResult result) onRowComplete;
  final bool reduceMotion;

  final OrchardFeedback feedback;
  late final WindController _wind;
  late final BasketComponent _basket;
  late final WindRibbonComponent _windRibbon;
  final List<TreeComponent> _trees = [];
  final List<Sprite> _fruitSprites = [];
  bool _paused;
  bool _finished = false;

  /// Long Row: multiplier applied to every tree's base tempo.
  double _tempo = 1;

  @override
  Color backgroundColor() => OrchardColors.ink;

  static String _fruitAsset(FruitType f) => 'fruit_${f.name}.png';

  /// Every image this game needs (preloaded by the screen).
  static List<String> assetsFor(RowDefinition row, String basketAsset) => [
        'bg_${row.season.artKey}.jpg',
        'tree_${row.season.artKey}.png',
        for (final t in row.trees) _fruitAsset(t.fruitType),
        basketAsset,
      ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await images.loadAll(assetsFor(row, basketAsset));

    _wind = WindController(
      enabled: row.wind.enabled,
      intervalSec: row.wind.intervalSec,
      shiftMs: row.wind.shiftMs,
      gentleWind: repository.gentleWind,
      seed: row.id,
    );

    add(PlayfieldBackground(
      screenSize: size,
      sprite: Sprite(images.fromCache('bg_${row.season.artKey}.jpg')),
      season: row.season,
      ambient: !reduceMotion,
    ));

    _windRibbon = WindRibbonComponent(screenSize: size);

    final treeSprite = Sprite(images.fromCache('tree_${row.season.artKey}.png'));
    final count = row.trees.length;
    // As large as the row allows without canopies overlapping
    // (canopy ≈ 0.83 × tree width, trees spaced width / (count + 1)).
    final slot = size.x / (count + 1);
    final scaleFactor = switch (count) {
      1 => (size.x * 0.52 / 150).clamp(1.2, 1.9),
      _ => (slot * 1.05 / 150).clamp(0.7, 1.45),
    };
    final ground = size.y * PlayfieldBackground.groundLine;
    for (var i = 0; i < count; i++) {
      final def = row.trees[i];
      final fruit = Sprite(images.fromCache(_fruitAsset(def.fruitType)));
      _fruitSprites.add(fruit);
      final x = size.x * (i + 1) / (count + 1);
      // Stagger heights slightly so three trees don't read as a wall.
      final y = ground + (count == 3 && i == 1 ? -14 : 0);
      final tree = TreeComponent(
        treeIndex: i,
        definition: def,
        clock: PulseClock(
          bpm: def.bpm,
          startBeat: def.startBeat - OrchardConstants.countInBeats,
        ),
        season: row.season,
        treeSprite: treeSprite,
        fruitSprite: fruit,
        goodWindowMs: row.goodWindowMs,
        perfectWindowMs: row.perfectWindowMs,
        remainingFruit: session.remainingFruit[i],
        onTapResult: _handleTap,
        groundPoint: Vector2(x, y),
        scaleFactor: scaleFactor,
        eyesOnly: repository.eyesOnlyRhythm,
        endless: session.isEndless,
      );
      _trees.add(tree);
      add(tree);
    }
    add(_windRibbon);

    final basketW = (size.x * 0.42).clamp(130.0, 200.0);
    _basket = BasketComponent(
      center: Vector2(size.x / 2, size.y - 34),
      sprite: Sprite(images.fromCache(basketAsset)),
      fruitSprites: _fruitSprites,
      width: basketW,
    );
    add(_basket);
  }

  /// Seconds of count-in left (for the "Ready" cue). 0 once play starts.
  double get countInBeatsLeft {
    if (_trees.isEmpty) return 0;
    final pos = _trees.first.clock.beatPosition;
    return pos < 0 ? -pos : 0;
  }

  void _handleTap(int treeIndex, BeatJudgement judgement) {
    if (session.isComplete || _paused) return;

    final result = session.applyTap(
      treeIndex: treeIndex,
      quality: judgement.quality,
      isRest: judgement.isRest,
    );
    final tree = _trees[treeIndex];
    tree.remainingFruit = session.remainingFruit[treeIndex];

    if (result.quality == TapQuality.miss) {
      if (result.shielded) {
        feedback.onShielded();
      } else {
        feedback.onBruised();
      }
      tree.bruiseShake();
      add(HarvestBurst(
        origin: tree.canopyCenter,
        style: BurstStyle.bruise,
        color: OrchardColors.dusk,
        count: 9,
        speed: 70,
      ));
    } else {
      final perfect = result.quality == TapQuality.perfect;
      feedback.onHarvest(perfect: perfect, bonus: result.bonus);
      tree.harvestPunch(perfect: perfect);
      add(HarvestBurst(
        origin: tree.canopyCenter,
        style: perfect ? BurstStyle.perfect : BurstStyle.good,
        color: perfect ? OrchardColors.gold : WorldColors.leafFresh,
        count: perfect ? 16 : 9,
        speed: perfect ? 130 : 85,
      ));
      if (perfect) {
        add(RippleRing(center: tree.canopyCenter, radius: tree.bandRadius, color: OrchardColors.gold));
      }
      for (var i = 0; i < result.fruitGained; i++) {
        add(FlyingFruit(
          start: tree.canopyCenter.clone(),
          target: _basket.mouth,
          sprite: _fruitSprites[treeIndex],
          duration: 0.48 + i * 0.08,
          fruitSize: tree.size.x * 0.2,
          onLanded: () => _basket.catchFruit(treeIndex),
        ));
      }
      if (session.isEndless && session.consumeTempoStep()) {
        _raiseTempo();
      }
    }

    onSessionUpdated(session, result);
    if (session.isComplete) _finish();
  }

  void _raiseTempo() {
    final lead = row.trees.first.bpm * _tempo;
    if (lead >= OrchardConstants.longRowMaxBpm) return;
    _tempo = (lead + OrchardConstants.longRowTempoRise) / row.trees.first.bpm;
    for (var i = 0; i < _trees.length; i++) {
      _trees[i].clock.bpm = row.trees[i].bpm * _tempo;
    }
  }

  double get currentLeadBpm => row.trees.first.bpm * _tempo;

  void _finish() {
    if (_finished) return;
    _finished = true;
    for (final t in _trees) {
      t.acceptsTaps = false;
    }
    final result = session.toResult();
    if (result.won) {
      feedback.onRowWin();
    } else {
      feedback.onRowLose();
    }
    // Let the last fruit land before handing over.
    add(TimerComponent(
      period: 0.75,
      removeOnFinish: true,
      onTick: () {
        pauseRhythm();
        onRowComplete(result);
      },
    ));
  }

  @override
  void update(double dt) {
    if (_paused) return;
    super.update(dt);
    if (_trees.isEmpty || _finished) return;

    final lead = _trees.first.clock;
    if (_wind.update(dt, lead.beatPeriodMs / 1000)) {
      feedback.onGust();
      _windRibbon.trigger(
        y: size.y * PlayfieldBackground.groundLine - _trees.first.size.y * 0.7,
        direction: _wind.direction,
      );
    }
    final offset = _wind.currentOffsetMs;
    for (final tree in _trees) {
      tree.windOffsetMs = offset;
    }

    // One metronome tick per lead-tree beat, at the moment the ring is born.
    feedback.onBeat(lead.beatIndex, isRest: row.trees.first.isRestBeat(lead.beatIndex));
  }

  bool get isPaused => _paused;

  void pauseRhythm() {
    _paused = true;
    for (final tree in _trees) {
      tree.clock.pause();
    }
  }

  void resumeRhythm() {
    _paused = false;
    for (final tree in _trees) {
      tree.clock.resume();
    }
  }
}
