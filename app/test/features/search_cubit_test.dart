import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/features/search/presentation/cubit/search_cubit.dart';
import 'package:orbijob/preview/preview_fixtures.dart';

class _Throwing implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) async =>
      throw Exception('x');
}

class _Empty implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) async =>
      const SearchResult(jobs: [], hasIntegratedSource: true);
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
    test(
      'a source that answers with nothing is "empty", not "no source"',
      () async {
        final c = SearchCubit(_Empty());
        await c.search('x');
        expect(c.state, const SearchEmpty('x'));
      },
    );
    test(
      'success carries scored jobs (fixtures are test/preview only)',
      () async {
        final c = SearchCubit(PreviewSearchRepository());
        await c.search('Pedreiro');
        expect((c.state as SearchSuccess).jobs.single.job.title, 'Pedreiro');
      },
    );
    test('compatibility and confidence are separate fields', () {
      const m = JobMatch(score: 81, confidence: ConfidenceLevel.low);
      expect(m.score, 81);
      expect(m.confidence, ConfidenceLevel.low);
    });
  });
}
