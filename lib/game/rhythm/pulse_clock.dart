/// A tree's metronome. Tracks a continuous beat position so the tempo can
/// change mid-row (Long Row) without the phase jumping.
class PulseClock {
  PulseClock({required double bpm, double startBeat = 0})
      : _bpm = bpm,
        _beats = startBeat;

  double _bpm;
  double _beats;
  double _elapsedMs = 0;
  bool paused = false;

  double get bpm => _bpm;

  /// Changes tempo, keeping the current beat position (and so the phase).
  set bpm(double value) {
    if (value > 0) _bpm = value;
  }

  double get elapsedMs => _elapsedMs;

  /// Continuous beat position (beat 3.5 = halfway through beat 3).
  double get beatPosition => _beats;

  int get beatIndex => _beats.floor();

  double get beatPeriodMs => 60000 / _bpm;

  /// Fraction 0..1 through the current beat.
  double get beatFraction => _beats - _beats.floor();

  double get phaseMs => beatFraction * beatPeriodMs;

  void update(double dtMs) {
    if (paused) return;
    _elapsedMs += dtMs;
    _beats += dtMs / beatPeriodMs;
  }

  void pause() => paused = true;

  void resume() => paused = false;

  void reset({double startBeat = 0}) {
    _elapsedMs = 0;
    _beats = startBeat;
    paused = false;
  }
}
