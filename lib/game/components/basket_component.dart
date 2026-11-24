import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../theme/orchard_colors.dart';

/// The basket sprite. Fruit that lands piles up inside; it bounces on catch.
class BasketComponent extends PositionComponent {
  BasketComponent({
    required Vector2 center,
    required this.sprite,
    required this.fruitSprites,
    double width = 160,
  }) {
    position = center;
    anchor = Anchor.bottomCenter;
    size = Vector2(width, width * 300 / 480);
  }

  final Sprite sprite;
  final List<Sprite> fruitSprites;

  /// 0..1 fill of the quota, drives how full the pile looks.
  double fill = 0;
  double _bounce = 0;
  final _pile = <_PileFruit>[];
  final _rng = Random(3);

  /// Where flying fruit should aim (world space).
  Vector2 get mouth => Vector2(position.x, position.y - size.y * 0.62);

  void catchFruit(int fruitIndex) {
    _bounce = 1;
    if (_pile.length < 14) {
      final n = _pile.length;
      final row = n < 6 ? 0 : (n < 11 ? 1 : 2);
      final inRow = row == 0 ? n : (row == 1 ? n - 6 : n - 11);
      final perRow = row == 0 ? 6 : (row == 1 ? 5 : 3);
      _pile.add(_PileFruit(
        sprite: fruitSprites[fruitIndex % fruitSprites.length],
        x: (inRow - (perRow - 1) / 2) * size.x * 0.12 + (_rng.nextDouble() - 0.5) * 4,
        y: -row * size.y * 0.12,
        angle: (_rng.nextDouble() - 0.5) * 0.8,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_bounce > 0) _bounce = max(0, _bounce - dt * 3.5);
    final s = 1 + 0.07 * sin(_bounce * pi) * _bounce;
    scale.setValues(1 + (s - 1) * 0.6, s);
  }

  @override
  void render(Canvas canvas) {
    // Contact shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.x / 2, size.y - 2), width: size.x * 0.9, height: 14),
      Paint()
        ..color = OrchardColors.ink.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Fruit sits behind the front weave: draw pile first, clipped above rim.
    final rimY = size.y * 110 / 300;
    final fruitSize = size.x * 0.17;
    for (final f in _pile) {
      canvas.save();
      canvas.translate(size.x / 2 + f.x, rimY + 6 + f.y);
      canvas.rotate(f.angle);
      f.sprite.render(canvas, size: Vector2.all(fruitSize), anchor: Anchor.center);
      canvas.restore();
    }
    sprite.render(canvas, size: size);
  }
}

class _PileFruit {
  _PileFruit({required this.sprite, required this.x, required this.y, required this.angle});

  final Sprite sprite;
  final double x;
  final double y;
  final double angle;
}
