import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/orchard_audio.dart';
import '../data/market.dart';
import '../data/row_definition.dart';
import '../data/rows.dart';
import '../game/harvest_session.dart';
import '../routing/app_routes.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import '../widgets/orchard_icons.dart';
import '../widgets/orchard_widgets.dart';
import '../widgets/overlays.dart';

/// The Orchard Path: one tall hillside, spring at the bottom, moon at the top.
class OrchardPathScreen extends StatefulWidget {
  const OrchardPathScreen({super.key});

  @override
  State<OrchardPathScreen> createState() => _OrchardPathScreenState();
}

class _OrchardPathScreenState extends State<OrchardPathScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker(
    (e) => _time.value = e.inMilliseconds / 1000,
  );
  final _time = ValueNotifier<double>(0);
  bool _scrolledOnce = false;

  static const _order = [
    Season.harvestMoon,
    Season.winterQuiet,
    Season.autumnGold,
    Season.summerSun,
    Season.springBloom,
  ];

  /// Where each keepsake sits: (season, x fraction, y fraction of its band).
  static const _keepsakeSpots = {
    'birdhouse': (Season.springBloom, 0.12, 0.30),
    'beehive': (Season.summerSun, 0.86, 0.62),
    'swing': (Season.summerSun, 0.10, 0.22),
    'scarecrow': (Season.autumnGold, 0.88, 0.40),
    'windmill': (Season.winterQuiet, 0.12, 0.48),
    'lantern': (Season.harvestMoon, 0.85, 0.55),
  };

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    OrchardAudio.instance.ambient(Ambient.day);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    _time.dispose();
    super.dispose();
  }

  double _bandHeight(Season s, double w) =>
      math.max(w * 1440 / 1080, seasonLengths[s]! * 86.0 + 170);

  /// Stake centres in path order (row 1 first), in content coordinates.
  List<Offset> _stakePoints(double w, Map<Season, double> bandTop) {
    final points = <Offset>[];
    for (final s in Season.values) {
      final n = seasonLengths[s]!;
      final h = _bandHeight(s, w);
      final top = bandTop[s]!;
      for (var i = 0; i < n; i++) {
        final u = n == 1 ? 0.5 : i / (n - 1);
        final y = top + h - 110 - u * (h - 210);
        final x = w * (0.5 + 0.27 * math.sin(i * 0.95 + s.index * 1.7));
        points.add(Offset(x, y));
      }
    }
    return points;
  }

  Future<void> _refresh() async => setState(() {});

  Future<void> _push(String route, {Object? args}) async {
    await Navigator.of(context).pushNamed(route, arguments: args);
    if (mounted) _refresh();
  }

  void _openRow(RowDefinition row) {
    final scope = OrchardScope.of(context);
    if (!scope.progression.isRowUnlocked(row.id)) {
      OrchardAudio.instance.play(Sfx.menu);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: OrchardColors.scrim,
      isScrollControlled: true,
      builder: (_) => _RowSheet(
        row: row,
        stars: scope.progression.starsForRow(row.id),
        dewdrops: scope.repository.dewdrops,
        onBegin: (carry) {
          Navigator.of(context).pop();
          _push(
            AppRoutes.harvest,
            args: HarvestArgs(row: row, dewdrops: carry),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = OrchardScope.of(context);
    final progression = scope.progression;
    final repo = scope.repository;
    final reduce = OrchardScope.reduceMotion(context);
    final next = progression.nextPlayableRowId();
    final owned = repo.ownedItems;

    return Scaffold(
      backgroundColor: OrchardColors.ink,
      body: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final bandTop = <Season, double>{};
          var y = 0.0;
          for (final s in _order) {
            bandTop[s] = y;
            y += _bandHeight(s, w);
          }
          // Room under spring so row 1 clears the bottom shelf.
          const shelfClearance = 120.0;
          final total = y + shelfClearance;
          final points = _stakePoints(w, bandTop);
          final clearedCount = orchardRows
              .where((r) => progression.starsForRow(r.id) > 0)
              .length;

          if (!_scrolledOnce) {
            _scrolledOnce = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_scroll.hasClients) return;
              final target = points[next - 1].dy - box.maxHeight * 0.55;
              _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
            });
          }

          return Stack(
            children: [
              SingleChildScrollView(
                controller: _scroll,
                child: SizedBox(
                  height: total,
                  width: w,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final s in _order)
                        Positioned(
                          top: bandTop[s],
                          left: 0,
                          width: w,
                          height: _bandHeight(s, w) + 2 + (s == Season.springBloom ? shelfClearance : 0),
                          child: Image.asset(
                            'assets/images/hub_${s.artKey}.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: Color.lerp(
                                OrchardColors.leaf,
                                OrchardColors.cream,
                                0.3 + s.index * 0.1,
                              )!,
                            ),
                          ),
                        ),
                      // Mist seams where seasons meet (world mist, not UI).
                      for (final s in _order.skip(1))
                        Positioned(
                          top: bandTop[s]! - 70,
                          left: 0,
                          right: 0,
                          height: 140,
                          child: const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x00F4EFE6),
                                    Color(0xB3F4EFE6),
                                    Color(0x00F4EFE6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _TrailPainter(
                              points: points,
                              cleared: clearedCount,
                            ),
                          ),
                        ),
                      ),
                      // Keepsakes bought at the Market Stall.
                      for (final k in keepsakes)
                        if (owned.contains(k.id) &&
                            _keepsakeSpots[k.id] != null)
                          Positioned(
                            left: w * _keepsakeSpots[k.id]!.$2 - 44,
                            top:
                                bandTop[_keepsakeSpots[k.id]!.$1]! +
                                _bandHeight(_keepsakeSpots[k.id]!.$1, w) *
                                    _keepsakeSpots[k.id]!.$3 -
                                44,
                            child: IgnorePointer(
                              child: Semantics(
                                label: k.name,
                                child: Image.asset(
                                  k.asset,
                                  width: 88,
                                  height: 88,
                                  errorBuilder: (_, _, _) => const SizedBox(),
                                ),
                              ),
                            ),
                          ),
                      for (var i = 0; i < orchardRows.length; i++)
                        _StakeNode(
                          key: ValueKey('stake-${i + 1}'),
                          row: orchardRows[i],
                          center: points[i],
                          stars: progression.starsForRow(i + 1),
                          unlocked: progression.isRowUnlocked(i + 1),
                          isNext:
                              i + 1 == next &&
                              progression.starsForRow(i + 1) == 0,
                          time: _time,
                          reduceMotion: reduce,
                          onTap: () => _openRow(orchardRows[i]),
                        ),
                      // Locked seasons wait under mist.
                      for (final s in Season.values)
                        if (!progression.isSeasonUnlocked(s))
                          Positioned(
                            top: bandTop[s],
                            left: 0,
                            right: 0,
                            height: _bandHeight(s, w),
                            child: _SeasonMist(season: s),
                          ),
                      // Season names sit in the mist where each season begins
                      // (ink on light mist); Spring's sits on the bottom meadow.
                      for (final s in Season.values)
                        Positioned(
                          top: bandTop[s]! +
                              _bandHeight(s, w) +
                              (s == Season.springBloom ? 8 : -16),
                          left: 20,
                          child: IgnorePointer(
                            child: Text(
                              s.label,
                              style: s == Season.springBloom
                                  ? OrchardText.heading(
                                      color: OrchardColors.cream,
                                      size: 22,
                                    ).copyWith(shadows: OrchardText.onArt)
                                  : OrchardText.heading(
                                      color: OrchardColors.ink,
                                      size: 22,
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // ── Top strip: what you carry ──
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10,
                left: 16,
                right: 12,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: OrchardColors.cream.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: OrchardColors.shadow,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Counter(
                            icon: OIcon.seed,
                            value: repo.seeds,
                            semanticLabel: 'seeds',
                          ),
                          const SizedBox(width: 16),
                          Counter(
                            icon: OIcon.dewdrop,
                            value: repo.dewdrops,
                            semanticLabel: 'dewdrops',
                            fill: const Color(0xFFE4F1F4),
                          ),
                          const SizedBox(width: 16),
                          Counter(
                            icon: OIcon.star,
                            value: progression.totalStars,
                            semanticLabel: 'stars',
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconStake(
                      icon: OIcon.windmill,
                      label: 'Wind and Hush',
                      onArt: true,
                      onTap: () async {
                        await showWindAndHush(context);
                        _refresh();
                      },
                    ),
                  ],
                ),
              ),
              // ── Bottom shelf ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Shelf(
                  nextRow: rowById(next)!,
                  dailyDone: progression.dailyDoneToday,
                  onDaily: () => _push(AppRoutes.daily),
                  onLongRow: () => _push(
                    AppRoutes.harvest,
                    args: const HarvestArgs(
                      row: longRowDefinition,
                      mode: PlayMode.longRow,
                    ),
                  ),
                  onMarket: () => _push(AppRoutes.market),
                  onJournal: () => _push(AppRoutes.journal),
                  onNext: () => _openRow(rowById(next)!),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The worn trail; cleared stretches are stitched in leaf green.
class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.points, required this.cleared});

  final List<Offset> points;
  final int cleared;

  Path _through(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      p.quadraticBezierTo(a.dx, (a.dy + mid.dy) / 2, mid.dx, mid.dy);
      p.quadraticBezierTo(b.dx, (mid.dy + b.dy) / 2, b.dx, b.dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final trail = _through(points);
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..color = OrchardColors.ink.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFEFE2C6).withValues(alpha: 0.82),
    );
    if (cleared > 0) {
      final done = _through(
        points.sublist(0, math.min(points.length, cleared + 1)),
      );
      for (final metric in done.computeMetrics()) {
        var d = 0.0;
        while (d < metric.length) {
          final seg = metric.extractPath(d, math.min(d + 9, metric.length));
          canvas.drawPath(
            seg,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round
              ..color = OrchardColors.leaf,
          );
          d += 16;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.cleared != cleared || old.points.length != points.length;
}

class _StakeNode extends StatelessWidget {
  const _StakeNode({
    super.key,
    required this.row,
    required this.center,
    required this.stars,
    required this.unlocked,
    required this.isNext,
    required this.time,
    required this.reduceMotion,
    required this.onTap,
  });

  final RowDefinition row;
  final Offset center;
  final int stars;
  final bool unlocked;
  final bool isNext;
  final ValueListenable<double> time;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cleared = stars > 0;
    final named = row.isSeasonFinale;
    final label = unlocked
        ? '${row.title}, ${row.season.label}${cleared
              ? ', $stars stars'
              : isNext
              ? ', next row'
              : ''}'
        : '${row.title}, locked';
    final disc = named ? 50.0 : 42.0;

    Widget disc0 = Container(
      width: disc,
      height: disc,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: !unlocked
            ? OrchardColors.cream.withValues(alpha: 0.55)
            : isNext
            ? OrchardColors.gold
            : cleared
            ? OrchardColors.leaf
            : OrchardColors.cream,
        shape: named ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: named ? BorderRadius.circular(14) : null,
        boxShadow: [
          BoxShadow(
            color: OrchardColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: unlocked
          ? Text(
              '${row.id}',
              style: OrchardText.label(
                size: named ? 18 : 16,
                color: cleared && !isNext
                    ? OrchardColors.cream
                    : OrchardColors.ink,
              ),
            )
          : const OrchardIcon(OIcon.lock, size: 18),
    );

    if (isNext && !reduceMotion) {
      final inner = disc0;
      disc0 = ValueListenableBuilder<double>(
        valueListenable: time,
        builder: (context, t, child) {
          final b = 0.5 + 0.5 * math.sin(t * 2 * math.pi / 2.4);
          final ring = disc + 14 + 10 * b;
          return SizedBox.square(
            dimension: disc,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                OverflowBox(
                  maxWidth: ring,
                  maxHeight: ring,
                  child: Container(
                    width: ring,
                    height: ring,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: OrchardColors.gold.withValues(
                          alpha: 0.3 + 0.45 * (1 - b),
                        ),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            ),
          );
        },
        child: inner,
      );
    }

    final stake = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cleared)
          StarRow(stars: stars, size: 13)
        else
          const SizedBox(height: 13),
        const SizedBox(height: 4),
        disc0,
        if (named && unlocked) ...[
          const SizedBox(height: 4),
          Text(
            row.title,
            style: OrchardText.small(
              color: OrchardColors.cream,
            ).copyWith(fontWeight: FontWeight.w600, shadows: OrchardText.onArt),
          ),
        ],
      ],
    );

    return Positioned(
      left: center.dx - 60,
      top: center.dy - 40,
      width: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (cleared)
            Padding(
              padding: const EdgeInsets.only(right: 2, top: 12),
              child: Image.asset(
                'assets/images/sapling.png',
                width: 30,
                height: 38,
                errorBuilder: (_, _, _) => const SizedBox(width: 30),
              ),
            ),
          Pressable(
            semanticLabel: label,
            onTap: unlocked ? onTap : null,
            child: stake,
          ),
        ],
      ),
    );
  }
}

class _SeasonMist extends StatelessWidget {
  const _SeasonMist({required this.season});

  final Season season;

  @override
  Widget build(BuildContext context) {
    final finale = rowsInSeason(Season.values[season.index - 1]).last;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: WorldColors.mist.withValues(alpha: 0.72)),
        Image.asset(
          'assets/images/mist.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OrchardIcon(
                OIcon.lock,
                size: 30,
                color: OrchardColors.dusk,
              ),
              const SizedBox(height: 10),
              Text(
                season.label,
                style: OrchardText.heading(color: OrchardColors.dusk),
              ),
              const SizedBox(height: 4),
              Text(
                'Clear ${finale.title} to open the way.',
                style: OrchardText.body(color: OrchardColors.dusk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.nextRow,
    required this.dailyDone,
    required this.onDaily,
    required this.onLongRow,
    required this.onMarket,
    required this.onJournal,
    required this.onNext,
  });

  final RowDefinition nextRow;
  final bool dailyDone;
  final VoidCallback onDaily;
  final VoidCallback onLongRow;
  final VoidCallback onMarket;
  final VoidCallback onJournal;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    Widget item(
      OIcon icon,
      String label,
      VoidCallback onTap, {
      bool dot = false,
    }) {
      return Expanded(
        child: Pressable(
          semanticLabel: dot ? '$label, new today' : label,
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    OrchardIcon(icon, size: 26),
                    if (dot)
                      Positioned(
                        right: -4,
                        top: -2,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: OrchardColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: OrchardText.small(
                    color: OrchardColors.ink,
                  ).copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PaperSheet(
      topOnly: true,
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          item(OIcon.calendar, 'Daily', onDaily, dot: !dailyDone),
          item(OIcon.longRow, 'Long Row', onLongRow),
          item(OIcon.market, 'Market', onMarket),
          item(OIcon.journal, 'Journal', onJournal),
          const SizedBox(width: 8),
          StakeButton(
            label: 'Row ${nextRow.id}',
            icon: OIcon.play,
            expand: false,
            compact: true,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _RowSheet extends StatefulWidget {
  const _RowSheet({
    required this.row,
    required this.stars,
    required this.dewdrops,
    required this.onBegin,
  });

  final RowDefinition row;
  final int stars;
  final int dewdrops;
  final ValueChanged<int> onBegin;

  @override
  State<_RowSheet> createState() => _RowSheetState();
}

class _RowSheetState extends State<_RowSheet> {
  int _carry = 0;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final rules = <String>[
      if (r.trees.length > 1) '${r.trees.length} trees, own tempos',
      if (r.trees.any((t) => t.hasRests)) 'rest beats',
      if (r.wind.enabled) 'wind gusts',
      if (r.trees.any((t) => t.hasFadingEcho)) 'fading echo',
    ];
    final tempo = r.trees.map((t) => t.bpm.round()).join(' · ');
    return PaperSheet(
      topOnly: true,
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(r.title, style: OrchardText.heading())),
              StarRow(stars: widget.stars, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r.isSeasonFinale
                ? '${r.season.label} finale'
                : '${r.season.label}, row ${r.rowInSeason}',
            style: OrchardText.small(),
          ),
          const SizedBox(height: 16),
          Text(
            rules.isEmpty
                ? r.season.ruleHint
                : 'This row: ${rules.join(', ')}.',
            style: OrchardText.body(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _Fact(label: 'Basket', value: '${r.quota}'),
              _Fact(label: 'Tempo', value: '$tempo bpm'),
              _Fact(label: 'Fruit on the trees', value: '${r.totalFruit}'),
            ],
          ),
          if (widget.dewdrops > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Carry a dewdrop? It saves one fruit from bruising.',
                    style: OrchardText.small(),
                  ),
                ),
                Pressable(
                  semanticLabel: _carry > 0
                      ? 'Dewdrop carried, tap to leave it'
                      : 'Carry a dewdrop',
                  onTap: () => setState(() => _carry = _carry > 0 ? 0 : 1),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: OrchardIcon(
                      OIcon.dewdrop,
                      size: 30,
                      fill: _carry > 0 ? const Color(0xFFBFE0E8) : null,
                      color: _carry > 0
                          ? OrchardColors.ink
                          : OrchardColors.inkFaint,
                      strokeWidth: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          StakeButton(
            label: widget.stars > 0 ? 'Harvest it again' : 'Begin the row',
            icon: OIcon.play,
            onTap: () => widget.onBegin(_carry),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: OrchardText.label()),
        Text(label, style: OrchardText.small()),
      ],
    );
  }
}
