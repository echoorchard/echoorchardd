import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

enum BurstStyle { perfect, good, bruise, regrow }

/// Short particle spray at a canopy: gold sparks + a ripple ring for a
/// perfect, leaf flecks for a good harvest, falling dusk drops for a bruise.
class HarvestBurst extends ParticleSystemComponent {
  HarvestBurst({
    required Vector2 origin,
    required BurstStyle style,
    required Color color,
    int count = 14,
    double speed = 100,
  }) : super(
          position: origin,
          particle: Particle.generate(
            count: count,
            lifespan: style == BurstStyle.bruise ? 0.7 : 0.6,
            generator: (i) {
              final r = _random;
              final angle = style == BurstStyle.bruise
                  ? pi / 2 + (r.nextDouble() - 0.5) * 1.6
                  : r.nextDouble() * 2 * pi;
              final mag = speed * (0.35 + r.nextDouble() * 0.65);
              final size = 2.0 + r.nextDouble() * 3;
              return AcceleratedParticle(
                acceleration: Vector2(0, style == BurstStyle.bruise ? 260 : 140),
                speed: Vector2(cos(angle), sin(angle)) * mag,
                child: ComputedParticle(
                  renderer: (canvas, p) {
                    final fade = (1 - p.progress).clamp(0.0, 1.0);
                    final paint = Paint()..color = color.withValues(alpha: fade);
                    if (style == BurstStyle.good || style == BurstStyle.regrow) {
                      // Little leaf flecks.
                      canvas.save();
                      canvas.rotate(angle + p.progress * 3);
                      canvas.drawOval(
                        Rect.fromCenter(center: Offset.zero, width: size * 2.2, height: size),
                        paint,
                      );
                      canvas.restore();
                    } else {
                      canvas.drawCircle(Offset.zero, size * (0.5 + 0.5 * fade), paint);
                    }
                  },
                ),
              );
            },
          ),
        );

  static final Random _random = Random();
}

/// An expanding ring at the band: the visual "answer" to a perfect tap.
class RippleRing extends PositionComponent {
  RippleRing({required Vector2 center, required this.radius, required this.color}) {
    position = center;
  }

  final double radius;
  final Color color;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt / 0.42;
    if (_t >= 1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final e = 1 - pow(1 - _t, 3).toDouble();
    canvas.drawCircle(
      Offset.zero,
      radius * (1 + 0.45 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * (1 - _t) + 1
        ..color = color.withValues(alpha: (1 - _t) * 0.9),
    );
  }
}
