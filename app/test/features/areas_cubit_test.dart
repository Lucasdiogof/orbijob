import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/job_area.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/features/search/presentation/cubit/areas_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orbijob/features/search/domain/job_filters.dart';

class _Counting implements SearchRepository, AreaCountSource {
  _Counting(this.run);

  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async => const SearchResult(jobs: [], hasIntegratedSource: true);

  final Future<Map<JobArea, int>> Function(
    void Function(Map<JobArea, int>)? onPartial,
  )
  run;
  int calls = 0;

  @override
  Future<Map<JobArea, int>> areaCounts({
    void Function(Map<JobArea, int> soFar)? onPartial,
  }) {
    calls++;
    return run(onPartial);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'chips appear as each count arrives and the last state is loaded',
    () async {
      final repo = _Counting((p) async {
        p?.call({JobArea.technology: 5});
        p?.call({JobArea.technology: 5, JobArea.health: 2});
        return {JobArea.technology: 5, JobArea.health: 2};
      });
      final cubit = AreasCubit(
        repo,
        prefs: await SharedPreferences.getInstance(),
      );
      final states = <AreasState>[];
      final sub = cubit.stream.listen(states.add);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(states.map((s) => s.available.length), [1, 2, 2]);
      expect(states.last.loaded, isTrue);
    },
  );

  test(
    'a failed run keeps the cached chips and still finishes loaded',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AreasCubit.cacheKey, '{"technology":9,"health":4}');
      final repo = _Counting(
        (p) async => throw StateError('no area could be counted'),
      );
      final cubit = AreasCubit(repo, prefs: prefs);
      await cubit.load();
      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.counts, {JobArea.technology: 9, JobArea.health: 4});
    },
  );

  test('a fresh zero hides an area that the cache still had; an area that failed keeps its cached number', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AreasCubit.cacheKey,
      '{"technology":9,"health":4,"design":3}',
    );
    final repo = _Counting(
      (p) async => {JobArea.technology: 0, JobArea.design: 3},
    );
    final cubit = AreasCubit(repo, prefs: prefs);
    await cubit.load();
    expect(cubit.state.available, [JobArea.design, JobArea.health]);
  });

  test(
    'a second load while one is running does nothing (no duplicate requests)',
    () async {
      final repo = _Counting((p) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return {JobArea.sales: 1};
      });
      final cubit = AreasCubit(repo);
      await Future.wait([cubit.load(), cubit.load(), cubit.load()]);
      expect(repo.calls, 1);
    },
  );

  test('the counts are stored for the next start', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = _Counting((p) async => {JobArea.sales: 12});
    await AreasCubit(repo, prefs: prefs).load();
    expect(prefs.getString(AreasCubit.cacheKey), '{"sales":12}');
  });
}
