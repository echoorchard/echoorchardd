import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/achievements.dart';
import '../data/row_definition.dart';
import '../data/rows.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import '../widgets/orchard_icons.dart';
import '../widgets/orchard_widgets.dart';

/// Orchard Journal: a lifetime ledger and the twenty seals.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

enum _Section { ledger, seals }

class _JournalScreenState extends State<JournalScreen> {
  _Section _section = _Section.ledger;

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 360 ? 20.0 : 24.0;
    return Scaffold(
      backgroundColor: OrchardColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Orchard Journal'),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
              child: _SectionToggle(
                value: _section,
                onChanged: (s) => setState(() => _section = s),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 32),
                child: _section == _Section.ledger ? const _Ledger() : const _Seals(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet two-option switch: the chosen word is ink with a leaf underline,
/// the other is soft ink. No fill, no pill.
class _SectionToggle extends StatelessWidget {
  const _SectionToggle({required this.value, required this.onChanged});

  final _Section value;
  final ValueChanged<_Section> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(_Section s, String label) {
      final selected = value == s;
      return Pressable(
        semanticLabel: selected ? '$label, shown' : 'Show $label',
        onTap: selected ? () {} : () => onChanged(s),
        sound: !selected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: OrchardText.label(
                  color: selected ? OrchardColors.ink : OrchardColors.inkSoft,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2,
                width: 28,
                decoration: BoxDecoration(
                  color: selected ? OrchardColors.leaf : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 24,
      children: [
        option(_Section.ledger, 'Ledger'),
        option(_Section.seals, 'Seals'),
      ],
    );
  }
}

String _fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class _Ledger extends StatelessWidget {
  const _Ledger();

  @override
  Widget build(BuildContext context) {
    final scope = OrchardScope.of(context);
    final repo = scope.repository;
    final prog = scope.progression;
    final stats = repo.stats;
    int stat(String k) => stats[k] ?? 0;
    final rowCount = orchardRows.length;
    final streak = prog.dailyStreak;

    final lines = <(String, String)>[
      ('Fruit harvested', _fmt(stat('fruit'))),
      ('Perfect harvests', _fmt(stat('perfects'))),
      ('Good harvests', _fmt(stat('goods'))),
      ('Bruised fruit', _fmt(stat('bruises'))),
      ('Rows walked', _fmt(stat('rows_played'))),
      ('Baskets filled', _fmt(stat('rows_won'))),
      ('Longest perfect streak', _fmt(stat('best_streak'))),
      ('Rows cleared', '${prog.rowsCleared} / $rowCount'),
      ('Stars gathered', '${prog.totalStars} / ${rowCount * 3}'),
      ('Long Row best', _fmt(repo.longRowBest)),
      ('Daily streak', streak == 1 ? '1 day' : '$streak days'),
      ('Days in the orchard', _fmt(repo.playDates.length)),
      ('Seeds in hand', _fmt(repo.seeds)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('Ledger', style: OrchardText.heading(size: 22))),
        const SizedBox(height: 12),
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const _Hairline(),
          _LedgerLine(label: lines[i].$1, value: lines[i].$2),
        ],
        const SizedBox(height: 40),
        Semantics(header: true, child: Text('By season', style: OrchardText.heading(size: 22))),
        const SizedBox(height: 12),
        for (final (i, season) in Season.values.indexed) ...[
          if (i > 0) const _Hairline(),
          _SeasonLine(season: season),
        ],
      ],
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: OrchardColors.hairline);
}

class _LedgerLine extends StatelessWidget {
  const _LedgerLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(label, style: OrchardText.small())),
            const SizedBox(width: 16),
            Text(value, style: OrchardText.label(), textAlign: TextAlign.right),
          ],
        ),
      ),
    );
  }
}

class _SeasonLine extends StatelessWidget {
  const _SeasonLine({required this.season});

  final Season season;

  @override
  Widget build(BuildContext context) {
    final prog = OrchardScope.of(context).progression;
    final rows = rowsInSeason(season);
    final earned = rows.fold<int>(0, (sum, r) => sum + prog.starsForRow(r.id));
    final possible = rows.length * 3;
    return Semantics(
      label: '${season.label}: $earned of $possible stars',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(season.label, style: OrchardText.small())),
            const SizedBox(width: 16),
            OrchardIcon(
              OIcon.star,
              size: 16,
              fill: earned > 0 ? OrchardColors.gold : null,
              color: earned > 0 ? OrchardColors.ink : OrchardColors.inkFaint,
              strokeWidth: 1.6,
            ),
            const SizedBox(width: 6),
            Text('$earned / $possible', style: OrchardText.label()),
          ],
        ),
      ),
    );
  }
}

class _Seals extends StatelessWidget {
  const _Seals();

  @override
  Widget build(BuildContext context) {
    final have = OrchardScope.of(context).repository.achievements;
    final earnedCount = achievements.where((a) => have.contains(a.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          label: 'Seals, $earnedCount of ${achievements.length} earned',
          excludeSemantics: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            children: [
              Text('Seals', style: OrchardText.heading(size: 22)),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '$earnedCount of ${achievements.length}',
                  style: OrchardText.label(color: OrchardColors.inkSoft, size: 15),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final (i, a) in achievements.indexed) ...[
          if (i > 0) const _Hairline(),
          _SealLine(achievement: a, earned: have.contains(a.id)),
        ],
      ],
    );
  }
}

class _SealLine extends StatelessWidget {
  const _SealLine({required this.achievement, required this.earned});

  final Achievement achievement;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${achievement.title}, ${earned ? 'earned' : 'not yet earned'}. ${achievement.detail}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Seal(earned: earned),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: OrchardText.label(
                      color: earned ? OrchardColors.ink : OrchardColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(achievement.detail, style: OrchardText.small()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A drawn rosette seal: gold-filled with a star when earned, a faint
/// outline when not (shape differs as well as colour).
class _Seal extends StatelessWidget {
  const _Seal({required this.earned});

  final bool earned;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: CustomPaint(painter: _SealPainter(earned)),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter(this.earned);

  final bool earned;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;

    // Scalloped edge: twelve small circles around a core, unioned.
    var rosette = Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.78));
    const bumps = 12;
    for (var i = 0; i < bumps; i++) {
      final a = i * 2 * math.pi / bumps;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * 0.78);
      rosette = Path.combine(
        PathOperation.union,
        rosette,
        Path()..addOval(Rect.fromCircle(center: p, radius: r * 0.22)),
      );
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = earned ? OrchardColors.ink : OrchardColors.inkFaint;

    if (earned) {
      canvas.drawPath(rosette, Paint()..color = OrchardColors.gold);
    }
    canvas.drawPath(rosette, stroke);
    canvas.drawCircle(c, r * 0.52, stroke);

    if (earned) {
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final rr = i.isEven ? r * 0.34 : r * 0.15;
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
        i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
      }
      star.close();
      canvas.drawPath(star, stroke);
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.earned != earned;
}
