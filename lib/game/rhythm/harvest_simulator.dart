import '../../constants.dart';
import '../../data/row_definition.dart';
import '../harvest_session.dart';
import 'beat_judge.dart';
import 'pulse_clock.dart';
import 'wind_gust.dart';

/// How a simulated player behaves.
class SimPlayer {
  const SimPlayer({
    required this.errorMs,
    this.respectsRests = true,
    this.readsWind = true,
  });

  /// Tap this many ms after the band centre (negative = early).
  final double errorMs;
  final bool respectsRests;

  /// Whether the player follows the gust-shifted ring.
  final bool readsWind;

  /// Taps well inside the perfect window.
  factory SimPlayer.perfect(RowDefinition row) =>
      SimPlayer(errorMs: row.perfectWindowMs * 0.2);

  /// Taps between the perfect and good edges: every tap is "good".
  factory SimPlayer.steady(RowDefinition row) => SimPlayer(
        errorMs: (row.perfectWindowMs / 2 + row.goodWindowMs / 2) / 2,
      );
}

class SimOutcome {
  const SimOutcome(this.result, this.seconds);

  final RowResult result;
  final double seconds;
}

/// Plays [row] headlessly in 4 ms steps. The player taps each tree once per
/// beat at band centre + error, using the same judge and session as the game.
SimOutcome simulateRow(
  RowDefinition row,
  SimPlayer player, {
  double maxSeconds = 600,
  bool gentleWind = false,
}) {
  const stepMs = 4.0;
  final session = HarvestSession(row: row);
  final clocks = [
    for (final t in row.trees)
      PulseClock(
        bpm: t.bpm,
        startBeat: t.startBeat - OrchardConstants.countInBeats,
      ),
  ];
  final wind = WindController(
    enabled: row.wind.enabled,
    intervalSec: row.wind.intervalSec,
    shiftMs: row.wind.shiftMs,
    gentleWind: gentleWind,
    seed: row.id,
  );
  final lastTapped = List<int>.filled(row.trees.length, -1);
  var elapsed = 0.0;

  while (!session.isComplete && elapsed < maxSeconds * 1000) {
    elapsed += stepMs;
    for (final c in clocks) {
      c.update(stepMs);
    }
    wind.update(stepMs / 1000, clocks.first.beatPeriodMs / 1000);
    final windMs = wind.currentOffsetMs;

    for (var i = 0; i < clocks.length && !session.isComplete; i++) {
      final clock = clocks[i];
      final tree = row.trees[i];
      final period = clock.beatPeriodMs;
      final seen = player.readsWind ? windMs : 0.0;
      final target = clock.beatPosition + (seen - player.errorMs) / period;
      final beat = (target - ripeBandFraction).floor();
      if (beat < 0 || beat <= lastTapped[i]) continue;
      // Tap on the first step after this beat's target time.
      final past = (target - (beat + ripeBandFraction)) * period;
      if (past < 0 || past > stepMs * 2) continue;
      lastTapped[i] = beat;
      if (player.respectsRests && tree.isRestBeat(beat)) continue;
      if (session.remainingFruit[i] <= 0) continue;

      final judgement = judgeTap(
        beatPosition: clock.beatPosition,
        beatPeriodMs: period,
        goodWindowMs: row.goodWindowMs,
        perfectWindowMs: row.perfectWindowMs,
        windOffsetMs: windMs,
        isRestBeat: tree.isRestBeat,
      );
      if (judgement.isCountIn) continue;
      session.applyTap(
        treeIndex: i,
        quality: judgement.quality,
        isRest: judgement.isRest,
      );
    }
  }
  return SimOutcome(session.toResult(), elapsed / 1000);
}

/// Convenience used by tests and the daily generator.
bool isWinnableBySteadyPlayer(RowDefinition row) =>
    simulateRow(row, SimPlayer.steady(row)).result.won;
