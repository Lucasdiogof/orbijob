import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/design/theme/app_theme.dart';
import 'package:orbijob/features/search/presentation/widgets/search_suggestions_box.dart';
import 'package:orbijob/l10n/app_localizations.dart';

void main() {
  for (final lang in ['en', 'pt', 'es']) {
    for (final dark in [false, true]) {
      testWidgets(
        'suggestions fit a 320 px phone with 200% text ($lang, ${dark ? 'dark' : 'light'}) and search on tap',
        (t) async {
          t.view.physicalSize = const Size(320, 640);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          String? searched;
          await t.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SearchSuggestionsBox(
                    query: 'fisioterapia pélvica',
                    onSearch: (s) => searched = s,
                  ),
                ),
              ),
            ),
          );
          expect(t.takeException(), isNull);
          await t.tap(find.widgetWithText(ActionChip, 'fisioterapia'));
          expect(searched, 'fisioterapia');
        },
      );
    }
  }

  testWidgets('nothing to suggest renders nothing', (t) async {
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SearchSuggestionsBox(query: 'zzzzqqqq', onSearch: (_) {}),
        ),
      ),
    );
    expect(find.byType(ActionChip), findsNothing);
  });
}
