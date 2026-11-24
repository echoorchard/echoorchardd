import '../data/progression_service.dart';
import '../data/row_definition.dart';
import '../game/harvest_session.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const path = '/path';
  static const harvest = '/harvest';
  static const crowned = '/crowned';
  static const rests = '/rests';
  static const journal = '/journal';
  static const market = '/market';
  static const daily = '/daily';
  static const lesson = '/lesson';
  static const privacy = '/privacy';
}

/// Arguments for [AppRoutes.harvest].
class HarvestArgs {
  const HarvestArgs({
    required this.row,
    this.mode = PlayMode.row,
    this.dewdrops = 0,
  });

  final RowDefinition row;
  final PlayMode mode;

  /// Dewdrops the player chose to carry into this row.
  final int dewdrops;
}

/// Arguments for the result screens.
class ResultArgs {
  const ResultArgs({required this.result, required this.reward});

  final RowResult result;
  final HarvestReward reward;
}
