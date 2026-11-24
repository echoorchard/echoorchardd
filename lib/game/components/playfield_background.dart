import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../data/row_definition.dart';
import '../../theme/orchard_colors.dart';

/// The season painting, scaled to cover the screen, with a slow ambient
/// layer drifting over it: petals, pollen, leaves, snow or fireflies.
class PlayfieldBackground extends PositionComponent {
  PlayfieldBackground({
    required Vector2 screenSize,
    required this.sprite,
    required this.season,
    this.ambient = true,
  }) {
    size = screenSize;
    final rng = Random(season.index + 11);
    if (ambient) {
      for (var i = 0; i < _countFor(season); i++) {
        _motes.add(_Mote.random(rng, screenSize, season));
      }
    }
  }

  final Sprite sprite;
  final Season season;
  final bool ambient;
  final _motes = <_Mote>[];
  double _time = 0;

  /// Where trees stand, as a fraction of height (the art's ground line).
  static const groundLine = 0.70;

  static int _countFor(Season s) => switch (s) {
        Season.springBloom => 16,
        Season.summerSun => 12,
        Season.autumnGold => 14,
        Season.winterQuiet => 34,
        Season.harvestMoon => 18,
      };

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    for (final m in _motes) {
      m.step(dt, size, _time);
    }
  }

  @override
  void render(Canvas canvas) {
    // Cover-fit the 1080×1920 painting, anchored on the ground line so trees
    // always stand on the painted ground whatever the aspect ratio.
    final src = sprite.srcSize;
    final scale = max(size.x / src.x, size.y / src.y);
    final drawW = src.x * scale;
    final drawH = src.y * scale;
    final dx = (size.x - drawW) / 2;
    final dy = size.y * groundLine - drawH * groundLine;
    sprite.render(canvas, position: Vector2(dx, dy), size: Vector2(drawW, drawH));

    for (final m in _motes) {
      m.render(canvas, season, _time);
    }
  }
}

class _Mote {
  _Mote(this.x, this.y, this.vx, this.vy, this.r, this.phase);

  factory _Mote.random(Random rng, Vector2 size, Season s) {
    final x = rng.nextDouble() * size.x;
    final y = rng.nextDouble() * size.y;
    final phase = rng.nextDouble() * pi * 2;
    return switch (s) {
      Season.springBloom =>
        _Mote(x, y, 8 + rng.nextDouble() * 10, 14 + rng.nextDouble() * 10, 3 + rng.nextDouble() * 2.5, phase),
      Season.summerSun =>
        _Mote(x, y, 4 + rng.nextDouble() * 6, -4 - rng.nextDouble() * 6, 1.4 + rng.nextDouble() * 1.4, phase),
      Season.autumnGold =>
        _Mote(x, y, -6 - rng.nextDouble() * 12, 22 + rng.nextDouble() * 16, 4 + rng.nextDouble() * 3, phase),
      Season.winterQuiet =>
        _Mote(x, y, -3 + rng.nextDouble() * 6, 16 + rng.nextDouble() * 18, 1.4 + rng.nextDouble() * 2.2, phase),
      Season.harvestMoon =>
        _Mote(x, size.y * (0.3 + rng.nextDouble() * 0.6), 3 + rng.nextDouble() * 4, -2 - rng.nextDouble() * 3, 2 + rng.nextDouble() * 1.5, phase),
    };
  }

  double x, y;
  final double vx, vy, r, phase;

  void step(double dt, Vector2 size, double t) {
    x += (vx + sin(t * 0.9 + phase) * 9) * dt;
    y += vy * dt;
    if (y > size.y + 10) y = -10;
    if (y < -10) y = size.y + 10;
    if (x > size.x + 10) x = -10;
    if (x < -10) x = size.x + 10;
  }

  void render(Canvas canvas, Season s, double t) {
    switch (s) {
      case Season.springBloom:
        _petal(canvas, WorldColors.blossom, t);
      case Season.summerSun:
        canvas.drawCircle(Offset(x, y), r,
            Paint()..color = const Color(0xFFFFF6D0).withValues(alpha: 0.55 + 0.3 * sin(t * 2 + phase)));
      case Season.autumnGold:
        _petal(canvas, WorldColors.autumnLeaf, t, long: true);
      case Season.winterQuiet:
        canvas.drawCircle(Offset(x, y), r, Paint()..color = WorldColors.snow.withValues(alpha: 0.85));
      case Season.harvestMoon:
        final glow = (0.5 + 0.5 * sin(t * 1.7 + phase)).clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(x, y),
          r * 3.2,
          Paint()
            ..color = WorldColors.firefly.withValues(alpha: 0.18 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(Offset(x, y), r * 0.8, Paint()..color = WorldColors.firefly.withValues(alpha: 0.4 + 0.6 * glow));
    }
  }

  void _petal(Canvas canvas, Color c, double t, {bool long = false}) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(t * 1.3 + phase);
    final w = r * (long ? 2.4 : 2);
    final h = r * (long ? 1.1 : 1.3) * (0.6 + 0.4 * sin(t * 3 + phase).abs());
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), Paint()..color = c.withValues(alpha: 0.85));
    canvas.restore();
  }
}
