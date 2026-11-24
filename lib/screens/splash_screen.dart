import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../routing/app_routes.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import '../widgets/orchard_widgets.dart';

/// "Dawn over the grove": the painting, the wordmark, one echo ring, then the path.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  Timer? _timer;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2900), _go);
  }

  void _go() {
    if (_gone || !mounted) return;
    _gone = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.path);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = OrchardScope.reduceMotion(context);
    return Scaffold(
      backgroundColor: OrchardColors.ink,
      body: Semantics(
        button: true,
        label: 'Ripe Rhythm. Tap to enter the orchard.',
        child: GestureDetector(
          onTap: _go,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final fadeIn = Curves.easeOutCubic.transform((t / 0.4).clamp(0, 1));
              final drift = reduce ? 0.0 : -12 * Curves.easeInOut.transform(t);
              final word = Curves.easeOutCubic.transform(((t - 0.25) / 0.45).clamp(0, 1));
              final ring = ((t - 0.35) / 0.6).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: fadeIn,
                    child: Transform.translate(
                      offset: Offset(0, drift),
                      child: Transform.scale(
                        scale: reduce ? 1 : 1.04 - 0.04 * t,
                        child: Image.asset(
                          'assets/images/splash.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(color: OrchardColors.leaf),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 56),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CustomPaint(painter: _EchoMark(ring, reduce)),
                          ),
                          const SizedBox(height: 18),
                          Opacity(
                            opacity: word,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - word)),
                              child: Text(
                                'Ripe Rhythm',
                                style: OrchardText.title(color: OrchardColors.cream)
                                    .copyWith(fontSize: 48, shadows: OrchardText.onArt),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: word,
                            child: Text(
                              'Answer the pulse.',
                              style: OrchardText.heading(color: OrchardColors.cream, size: 20)
                                  .copyWith(fontWeight: FontWeight.w400, shadows: OrchardText.onArt),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The game's mark: a gold band and an echo ring growing to meet it.
class _EchoMark extends CustomPainter {
  _EchoMark(this.t, this.reduce);

  final double t;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = OrchardColors.gold.withValues(alpha: 0.95),
    );
    final ringR = reduce ? r * 0.78 : r * (0.2 + 0.58 * Curves.easeOutCubic.transform(t));
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = OrchardColors.cream.withValues(alpha: math.max(0.3, 1 - t * 0.4)),
    );
  }

  @override
  bool shouldRepaint(_EchoMark old) => old.t != t;
}
