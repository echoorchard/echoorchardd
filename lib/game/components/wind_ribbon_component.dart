import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A gust drawn as a few curling streaks that sweep across the row in the
/// direction the wind blows. Readable without colour: motion + shape.
class WindRibbonComponent extends PositionComponent {
  WindRibbonComponent({required this.screenSize}) {
    size = screenSize;
  }

  final Vector2 screenSize;
  double _t = 1;
  int _dir = 1;
  double _y = 0;

  bool get active => _t < 1;

  void trigger({required double y, required int direction}) {
    _t = 0;
    _y = y;
    _dir = direction == 0 ? 1 : direction;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_t < 1) _t = min(1, _t + dt / 1.1);
  }

  @override
  void render(Canvas canvas) {
    if (_t >= 1) return;
    final w = screenSize.x;
    final fade = sin(_t * pi);
    for (var i = 0; i < 4; i++) {
      final lane = _y + (i - 1.5) * 26;
      final head = (_t * 1.4 - 0.2 - i * 0.06) * w * 1.2;
      final x = _dir > 0 ? head : w - head;
      final len = w * 0.32;
      final path = Path()..moveTo(x, lane);
      for (var s = 1; s <= 12; s++) {
        final u = s / 12;
        path.lineTo(
          x - _dir * len * u,
          lane + sin(u * pi * 2 + i) * 5,
        );
      }
      // Curl at the head.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.6 - i * 0.35
          ..color = const Color(0xFFFFFDF6).withValues(alpha: 0.75 * fade),
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, lane - 6), radius: 6),
        _dir > 0 ? pi / 2 : -pi / 2,
        _dir > 0 ? -pi * 1.3 : pi * 1.3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.2
          ..color = const Color(0xFFFFFDF6).withValues(alpha: 0.7 * fade),
      );
    }
  }
}
