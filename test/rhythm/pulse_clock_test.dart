import 'package:flutter_test/flutter_test.dart';

import 'package:echo_orchard/game/rhythm/pulse_clock.dart';

void main() {
  test('pulse clock phase wraps at bpm 60', () {
    final clock = PulseClock(bpm: 60);
    clock.update(500);
    expect(clock.phaseMs, closeTo(500, 0.001));
    clock.update(500);
    expect(clock.phaseMs, closeTo(0, 0.001));
  });

  test('pause preserves phase', () {
    final clock = PulseClock(bpm: 60);
    clock.update(250);
    clock.pause();
    clock.update(1000);
    expect(clock.phaseMs, closeTo(250, 0.001));
    clock.resume();
    clock.update(250);
    expect(clock.phaseMs, closeTo(500, 0.001));
  });
}
