import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/features/profile/domain/pdf_picker.dart';
import 'package:orbijob/preview/preview_fixtures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';
import '../helpers/harness.dart';

const userA = AuthUser(id: 'user-a', email: 'a@example.com');

Future<void> search(WidgetTester t) async {
  await t.tap(find.text('Explore'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), 'Pedreiro');
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'a favourite the server refuses is rolled back and the user is told',
    (t) async {
      final repo = FailingFavorites();
      await pumpApp(t, repo: PreviewSearchRepository(), favorites: repo);
      await search(t);
      repo.error = const sb.PostgrestException(
        message: 'quota exceeded',
        code: '53400',
      );
      await t.tap(find.byTooltip('Save job'));
      await t.pumpAndSettle();
      expect(
        find.byTooltip('Save job'),
        findsOneWidget,
        reason: 'heart is back to unsaved',
      );
      expect(find.textContaining('reached the limit'), findsOneWidget);
      expect(repo.inner, isEmpty);
    },
  );

  testWidgets('favourites persist in the repository and reload from it', (
    t,
  ) async {
    final repo = FailingFavorites();
    await pumpApp(t, repo: PreviewSearchRepository(), favorites: repo);
    await search(t);
    await t.tap(find.byTooltip('Save job'));
    await t.pumpAndSettle();
    expect(repo.inner, hasLength(1));
    // A fresh app start (new Cubits) reads the saved job back from the repository.
    await pumpApp(t, repo: PreviewSearchRepository(), favorites: repo);
    await t.tap(find.text('Favorites'));
    await t.pumpAndSettle();
    expect(find.text('Pedreiro'), findsOneWidget);
  });

  testWidgets('favourites load failure shows retry, not an empty list', (
    t,
  ) async {
    final repo = FailingFavorites()
      ..error = sb.AuthRetryableFetchException(message: 'offline');
    await pumpApp(t, favorites: repo);
    await t.tap(find.text('Favorites'));
    await t.pumpAndSettle();
    expect(find.text('Could not load your data'), findsOneWidget);
    expect(find.text('No favorites yet'), findsNothing);
    repo.error = null;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);
  });

  testWidgets('saving a search stores it in the account; recents stay local', (
    t,
  ) async {
    final auth = FakeAuth()..currentUser = userA;
    final fakes = Fakes(auth: auth);
    await pumpApp(t, repo: PreviewSearchRepository(), auth: auth, fakes: fakes);
    await search(t);
    await t.tap(find.byTooltip('Save this search'));
    await t.pumpAndSettle();
    expect(fakes.savedSearches.rows.map((r) => r.query['term']), ['Pedreiro']);
    expect(find.byTooltip('Search saved'), findsOneWidget);
  });

  testWidgets('language choice applies at once and is saved to the account', (
    t,
  ) async {
    final auth = FakeAuth()..currentUser = userA;
    final fakes = Fakes(auth: auth);
    await pumpApp(t, auth: auth, fakes: fakes, size: const Size(390, 1600));
    await t.tap(find.byTooltip('Profile'));
    await t.pumpAndSettle();
    await t.tap(find.text('Português').last);
    await t.pumpAndSettle();
    expect(fakes.preferences.stored.locale, 'pt');
    expect(find.text('Perfil'), findsWidgets);
  });

  testWidgets(
    'countries of interest: add (normalised), reject invalid, remove',
    (t) async {
      final auth = FakeAuth()..currentUser = userA;
      final fakes = Fakes(auth: auth);
      await pumpApp(t, auth: auth, fakes: fakes, size: const Size(390, 2000));
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      final field = find.widgetWithText(
        TextField,
        'Add a country (2-letter code)',
      );
      await t.ensureVisible(field);
      await t.enterText(field, 'de');
      await t.tap(find.byTooltip('Add').last);
      await t.pumpAndSettle();
      expect(fakes.preferences.stored.countriesOfInterest, ['DE']);
      await t.tap(find.byTooltip('Remove country DE'));
      await t.pumpAndSettle();
      expect(fakes.preferences.stored.countriesOfInterest, isEmpty);
    },
  );

  testWidgets(
    'résumé upload: appears after a profile exists, uploads a PDF, deletes it',
    (t) async {
      final auth = FakeAuth()..currentUser = userA;
      final fakes = Fakes(auth: auth);
      await fakes.profiles.save(const ProfessionalProfile(name: 'Maria'));
      await pumpApp(
        t,
        auth: auth,
        fakes: fakes,
        size: const Size(390, 2400),
        pdfPicker: FakePdfPicker(PickedPdf(name: 'cv.pdf', bytes: tinyPdf())),
      );
      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      expect(find.text('No résumé uploaded yet.'), findsOneWidget);
      await t.tap(find.text('Upload PDF'));
      await t.pumpAndSettle();
      expect(fakes.resumes.rows, hasLength(1));
      expect(find.text('Résumé uploaded'), findsOneWidget);
      await t.tap(find.byTooltip('Delete').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Delete').last);
      await t.pumpAndSettle();
      expect(fakes.resumes.rows, isEmpty);
      expect(fakes.resumes.deleted, 1);
    },
  );

  testWidgets('résumé upload without a profile section is not offered', (
    t,
  ) async {
    final auth = FakeAuth()..currentUser = userA;
    await pumpApp(
      t,
      auth: auth,
      fakes: Fakes(auth: auth),
      size: const Size(390, 2400),
    );
    await t.tap(find.byTooltip('Profile'));
    await t.pumpAndSettle();
    expect(find.text('Upload PDF'), findsNothing);
  });
}
