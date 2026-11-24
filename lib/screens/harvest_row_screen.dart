import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/orchard_audio.dart';
import '../data/row_definition.dart';
import '../data/rows.dart';
import '../game/harvest_game.dart';
import '../game/harvest_session.dart';
import '../game/rhythm/tap_quality.dart';
import '../routing/app_routes.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import '../widgets/orchard_icons.dart';
import '../widgets/orchard_widgets.dart';
import '../widgets/overlays.dart';

/// Harvest Row: the season painting, the trees, and a quiet HUD.
class HarvestRowScreen extends StatefulWidget {
  const HarvestRowScreen({super.key, required this.args});

  final HarvestArgs args;

  @override
  State<HarvestRowScreen> createState() => _HarvestRowScreenState();
}

class _HarvestRowScreenState extends State<HarvestRowScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late HarvestSession _session;
  HarvestGame? _game;
  late final Ticker _ticker = createTicker(_onTick);

  bool _showPause = false;
  bool _showLesson = false;
  bool _leaving = false;
  String? _callout;
  TapQuality? _calloutQuality;
  int _calloutKey = 0;
  double _countIn = 0;
  int _lastLives = 3;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  RowDefinition get _row => widget.args.row;

  /// A lesson card opens tutorials and the first time you enter a season.
  bool get _wantsLesson => _row.isTutorial && _row.teach != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showLesson = _wantsLesson;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game == null) _start();
  }

  void _start() {
    final scope = OrchardScope.of(context);
    final basket = 'basket_${_basketKey(scope.repository.equippedBasket)}.png';
    _session = HarvestSession(
      row: _row,
      mode: widget.args.mode,
      dewdrops: widget.args.dewdrops,
    );
    _lastLives = _session.lives;
    _game = HarvestGame(
      row: _row,
      session: _session,
      repository: scope.repository,
      basketAsset: basket,
      reduceMotion: OrchardScope.reduceMotion(context),
      startPaused: _showLesson,
      onSessionUpdated: _onSessionUpdated,
      onRowComplete: _onRowComplete,
    );
    OrchardAudio.instance.ambient(_row.season.isNight ? Ambient.night : Ambient.day);
    if (!_ticker.isActive) _ticker.start();
  }

  static String _basketKey(String id) => id == 'moonweave' ? 'moon' : id;

  void _onTick(Duration _) {
    final left = _game?.countInBeatsLeft ?? 0;
    if ((left - _countIn).abs() > 0.05 || (left == 0 && _countIn != 0)) {
      setState(() => _countIn = left);
    }
  }

  void _onSessionUpdated(HarvestSession session, HarvestTapResult? tap) {
    if (!mounted) return;
    if (session.lives < _lastLives && !OrchardScope.reduceMotion(context)) {
      _shake.forward(from: 0);
    }
    _lastLives = session.lives;
    setState(() {
      if (tap != null && tap.message.isNotEmpty) {
        _callout = tap.message;
        _calloutQuality = tap.shielded ? null : tap.quality;
        _calloutKey++;
      }
    });
  }

  Future<void> _onRowComplete(RowResult result) async {
    if (!mounted || _leaving) return;
    _leaving = true;
    final progression = OrchardScope.of(context).progression;
    final reward = await progression.recordResult(result);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      result.won || result.mode == PlayMode.longRow ? AppRoutes.crowned : AppRoutes.rests,
      arguments: ResultArgs(result: result, reward: reward),
    );
  }

  void _pause() {
    if (_session.isComplete || _showLesson) return;
    _game?.pauseRhythm();
    OrchardAudio.instance.pauseAmbient();
    setState(() => _showPause = true);
  }

  void _resume() {
    _game?.resumeRhythm();
    OrchardAudio.instance.resumeAmbient();
    setState(() => _showPause = false);
  }

  void _restart() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.harvest, arguments: widget.args);
  }

  void _leave() {
    _leaving = true;
    Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_showPause && !_showLesson) {
      _pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: _showPause || _session.isComplete,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        backgroundColor: OrchardColors.ink,
        body: Shake(
          animation: _shake,
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  label: 'Harvest row. Tap a tree when its ring meets the golden band.',
                  child: GameWidget(game: game),
                ),
              ),
              // ── HUD: survival at the top ──
              Positioned(
                top: pad.top + 10,
                left: 16,
                right: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: _HudTag(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LifeLeaves(lives: _session.lives, shields: _session.dewdrops),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _row.title,
                                overflow: TextOverflow.ellipsis,
                                style: OrchardText.label(size: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconStake(icon: OIcon.pause, label: 'Pause', onTap: _pause, onArt: true),
                  ],
                ),
              ),
              // ── Harvest call-out ──
              if (_callout != null)
                Positioned(
                  top: pad.top + 76,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: _Callout(key: ValueKey(_calloutKey), text: _callout!, quality: _calloutQuality),
                  ),
                ),
              // ── Count-in ──
              if (_countIn > 0 && !_showLesson && !_showPause)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: const Alignment(0, -0.62),
                      child: Text(
                        _countIn > 1 ? 'Listen…' : 'Ready',
                        style: OrchardText.heading(color: OrchardColors.cream, size: 30)
                            .copyWith(shadows: OrchardText.onArt),
                      ),
                    ),
                  ),
                ),
              // ── Goal at the bottom: basket count ──
              Positioned(
                left: 0,
                right: 0,
                bottom: pad.bottom + 4,
                child: IgnorePointer(child: Center(child: _BasketCount(session: _session, game: game))),
              ),
              if (_showLesson)
                Positioned.fill(
                  child: _LessonCard(
                    row: _row,
                    onReady: () {
                      setState(() => _showLesson = false);
                      game.resumeRhythm();
                    },
                    onBack: _leave,
                  ),
                ),
              if (_showPause)
                Positioned.fill(
                  child: BeneathCanopyOverlay(
                    rowTitle: _row.title,
                    onResume: _resume,
                    onRestart: _restart,
                    onLeave: _leave,
                    onHush: () => showWindAndHush(context, inRow: true),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudTag extends StatelessWidget {
  const _HudTag({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: OrchardColors.cream.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: OrchardColors.shadow, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }
}

class _BasketCount extends StatelessWidget {
  const _BasketCount({required this.session, required this.game});

  final HarvestSession session;
  final HarvestGame game;

  @override
  Widget build(BuildContext context) {
    final endless = session.isEndless;
    final text = endless ? '${session.basketCount}' : '${session.basketCount} / ${session.quota}';
    return Semantics(
      label: endless
          ? 'Score ${session.basketCount}'
          : '${session.basketCount} of ${session.quota} fruit in the basket',
      excludeSemantics: true,
      child: _HudTag(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OrchardIcon(OIcon.basket, size: 20, fill: Color(0xFFE9D3A8), strokeWidth: 1.6),
            const SizedBox(width: 8),
            Text(text, style: OrchardText.number(size: 20)),
            if (endless) ...[
              const SizedBox(width: 12),
              Text('${game.currentLeadBpm.round()} bpm', style: OrchardText.small()),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Perfect" / "Good harvest" / "Bruised": the word carries the meaning,
/// colour only reinforces it.
class _Callout extends StatelessWidget {
  const _Callout({super.key, required this.text, required this.quality});

  final String text;
  final TapQuality? quality;

  @override
  Widget build(BuildContext context) {
    final reduce = OrchardScope.reduceMotion(context);
    final color = switch (quality) {
      TapQuality.perfect => OrchardColors.gold,
      TapQuality.good => OrchardColors.cream,
      TapQuality.miss => const Color(0xFFE7DDF0),
      null => const Color(0xFFE4F1F4),
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, t, child) {
        final opacity = t < 0.15 ? t / 0.15 : (t > 0.7 ? (1 - t) / 0.3 : 1.0);
        final rise = reduce ? 0.0 : -14 * t;
        final pop = reduce ? 1.0 : (t < 0.15 ? 0.85 + t : 1.0);
        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, rise),
            child: Transform.scale(scale: pop, child: child),
          ),
        );
      },
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: OrchardText.heading(color: color, size: quality == TapQuality.perfect ? 28 : 22)
            .copyWith(shadows: OrchardText.onArt),
      ),
    );
  }
}

/// Opens a tutorial row: the season's rule, in one line, with a tiny diagram.
class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.row, required this.onReady, required this.onBack});

  final RowDefinition row;
  final VoidCallback onReady;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final inSeason = rowsInSeason(row.season);
    final index = inSeason.indexOf(row) + 1;
    return ColoredBox(
      color: OrchardColors.scrim,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PaperSheet(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title, style: OrchardText.heading()),
                  const SizedBox(height: 12),
                  Text(row.teach ?? row.season.ruleHint, style: OrchardText.body()),
                  const SizedBox(height: 12),
                  Text(
                    'New in ${row.season.label}: ${row.season.rule.toLowerCase()}. '
                    'Row $index of ${inSeason.length}.',
                    style: OrchardText.small(),
                  ),
                  const SizedBox(height: 24),
                  StakeButton(label: 'Begin the row', icon: OIcon.play, onTap: onReady),
                  const SizedBox(height: 4),
                  QuietButton(label: 'Back to the path', icon: OIcon.back, onTap: onBack),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
