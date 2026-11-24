import 'tap_quality.dart';

/// Where the ripe band sits inside each beat (0 = ring smallest, 1 = largest).
const double ripeBandFraction = 0.75;

class BeatJudgement {
  const BeatJudgement({
    required this.quality,
    required this.beat,
    required this.isRest,
    required this.errorMs,
  });

  /// The tap's quality. Always [TapQuality.miss] on a rest beat.
  final TapQuality quality;

  /// The beat whose ripe band the tap was closest to. Negative = count-in.
  final int beat;
  final bool isRest;

  /// Signed distance from the band centre (negative = early).
  final double errorMs;

  bool get isCountIn => beat < 0;
}

/// Pure tap evaluation used by the game and by the simulator.
///
/// [beatPosition] is the tree clock's continuous position; [windOffsetMs]
/// shifts the ripe moment (a positive gust makes the band arrive early).
BeatJudgement judgeTap({
  required double beatPosition,
  required double beatPeriodMs,
  required double goodWindowMs,
  required double perfectWindowMs,
  double windOffsetMs = 0,
  bool Function(int beat)? isRestBeat,
}) {
  if (beatPeriodMs <= 0) {
    return const BeatJudgement(
      quality: TapQuality.miss,
      beat: -1,
      isRest: false,
      errorMs: 0,
    );
  }
  final effective = beatPosition + windOffsetMs / beatPeriodMs;
  final beat = (effective - ripeBandFraction).round();
  final errorMs = (effective - (beat + ripeBandFraction)) * beatPeriodMs;
  final dist = errorMs.abs();
  final rest = isRestBeat?.call(beat) ?? false;

  TapQuality quality;
  if (dist <= perfectWindowMs / 2) {
    quality = TapQuality.perfect;
  } else if (dist <= goodWindowMs / 2) {
    quality = TapQuality.good;
  } else {
    quality = TapQuality.miss;
  }
  if (rest) quality = TapQuality.miss;

  return BeatJudgement(
    quality: quality,
    beat: beat,
    isRest: rest,
    errorMs: errorMs,
  );
}

/// 0..1 closeness of the ring to the band, for anticipation glow.
double bandProximity({
  required double beatPosition,
  required double beatPeriodMs,
  required double goodWindowMs,
  double windOffsetMs = 0,
}) {
  if (beatPeriodMs <= 0 || goodWindowMs <= 0) return 0;
  final effective = beatPosition + windOffsetMs / beatPeriodMs;
  final beat = (effective - ripeBandFraction).round();
  final dist = ((effective - (beat + ripeBandFraction)) * beatPeriodMs).abs();
  return (1 - dist / goodWindowMs).clamp(0.0, 1.0);
}
