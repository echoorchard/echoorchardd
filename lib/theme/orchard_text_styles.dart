import 'package:flutter/material.dart';

import 'orchard_colors.dart';

/// Fraunces only (docs/DESIGN_LANGUAGE.md §2).
abstract final class OrchardText {
  static const _family = 'Fraunces';
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle title({Color color = OrchardColors.ink}) => TextStyle(
        fontFamily: _family,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle heading({Color color = OrchardColors.ink, double size = 26}) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: color,
      );

  static TextStyle label({Color color = OrchardColors.ink, double size = 17}) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
        fontFeatures: _tabular,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontFamily: _family,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color ?? OrchardColors.ink,
      );

  static TextStyle small({Color? color}) => TextStyle(
        fontFamily: _family,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color ?? OrchardColors.inkSoft,
        fontFeatures: _tabular,
      );

  /// Big number in the HUD / result count-up.
  static TextStyle number({Color color = OrchardColors.ink, double size = 22}) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: color,
        fontFeatures: _tabular,
      );

  /// Text sitting directly on painted art.
  static List<Shadow> onArt = [
    Shadow(color: OrchardColors.ink.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 1)),
  ];
}
