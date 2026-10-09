import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/design/design.dart';
import 'core/di/injector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  configureDependencies();
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
