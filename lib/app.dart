import 'package:flutter/material.dart';

import 'data/progress_repository.dart';
import 'data/progression_service.dart';
import 'routing/app_routes.dart';
import 'screens/daily_screen.dart';
import 'screens/harvest_row_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/market_screen.dart';
import 'screens/orchard_path_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/result_screens.dart';
import 'screens/splash_screen.dart';
import 'theme/orchard_colors.dart';
import 'theme/orchard_text_styles.dart';
import 'widgets/orchard_widgets.dart';

class EchoOrchardApp extends StatelessWidget {
  const EchoOrchardApp({
    super.key,
    required this.repository,
    required this.progression,
    this.initialRoute = AppRoutes.splash,
  });

  final ProgressRepository repository;
  final ProgressionService progression;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return OrchardScope(
      repository: repository,
      progression: progression,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ripe Rhythm',
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Fraunces',
          scaffoldBackgroundColor: OrchardColors.cream,
          colorScheme: ColorScheme.fromSeed(
            seedColor: OrchardColors.leaf,
            primary: OrchardColors.leaf,
            surface: OrchardColors.cream,
            onSurface: OrchardColors.ink,
          ),
          textTheme: TextTheme(
            headlineMedium: OrchardText.heading(),
            bodyMedium: OrchardText.body(),
            labelLarge: OrchardText.label(),
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: OrchardColors.leaf,
            selectionColor: OrchardColors.gold.withValues(alpha: 0.4),
            selectionHandleColor: OrchardColors.leaf,
          ),
          splashFactory: InkSparkle.splashFactory,
          highlightColor: Colors.transparent,
        ),
        initialRoute: initialRoute,
        onGenerateRoute: (settings) {
          final reduce = repository.reduceMotion;
          Route<dynamic> page(WidgetBuilder b) =>
              OrchardRoute(builder: b, settings: settings, reduceMotion: reduce);
          final args = settings.arguments;
          switch (settings.name) {
            case AppRoutes.splash:
              return page((_) => const SplashScreen());
            case AppRoutes.harvest:
              return page((_) => HarvestRowScreen(args: args! as HarvestArgs));
            case AppRoutes.crowned:
              return page((_) => BasketCrownedScreen(args: args! as ResultArgs));
            case AppRoutes.rests:
              return page((_) => SeasonRestsScreen(args: args! as ResultArgs));
            case AppRoutes.journal:
              return page((_) => const JournalScreen());
            case AppRoutes.market:
              return page((_) => const MarketScreen());
            case AppRoutes.daily:
              return page((_) => const DailyScreen());
            case AppRoutes.lesson:
              return page((_) => const LessonScreen());
            case AppRoutes.privacy:
              return page((_) => const PrivacyScreen());
            case AppRoutes.path:
            default:
              return page((_) => const OrchardPathScreen());
          }
        },
      ),
    );
  }
}
