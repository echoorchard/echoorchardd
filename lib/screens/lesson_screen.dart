import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/orchard_audio.dart';
import '../game/rhythm/beat_judge.dart';
import '../game/rhythm/tap_quality.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import '../widgets/orchard_icons.dart';
import '../widgets/orchard_widgets.dart';

/// "How to harvest": five short pages, each with a live practice ring that
/// uses the real judge, so what you learn here is exactly how rows score.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _Page {
  const _Page(
    this.title,
    this.body, {
    this.rest = '',
    this.wind = false,
    this.echo = false,
    this.demo = true,
  });

  final String title;
  final String body;
  final String rest;
  final bool wind;
  final bool echo;
  final bool demo;
}

const _pages = [
  _Page(
    'Tap on the band',
    'Each tree has a pulse. A ring grows from the canopy; when it meets the golden band, tap the tree. '
        'Right on the band is a perfect: two fruit. Close is a good harvest: one fruit.',
  ),
  _Page(
    'Let rest beats pass',
    'From Autumn, some beats wither: the band turns dashed and dusky, with a little rest mark above it. '
        'Tapping a rest beat bruises fruit. Just let it go by.',
    rest: 'xx-',
  ),
  _Page(
    'Follow the wind',
    'In Winter a gust can push the ring forward or hold it back for a few beats. '
        'Trust the ring, not the count in your head.',
    wind: true,
  ),
  _Page(
    'Keep the fading echo',
    'Under the Harvest Moon the ring fades to a faint trace for a few beats. The band stays. '
        'Keep tapping in the same time; the pulse tick keeps going if your sound is on.',
    echo: true,
  ),
  _Page(
    'Leaves, dewdrops and seeds',
    'A bruise costs a leaf. Lose all three and the season rests: try again for free. '
        'Ten clean harvests in a row regrow a leaf. Dewdrops from the Daily Row save a fruit from one bruise. '
        'Seeds come only from playing, and buy baskets and keepsakes at the Market Stall.',
    demo: false,
  ),
];

class _LessonScreenState extends State<LessonScreen> {
  final _pager = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) OrchardScope.of(context).repository.setLessonSeen();
    });
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: OrchardColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'How to harvest'),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _LessonPage(page: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Semantics(
                    label: 'Page ${_page + 1} of ${_pages.length}',
                    child: Row(
                      children: [
                        for (var i = 0; i < _pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _page ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? OrchardColors.leaf
                                  : OrchardColors.inkFaint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Spacer(),
                  Flexible(
                    flex: 4,
                    child: StakeButton(
                      label: last ? 'To the orchard' : 'Next',
                      expand: false,
                      onTap: () {
                        if (last) {
                          Navigator.of(context).maybePop();
                        } else {
                          _pager.nextPage(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonPage extends StatelessWidget {
  const _LessonPage({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (page.demo) _PracticeRing(page: page) else const _LeavesDiagram(),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(page.title, style: OrchardText.heading()),
          ),
          const SizedBox(height: 10),
          Text(page.body, style: OrchardText.body()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// A live, tappable practice tree drawn in code.
class _PracticeRing extends StatefulWidget {
  const _PracticeRing({required this.page});

  final _Page page;

  @override
  State<_PracticeRing> createState() => _PracticeRingState();
}

class _PracticeRingState extends State<_PracticeRing>
    with SingleTickerProviderStateMixin {
  static const bpm = 56.0;
  static const good = 520.0;
  static const perfect = 240.0;
  late final Ticker _ticker;
  double _beats = -1;
  Duration _last = Duration.zero;
  String _feedback = 'Tap the circle as the ring meets the band';
  TapQuality? _quality;
  int _harvested = 0;

  double get _period => 60000 / bpm;

  double get _wind {
    if (!widget.page.wind) return 0;
    // A gust every 6 beats, lasting 2 beats, alternating direction.
    final cycle = (_beats / 6).floor();
    final inGust = _beats - cycle * 6 < 2 && _beats > 2;
    return inGust ? (cycle.isEven ? 110 : -110) : 0;
  }

  bool _isRest(int beat) {
    final p = widget.page.rest;
    if (p.isEmpty || beat < 0) return false;
    return p[beat % p.length] == '-';
  }

  bool _echoVisible(int beat) => !widget.page.echo || beat < 0 || beat % 5 < 3;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1000;
      _last = elapsed;
      setState(() => _beats += dt / _period);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tap() {
    final j = judgeTap(
      beatPosition: _beats,
      beatPeriodMs: _period,
      goodWindowMs: good,
      perfectWindowMs: perfect,
      windOffsetMs: _wind,
      isRestBeat: _isRest,
    );
    if (j.isCountIn) return;
    setState(() {
      _quality = j.quality;
      if (j.isRest) {
        _feedback = 'That was a rest beat. Let the dashed band pass.';
        OrchardAudio.instance.play(Sfx.bruise);
      } else if (j.quality == TapQuality.perfect) {
        _harvested += 2;
        _feedback = 'Perfect: two fruit';
        OrchardAudio.instance.play(Sfx.perfect);
      } else if (j.quality == TapQuality.good) {
        _harvested += 1;
        _feedback = j.errorMs < 0
            ? 'Good, a touch early'
            : 'Good, a touch late';
        OrchardAudio.instance.play(Sfx.harvest);
      } else {
        _feedback = j.errorMs < 0
            ? 'Too early: wait for the band'
            : 'Too late: the ring had passed';
        OrchardAudio.instance.play(Sfx.bruise);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final eff = _beats + _wind / _period;
    final beat = (eff - ripeBandFraction).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: 'Practice tree. $_feedback',
          child: GestureDetector(
            onTapDown: (_) => _tap(),
            child: AspectRatio(
              aspectRatio: 1.25,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.page.echo
                      ? const Color(0xFF2E3550)
                      : const Color(0xFFDCE9D6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CustomPaint(
                  painter: _PracticePainter(
                    fraction: eff - eff.floor(),
                    rest: _isRest(beat) && beat >= 0,
                    echo: _echoVisible(_beats.floor()) ? 1 : 0.12,
                    flash: _quality,
                    windDir: _wind == 0 ? 0 : (_wind > 0 ? 1 : -1),
                    night: widget.page.echo,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _feedback,
                  key: ValueKey(_feedback),
                  style: OrchardText.label(size: 16),
                ),
              ),
            ),
            Counter(
              icon: OIcon.basket,
              value: _harvested,
              semanticLabel: 'fruit practised',
              fill: const Color(0xFFE9D3A8),
            ),
          ],
        ),
      ],
    );
  }
}

class _PracticePainter extends CustomPainter {
  _PracticePainter({
    required this.fraction,
    required this.rest,
    required this.echo,
    required this.flash,
    required this.windDir,
    required this.night,
  });

  final double fraction;
  final bool rest;
  final double echo;
  final TapQuality? flash;
  final int windDir;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.46);
    final cr = size.height * 0.26;
    // Ground + trunk + canopy, drawn simply.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.8, size.width, size.height * 0.2),
      Paint()
        ..color = night ? const Color(0xFF22303F) : const Color(0xFFA9C99A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, size.height * 0.7),
          width: 18,
          height: size.height * 0.24,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF6B4E3D),
    );
    canvas.drawCircle(
      c,
      cr,
      Paint()..color = night ? const Color(0xFF2F5A55) : OrchardColors.leaf,
    );
    final r0 = cr * 0.32;
    final r1 = cr * 1.22;
    final band = r0 + (r1 - r0) * ripeBandFraction;
    if (rest) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = OrchardColors.dusk;
      for (var i = 0; i < 18; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: band),
          i * 2 * math.pi / 18,
          math.pi / 18,
          false,
          p,
        );
      }
      canvas.drawLine(
        Offset(c.dx - 8, c.dy - cr * 1.42),
        Offset(c.dx + 8, c.dy - cr * 1.42),
        Paint()
          ..color = OrchardColors.cream
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(
        c,
        band,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..color = OrchardColors.gold.withValues(alpha: 0.2),
      );
      canvas.drawCircle(
        c,
        band,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = OrchardColors.gold,
      );
    }
    final ring = r0 + (r1 - r0) * fraction;
    canvas.drawCircle(
      c,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = (night ? const Color(0xFFFFE6B0) : OrchardColors.cream)
            .withValues(alpha: echo),
    );
    if (windDir != 0) {
      final y = c.dy - cr * 1.6;
      for (var i = 0; i < 3; i++) {
        final x0 = size.width * (windDir > 0 ? 0.12 : 0.88);
        canvas.drawLine(
          Offset(x0, y + i * 12),
          Offset(x0 + windDir * size.width * (0.18 - i * 0.04), y + i * 12),
          Paint()
            ..color = OrchardColors.cream
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PracticePainter old) => true;
}

/// Static diagram: three leaves, one lost, a dewdrop shielding.
class _LeavesDiagram extends StatelessWidget {
  const _LeavesDiagram();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: const Wrap(
        spacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OrchardIcon(OIcon.leaf, size: 44, fill: OrchardColors.leaf),
          OrchardIcon(OIcon.leaf, size: 44, fill: OrchardColors.leaf),
          OrchardIcon(OIcon.leaf, size: 44, color: OrchardColors.dusk),
          OrchardIcon(OIcon.dewdrop, size: 40, fill: Color(0xFFBFE0E8)),
          OrchardIcon(OIcon.seed, size: 40, fill: OrchardColors.gold),
        ],
      ),
    );
  }
}
