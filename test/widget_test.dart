import 'package:echo_orchard/app.dart';
import 'package:echo_orchard/audio/orchard_audio.dart';
import 'package:echo_orchard/data/progress_repository.dart';
import 'package:echo_orchard/data/progression_service.dart';
import 'package:echo_orchard/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pump in 16 ms steps (the hub has a looping ambient ticker).
Future<void> pumpFor(WidgetTester t, Duration d) async {
  final steps = d.inMilliseconds ~/ 16;
  for (var i = 0; i < steps; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  OrchardAudio.disabled = true;

  Future<ProgressRepository> boot(WidgetTester tester, {Map<String, Object> prefs = const {}, String route = AppRoutes.path}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    final repo = ProgressRepository(await SharedPreferences.getInstance());
    final prog = ProgressionService(repo, clock: () => DateTime(2026, 11, 12));
    await tester.pumpWidget(EchoOrchardApp(repository: repo, progression: prog, initialRoute: route));
    await pumpFor(tester, const Duration(milliseconds: 400));
    return repo;
  }

  testWidgets('splash shows the wordmark and moves on to the path', (tester) async {
    await boot(tester, route: AppRoutes.splash);
    expect(find.text('Echo Orchard'), findsOneWidget);
    expect(find.text('Answer the pulse.'), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 3200));
    expect(find.bySemanticsLabel(RegExp('First Pulse')), findsOneWidget);
  });

  testWidgets('the path: shelf, locked seasons and the row sheet', (tester) async {
    await boot(tester);
    expect(find.bySemanticsLabel('Daily, new today'), findsOneWidget);
    expect(find.bySemanticsLabel('Long Row'), findsOneWidget);
    expect(find.bySemanticsLabel('Market'), findsOneWidget);
    expect(find.bySemanticsLabel('Journal'), findsOneWidget);
    expect(find.text('Clear First Basket to open the way.'), findsOneWidget);

    await tester.tap(find.text('Row 1'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('First Pulse'), findsWidgets);
    expect(find.text('Begin the row'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress shows on the path: stars, saplings, next stake', (tester) async {
    await boot(tester, prefs: {'unlocked_row_id': 4, 'stars_row_1': 3, 'stars_row_2': 2, 'stars_row_3': 1, 'seeds': 42});
    expect(find.text('Row 4'), findsOneWidget);
    expect(find.bySemanticsLabel('42 seeds'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Two for One, Spring Bloom, 2 stars')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Row 4, Spring Bloom, next row')), findsOneWidget);
  });

  testWidgets('Wind & Hush toggles persist and reset asks first', (tester) async {
    final repo = await boot(tester, prefs: {'seeds': 99, 'unlocked_row_id': 7});
    await tester.tap(find.bySemanticsLabel('Wind and Hush'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Wind & Hush'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Credits'), findsNothing);

    await tester.tap(find.text('Reduce motion'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(repo.reduceMotion, isTrue);

    await tester.ensureVisible(find.text('Reset the orchard'));
    await tester.tap(find.text('Reset the orchard'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.text('Reset the orchard?'), findsOneWidget);
    await tester.tap(find.text('Keep my orchard'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(repo.seeds, 99);

    await tester.tap(find.text('Reset the orchard'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Yes, clear everything'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(repo.seeds, 0);
    expect(repo.getUnlockedRowId(), 1);
    expect(repo.reduceMotion, isTrue);
  });

  testWidgets('How to harvest: interactive pages', (tester) async {
    await boot(tester, route: AppRoutes.lesson);
    expect(find.text('Tap on the band'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('Practice tree')));
    await pumpFor(tester, const Duration(milliseconds: 100));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await pumpFor(tester, const Duration(milliseconds: 450));
    }
    expect(find.text('Leaves, dewdrops and seeds'), findsOneWidget);
    expect(find.text('To the orchard'), findsOneWidget);
  });
}
