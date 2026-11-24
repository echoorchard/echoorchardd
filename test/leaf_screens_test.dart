import 'package:echo_orchard/audio/orchard_audio.dart';
import 'package:echo_orchard/data/daily.dart';
import 'package:echo_orchard/data/progress_repository.dart';
import 'package:echo_orchard/data/progression_service.dart';
import 'package:echo_orchard/screens/daily_screen.dart';
import 'package:echo_orchard/screens/journal_screen.dart';
import 'package:echo_orchard/screens/market_screen.dart';
import 'package:echo_orchard/screens/privacy_screen.dart';
import 'package:echo_orchard/widgets/orchard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _today = DateTime(2026, 11, 12);

Future<ProgressRepository> _repo([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return ProgressRepository(await SharedPreferences.getInstance());
}

Future<void> _pumpFrames(WidgetTester tester, [int frames = 30]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<ProgressRepository> _show(
  WidgetTester tester,
  Widget screen, {
  Map<String, Object> values = const {},
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = await _repo(values);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: OrchardScope(
      repository: repo,
      progression: ProgressionService(repo, clock: () => _today),
      child: screen,
    ),
  ));
  await _pumpFrames(tester, 4);
  return repo;
}

void main() {
  setUpAll(() => OrchardAudio.disabled = true);

  for (final scale in [1.0, 1.3]) {
    group('at text scale $scale', () {
      testWidgets('Journal shows the ledger and the seals', (tester) async {
        await _show(tester, const JournalScreen(), textScale: scale, values: {
          'seeds': 42,
          'stats': '{"fruit":1234,"perfects":300,"rows_played":12}',
          'achievements': ['first_row'],
          'stars_row_1': 3,
        });
        expect(find.text('Orchard Journal'), findsOneWidget);
        expect(find.text('Fruit harvested'), findsOneWidget);
        expect(find.text('1,234'), findsOneWidget);
        expect(find.text('1 / 50'), findsOneWidget);
        expect(find.text('3 / 150'), findsOneWidget);
        expect(find.text('Spring Bloom'), findsOneWidget);
        expect(find.text('3 / 27'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Seals'));
        await _pumpFrames(tester, 12);
        expect(find.text('1 of 20'), findsOneWidget);
        expect(find.text('First Fruit'), findsOneWidget);
        expect(find.text('Well-Kept Hill'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Market lists baskets and keepsakes', (tester) async {
        await _show(tester, const MarketScreen(), textScale: scale, values: {'seeds': 50});
        expect(find.text('Market Stall'), findsOneWidget);
        expect(find.text('Baskets'), findsOneWidget);
        expect(find.text('Keepsakes'), findsOneWidget);
        expect(find.text('Willow Basket'), findsOneWidget);
        expect(find.text('In use'), findsOneWidget);
        expect(find.text('Moon Lantern'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Daily shows today, the streak and the reward', (tester) async {
        await _show(tester, const DailyScreen(), textScale: scale);
        expect(find.text('Daily Row'), findsOneWidget);
        expect(find.text("Walk today's row"), findsOneWidget);
        expect(find.text('First clear today: 15 seeds and a dewdrop'), findsOneWidget);
        expect(find.text('days in a row'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Privacy: no data, no account, local saves, support via Play', (tester) async {
        await _show(tester, const PrivacyScreen(), textScale: scale);
        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.textContaining('does not collect any data'), findsOneWidget);
        expect(find.textContaining('No account or sign-in is needed'), findsOneWidget);
        expect(find.text('Your progress is saved only on this device.'), findsOneWidget);
        expect(find.textContaining('Reset the orchard'), findsOneWidget);
        expect(find.textContaining('app data'), findsOneWidget);
        expect(find.text('Uninstall the game.'), findsOneWidget);
        expect(
          find.text(
            'For questions or support, please use the developer contact details '
            "shown on this game's Google Play store listing.",
          ),
          findsOneWidget,
        );
        // No contact details, links, ads or purchase talk inside the app.
        expect(find.textContaining('@'), findsNothing);
        expect(find.textContaining('http'), findsNothing);
        expect(find.textContaining(RegExp(r'\bads?\b|purchase', caseSensitive: false)), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('Daily says when today is already cleared', (tester) async {
    await _show(tester, const DailyScreen(), values: {
      'daily_dates': [
        DailyRow.dateKey(_today.subtract(const Duration(days: 1))),
        DailyRow.dateKey(_today),
      ],
    });
    expect(find.text('Cleared today, come back tomorrow for a new row'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('2 days in a row'), findsOneWidget);
    semantics.dispose();
    expect(find.text('First clear today: 15 seeds and a dewdrop'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Market trades 120 seeds for the Rush Basket', (tester) async {
    final repo = await _show(tester, const MarketScreen(), values: {'seeds': 500});

    await tester.tap(find.text('Rush Basket'));
    await _pumpFrames(tester);
    expect(find.text('Trade 120 seeds for the Rush Basket?'), findsOneWidget);

    await tester.tap(find.text('Trade 120 seeds'));
    await _pumpFrames(tester);

    expect(repo.ownedItems, contains('rush'));
    expect(repo.equippedBasket, 'rush');
    expect(repo.seeds, 380);
    expect(find.text('The Rush Basket is yours'), findsOneWidget);

    await tester.tap(find.text('Back to the stall'));
    await _pumpFrames(tester);
    expect(find.text('380'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Market shows the shortfall and keeps the trade closed', (tester) async {
    final repo = await _show(tester, const MarketScreen(), values: {'seeds': 108});

    await tester.tap(find.text('Rush Basket'));
    await _pumpFrames(tester);
    expect(find.text('12 more seeds'), findsOneWidget);

    await tester.tap(find.text('Trade 120 seeds'));
    await _pumpFrames(tester);
    expect(repo.seeds, 108);
    expect(repo.ownedItems, isNot(contains('rush')));
    expect(tester.takeException(), isNull);
  });
}
