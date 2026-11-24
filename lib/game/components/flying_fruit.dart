import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A fruit sprite that arcs from a canopy into the basket, then removes
/// itself. Purely cosmetic: the session's basket count is authoritative.
class FlyingFruit extends PositionComponent {
  FlyingFruit({
    required this.start,
    required this.target,
    required this.sprite,
    this.duration = 0.55,
    this.fruitSize = 30,
    this.onLanded,
  }) {
    position = start.clone();
    anchor = Anchor.center;
    size = Vector2.all(fruitSize);
    _control = Vector2((start.x + target.x) / 2, min(start.y, target.y) - 90);
    _spin = (Random().nextDouble() - 0.5) * 4;
  }

  final Vector2 start;
  final Vector2 target;
  final Sprite sprite;
  final double duration;
  final double fruitSize;
  final VoidCallback? onLanded;

  late final Vector2 _control;
  late final double _spin;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt / duration;
    if (_t >= 1) {
      onLanded?.call();
      removeFromParent();
      return;
    }
    // easeInCubic-ish: slow lift, quick drop into the basket.
    final t = _t * _t * (3 - 2 * _t);
    final inv = 1 - t;
    position
      ..x = inv * inv * start.x + 2 * inv * t * _control.x + t * t * target.x
      ..y = inv * inv * start.y + 2 * inv * t * _control.y + t * t * target.y;
    angle = _spin * _t;
    scale.setAll(1.0 - 0.3 * _t);
  }

  @override
  void render(Canvas canvas) {
    sprite.render(canvas, size: size);
  }
}
