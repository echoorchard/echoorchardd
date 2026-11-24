import 'dart:math';

/// Periodic gusts that shift every tree's ripe moment by ±[shiftMs] for a few
/// beats. Deterministic per [seed] so rows and the simulator agree.
class WindController {
  WindController({
    required this.enabled,
    this.intervalSec = 12,
    this.shiftMs = 100,
    this.durationBeats = 2.5,
    this.gentleWind = false,
    int seed = 7,
  }) : _random = Random(seed);

  final bool enabled;
  final double intervalSec;
  final double shiftMs;
  final double durationBeats;
  bool gentleWind;

  double _elapsedSec = 0;
  double _activeRemainingBeats = 0;
  double _currentShiftMs = 0;
  final Random _random;

  /// Gentle Wind (accessibility): gusts come less often and push less.
  double get _effectiveShift => gentleWind ? shiftMs * 0.6 : shiftMs;

  double get currentOffsetMs =>
      _activeRemainingBeats > 0 ? _currentShiftMs : 0;

  bool get isActive => _activeRemainingBeats > 0;

  /// -1 (gust from the right, late) / 1 (from the left, early) / 0.
  int get direction => !isActive ? 0 : (_currentShiftMs > 0 ? 1 : -1);

  /// Returns true on the frame a new gust starts.
  bool update(double dtSec, double beatPeriodSec) {
    if (!enabled) return false;

    _elapsedSec += dtSec;

    if (_activeRemainingBeats > 0) {
      _activeRemainingBeats -= dtSec / beatPeriodSec;
      if (_activeRemainingBeats <= 0) {
        _activeRemainingBeats = 0;
        _currentShiftMs = 0;
      }
      return false;
    }

    final interval = gentleWind ? intervalSec * 1.8 : intervalSec;
    if (_elapsedSec >= interval) {
      _elapsedSec = 0;
      _activeRemainingBeats = durationBeats;
      _currentShiftMs = (_random.nextBool() ? 1 : -1) * _effectiveShift;
      return true;
    }
    return false;
  }

  void reset() {
    _elapsedSec = 0;
    _activeRemainingBeats = 0;
    _currentShiftMs = 0;
  }
}
