import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/supabase_bootstrap.dart';
import 'core/design/design.dart';
import 'core/di/injector.dart';
import 'features/auth/data/supabase_auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // Public configuration only (--dart-define). Without it the app runs fully offline-first, without accounts.
  final client = await initSupabase(AppConfig.fromEnvironment());
  configureDependencies(
    authRepository: client == null ? null : SupabaseAuthRepository(client),
  );
  if (client != null) registerSupabaseRepositories(client);
  runApp(const OrbiJobApp());
}

/// Exposes the bundled OFL font licences in Flutter's licence page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, path) in AppAssets.fontLicenses) {
      yield LicenseEntryWithLineBreaks(<String>[
        name,
      ], await rootBundle.loadString(path));
    }
  });
}
