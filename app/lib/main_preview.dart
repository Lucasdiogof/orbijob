// Preview entrypoint: `flutter run -t lib/main_preview.dart` (or `flutter build web -t lib/main_preview.dart`).
// It plugs ILLUSTRATIVE fictional jobs into the real UI and pins a banner saying so on every screen.
// The production entrypoint (lib/main.dart) never references the fixtures.
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/design/design.dart';
import 'core/di/injector.dart';
import 'l10n/app_localizations.dart';
import 'main.dart' show registerFontLicenses;
import 'preview/preview_fixtures.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // ?delay=ms (web) makes the "loading" state observable in screenshots.
  final delay = int.tryParse(Uri.base.queryParameters['delay'] ?? '') ?? 0;
  configureDependencies(
    searchRepository: PreviewSearchRepository(
      delay: Duration(milliseconds: delay),
      now: DateTime.now(),
    ),
  );
  runApp(OrbiJobApp(builder: previewBanner));
}

Widget previewBanner(BuildContext context, Widget? child) {
  final c = context.colors;
  final l = AppLocalizations.of(context);
  return Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: Material(
          color: c.warningContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s1,
              ),
              child: Semantics(
                container: true,
                child: Text(
                  l.previewBanner,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall!.copyWith(
                    color: c.onWarningContainer,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ],
  );
}
