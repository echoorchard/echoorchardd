import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'audio/orchard_audio.dart';
import 'data/progress_repository.dart';
import 'data/progression_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The bundled Fraunces font is SIL OFL 1.1; its licence ships with the app
  // and appears in Flutter's licence registry (no in-app credits screen).
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Fraunces'], ofl);
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final repository = ProgressRepository(prefs);
  final progression = ProgressionService(repository);
  await OrchardAudio.instance.init(repository);
  await progression.markPlayedToday();

  runApp(EchoOrchardApp(repository: repository, progression: progression));
}
