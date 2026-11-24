import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// All on-device saves. Nothing ever leaves the device.
class ProgressRepository {
  ProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _unlockedRowKey = 'unlocked_row_id';
  static const _lastPlayedRowKey = 'last_played_row_id';
  static const _starsPrefix = 'stars_row_';
  static const _seedsKey = 'seeds';
  static const _dewdropsKey = 'dewdrops';
  static const _ownedKey = 'owned_items';
  static const _basketKey = 'equipped_basket';
  static const _achievementsKey = 'achievements';
  static const _statsKey = 'stats';
  static const _dailyDatesKey = 'daily_dates';
  static const _playDatesKey = 'play_dates';
  static const _longRowBestKey = 'long_row_best';
  static const _lessonSeenKey = 'lesson_seen';

  // Settings
  static const _soundKey = 'sound_on';
  static const _musicKey = 'music_on';
  static const _vibrationKey = 'vibration_on';
  static const _pulseTickKey = 'pulse_tick';
  static const _eyesOnlyKey = 'eyes_only_rhythm';
  static const _gentleWindKey = 'gentle_wind';
  static const _reduceMotionKey = 'reduce_motion';

  // ── Rows ──────────────────────────────────────────────────────────────
  int getUnlockedRowId() => _prefs.getInt(_unlockedRowKey) ?? 1;

  Future<void> setUnlockedRowId(int id) => _prefs.setInt(_unlockedRowKey, id);

  int getLastPlayedRowId() => _prefs.getInt(_lastPlayedRowKey) ?? 1;

  Future<void> setLastPlayedRowId(int id) =>
      _prefs.setInt(_lastPlayedRowKey, id);

  int getStars(int rowId) => _prefs.getInt('$_starsPrefix$rowId') ?? 0;

  /// Stores [stars] if better. Returns how many stars were newly earned.
  Future<int> setStars(int rowId, int stars) async {
    final current = getStars(rowId);
    if (stars > current) {
      await _prefs.setInt('$_starsPrefix$rowId', stars);
      return stars - current;
    }
    return 0;
  }

  int totalStars(int rowCount) {
    var total = 0;
    for (var i = 1; i <= rowCount; i++) {
      total += getStars(i);
    }
    return total;
  }

  // ── Currency & items ──────────────────────────────────────────────────
  int get seeds => _prefs.getInt(_seedsKey) ?? 0;

  Future<void> addSeeds(int amount) => _prefs.setInt(_seedsKey, seeds + amount);

  /// Spends seeds if affordable. Returns false otherwise.
  Future<bool> spendSeeds(int amount) async {
    if (amount > seeds) return false;
    await _prefs.setInt(_seedsKey, seeds - amount);
    return true;
  }

  int get dewdrops => _prefs.getInt(_dewdropsKey) ?? 0;

  Future<void> setDewdrops(int value) =>
      _prefs.setInt(_dewdropsKey, value.clamp(0, 99));

  Set<String> get ownedItems =>
      (_prefs.getStringList(_ownedKey) ?? const []).toSet();

  Future<void> addOwnedItem(String id) =>
      _prefs.setStringList(_ownedKey, {...ownedItems, id}.toList()..sort());

  String get equippedBasket => _prefs.getString(_basketKey) ?? 'willow';

  Future<void> setEquippedBasket(String id) => _prefs.setString(_basketKey, id);

  // ── Achievements & stats ──────────────────────────────────────────────
  Set<String> get achievements =>
      (_prefs.getStringList(_achievementsKey) ?? const []).toSet();

  Future<void> addAchievement(String id) => _prefs.setStringList(
      _achievementsKey, {...achievements, id}.toList()..sort());

  Map<String, int> get stats {
    final raw = _prefs.getString(_statsKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  int stat(String key) => stats[key] ?? 0;

  Future<void> saveStats(Map<String, int> value) =>
      _prefs.setString(_statsKey, jsonEncode(value));

  int get longRowBest => _prefs.getInt(_longRowBestKey) ?? 0;

  Future<void> setLongRowBest(int value) =>
      _prefs.setInt(_longRowBestKey, value);

  // ── Dates (yyyy-mm-dd, local) ─────────────────────────────────────────
  List<String> get dailyDates => _prefs.getStringList(_dailyDatesKey) ?? [];

  Future<void> addDailyDate(String date) {
    final dates = {...dailyDates, date}.toList()..sort();
    final trimmed = dates.length > 120 ? dates.sublist(dates.length - 120) : dates;
    return _prefs.setStringList(_dailyDatesKey, trimmed);
  }

  List<String> get playDates => _prefs.getStringList(_playDatesKey) ?? [];

  Future<void> addPlayDate(String date) {
    if (playDates.contains(date)) return Future.value();
    final dates = [...playDates, date]..sort();
    final trimmed = dates.length > 400 ? dates.sublist(dates.length - 400) : dates;
    return _prefs.setStringList(_playDatesKey, trimmed);
  }

  bool get lessonSeen => _prefs.getBool(_lessonSeenKey) ?? false;

  Future<void> setLessonSeen() => _prefs.setBool(_lessonSeenKey, true);

  // ── Settings ──────────────────────────────────────────────────────────
  bool get soundOn => _prefs.getBool(_soundKey) ?? true;
  Future<void> setSoundOn(bool v) => _prefs.setBool(_soundKey, v);

  bool get musicOn => _prefs.getBool(_musicKey) ?? true;
  Future<void> setMusicOn(bool v) => _prefs.setBool(_musicKey, v);

  bool get vibrationOn => _prefs.getBool(_vibrationKey) ?? true;
  Future<void> setVibrationOn(bool v) => _prefs.setBool(_vibrationKey, v);

  bool get pulseTickEnabled => _prefs.getBool(_pulseTickKey) ?? true;
  Future<void> setPulseTickEnabled(bool v) => _prefs.setBool(_pulseTickKey, v);

  bool get eyesOnlyRhythm => _prefs.getBool(_eyesOnlyKey) ?? false;
  Future<void> setEyesOnlyRhythm(bool v) => _prefs.setBool(_eyesOnlyKey, v);

  bool get gentleWind => _prefs.getBool(_gentleWindKey) ?? false;
  Future<void> setGentleWind(bool v) => _prefs.setBool(_gentleWindKey, v);

  bool get reduceMotion => _prefs.getBool(_reduceMotionKey) ?? false;
  Future<void> setReduceMotion(bool v) => _prefs.setBool(_reduceMotionKey, v);

  /// Erases all progress, items and stats. Settings are kept.
  Future<void> resetProgress() async {
    final keep = {
      _soundKey,
      _musicKey,
      _vibrationKey,
      _pulseTickKey,
      _eyesOnlyKey,
      _gentleWindKey,
      _reduceMotionKey,
    };
    for (final key in _prefs.getKeys().toList()) {
      if (!keep.contains(key)) await _prefs.remove(key);
    }
  }
}
