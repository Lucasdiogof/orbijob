import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/widgets/app_navigation.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/harness.dart';

void main() {
  testWidgets(
    'compact: four destinations in a bottom bar, profile in the header',
    (t) async {
      await pumpApp(t, size: const Size(390, 844));
      expect(find.byType(AppNavBar), findsOneWidget);
      expect(find.byType(AppNavRail), findsNothing);
      for (final n in ['Home', 'Explore', 'Favorites', 'Applications']) {
        expect(find.text(n), findsWidgets);
      }
      expect(find.byTooltip('Profile'), findsOneWidget);
    },
  );

  testWidgets(
    'navigates between the four pages and shows honest empty states',
    (t) async {
      await pumpApp(t);
      expect(find.text('What are you looking for?'), findsOneWidget);
      await t.tap(find.text('Favorites'));
      await t.pumpAndSettle();
      expect(find.text('No favorites yet'), findsOneWidget);
      await t.tap(find.text('Applications'));
      await t.pumpAndSettle();
      expect(find.text('No applications tracked'), findsWidgets);
      await t.tap(find.text('Explore'));
      await t.pumpAndSettle();
      expect(find.text('Search for any profession'), findsOneWidget);
    },
  );

  testWidgets(
    'home search field opens Explore with the keyboard field focused',
    (t) async {
      await pumpApp(t);
      await t.tap(find.byType(TextField));
      await t.pumpAndSettle();
      expect(find.text('Search for any profession'), findsOneWidget);
      final field = t.widget<EditableText>(find.byType(EditableText).last);
      expect(field.focusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'area chip runs the search and goes to Explore; no source -> explicit state',
    (t) async {
      await pumpApp(t);
      await t.tap(find.text('Health'));
      await t.pumpAndSettle();
      expect(find.text('No integrated source for this search'), findsOneWidget);
      expect(find.text('Health'), findsWidgets);
    },
  );

  testWidgets(
    'searching with a connected (preview) source shows cards with separate compatibility and confidence',
    (t) async {
      await pumpApp(t, repo: PreviewSearchRepository());
      await t.tap(find.text('Explore'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Pedreiro');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('Pedreiro'), findsWidgets);
      expect(find.text('Construtora Exemplo'), findsOneWidget);
      expect(find.text('74'), findsOneWidget);
      expect(find.text('Compatibility'), findsOneWidget);
      expect(find.text('Medium confidence'), findsOneWidget);
      expect(find.textContaining('€'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
    },
  );

  testWidgets('favoriting from a result lists it in Favorites', (t) async {
    await pumpApp(t, repo: PreviewSearchRepository());
    await t.tap(find.text('Explore'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Pedreiro');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Save job'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    await t.tap(find.text('Favorites'));
    await t.pumpAndSettle();
    expect(find.text('Pedreiro'), findsOneWidget);
    expect(find.text('No favorites yet'), findsNothing);
  });

  testWidgets('medium width uses a navigation rail with labels', (t) async {
    await pumpApp(t, size: const Size(800, 1000));
    expect(find.byType(AppNavRail), findsOneWidget);
    expect(find.byType(AppNavBar), findsNothing);
    expect(t.widget<AppNavRail>(find.byType(AppNavRail)).extended, isFalse);
  });

  testWidgets('expanded width uses an extended rail', (t) async {
    await pumpApp(t, size: const Size(1280, 800));
    expect(t.widget<AppNavRail>(find.byType(AppNavRail)).extended, isTrue);
  });

  testWidgets(
    'short landscape phone keeps the rail but drops its labels (icons + tooltips + semantics)',
    (t) async {
      await pumpApp(t, size: const Size(844, 390));
      final rail = t.widget<AppNavRail>(find.byType(AppNavRail));
      expect(rail.showLabels, isFalse);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop Explore is master/detail: selecting a card fills the detail pane',
    (t) async {
      await pumpApp(
        t,
        size: const Size(1280, 800),
        repo: PreviewSearchRepository(),
      );
      await t.tap(find.text('Explore'));
      await t.pumpAndSettle();
      expect(find.text('Select a job to see its details.'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Pedreiro');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      await t.tap(find.text('Construtora Exemplo'));
      await t.pumpAndSettle();
      expect(find.text('Select a job to see its details.'), findsNothing);
      expect(
        find.text('Compatibility and confidence are separate measures.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('narrow Explore opens the job as a page', (t) async {
    await pumpApp(t, repo: PreviewSearchRepository());
    await t.tap(find.text('Explore'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Pedreiro');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    await t.tap(find.text('Construtora Exemplo'));
    await t.pumpAndSettle();
    expect(find.text('Job details'), findsOneWidget);
    expect(
      find.text('Open official application'),
      findsNothing,
      reason: 'no destination wired, so no button',
    );
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets(
      'rail: full height and labels stay on one line (text ${(scale * 100).round()}%)',
      (t) async {
        await pumpApp(t, size: const Size(800, 1000), textScale: scale);
        expect(
          t.getSize(find.byType(AppNavRail)).height,
          greaterThan(850),
          reason: 'rail must fill the window height',
        );
        for (final label in ['Home', 'Explore', 'Favorites', 'Applications']) {
          final h = t
              .getSize(
                find.descendant(
                  of: find.byType(AppNavRail),
                  matching: find.text(label),
                ),
              )
              .height;
          expect(h, lessThan(30), reason: '$label wrapped inside the rail');
        }
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'bottom bar: labels stay on one line (text ${(scale * 100).round()}%)',
      (t) async {
        await pumpApp(t, size: const Size(360, 700), textScale: scale);
        for (final label in ['Home', 'Explore', 'Favorites', 'Applications']) {
          final h = t
              .getSize(
                find.descendant(
                  of: find.byType(AppNavBar),
                  matching: find.text(label),
                ),
              )
              .height;
          expect(h, lessThan(30), reason: '$label wrapped inside the bar');
        }
      },
    );
  }
}
