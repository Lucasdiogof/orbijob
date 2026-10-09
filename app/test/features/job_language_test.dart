import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/home/recent_searches_cubit.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/harness.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadBrandFonts();
  });

  for (final (locale, searched, tabLabel) in [
    (const Locale('pt'), 'Fonte: Example source', 'Explorar'),
    (const Locale('es'), 'Fuente: Example source', 'Explorar'),
    (const Locale('en'), 'Source: Example source', 'Explore'),
  ]) {
    testWidgets(
      'UI follows ${locale.languageCode}; job text keeps its language',
      (t) async {
        await pumpApp(
          t,
          locale: locale,
          repo: PreviewSearchRepository(),
          size: const Size(390, 1200),
        );
        await t.tap(find.text(tabLabel).first);
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), 'Berlin');
        await t.testTextInput.receiveAction(TextInputAction.search);
        await t.pumpAndSettle();
        // Original German title is never translated, whatever the interface language.
        expect(find.text('Beckenboden-Physiotherapeut:in'), findsOneWidget);
        expect(find.text('Vollzeit'), findsOneWidget);
        expect(find.text('Deutsch'), findsOneWidget, reason: 'language badge');
        expect(find.text(searched), findsWidgets);
      },
    );
  }

  testWidgets('no language badge when the posting matches the UI language', (
    t,
  ) async {
    await pumpApp(
      t,
      locale: const Locale('en'),
      repo: PreviewSearchRepository(),
      size: const Size(390, 1200),
    );
    await t.tap(find.text('Explore').first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Flutter');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(find.text('Senior Flutter Developer'), findsOneWidget);
    expect(find.text('English'), findsNothing);
  });

  test('recent searches: newest first, deduped, capped, clearable', () {
    final c = RecentSearchesCubit();
    for (final q in ['a', 'b', 'c', 'd', 'e', 'f', 'B ', '  ']) {
      c.record(q);
    }
    expect(c.state, ['B', 'f', 'e', 'd', 'c']);
    c.clear();
    expect(c.state, isEmpty);
  });
}
