import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../data/progress_repository.dart';

enum Sfx {
  tick,
  rest,
  harvest,
  perfect,
  bonus,
  bruise,
  gust,
  star,
  win,
  lose,
  unlock,
  buy,
  menu,
}

enum Ambient { day, night }

/// Sound effects (synthesised by tool/make_sfx.py) and the ambient bed.
/// Every call is fire-and-forget and never throws.
class OrchardAudio {
  OrchardAudio._();

  static final OrchardAudio instance = OrchardAudio._();

  /// Tests switch audio off entirely.
  static bool disabled = false;

  ProgressRepository? _repo;
  final Map<Sfx, AudioPool> _pools = {};
  AudioPlayer? _ambientPlayer;
  Ambient? _ambient;
  bool _ready = false;

  static const _volumes = {
    Sfx.tick: 0.55,
    Sfx.rest: 0.5,
    Sfx.menu: 0.5,
    Sfx.gust: 0.7,
    Sfx.buy: 0.8,
  };

  Future<void> init(ProgressRepository repo) async {
    _repo = repo;
    if (disabled || _ready) return;
    _ready = true;
    for (final s in Sfx.values) {
      try {
        _pools[s] = await AudioPool.createFromAsset(
          path: 'audio/${s.name}.ogg',
          maxPlayers: s == Sfx.tick || s == Sfx.harvest || s == Sfx.perfect ? 4 : 2,
        );
      } catch (e) {
        debugPrint('audio: could not load ${s.name}: $e');
      }
    }
  }

  void play(Sfx sfx, {double volume = 1}) {
    if (disabled || !(_repo?.soundOn ?? false)) return;
    final pool = _pools[sfx];
    if (pool == null) return;
    pool.start(volume: (_volumes[sfx] ?? 1) * volume).catchError((_) => () async {});
  }

  /// Starts (or switches) the ambient loop; respects the music setting.
  Future<void> ambient(Ambient which) async {
    _ambient = which;
    if (disabled) return;
    if (!(_repo?.musicOn ?? false)) {
      await _stopAmbient();
      return;
    }
    try {
      final player = _ambientPlayer ??= AudioPlayer()
        ..setReleaseMode(ReleaseMode.loop);
      await player.stop();
      await player.setVolume(0.55);
      await player.play(AssetSource('audio/ambient_${which.name}.ogg'));
    } catch (e) {
      debugPrint('audio: ambient failed: $e');
    }
  }

  /// Re-applies the music setting after it changes.
  Future<void> refreshAmbient() async {
    if (_ambient == null) return;
    await ambient(_ambient!);
  }

  Future<void> pauseAmbient() async {
    if (disabled) return;
    try {
      await _ambientPlayer?.pause();
    } catch (_) {}
  }

  Future<void> resumeAmbient() async {
    if (disabled || !(_repo?.musicOn ?? false)) return;
    try {
      await _ambientPlayer?.resume();
    } catch (_) {}
  }

  Future<void> _stopAmbient() async {
    try {
      await _ambientPlayer?.stop();
    } catch (_) {}
  }
}
