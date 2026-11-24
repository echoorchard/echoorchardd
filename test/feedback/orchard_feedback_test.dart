import 'package:echo_orchard/audio/orchard_audio.dart';
import 'package:echo_orchard/data/progress_repository.dart';
import 'package:echo_orchard/game/feedback/orchard_feedback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  OrchardAudio.disabled = true;

  Future<OrchardFeedback> make(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final repo = ProgressRepository(await SharedPreferences.getInstance());
    return OrchardFeedback(repo);
  }

  test('ticks exactly once per beat, never during the count-in', () async {
    final f = await make({});
    for (final beat in [-2, -2, -1, 0, 0, 0, 1, 1, 2, 3, 3]) {
      f.onBeat(beat, isRest: false);
    }
    expect(f.ticks, 4); // beats 0, 1, 2, 3
  });

  test('no ticks in Eyes-only mode or with the pulse tick off', () async {
    final eyes = await make({'eyes_only_rhythm': true});
    final off = await make({'pulse_tick': false});
    for (var b = 0; b < 5; b++) {
      eyes.onBeat(b, isRest: false);
      off.onBeat(b, isRest: false);
    }
    expect(eyes.ticks, 0);
    expect(off.ticks, 0);
  });
}
