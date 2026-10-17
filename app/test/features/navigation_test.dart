import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/orbi/orbi.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/harness.dart';

void main() {
  testWidgets(
    'compact: four destinations in a bottom bar, profile in the header',
    (t) async {
      await pumpApp(t, size: const Size(390, 844));
      expect(find.byType(OrbiNavigationBar), findsOneWidget);
      expect(find.byType(OrbiSideNav), findsNothing);
      for (final n in ['Home', 'Explore', 'Favorites', 'Applications']) {
        expect(find.text(n), findsWidgets);
      }
      expect(find.byTooltip('Profile'), findsOneWidget);
    },
  );

  testWidgets('navigates between the four pages and shows honest empty states', (
    t,
  ) async {
    await pumpApp(t);
    expect(find.text('Find your next opportunity'), findsOneWidget);
    await t.tap(find.text('Favorites'));
    await t.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);
    await t.tap(find.text('Applications'));
    await t.pumpAndSettle();
    expect(find.text('No applications tracked'), findsWidgets);
    await t.tap(find.text('Explore'));
    await t.pumpAndSettle();
    // Explore lists the newest jobs on its own; this build has no backend configuration, and it says so (not "no source")
    expect(find.text('This build is not connected to OrbiJob'), findsWidgets);
    expect(find.text('No integrated source for this search'), findsNothing);
  });

  testWidgets(
    'home search field opens Explore with the keyboard field focused',
    (t) async {
      await pumpApp(t);
      await t.tap(find.byType(TextField));
      await t.pumpAndSettle();
      final field = t.widget<EditableText>(find.byType(EditableText).last);
      expect(field.focusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'an area tile (only areas that have jobs are offered) filters Explore to that area',
    (t) async {
      await pumpApp(
        t,
        size: const Size(390, 2400),
        repo: PreviewSearchRepository(),
      );
      // every tile carries its real count; none is drawn for an area without jobs
      expect(find.text('Health'), findsOneWidget);
      expect(find.textContaining('Hospitality'), findsNothing);
      await t.tap(find.text('Health'));
      await t.pumpAndSettle();
      expect(find.text('Registered Nurse'), findsWidgets);
      expect(find.text('Residential Painter'), findsNothing);
      expect(find.text('Senior Flutter Developer'), findsNothing);
    },
  );

  testWidgets(
    'without a backend there are no area tiles and no list: the build says it is not connected',
    (t) async {
      await pumpApp(t);
      expect(find.text('Health'), findsNothing);
      expect(find.text('This build is not connected to OrbiJob'), findsWidgets);
    },
  );

  testWidgets(
    'Home lists the newest jobs on opening; tapping one opens its detail',
    (t) async {
      await pumpApp(t, repo: PreviewSearchRepository());
      expect(find.text('Latest jobs'), findsOneWidget);
      expect(find.text('Registered Nurse'), findsWidgets);
      await t.ensureVisible(find.text('Registered Nurse').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Registered Nurse').first);
      await t.pumpAndSettle();
      expect(find.text('Job details'), findsWidgets);
    },
  );

  testWidgets(
    'searching with a connected (preview) source shows result cards with compatibility',
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
    expect(find.byType(OrbiSideNav), findsOneWidget);
    expect(find.byType(OrbiNavigationBar), findsNothing);
    expect(t.widget<OrbiSideNav>(find.byType(OrbiSideNav)).extended, isFalse);
  });

  testWidgets('expanded width uses an extended rail', (t) async {
    await pumpApp(t, size: const Size(1280, 800));
    expect(t.widget<OrbiSideNav>(find.byType(OrbiSideNav)).extended, isTrue);
  });

  testWidgets(
    'short landscape phone keeps the rail but drops its labels (icons + tooltips + semantics)',
    (t) async {
      await pumpApp(t, size: const Size(844, 390));
      final rail = t.widget<OrbiSideNav>(find.byType(OrbiSideNav));
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
          t.getSize(find.byType(OrbiSideNav)).height,
          greaterThan(850),
          reason: 'rail must fill the window height',
        );
        for (final label in ['Home', 'Explore', 'Favorites', 'Applications']) {
          final h = t
              .getSize(
                find.descendant(
                  of: find.byType(OrbiSideNav),
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
                  of: find.byType(OrbiNavigationBar),
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
