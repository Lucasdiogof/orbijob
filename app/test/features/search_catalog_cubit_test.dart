import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/features/search/presentation/cubit/search_cubit.dart';

JobPosting job(String id, {String title = 'Job'}) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: 'Co',
  title: '$title $id',
  originalUrl: 'https://jobicy.com/jobs/$id',
);

class Call {
  Call(this.query, this.country, this.filters, this.offset, this.limit);
  final String query;
  final String? country;
  final JobFilters filters;
  final int offset;
  final int limit;
}

/// Serves a fixed catalogue in pages, like the real repository, and records every request.
class PagedRepo implements SearchRepository {
  PagedRepo(this.all, {this.skipEvery = 0, this.integrated = true});
  final List<JobPosting> all;
  final int skipEvery;
  final bool integrated;
  final calls = <Call>[];
  Object? failOnCall;
  Completer<void>? gate;

  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async {
    calls.add(Call(query, countryCode, filters, offset, limit));
    if (gate != null) await gate!.future;
    if (failOnCall == calls.length) throw Exception('server down');
    if (!integrated) {
      return const SearchResult(jobs: [], hasIntegratedSource: false);
    }
    final slice = all.skip(offset).take(limit + 1).toList();
    final page = slice.take(limit).toList();
    final shown = [
      for (var i = 0; i < page.length; i++)
        if (skipEvery == 0 || (offset + i + 1) % skipEvery != 0)
          ScoredJob(page[i]),
    ];
    return SearchResult(
      jobs: shown,
      hasIntegratedSource: true,
      hasMore: slice.length > limit,
      consumed: page.length,
    );
  }
}

List<JobPosting> catalogue(int n) => [for (var i = 1; i <= n; i++) job('$i')];

void main() {
  group('SearchCubit with the catalogue', () {
    test(
      'first page, then "show more" appends the next one in order',
      () async {
        final repo = PagedRepo(catalogue(45));
        final c = SearchCubit(repo, pageSize: 20);
        await c.search('job');
        var s = c.state as SearchSuccess;
        expect(s.jobs, hasLength(20));
        expect(s.hasMore, isTrue);
        await c.loadMore();
        s = c.state as SearchSuccess;
        expect(s.jobs, hasLength(40));
        expect(s.jobs.last.job.externalId, '40');
        await c.loadMore();
        s = c.state as SearchSuccess;
        expect(s.jobs, hasLength(45));
        expect(s.hasMore, isFalse);
        expect(repo.calls.map((x) => x.offset), [0, 20, 40]);
        await c.loadMore(); // nothing more: ignored
        expect(repo.calls, hasLength(3));
      },
    );

    test(
      'skipped rows do not shift the next page (offset follows server rows)',
      () async {
        final repo = PagedRepo(catalogue(45), skipEvery: 5);
        final c = SearchCubit(repo, pageSize: 20);
        await c.search('job');
        expect((c.state as SearchSuccess).jobs, hasLength(16));
        await c.loadMore();
        expect(repo.calls.last.offset, 20);
        final ids = (c.state as SearchSuccess).jobs
            .map((j) => j.job.externalId)
            .toList();
        expect(ids.toSet(), hasLength(ids.length), reason: 'no job twice');
      },
    );

    test('a job that appears on two pages is listed once', () async {
      final repo = PagedRepo([...catalogue(20), job('20'), ...catalogue(0)]);
      final c = SearchCubit(repo, pageSize: 20);
      await c.search('job');
      await c.loadMore();
      expect((c.state as SearchSuccess).jobs, hasLength(20));
    });

    test('a second tap on "show more" while loading is ignored', () async {
      final repo = PagedRepo(catalogue(45));
      final c = SearchCubit(repo, pageSize: 20);
      await c.search('job');
      repo.gate = Completer<void>();
      final first = c.loadMore();
      expect((c.state as SearchSuccess).loadingMore, isTrue);
      await c.loadMore();
      expect(repo.calls, hasLength(2));
      repo.gate!.complete();
      await first;
      expect((c.state as SearchSuccess).loadingMore, isFalse);
    });

    test('a failed "show more" keeps the list and offers retry; retrying loads the page', () async {
      final repo = PagedRepo(catalogue(45))..failOnCall = 2;
      final c = SearchCubit(repo, pageSize: 20);
      await c.search('job');
      await c.loadMore();
      var s = c.state as SearchSuccess;
      expect(s.jobs, hasLength(20));
      expect(s.loadMoreFailed, isTrue);
      expect(s.loadingMore, isFalse);
      await c.loadMore();
      s = c.state as SearchSuccess;
      expect(s.jobs, hasLength(40));
      expect(s.loadMoreFailed, isFalse);
    });

    test(
      'changing filters reloads from the first page with the new filters',
      () async {
        final repo = PagedRepo(catalogue(45));
        final c = SearchCubit(repo, pageSize: 20);
        await c.search('job', countryCode: 'PT');
        await c.loadMore();
        const f = JobFilters(
          workModes: {WorkMode.remote},
          publishedWithinDays: 7,
        );
        await c.setFilters(f);
        expect(repo.calls.last.offset, 0);
        expect(repo.calls.last.filters, f);
        expect(
          repo.calls.last.country,
          'PT',
          reason: 'country argument survives a filter change',
        );
        expect((c.state as SearchSuccess).jobs, hasLength(20));
        expect(c.state.filters, f);
      },
    );

    test('filters set before any search are remembered and sent with the first one', () async {
      final repo = PagedRepo(catalogue(3));
      final c = SearchCubit(repo);
      await c.setFilters(const JobFilters(onlyWithSalary: true));
      expect(
        c.state,
        const SearchIdle(filters: JobFilters(onlyWithSalary: true)),
      );
      expect(repo.calls, isEmpty);
      await c.search('x');
      expect(repo.calls.single.filters.onlyWithSalary, isTrue);
    });

    test(
      'setting identical filters does nothing; clearFilters reloads',
      () async {
        final repo = PagedRepo(catalogue(3));
        final c = SearchCubit(repo);
        await c.search('x');
        await c.setFilters(const JobFilters());
        expect(repo.calls, hasLength(1));
        await c.setFilters(const JobFilters(onlyWithSalary: true));
        await c.clearFilters();
        expect(repo.calls, hasLength(3));
        expect(c.filters.isActive, isFalse);
      },
    );

    test('browse lists the newest jobs without a term and without feeding recent searches', () async {
      final repo = PagedRepo(catalogue(3));
      final recorded = <String>[];
      final c = SearchCubit(repo, onQuery: recorded.add);
      await c.browse();
      expect(repo.calls.single.query, '');
      expect((c.state as SearchSuccess).jobs, hasLength(3));
      expect(recorded, isEmpty);
      await c.search('   ');
      expect(c.state, isA<SearchIdle>());
    });

    test('an old response never overwrites a newer search', () async {
      final gate = Completer<void>();
      final slow = PagedRepo(catalogue(5))..gate = gate;
      final c = SearchCubit(slow);
      final first = c.search('slow');
      await Future<void>.delayed(Duration.zero);
      slow.gate = null;
      await c.search('fast');
      final fastState = c.state;
      expect(fastState, isA<SearchSuccess>());
      expect((fastState as SearchSuccess).query, 'fast');
      // let the first request finish: it must be discarded
      gate.complete();
      await first;
      expect((c.state as SearchSuccess).query, 'fast');
    });

    test('clear() while loading discards the in-flight answer', () async {
      final repo = PagedRepo(catalogue(5))..gate = Completer<void>();
      final c = SearchCubit(repo);
      final f = c.search('x');
      await Future<void>.delayed(Duration.zero);
      c.clear();
      repo.gate!.complete();
      await f;
      expect(c.state, isA<SearchIdle>());
    });

    test('server failure -> failure state; retry repeats the same search and filters', () async {
      final repo = PagedRepo(catalogue(3))..failOnCall = 1;
      final c = SearchCubit(repo);
      await c.setFilters(const JobFilters(publishedWithinDays: 1));
      await c.search('x', countryCode: 'DE');
      expect(
        c.state,
        const SearchFailure('x', filters: JobFilters(publishedWithinDays: 1)),
      );
      await c.retry();
      expect(c.state, isA<SearchSuccess>());
      expect(repo.calls.last.country, 'DE');
      expect(repo.calls.last.filters.publishedWithinDays, 1);
    });

    test('retry with nothing searched does nothing', () async {
      final repo = PagedRepo(catalogue(1));
      await SearchCubit(repo).retry();
      expect(repo.calls, isEmpty);
    });

    test('empty catalogue with an authorised source -> empty; without one -> no source', () async {
      final empty = SearchCubit(PagedRepo(const []));
      await empty.search('x');
      expect(empty.state, const SearchEmpty('x'));
      final none = SearchCubit(PagedRepo(const [], integrated: false));
      await none.search('x');
      expect(none.state, const SearchNoSource('x'));
    });

    test('empty result under active filters keeps the filters so the UI can offer to clear them', () async {
      final c = SearchCubit(PagedRepo(const []));
      await c.setFilters(const JobFilters(countryCode: 'PT'));
      await c.search('x');
      expect(
        c.state,
        const SearchEmpty('x', filters: JobFilters(countryCode: 'PT')),
      );
    });

    test('a page of only-invalid rows that still has more pages is not reported as empty', () async {
      final repo = PagedRepo(catalogue(30), skipEvery: 1); // every row skipped
      final c = SearchCubit(repo, pageSize: 10);
      await c.search('x');
      final s = c.state as SearchSuccess;
      expect(s.jobs, isEmpty);
      expect(s.hasMore, isTrue);
    });
  });
}
