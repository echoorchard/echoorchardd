import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/daily.dart';
import '../data/row_definition.dart';
import '../game/harvest_session.dart';
import '../routing/app_routes.dart';
import '../theme/orchard_colors.dart';
import '../theme/orchard_text_styles.dart';
import '../widgets/orchard_icons.dart';
import '../widgets/orchard_widgets.dart';

/// Daily Row: today's date-seeded row, the streak and a five-week calendar.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  /// The rules a row uses, read from its trees and wind.
  static List<String> rulesOf(RowDefinition row) {
    final rules = <String>[];
    if (row.trees.map((t) => t.bpm).toSet().length > 1) rules.add('Many tempos');
    if (row.trees.any((t) => t.hasRests)) rules.add('Rest beats');
    if (row.wind.enabled) rules.add('Wind');
    if (row.trees.any((t) => t.hasFadingEcho)) rules.add('Fading echo');
    if (rules.isEmpty) rules.add('One pulse');
    return rules;
  }

  @override
  Widget build(BuildContext context) {
    final scope = OrchardScope.of(context);
    final prog = scope.progression;
    final row = prog.todaysDaily;
    final done = prog.dailyDoneToday;
    final streak = prog.dailyStreak;
    final trees = row.trees.length;
    final gutter = MediaQuery.sizeOf(context).width < 360 ? 20.0 : 24.0;

    return Scaffold(
      backgroundColor: OrchardColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Daily Row'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(row.season.label, style: OrchardText.heading(size: 22)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$trees ${trees == 1 ? 'tree' : 'trees'} · a basket of ${row.quota}',
                      style: OrchardText.small(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [for (final r in rulesOf(row)) _Rule(text: r)],
                    ),
                    const SizedBox(height: 32),
                    Semantics(
                      label: streak == 1 ? '1 day in a row' : '$streak days in a row',
                      excludeSemantics: true,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 8,
                        children: [
                          Text('$streak', style: OrchardText.number(size: 32)),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              streak == 1 ? 'day in a row' : 'days in a row',
                              style: OrchardText.body(color: OrchardColors.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Calendar(today: prog.today, cleared: scope.repository.dailyDates.toSet()),
                    const SizedBox(height: 28),
                    if (done) ...[
                      Text(
                        'Cleared today, come back tomorrow for a new row',
                        style: OrchardText.label(size: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can walk it again, but replays earn no reward.',
                        style: OrchardText.small(),
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: OrchardIcon(
                              OIcon.dewdrop,
                              size: 20,
                              fill: Color(0xFFE4F1F4),
                              strokeWidth: 1.6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'First clear today: ${OrchardConstants.seedsDaily} seeds and a dewdrop',
                              style: OrchardText.label(size: 16),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
              child: StakeButton(
                label: "Walk today's row",
                icon: OIcon.play,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.harvest,
                  arguments: HarvestArgs(row: prog.todaysDaily, mode: PlayMode.daily),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const OrchardIcon(OIcon.leaf, size: 14, strokeWidth: 1.6),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: OrchardText.body())),
      ],
    );
  }
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Five weeks, Monday to Sunday, ending with this week. Cleared days carry a
/// gold leaf, today has a leaf-green ring, future days are faint.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.today, required this.cleared});

  final DateTime today;
  final Set<String> cleared;

  @override
  Widget build(BuildContext context) {
    final day = DateTime(today.year, today.month, today.day);
    final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day - 28);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (final l in letters)
                Expanded(
                  child: Center(child: Text(l, style: OrchardText.small())),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        for (var w = 0; w < 5; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: _DayCell(
                    date: DateTime(start.year, start.month, start.day + w * 7 + d),
                    today: day,
                    cleared: cleared,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.today, required this.cleared});

  final DateTime date;
  final DateTime today;
  final Set<String> cleared;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today;
    final isFuture = date.isAfter(today);
    final done = cleared.contains(DailyRow.dateKey(date));

    final Widget mark;
    if (done) {
      mark = const OrchardIcon(OIcon.leaf, size: 20, fill: OrchardColors.gold, strokeWidth: 1.6);
    } else {
      mark = Text(
        '${date.day}',
        maxLines: 1,
        style: OrchardText.small(
          color: isFuture
              ? OrchardColors.inkFaint
              : isToday
                  ? OrchardColors.ink
                  : OrchardColors.inkSoft,
        ),
      );
    }

    final state = done
        ? 'cleared'
        : isFuture
            ? 'still to come'
            : isToday
                ? 'not cleared yet'
                : 'not cleared';
    return Semantics(
      label: '${isToday ? 'Today, ' : ''}${date.day} ${_monthNames[date.month - 1]}, $state',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: OrchardColors.leaf, width: 2),
                  )
                : null,
            alignment: Alignment.center,
            child: FittedBox(fit: BoxFit.scaleDown, child: mark),
          ),
        ),
      ),
    );
  }
}
