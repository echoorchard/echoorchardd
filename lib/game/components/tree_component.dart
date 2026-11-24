import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../data/row_definition.dart';
import '../../theme/orchard_colors.dart';
import '../../theme/orchard_text_styles.dart';
import '../rhythm/beat_judge.dart';
import '../rhythm/pulse_clock.dart';

typedef TreeTapHandler = void Function(int treeIndex, BeatJudgement judgement);

/// One pulsing tree: sprite, fruit, echo ring and ripe band.
class TreeComponent extends PositionComponent with TapCallbacks {
  TreeComponent({
    required this.treeIndex,
    required this.definition,
    required this.clock,
    required this.season,
    required this.treeSprite,
    required this.fruitSprite,
    required this.goodWindowMs,
    required this.perfectWindowMs,
    required this.remainingFruit,
    required this.onTapResult,
    required Vector2 groundPoint,
    double scaleFactor = 1,
    this.eyesOnly = false,
    this.endless = false,
  }) {
    position = groundPoint;
    size = Vector2(150, 200) * scaleFactor;
    anchor = Anchor.bottomCenter;
  }

  final int treeIndex;
  final TreeDefinition definition;
  final PulseClock clock;
  final Season season;
  final Sprite treeSprite;
  final Sprite fruitSprite;
  final double goodWindowMs;
  final double perfectWindowMs;
  final TreeTapHandler onTapResult;
  final bool eyesOnly;
  final bool endless;

  int remainingFruit;
  double windOffsetMs = 0;
  bool acceptsTaps = true;

  double _squash = 1; // 1 = rest, counts down to 0 during the squash
  double _flash = 0;
  Color _flashColor = OrchardColors.gold;
  double _echoAlpha = 1;
  double _sway = 0;

  late final TextPaint _countPaint = TextPaint(
    style: OrchardText.small(color: OrchardColors.cream).copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 16,
      shadows: OrchardText.onArt,
    ),
  );

  // Canopy geometry, matching the painted sprite (centre 180,190 r150 of 360×480).
  Offset get _canopyLocal => Offset(size.x * 0.5, size.y * 190 / 480);
  double get _canopyRadius => size.x * 150 / 360;

  /// World-space canopy centre, where fruit and bursts start.
  Vector2 get canopyCenter => Vector2(
        position.x - size.x / 2 + _canopyLocal.dx,
        position.y - size.y + _canopyLocal.dy,
      );

  double get bandRadius => _ringRadius(ripeBandFraction);

  double _ringRadius(double f) {
    final r0 = _canopyRadius * 0.32;
    final r1 = _canopyRadius * 1.22;
    return r0 + (r1 - r0) * f;
  }

  /// The beat the ring is currently heading for (or just passed).
  int get _bandBeat {
    final eff = clock.beatPosition + windOffsetMs / clock.beatPeriodMs;
    return (eff - ripeBandFraction).round();
  }

  void harvestPunch({required bool perfect}) {
    _squash = 0;
    _flash = 1;
    _flashColor = perfect ? OrchardColors.gold : WorldColors.leafFresh;
  }

  void bruiseShake() {
    _flash = 1;
    _flashColor = OrchardColors.dusk;
    _sway = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    clock.update(dt * 1000);
    if (_squash < 1) _squash = min(1, _squash + dt / 0.18);
    if (_flash > 0) _flash = max(0, _flash - dt * 2.6);
    if (_sway > 0) _sway = max(0, _sway - dt * 3.3);

    // Fading echo: ease the ring between visible and ghost.
    final visible = definition.isEchoVisible(clock.beatIndex);
    final target = visible ? 1.0 : 0.12;
    _echoAlpha += (target - _echoAlpha) * min(1, dt * 6);

    // Squash: 1 → 0.92 → 1.05 → 1 (vertical), width counters it.
    final t = _squash;
    double sy;
    if (t < 0.35) {
      sy = 1 - 0.08 * (t / 0.35);
    } else if (t < 0.7) {
      sy = 0.92 + 0.13 * ((t - 0.35) / 0.35);
    } else {
      sy = 1.05 - 0.05 * ((t - 0.7) / 0.3);
    }
    if (t >= 1) sy = 1;
    scale.setValues(1 + (1 - sy) * 0.6, sy);
    angle = sin(_sway * pi * 4) * 0.035 * _sway;
  }

  @override
  void render(Canvas canvas) {
    treeSprite.render(canvas, size: size);

    final c = _canopyLocal;
    final cr = _canopyRadius;

    // Fruit on the canopy.
    final shown = endless ? 5 : min(remainingFruit, 6);
    final fs = size.x * 0.17;
    for (var i = 0; i < shown; i++) {
      final a = -pi / 2 + (i - 2.5) * 0.62;
      final rr = cr * (i.isEven ? 0.58 : 0.4);
      fruitSprite.render(
        canvas,
        position: Vector2(c.dx + cos(a) * rr, c.dy + sin(a) * rr * 0.85 + cr * 0.12),
        size: Vector2.all(fs),
        anchor: Anchor.center,
      );
    }

    final period = clock.beatPeriodMs;
    final eff = clock.beatPosition + windOffsetMs / period;
    final frac = eff - eff.floor();
    final beat = _bandBeat;
    final countIn = beat < 0;
    final rest = definition.isRestBeat(beat);
    final prox = bandProximity(
      beatPosition: clock.beatPosition,
      beatPeriodMs: period,
      goodWindowMs: goodWindowMs,
      windOffsetMs: windOffsetMs,
    );

    final bandR = bandRadius;
    final perfectHalf = perfectWindowMs / 2 / period;
    final goodHalf = goodWindowMs / 2 / period;
    final bandWidth = (_ringRadius(ripeBandFraction + perfectHalf) -
            _ringRadius(ripeBandFraction - perfectHalf))
        .clamp(3.0, 8.0);
    final outerWidth = (_ringRadius(ripeBandFraction + goodHalf) -
            _ringRadius(ripeBandFraction - goodHalf))
        .clamp(6.0, 22.0);

    if (rest && !countIn) {
      // Withered band: dashed dusk ring + a hollow centre mark (shape, not
      // just colour, says "don't tap").
      _dashedCircle(canvas, c, bandR, OrchardColors.dusk.withValues(alpha: 0.85), 4);
      canvas.drawLine(
        Offset(c.dx - 7, c.dy - cr * 1.38),
        Offset(c.dx + 7, c.dy - cr * 1.38),
        Paint()
          ..color = OrchardColors.cream
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final dim = countIn ? 0.35 : 1.0;
      // Good zone halo.
      canvas.drawCircle(
        c,
        bandR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outerWidth
          ..color = OrchardColors.gold.withValues(alpha: (0.07 + 0.16 * prox) * dim),
      );
      // Perfect band.
      canvas.drawCircle(
        c,
        bandR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = bandWidth + (eyesOnly ? 2 : 0) + 2 * prox
          ..color = OrchardColors.gold.withValues(alpha: ((eyesOnly ? 0.8 : 0.66) + 0.34 * prox) * dim),
      );
      // Ink edge so the band reads on bright art.
      canvas.drawCircle(
        c,
        bandR + bandWidth / 2 + 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = OrchardColors.ink.withValues(alpha: 0.25 * dim),
      );
    }

    // Echo ring.
    final ringR = _ringRadius(frac);
    final ringColor = WorldColors.ring(season);
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..color = OrchardColors.ink.withValues(alpha: 0.28 * _echoAlpha),
    );
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = ringColor.withValues(alpha: 0.95 * _echoAlpha),
    );

    if (_flash > 0) {
      canvas.drawCircle(
        c,
        bandR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * _flash
          ..color = _flashColor.withValues(alpha: 0.6 * _flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    if (!endless) {
      _countPaint.render(
        canvas,
        '$remainingFruit',
        Vector2(size.x / 2, size.y + 6),
        anchor: Anchor.topCenter,
      );
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Color color, double width) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    const dashes = 18;
    for (var i = 0; i < dashes; i++) {
      final a = i * 2 * pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, pi / dashes, false, paint);
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    // Generous hit area: the whole canopy disc plus the trunk.
    final c = _canopyLocal;
    final dx = point.x - c.dx;
    final dy = point.y - c.dy;
    return dx * dx + dy * dy <= pow(_canopyRadius * 1.35, 2) ||
        (point.x >= 0 && point.x <= size.x && point.y >= 0 && point.y <= size.y);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!acceptsTaps) return;
    final judgement = judgeTap(
      beatPosition: clock.beatPosition,
      beatPeriodMs: clock.beatPeriodMs,
      goodWindowMs: goodWindowMs,
      perfectWindowMs: perfectWindowMs,
      windOffsetMs: windOffsetMs,
      isRestBeat: definition.isRestBeat,
    );
    if (judgement.isCountIn) return;
    onTapResult(treeIndex, judgement);
  }
}
