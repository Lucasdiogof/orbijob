import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobradar/app.dart';
import 'package:jobradar/core/di/injector.dart';
import 'package:jobradar/features/search/domain/entities/job_posting.dart';
import 'package:jobradar/features/search/domain/search_repository.dart';
import 'package:jobradar/features/search/presentation/cubit/search_cubit.dart';

class _Throwing implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) async => throw Exception('x');
}

class _One implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) async => const SearchResult(
        hasIntegratedSource: true,
        jobs: [JobPosting(source: 't', externalId: '1', company: 'Co', title: 'Job', originalUrl: 'https://e.x/1')],
      );
}

void main() {
  group('SearchCubit', () {
    test('empty query returns to idle', () async {
      final c = SearchCubit(NoSourceSearchRepository());
      await c.search('   ');
      expect(c.state, const SearchIdle());
    });
    test('no integrated source is reported honestly, never fake results', () async {
      final c = SearchCubit(NoSourceSearchRepository());
      await c.search('pedreiro', countryCode: 'PT');
      expect(c.state, const SearchNoSource('pedreiro'));
    });
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

    testWidgets('shows idle then the no-source state after a search', (t) async {
      await t.pumpWidget(const JobRadarApp());
      await t.pumpAndSettle();
      expect(find.text('Search for any profession'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'electrician');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('No integrated source for this search'), findsOneWidget);
    });

    testWidgets('meets text-contrast and tap-target guidelines', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(const JobRadarApp());
      await t.pumpAndSettle();
      await expectLater(t, meetsGuideline(textContrastGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      h.dispose();
    });

    testWidgets('dark theme renders', (t) async {
      t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await t.pumpWidget(const JobRadarApp());
      await t.pumpAndSettle();
      expect(find.byType(BlocBuilder<SearchCubit, SearchState>), findsOneWidget);
      addTearDown(t.platformDispatcher.clearAllTestValues);
    });
  });
}
