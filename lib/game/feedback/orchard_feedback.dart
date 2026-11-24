import 'package:flutter/services.dart';

import '../../audio/orchard_audio.dart';
import '../../data/progress_repository.dart';

/// Sound + haptics for gameplay events, gated by the player's settings.
/// Visual feedback always leads; this only reinforces it.
class OrchardFeedback {
  OrchardFeedback(this._repository, {OrchardAudio? audio})
      : _audio = audio ?? OrchardAudio.instance;

  final ProgressRepository _repository;
  final OrchardAudio _audio;
  int _lastBeat = -999;

  bool get _sound => !_repository.eyesOnlyRhythm;
  bool get _buzz => _repository.vibrationOn;

  /// Number of metronome ticks played (used by tests).
  int ticks = 0;

  /// Call every frame with the lead tree's beat index; ticks once per beat.
  void onBeat(int beat, {required bool isRest}) {
    if (beat == _lastBeat) return;
    _lastBeat = beat;
    if (beat < 0) return;
    if (!_sound || !_repository.pulseTickEnabled) return;
    ticks++;
    _audio.play(isRest ? Sfx.rest : Sfx.tick);
  }

  void onHarvest({required bool perfect, bool bonus = false}) {
    if (_buzz) {
      perfect ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
    }
    if (!_sound) return;
    _audio.play(bonus ? Sfx.bonus : (perfect ? Sfx.perfect : Sfx.harvest));
  }

  void onBruised() {
    if (_buzz) HapticFeedback.heavyImpact();
    if (_sound) _audio.play(Sfx.bruise);
  }

  void onShielded() {
    if (_buzz) HapticFeedback.selectionClick();
    if (_sound) _audio.play(Sfx.rest);
  }

  void onGust() {
    if (_sound) _audio.play(Sfx.gust);
  }

  void onRowWin() {
    if (_buzz) HapticFeedback.mediumImpact();
    if (_sound) _audio.play(Sfx.win);
  }

  void onRowLose() {
    if (_buzz) HapticFeedback.lightImpact();
    if (_sound) _audio.play(Sfx.lose);
  }
}
