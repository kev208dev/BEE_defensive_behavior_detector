import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/config/mode_storage.dart';
import 'core/models/hive_status.dart';
import 'core/providers.dart';
import 'features/alerts/domain/push_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A monitoring phone sits in front of a hive for hours; portrait-lock keeps
  // the camera geometry stable across the session.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  // SharedPreferences is the only thing that must be ready before the first
  // frame — the saved mode decides which screen the app opens on.
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ModeStorage storage = ModeStorage(prefs);

  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      modeStorageProvider.overrideWithValue(storage),
    ],
  );

  // Notification setup only matters on a manager phone, and it must never
  // block startup — so it runs after the first frame and swallows failures.
  if (storage.readMode() == AppMode.manager && !AppConfig.demoMode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container.read(pushBootstrapProvider).start().ignore();
    });
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BeehiveGuardApp(),
    ),
  );
}
