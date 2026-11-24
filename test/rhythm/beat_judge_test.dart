import 'package:echo_orchard/game/rhythm/beat_judge.dart';
import 'package:echo_orchard/game/rhythm/pulse_clock.dart';
import 'package:echo_orchard/game/rhythm/tap_quality.dart';
import 'package:flutter_test/flutter_test.dart';

BeatJudgement j(double pos, {double wind = 0, bool Function(int)? rest}) => judgeTap(
      beatPosition: pos,
      beatPeriodMs: 1000,
      goodWindowMs: 400,
      perfectWindowMs: 160,
      windOffsetMs: wind,
      isRestBeat: rest,
    );

void main() {
  test('band centre is perfect, edges are good, far is a miss', () {
    expect(j(2.75).quality, TapQuality.perfect);
    expect(j(2.75 + 0.07).quality, TapQuality.perfect);
    expect(j(2.75 + 0.15).quality, TapQuality.good);
    expect(j(2.75 - 0.15).quality, TapQuality.good);
    expect(j(2.75 + 0.3).quality, TapQuality.miss);
  });

  test('reports which beat and the signed error', () {
    final early = j(4.70);
    expect(early.beat, 4);
    expect(early.errorMs, closeTo(-50, 0.001));
    final late = j(4.80);
    expect(late.errorMs, closeTo(50, 0.001));
  });

  test('taps during the count-in are flagged', () {
    expect(j(-1.25).isCountIn, isTrue);
    expect(j(0.75).isCountIn, isFalse);
  });

  test('rest beats always miss', () {
    bool rest(int b) => b % 3 == 2;
    final r = j(2.75, rest: rest);
    expect(r.isRest, isTrue);
    expect(r.quality, TapQuality.miss);
    expect(j(3.75, rest: rest).quality, TapQuality.perfect);
  });

  test('a positive gust makes the band arrive early', () {
    // Without wind this tap is 150 ms early (good)…
    expect(j(2.60).quality, TapQuality.good);
    // …with a +150 ms gust it lands dead centre.
    expect(j(2.60, wind: 150).quality, TapQuality.perfect);
  });

  test('pulse clock keeps phase when the tempo changes', () {
    final c = PulseClock(bpm: 60);
    c.update(1500);
    expect(c.beatPosition, closeTo(1.5, 1e-9));
    c.bpm = 120;
    expect(c.beatPosition, closeTo(1.5, 1e-9));
    c.update(250);
    expect(c.beatPosition, closeTo(2.0, 1e-9));
    expect(c.beatIndex, 2);
  });

  test('count-in start beat and pause', () {
    final c = PulseClock(bpm: 60, startBeat: -2);
    c.update(500);
    expect(c.beatPosition, closeTo(-1.5, 1e-9));
    c.pause();
    c.update(1000);
    expect(c.beatPosition, closeTo(-1.5, 1e-9));
  });
}
