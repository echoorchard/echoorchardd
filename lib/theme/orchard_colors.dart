import 'package:flutter/material.dart';

import '../data/row_definition.dart';

/// The five interface colours (docs/DESIGN_LANGUAGE.md §1). Each has one job.
abstract final class OrchardColors {
  /// Paper: every interface surface.
  static const cream = Color(0xFFFFF6E8);

  /// Text, drawn icon strokes, shadows.
  static const ink = Color(0xFF2C2416);

  /// Action & structure: primary buttons, the path, current row.
  static const leaf = Color(0xFF3D6B4F);

  /// The beat / "now": ripe band, perfect, stars, seeds.
  static const gold = Color(0xFFE8A838);

  /// Rest & failure: bruise, rest beats, locked mist, Season Rests.
  static const dusk = Color(0xFF5E4B6E);

  // Derived tones (not new colours).
  static final inkSoft = ink.withValues(alpha: 0.72);
  static final inkFaint = ink.withValues(alpha: 0.38);
  static final hairline = ink.withValues(alpha: 0.10);
  static final scrim = ink.withValues(alpha: 0.55);
  static final shadow = ink.withValues(alpha: 0.16);
  static final leafPressed = Color.lerp(leaf, ink, 0.25)!;
}

/// World colours: used only for code-drawn things that live inside the art
/// (rings, particles, fruit glints), never for interface chrome.
abstract final class WorldColors {
  static const apple = Color(0xFFC8463D);
  static const pear = Color(0xFFC9B33F);
  static const plum = Color(0xFF7A4E8C);
  static const peach = Color(0xFFF2B38A);
  static const blossom = Color(0xFFF3B6C6);
  static const autumnLeaf = Color(0xFFD9733A);
  static const snow = Color(0xFFFFFFFF);
  static const firefly = Color(0xFFFFE6B0);
  static const leafFresh = Color(0xFF7FBF7A);

  static Color fruit(FruitType t) => switch (t) {
        FruitType.apple => apple,
        FruitType.pear => pear,
        FruitType.plum => plum,
        FruitType.peach => peach,
      };

  /// The echo ring stroke: light on day art, warm on the night sky.
  static Color ring(Season s) =>
      s.isNight ? firefly : const Color(0xFFFFFDF6);

  /// Mist that sits over locked seasons on the path.
  static const mist = Color(0xFFE9E4EE);
}
