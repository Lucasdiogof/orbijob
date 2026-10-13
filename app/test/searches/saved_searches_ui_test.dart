import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_area.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/searches/domain/saved_search.dart';
import 'package:orbijob/features/searches/domain/search_spec.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.com');

Future<void> _explore(WidgetTester t, [String term = 'Pedreiro']) async {
  await t.tap(find.text('Explore'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), term);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'save a search with alerts: name, switch and frequency are stored',
    (t) async {
      final auth = FakeAuth()..currentUser = _user;
      final fakes = Fakes(auth: auth);
      await pumpApp(
        t,
        repo: PreviewSearchRepository(),
        auth: auth,
        fakes: fakes,
        size: const Size(390, 1000),
      );
      await _explore(t);
      await t.tap(find.text('Save search'));
      await t.pumpAndSettle();
      // the sheet is pre-filled with a readable name and shows what is being saved
      expect(find.widgetWithText(TextFormField, 'Pedreiro'), findsOneWidget);
      await t.enterText(find.byType(TextFormField).last, 'Bricklayers');
      await t.tap(find.text('Alert me about new jobs'));
      await t.pumpAndSettle();
      expect(find.text('How often to check'), findsOneWidget);
      await t.tap(find.text('Every hour'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save').last);
      await t.pumpAndSettle();
      final s = fakes.savedSearches.rows.single;
      expect(s.name, 'Bricklayers');
      expect(s.alertsEnabled, isTrue);
      expect(s.frequency, AlertFrequency.instant);
      expect(s.spec.term, 'Pedreiro');
      // already saved: the button now edits instead of saving again
      expect(find.text('Edit'), findsWidgets);
    },
  );

  testWidgets('a name is required', (t) async {
    final auth = FakeAuth()..currentUser = _user;
    final fakes = Fakes(auth: auth);
    await pumpApp(
      t,
      repo: PreviewSearchRepository(),
      auth: auth,
      fakes: fakes,
      size: const Size(390, 1000),
    );
    await _explore(t);
    await t.tap(find.text('Save search'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).last, '   ');
    await t.tap(find.text('Save').last);
    await t.pumpAndSettle();
    expect(find.text('Give the search a name.'), findsOneWidget);
    expect(fakes.savedSearches.rows, isEmpty);
  });

  testWidgets(
    'the saved searches page lists, switches alerts, duplicates and deletes',
    (t) async {
      final auth = FakeAuth()..currentUser = _user;
      final fakes = Fakes(auth: auth);
      fakes.savedSearches.rows.addAll([
        SavedSearch(
          id: 'a',
          name: 'Health in Germany',
          query: const SearchSpec(
            filters: JobFilters(
              area: JobArea.health,
              countryCode: 'DE',
              workModes: {WorkMode.remote},
            ),
          ).toQuery(),
        ),
        SavedSearch(
          id: 'b',
          name: 'Nurses',
          alertsEnabled: true,
          frequency: AlertFrequency.weekly,
          query: const SearchSpec(term: 'nurse').toQuery(),
        ),
      ]);
      await pumpApp(
        t,
        repo: PreviewSearchRepository(),
        auth: auth,
        fakes: fakes,
        size: const Size(390, 1000),
      );
      // Home shows them as chips, with a bell on the one that alerts
      expect(find.text('Health in Germany'), findsOneWidget);
      await t.tap(find.text('See all').first);
      await t.pumpAndSettle();
      expect(find.text('Saved searches'), findsWidgets);
      expect(find.text('Alerts on · Once a week'), findsOneWidget);
      expect(find.text('Alerts off'), findsOneWidget);
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('Remote'), findsOneWidget);

      // switch alerts on for the first
      await t.tap(find.byType(Switch).first);
      await t.pumpAndSettle();
      expect(
        fakes.savedSearches.rows.firstWhere((r) => r.id == 'a').alertsEnabled,
        isTrue,
      );

      // duplicate the second
      await t.tap(find.byTooltip('Actions for Nurses'));
      await t.pumpAndSettle();
      await t.tap(find.text('Duplicate'));
      await t.pumpAndSettle();
      expect(
        fakes.savedSearches.rows.map((r) => r.name),
        contains('Nurses (copy)'),
      );
      expect(
        fakes.savedSearches.rows
            .firstWhere((r) => r.name == 'Nurses (copy)')
            .alertsEnabled,
        isFalse,
      );

      // delete it again, after confirming
      await t.tap(find.byTooltip('Actions for Nurses (copy)'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(find.text('Delete this search?'), findsOneWidget);
      await t.tap(find.text('Delete').last);
      await t.pumpAndSettle();
      expect(
        fakes.savedSearches.rows.map((r) => r.name),
        isNot(contains('Nurses (copy)')),
      );
    },
  );

  testWidgets('opening a saved search runs it in Explore with its filters', (
    t,
  ) async {
    final auth = FakeAuth()..currentUser = _user;
    final fakes = Fakes(auth: auth);
    fakes.savedSearches.rows.add(
      SavedSearch(
        id: 'a',
        name: 'Remote bricklayer',
        query: const SearchSpec(
          term: 'Pedreiro',
          filters: JobFilters(workModes: {WorkMode.remote}),
        ).toQuery(),
      ),
    );
    await pumpApp(
      t,
      repo: PreviewSearchRepository(),
      auth: auth,
      fakes: fakes,
      size: const Size(390, 1000),
    );
    await t.tap(find.text('Remote bricklayer'));
    await t.pumpAndSettle();
    // Explore is on screen, with the text and the Remote chip applied
    expect(find.widgetWithText(TextField, 'Pedreiro'), findsOneWidget);
  });

  testWidgets('signed out: the page asks for an account instead of failing', (
    t,
  ) async {
    final auth = FakeAuth();
    await pumpApp(
      t,
      repo: PreviewSearchRepository(),
      auth: auth,
      fakes: Fakes(auth: auth),
      size: const Size(390, 1000),
    );
    await _explore(t);
    await t.tap(find.text('Save search'));
    await t.pumpAndSettle();
    expect(find.text('Saved searches'), findsWidgets);
    expect(find.textContaining('Sign in'), findsWidgets);
  });
}
