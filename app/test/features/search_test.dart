import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/app.dart';
import 'package:orbijob/core/di/injector.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/features/search/presentation/cubit/search_cubit.dart';

class _Throwing implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) async =>
      throw Exception('x');
}

class _One implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) async =>
      const SearchResult(
        hasIntegratedSource: true,
        jobs: [
          JobPosting(
            source: 't',
            externalId: '1',
            company: 'Co',
            title: 'Job',
            originalUrl: 'https://e.x/1',
          ),
        ],
      );
}

void main() {
  group('SearchCubit', () {
    test('empty query returns to idle', () async {
      final c = SearchCubit(NoSourceSearchRepository());
      await c.search('   ');
      expect(c.state, const SearchIdle());
    });
    test(
      'no integrated source is reported honestly, never fake results',
      () async {
        final c = SearchCubit(NoSourceSearchRepository());
        await c.search('pedreiro', countryCode: 'PT');
        expect(c.state, const SearchNoSource('pedreiro'));
      },
    );
    test('repository error becomes failure state', () async {
      final c = SearchCubit(_Throwing());
      await c.search('x');
      expect(c.state, const SearchFailure('x'));
    });
    test('success carries jobs', () async {
      final c = SearchCubit(_One());
      await c.search('x');
      expect((c.state as SearchSuccess).jobs.single.title, 'Job');
    });
  });

  group('SearchPage', () {
    setUp(() async {
      await sl.reset();
      configureDependencies();
    });

    testWidgets('shows idle then the no-source state after a search', (
      t,
    ) async {
      await t.pumpWidget(const OrbiJobApp());
      await t.pumpAndSettle();
      await t.tap(find.text('Explore'));
      await t.pumpAndSettle();
      expect(find.text('Search for any profession'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'electrician');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('No integrated source for this search'), findsOneWidget);
    });

    testWidgets('has four main destinations and profile in the header', (
      t,
    ) async {
      await t.pumpWidget(const OrbiJobApp());
      await t.pumpAndSettle();
      for (final n in ['Home', 'Explore', 'Favorites', 'Applications']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.byTooltip('Profile'), findsOneWidget);
      await t.tap(find.text('Favorites'));
      await t.pumpAndSettle();
      expect(find.text('No favorites yet'), findsOneWidget);
      await t.tap(find.text('Applications'));
      await t.pumpAndSettle();
      expect(find.text('No applications tracked'), findsOneWidget);
    });

    testWidgets('uses a navigation rail on wide screens', (t) async {
      t.view.physicalSize = const Size(1200, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const OrbiJobApp());
      await t.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('meets text-contrast and tap-target guidelines', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(const OrbiJobApp());
      await t.pumpAndSettle();
      await expectLater(t, meetsGuideline(textContrastGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      h.dispose();
    });

    testWidgets('dark theme renders', (t) async {
      t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await t.pumpWidget(const OrbiJobApp());
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      addTearDown(t.platformDispatcher.clearAllTestValues);
    });
  });
}
