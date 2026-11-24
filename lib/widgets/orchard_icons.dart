import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/orchard_colors.dart';

/// Ripe Rhythm's own drawn icon set: 24-unit box, 2-unit ink stroke, round
/// caps and joins. Replaces Material icons and emoji everywhere.
enum OIcon {
  basket,
  leaf,
  star,
  seed,
  dewdrop,
  calendar,
  journal,
  market,
  windmill,
  pause,
  back,
  lock,
  restart,
  close,
  check,
  sound,
  music,
  vibration,
  eye,
  wind,
  motion,
  tick,
  privacy,
  play,
  longRow,
}

class OrchardIcon extends StatelessWidget {
  const OrchardIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color = OrchardColors.ink,
    this.fill,
    this.strokeWidth = 2,
  });

  final OIcon icon;
  final double size;
  final Color color;

  /// Optional fill for closed shapes (star, leaf, seed, dewdrop, basket).
  final Color? fill;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(icon, color, fill, strokeWidth),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.fill, this.strokeWidth);

  final OIcon icon;
  final Color color;
  final Color? fill;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()..color = fill ?? Colors.transparent;

    void shape(Path p) {
      if (fill != null) canvas.drawPath(p, fillPaint);
      canvas.drawPath(p, stroke);
    }

    switch (icon) {
      case OIcon.basket:
        shape(Path()
          ..moveTo(3.5, 10)
          ..lineTo(20.5, 10)
          ..lineTo(18.5, 20)
          ..lineTo(5.5, 20)
          ..close());
        canvas.drawPath(
            Path()
              ..moveTo(7, 10)
              ..cubicTo(7, 3.5, 17, 3.5, 17, 10),
            stroke);
        canvas.drawLine(const Offset(9, 13), const Offset(9.5, 17), stroke);
        canvas.drawLine(const Offset(12, 13), const Offset(12, 17), stroke);
        canvas.drawLine(const Offset(15, 13), const Offset(14.5, 17), stroke);
      case OIcon.leaf:
        shape(_leaf());
        canvas.drawLine(const Offset(6, 18), const Offset(15, 9), stroke..strokeWidth = strokeWidth * 0.75);
      case OIcon.star:
        shape(_star(12, 12.5, 9.5, 4.2));
      case OIcon.seed:
        shape(Path()
          ..moveTo(12, 3.5)
          ..cubicTo(18.5, 8, 18.5, 17, 12, 20.5)
          ..cubicTo(5.5, 17, 5.5, 8, 12, 3.5)
          ..close());
        canvas.drawLine(const Offset(12, 8), const Offset(12, 16), stroke);
      case OIcon.dewdrop:
        shape(Path()
          ..moveTo(12, 3)
          ..cubicTo(15, 8, 18.5, 11, 18.5, 14.5)
          ..arcToPoint(const Offset(5.5, 14.5), radius: const Radius.circular(6.5))
          ..cubicTo(5.5, 11, 9, 8, 12, 3)
          ..close());
        canvas.drawArc(Rect.fromCircle(center: const Offset(12, 14.5), radius: 3.6),
            math.pi * 0.55, math.pi * 0.5, false, stroke);
      case OIcon.calendar:
        canvas.drawRRect(
            RRect.fromLTRBR(4, 5.5, 20, 20, const Radius.circular(2.5)), stroke);
        canvas.drawLine(const Offset(4, 10), const Offset(20, 10), stroke);
        canvas.drawLine(const Offset(8.5, 3.5), const Offset(8.5, 7), stroke);
        canvas.drawLine(const Offset(15.5, 3.5), const Offset(15.5, 7), stroke);
        canvas.drawPath(_leaf(scale: 0.42, dx: 9.4, dy: 11.4), stroke);
      case OIcon.journal:
        canvas.drawPath(
            Path()
              ..moveTo(12, 6.5)
              ..cubicTo(9, 4.5, 6, 4.5, 3.5, 5.5)
              ..lineTo(3.5, 19)
              ..cubicTo(6, 18, 9, 18, 12, 20)
              ..cubicTo(15, 18, 18, 18, 20.5, 19)
              ..lineTo(20.5, 5.5)
              ..cubicTo(18, 4.5, 15, 4.5, 12, 6.5)
              ..close(),
            stroke);
        canvas.drawLine(const Offset(12, 6.5), const Offset(12, 20), stroke);
      case OIcon.market:
        canvas.drawPath(
            Path()
              ..moveTo(3, 9)
              ..lineTo(5, 4)
              ..lineTo(19, 4)
              ..lineTo(21, 9),
            stroke);
        for (var i = 0; i < 4; i++) {
          final x = 3 + i * 4.5;
          canvas.drawArc(Rect.fromLTWH(x, 6.75, 4.5, 4.5), 0, math.pi, false, stroke);
        }
        canvas.drawLine(const Offset(5, 11.5), const Offset(5, 20), stroke);
        canvas.drawLine(const Offset(19, 11.5), const Offset(19, 20), stroke);
        canvas.drawLine(const Offset(3.5, 20), const Offset(20.5, 20), stroke);
        canvas.drawRRect(RRect.fromLTRBR(9, 14, 15, 20, const Radius.circular(1)), stroke);
      case OIcon.windmill:
        const c = Offset(12, 10);
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + math.pi / 4;
          final tip = c + Offset(math.cos(a), math.sin(a)) * 7.5;
          final side = c + Offset(math.cos(a + 0.5), math.sin(a + 0.5)) * 6.2;
          canvas.drawPath(Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(side.dx, side.dy)
            ..close(), stroke);
        }
        canvas.drawLine(const Offset(12, 10), const Offset(12, 21), stroke);
        canvas.drawLine(const Offset(8.5, 21), const Offset(15.5, 21), stroke);
      case OIcon.pause:
        // A canopy arch with two trunks.
        canvas.drawPath(
            Path()
              ..moveTo(4, 12)
              ..cubicTo(4, 4, 20, 4, 20, 12)
              ..cubicTo(18, 13.5, 6, 13.5, 4, 12),
            stroke);
        canvas.drawLine(const Offset(9.5, 13), const Offset(9.5, 20), stroke);
        canvas.drawLine(const Offset(14.5, 13), const Offset(14.5, 20), stroke);
      case OIcon.back:
        canvas.drawPath(
            Path()
              ..moveTo(20, 12)
              ..lineTo(5, 12)
              ..moveTo(10.5, 6)
              ..lineTo(4.5, 12)
              ..lineTo(10.5, 18),
            stroke);
        canvas.drawPath(_leaf(scale: 0.32, dx: 14.5, dy: 4.6), stroke);
      case OIcon.lock:
        canvas.drawRRect(RRect.fromLTRBR(5.5, 10.5, 18.5, 20.5, const Radius.circular(2.5)), stroke);
        canvas.drawPath(
            Path()
              ..moveTo(8.5, 10.5)
              ..lineTo(8.5, 8)
              ..arcToPoint(const Offset(15.5, 8), radius: const Radius.circular(3.5))
              ..lineTo(15.5, 10.5),
            stroke);
        canvas.drawLine(const Offset(12, 14), const Offset(12, 17), stroke);
      case OIcon.restart:
        canvas.drawArc(Rect.fromCircle(center: const Offset(12, 12.5), radius: 7.5),
            -math.pi * 0.35, math.pi * 1.65, false, stroke);
        canvas.drawPath(
            Path()
              ..moveTo(17.5, 3.5)
              ..lineTo(18.2, 8.2)
              ..lineTo(13.6, 8.6),
            stroke);
      case OIcon.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), stroke);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), stroke);
      case OIcon.check:
        canvas.drawPath(
            Path()
              ..moveTo(5, 12.5)
              ..lineTo(10, 17.5)
              ..lineTo(19.5, 7),
            stroke);
      case OIcon.sound:
        canvas.drawPath(
            Path()
              ..moveTo(4, 9.5)
              ..lineTo(8, 9.5)
              ..lineTo(13, 5)
              ..lineTo(13, 19)
              ..lineTo(8, 14.5)
              ..lineTo(4, 14.5)
              ..close(),
            stroke);
        canvas.drawArc(Rect.fromCircle(center: const Offset(13, 12), radius: 4.5), -0.8, 1.6, false, stroke);
        canvas.drawArc(Rect.fromCircle(center: const Offset(13, 12), radius: 8), -0.75, 1.5, false, stroke);
      case OIcon.music:
        canvas.drawOval(Rect.fromCenter(center: const Offset(7.5, 17.5), width: 6, height: 4.5), stroke);
        canvas.drawOval(Rect.fromCenter(center: const Offset(17, 15.5), width: 6, height: 4.5), stroke);
        canvas.drawPath(
            Path()
              ..moveTo(10.5, 17.5)
              ..lineTo(10.5, 5.5)
              ..lineTo(20, 3.5)
              ..lineTo(20, 15.5),
            stroke);
      case OIcon.vibration:
        canvas.drawRRect(RRect.fromLTRBR(8, 4, 16, 20, const Radius.circular(2)), stroke);
        canvas.drawPath(Path()..moveTo(4.5, 8)..lineTo(3, 10)..lineTo(4.5, 12)..lineTo(3, 14)..lineTo(4.5, 16), stroke);
        canvas.drawPath(Path()..moveTo(19.5, 8)..lineTo(21, 10)..lineTo(19.5, 12)..lineTo(21, 14)..lineTo(19.5, 16), stroke);
      case OIcon.eye:
        canvas.drawPath(
            Path()
              ..moveTo(2.5, 12)
              ..cubicTo(6, 5.5, 18, 5.5, 21.5, 12)
              ..cubicTo(18, 18.5, 6, 18.5, 2.5, 12)
              ..close(),
            stroke);
        canvas.drawCircle(const Offset(12, 12), 3, stroke);
      case OIcon.wind:
        canvas.drawPath(
            Path()
              ..moveTo(3, 9)
              ..lineTo(15, 9)
              ..arcToPoint(const Offset(15, 4), radius: const Radius.circular(2.5), clockwise: false)
              ..moveTo(3, 13)
              ..lineTo(18.5, 13)
              ..arcToPoint(const Offset(18.5, 18.5), radius: const Radius.circular(2.75))
              ..moveTo(3, 17)
              ..lineTo(10, 17),
            stroke);
      case OIcon.motion:
        canvas.drawCircle(const Offset(15, 12), 5, stroke);
        canvas.drawLine(const Offset(3, 9), const Offset(7.5, 9), stroke);
        canvas.drawLine(const Offset(2, 12), const Offset(7, 12), stroke);
        canvas.drawLine(const Offset(3, 15), const Offset(7.5, 15), stroke);
      case OIcon.tick:
        canvas.drawCircle(const Offset(12, 12), 8.5, stroke);
        canvas.drawCircle(const Offset(12, 12), 4.5, stroke);
        canvas.drawCircle(const Offset(12, 12), 1, Paint()..color = color);
      case OIcon.privacy:
        canvas.drawPath(
            Path()
              ..moveTo(12, 3)
              ..lineTo(19.5, 6)
              ..cubicTo(19.5, 13, 16.5, 18, 12, 21)
              ..cubicTo(7.5, 18, 4.5, 13, 4.5, 6)
              ..close(),
            stroke);
        canvas.drawPath(Path()..moveTo(8.5, 12)..lineTo(11, 14.5)..lineTo(15.5, 9.5), stroke);
      case OIcon.play:
        shape(Path()
          ..moveTo(8, 5)
          ..lineTo(19, 12)
          ..lineTo(8, 19)
          ..close());
      case OIcon.longRow:
        for (var i = 0; i < 3; i++) {
          final x = 5.0 + i * 7;
          final y = 14.0 - i * 2.5;
          canvas.drawCircle(Offset(x, y - 3), 3, stroke);
          canvas.drawLine(Offset(x, y), Offset(x, y + 5), stroke);
        }
        canvas.drawLine(const Offset(2.5, 20.5), const Offset(21.5, 20.5), stroke);
    }
  }

  Path _leaf({double scale = 1, double dx = 0, double dy = 0}) {
    final p = Path()
      ..moveTo(5, 19)
      ..cubicTo(4, 10, 10, 4, 19.5, 4.5)
      ..cubicTo(20, 14, 14, 20, 5, 19)
      ..close();
    if (scale == 1 && dx == 0 && dy == 0) return p;
    final m = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    return p.transform(m.storage);
  }

  Path _star(double cx, double cy, double outer, double inner) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon ||
      old.color != color ||
      old.fill != fill ||
      old.strokeWidth != strokeWidth;
}
