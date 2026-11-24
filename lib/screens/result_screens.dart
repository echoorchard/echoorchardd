import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/orchard_audio.dart';
import '../data/progression_service.dart';
import '../data/row_definition.dart';
import '../data/rows.dart';
import '../game/harvest_session.dart';
import '../routing/app_routes.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import '../widgets/orchard_icons.dart';
import '../widgets/orchard_widgets.dart';

/// Season painting behind a result, washed with golden hour or dusk.
class _ResultBackdrop extends StatelessWidget {
  const _ResultBackdrop({required this.season, required this.wash, required this.child});

  final Season season;
  final Color wash;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/bg_${season.artKey}.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0, 0.4),
          errorBuilder: (_, _, _) => const ColoredBox(color: OrchardColors.leaf),
        ),
        // Light falloff: the wash is strongest at the top, like evening sky.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [wash.withValues(alpha: 0.75), wash.withValues(alpha: 0.15)],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// "Basket Crowned": row cleared (also ends the Long Row).
class BasketCrownedScreen extends StatefulWidget {
  const BasketCrownedScreen({super.key, required this.args});

  final ResultArgs args;

  @override
  State<BasketCrownedScreen> createState() => _BasketCrownedScreenState();
}

class _BasketCrownedScreenState extends State<BasketCrownedScreen> with TickerProviderStateMixin {
  late final AnimationController _stars = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _seeds = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  final List<Timer> _timers = [];

  RowResult get _result => widget.args.result;
  HarvestReward get _reward => widget.args.reward;
  bool get _endless => _result.mode == PlayMode.longRow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    if (!mounted) return;
    final reduce = OrchardScope.reduceMotion(context);
    if (reduce) {
      _stars.value = 1;
      _seeds.value = 1;
    } else {
      _confetti.forward();
      _stars.forward();
      for (var i = 0; i < _result.stars; i++) {
        _timers.add(Timer(Duration(milliseconds: 180 + i * 260), () => OrchardAudio.instance.play(Sfx.star)));
      }
      _timers.add(Timer(const Duration(milliseconds: 1000), () {
        if (mounted) _seeds.forward();
      }));
    }
    if (_reward.achievements.isNotEmpty || _reward.seasonUnlocked != null) {
      _timers.add(Timer(const Duration(milliseconds: 1500), () => OrchardAudio.instance.play(Sfx.unlock)));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _stars.dispose();
    _seeds.dispose();
    _confetti.dispose();
    super.dispose();
  }

  RowDefinition? get _next {
    if (_result.mode != PlayMode.row) return null;
    return rowById(_result.row.id + 1);
  }

  void _toPath() => Navigator.of(context).popUntil((r) => r.settings.name == AppRoutes.path || r.isFirst);

  void _replay() => Navigator.of(context).pushReplacementNamed(
        AppRoutes.harvest,
        arguments: HarvestArgs(row: _result.row, mode: _result.mode),
      );

  @override
  Widget build(BuildContext context) {
    final next = _next;
    final title = _endless
        ? 'The Long Row rests'
        : _result.mode == PlayMode.daily
            ? 'Daily Row gathered'
            : 'Basket crowned';
    final subtitle = _endless
        ? (_reward.newBest ? 'A new best for the Long Row.' : 'Best so far: ${OrchardScope.of(context).repository.longRowBest}')
        : _result.row.isSeasonFinale
            ? '${_result.row.title}: the ${_result.row.season.label} finale is yours.'
            : '${_result.row.title} · ${_result.row.season.label}';

    return Scaffold(
      body: _ResultBackdrop(
        season: _result.row.season,
        wash: const Color(0xFFFFE4A0),
        child: Stack(
          children: [
            if (!OrchardScope.reduceMotion(context))
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confetti,
                    builder: (context, _) => CustomPaint(painter: _PetalFall(_confetti.value, _result.row.season)),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  if (_endless)
                    Text('${_result.score}', style: OrchardText.title(color: OrchardColors.ink).copyWith(fontSize: 72))
                  else
                    AnimatedBuilder(
                      animation: _stars,
                      builder: (context, _) => _PoppingStars(stars: _result.stars, t: _stars.value),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PaperSheet(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(header: true, child: Text(title, style: OrchardText.title().copyWith(fontSize: 34))),
                          const SizedBox(height: 6),
                          Text(subtitle, style: OrchardText.body(color: OrchardColors.inkSoft)),
                          const SizedBox(height: 20),
                          _Ledger(result: _result, reward: _reward, seedAnim: _seeds),
                          if (_reward.seasonUnlocked != null) ...[
                            const SizedBox(height: 14),
                            _Note(
                              icon: OIcon.leaf,
                              text: '${_reward.seasonUnlocked!.label} opens: ${_reward.seasonUnlocked!.rule.toLowerCase()}.',
                            ),
                          ],
                          for (final a in _reward.achievements) ...[
                            const SizedBox(height: 10),
                            _Note(icon: OIcon.star, text: 'Seal earned: ${a.title}'),
                          ],
                          const SizedBox(height: 24),
                          if (next != null)
                            StakeButton(
                              label: 'Next: ${next.title}',
                              icon: OIcon.play,
                              onTap: () => Navigator.of(context).pushReplacementNamed(
                                AppRoutes.harvest,
                                arguments: HarvestArgs(row: next),
                              ),
                            )
                          else
                            StakeButton(label: 'Back to the path', icon: OIcon.back, onTap: _toPath),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              QuietButton(
                                label: _endless ? 'Walk it again' : 'Harvest again',
                                icon: OIcon.restart,
                                onTap: _replay,
                              ),
                              if (next != null) QuietButton(label: 'The path', icon: OIcon.back, onTap: _toPath),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.result, required this.reward, required this.seedAnim});

  final RowResult result;
  final HarvestReward reward;
  final Animation<double> seedAnim;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(label, style: OrchardText.small())),
              value,
            ],
          ),
        );
    final pct = (result.perfectPct * 100).round();
    return Column(
      children: [
        line('Perfect harvests', Text('${result.perfectTaps}  ·  $pct%', style: OrchardText.label(size: 15))),
        line('Best perfect run', Text('${result.bestStreak}', style: OrchardText.label(size: 15))),
        if (result.dewdropsUsed > 0)
          line('Dewdrops spent', Text('${result.dewdropsUsed}', style: OrchardText.label(size: 15))),
        line(
          'Seeds earned',
          AnimatedBuilder(
            animation: seedAnim,
            builder: (context, _) {
              final shown = (reward.seeds * Curves.easeOutCubic.transform(seedAnim.value)).round();
              return Counter(icon: OIcon.seed, value: shown, semanticLabel: 'seeds earned');
            },
          ),
        ),
        if (reward.dewdropsEarned > 0)
          line(
            'Dewdrops earned',
            Counter(
              icon: OIcon.dewdrop,
              value: reward.dewdropsEarned,
              semanticLabel: 'dewdrops earned',
              fill: const Color(0xFFE4F1F4),
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final OIcon icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrchardIcon(icon, size: 20, fill: OrchardColors.gold, strokeWidth: 1.6),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: OrchardText.body())),
      ],
    );
  }
}

/// Three big stars: earned ones pop in one by one (easeOutBack).
class _PoppingStars extends StatelessWidget {
  const _PoppingStars({required this.stars, required this.t});

  final int stars;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars of 3 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == 1 ? 18 : 0, left: 6, right: 6),
              child: Builder(builder: (context) {
                final start = 0.12 + i * 0.24;
                final local = ((t - start) / 0.3).clamp(0.0, 1.0);
                final earned = i < stars;
                final s = earned ? Curves.easeOutBack.transform(local) : 1.0;
                return Transform.scale(
                  scale: earned ? s : 1,
                  child: OrchardIcon(
                    OIcon.star,
                    size: i == 1 ? 76 : 60,
                    fill: earned && local > 0 ? OrchardColors.gold : OrchardColors.cream.withValues(alpha: 0.5),
                    color: earned ? OrchardColors.ink : OrchardColors.inkFaint,
                    strokeWidth: 1.4,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

/// A brief shower of the season's petals (or leaves, snow, fireflies).
class _PetalFall extends CustomPainter {
  _PetalFall(this.t, this.season);

  final double t;
  final Season season;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final rng = math.Random(9);
    final color = switch (season) {
      Season.springBloom => WorldColors.blossom,
      Season.summerSun => OrchardColors.gold,
      Season.autumnGold => WorldColors.autumnLeaf,
      Season.winterQuiet => WorldColors.snow,
      Season.harvestMoon => WorldColors.firefly,
    };
    for (var i = 0; i < 46; i++) {
      final x0 = rng.nextDouble() * size.width;
      final delay = rng.nextDouble() * 0.35;
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * (size.height * (0.55 + rng.nextDouble() * 0.4));
      final x = x0 + math.sin(local * 6 + i) * 18;
      final fade = local > 0.75 ? (1 - local) / 0.25 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * 5 + i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 10, height: 6),
        Paint()..color = color.withValues(alpha: 0.9 * fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalFall old) => old.t != t;
}

/// "Season Rests": the row ended before the basket filled.
class SeasonRestsScreen extends StatefulWidget {
  const SeasonRestsScreen({super.key, required this.args});

  final ResultArgs args;

  @override
  State<SeasonRestsScreen> createState() => _SeasonRestsScreenState();
}

class _SeasonRestsScreenState extends State<SeasonRestsScreen> {
  int _carry = 0;

  RowResult get _result => widget.args.result;

  @override
  Widget build(BuildContext context) {
    final repo = OrchardScope.of(context).repository;
    final dewdrops = repo.dewdrops;
    final bare = _result.end == RowEnd.bareBranches;
    final line = bare
        ? 'The branches went bare before the basket filled. Perfect harvests give two fruit each.'
        : _result.row.trees.any((t) => t.hasRests)
            ? 'Three bruises. Watch for the withered band, and let rest beats pass.'
            : 'Three bruises. Let the ring meet the band before you tap.';
    return Scaffold(
      body: _ResultBackdrop(
        season: _result.row.season,
        wash: OrchardColors.dusk,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PaperSheet(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text('The season rests', style: OrchardText.title().copyWith(fontSize: 34))),
                      const SizedBox(height: 6),
                      Text('${_result.row.title}: ${_result.score} of ${_result.row.quota} gathered.',
                          style: OrchardText.label(size: 16, color: OrchardColors.inkSoft)),
                      const SizedBox(height: 14),
                      Text(line, style: OrchardText.body()),
                      if (dewdrops > 0) ...[
                        const SizedBox(height: 18),
                        _DewdropPicker(
                          available: dewdrops,
                          value: _carry,
                          onChanged: (v) => setState(() => _carry = v),
                        ),
                      ],
                      const SizedBox(height: 24),
                      StakeButton(
                        label: 'Try the row again',
                        icon: OIcon.restart,
                        onTap: () => Navigator.of(context).pushReplacementNamed(
                          AppRoutes.harvest,
                          arguments: HarvestArgs(row: _result.row, mode: _result.mode, dewdrops: _carry),
                        ),
                      ),
                      const SizedBox(height: 4),
                      QuietButton(
                        label: 'Back to the path',
                        icon: OIcon.back,
                        onTap: () => Navigator.of(context)
                            .popUntil((r) => r.settings.name == AppRoutes.path || r.isFirst),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choose 0–3 dewdrops to carry (each absorbs one bruise).
class _DewdropPicker extends StatelessWidget {
  const _DewdropPicker({required this.available, required this.value, required this.onChanged});

  final int available;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final max = math.min(3, available);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Carry dewdrops? Each one saves a fruit from bruising. You have $available.',
            style: OrchardText.small()),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 1; i <= max; i++)
              Pressable(
                semanticLabel: value >= i ? 'Carry ${i - 1} dewdrops' : 'Carry $i dewdrops',
                onTap: () => onChanged(value >= i ? i - 1 : i),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: OrchardIcon(
                    OIcon.dewdrop,
                    size: 30,
                    fill: value >= i ? const Color(0xFFBFE0E8) : null,
                    color: value >= i ? OrchardColors.ink : OrchardColors.inkFaint,
                    strokeWidth: 1.6,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
