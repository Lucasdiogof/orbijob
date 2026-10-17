import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/features/home/latest_jobs_cubit.dart';
import 'package:orbijob/features/search/data/job_cache_codec.dart';
import 'package:orbijob/features/search/data/offline_first_search_repository.dart';
import 'package:orbijob/features/search/data/search_results_cache.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:orbijob/features/search/presentation/cubit/search_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ORBI-001: what the person already saw opens again without a connection, says when it was saved, never replaces a fresh answer, and never invents one.

JobPosting job(
  String id, {
  String title = 'Flutter Developer',
  String? description,
}) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: 'Acme',
  title: title,
  originalUrl: 'https://example.com/$id',
  country: 'BR',
  city: 'Goiânia',
  workMode: WorkMode.remote,
  salaryMin: 1000,
  salaryMax: 2000,
  salaryCurrency: 'BRL',
  salaryPeriod: SalaryPeriod.month,
  publishedAt: DateTime.utc(2026, 10, 1, 12),
  sourceName: 'Jobicy',
  language: 'pt',
  geoRestrictions: const ['BR', 'LATAM'],
  description: description ?? 'Descrição original em português.',
  skills: const ['Dart'],
);

/// A catalogue that answers, or fails with the given error, and counts calls.
class FakeCatalogue implements SearchRepository {
  FakeCatalogue({this.jobs = const [], this.error, this.hasSource = true});
  List<JobPosting> jobs;
  Object? error;
  bool hasSource;
  int calls = 0;
  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async {
    calls++;
    if (error != null) throw error!;
    return SearchResult(
      jobs: [for (final j in jobs) ScoredJob(j)],
      hasIntegratedSource: hasSource,
      hasMore: jobs.length >= limit,
    );
  }
}

void main() {
  final t0 = DateTime.utc(2026, 10, 17, 12);

  group('local copy of a posting', () {
    test('round-trips every field, in the original language', () {
      final j = job('1');
      final back = jobFromCacheJson(jsonDecode(jsonEncode(jobToCacheJson(j))));
      expect(back, isNotNull);
      expect(back!.title, j.title);
      expect(back.description, j.description);
      expect(back.geoRestrictions, j.geoRestrictions);
      expect(back.salaryPeriod, SalaryPeriod.month);
      expect(back.workMode, WorkMode.remote);
      expect(back.publishedAt, j.publishedAt);
      expect(back.skills, ['Dart']);
    });
    test('a very long description is cut, a damaged entry is dropped', () {
      final long = 'x' * (maxCachedDescription + 500);
      expect(
        jobToCacheJson(job('2', description: long))['d'].toString().length,
        maxCachedDescription,
      );
      expect(jobFromCacheJson({'s': 'a'}), isNull);
      expect(jobFromCacheJson('garbage'), isNull);
    });
  });

  group('cache key', () {
    test(
      'the same search (case, spaces, country in the filter or beside it) is the same key; another filter is another',
      () {
        expect(searchCacheKey('  Flutter  '), searchCacheKey('flutter'));
        expect(
          searchCacheKey('flutter', countryCode: 'br'),
          searchCacheKey(
            'flutter',
            filters: const JobFilters(countryCode: 'BR'),
          ),
        );
        expect(
          searchCacheKey(
            'flutter',
            filters: const JobFilters(workModes: {WorkMode.remote}),
          ),
          isNot(searchCacheKey('flutter')),
        );
      },
    );
  });

  group('stored on the device', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('write then read, expiry, bounded size, damaged store', () async {
      final prefs = await SharedPreferences.getInstance();
      var now = t0;
      final cache = PrefsSearchResultsCache(
        prefs,
        now: () => now,
        maxEntries: 3,
      );
      CachedSearch entry(String k) => CachedSearch(
        key: k,
        query: k,
        savedAt: now,
        jobs: [job(k)],
        hasIntegratedSource: true,
      );
      await cache.write(entry('a'));
      expect((await cache.read('a'))!.jobs.single.externalId, 'a');
      expect(await cache.read('zzz'), isNull);

      now = t0.add(const Duration(days: 15));
      expect(
        await cache.read('a'),
        isNull,
        reason: 'listings are volatile: older than 14 days is not offered',
      );

      now = t0;
      for (final k in ['b', 'c', 'd']) {
        await cache.write(entry(k));
      }
      expect(
        await cache.read('a'),
        isNull,
        reason: 'the oldest search went out',
      );
      expect(await cache.read('d'), isNotNull);

      await prefs.setString(PrefsSearchResultsCache.storeKey, '{not json');
      expect(await cache.read('d'), isNull);
      await cache.write(entry('e'));
      expect(
        await cache.read('e'),
        isNotNull,
        reason: 'a damaged store heals on the next write',
      );

      await cache.clear();
      expect(prefs.getString(PrefsSearchResultsCache.storeKey), isNull);
    });
  });

  group('offline-first repository', () {
    late FakeCatalogue net;
    late MemorySearchResultsCache cache;
    late OfflineFirstSearchRepository repo;
    setUp(() {
      net = FakeCatalogue(jobs: [job('1'), job('2')]);
      cache = MemorySearchResultsCache(now: () => t0);
      repo = OfflineFirstSearchRepository(
        net,
        cache,
        now: () => t0,
        networkTimeout: const Duration(milliseconds: 200),
      );
    });

    test(
      'online: answers from the catalogue and keeps the page; the cache never answers while the catalogue does',
      () async {
        final r = await repo.search('flutter');
        expect(r.cachedAt, isNull);
        expect(r.jobs, hasLength(2));
        net.jobs = [job('9')];
        final again = await repo.search('flutter');
        expect(again.jobs.single.job.externalId, '9');
        expect(again.cachedAt, isNull);
      },
    );

    test(
      'no connection: the saved page of the SAME search, dated, with no further pages',
      () async {
        await repo.search('flutter');
        net.error = const SocketException('Failed host lookup');
        final r = await repo.search('flutter');
        expect(r.cachedAt, t0);
        expect(r.jobs.map((s) => s.job.externalId), ['1', '2']);
        expect(r.hasMore, isFalse);
        expect(
          r.jobs.first.job.description,
          'Descrição original em português.',
        );
      },
    );

    test(
      'a search never made, another filter, or a later page is NOT answered from the cache: the original error comes back',
      () async {
        await repo.search('flutter');
        net.error = http.ClientException('offline');
        await expectLater(
          repo.search('dart'),
          throwsA(isA<http.ClientException>()),
        );
        await expectLater(
          repo.search(
            'flutter',
            filters: const JobFilters(workModes: {WorkMode.remote}),
          ),
          throwsA(isA<http.ClientException>()),
        );
        await expectLater(
          repo.search('flutter', offset: 20),
          throwsA(isA<http.ClientException>()),
        );
      },
    );

    test(
      'an answer the server gave on purpose (denied, invalid) is not hidden behind the cache',
      () async {
        await repo.search('flutter');
        net.error = const DataFailure(DataFailureKind.denied);
        await expectLater(repo.search('flutter'), throwsA(isA<DataFailure>()));
      },
    );

    test(
      'a catalogue that does not answer in time falls back to the saved page instead of a skeleton',
      () async {
        await repo.search('flutter');
        final slow = _Slow();
        final r2 = OfflineFirstSearchRepository(
          slow,
          cache,
          now: () => t0,
          networkTimeout: const Duration(milliseconds: 50),
        );
        final r = await r2.search('flutter');
        expect(r.cachedAt, t0);
      },
    );

    test(
      'an empty page and "no source" without jobs are not stored (they would hide a recovery)',
      () async {
        net.jobs = [];
        await repo.search('nothing');
        expect(cache.entries, isEmpty);
      },
    );

    test('classification: no connection / service error / other', () {
      expect(
        classifyCatalogueError(TimeoutException('x')),
        CatalogueFailure.offline,
      );
      expect(
        classifyCatalogueError(http.ClientException('x')),
        CatalogueFailure.offline,
      );
      expect(
        classifyCatalogueError(const SocketException('x')),
        CatalogueFailure.offline,
      );
      expect(
        classifyCatalogueError(const DataFailure(DataFailureKind.unavailable)),
        CatalogueFailure.server,
      );
      expect(
        classifyCatalogueError(const DataFailure(DataFailureKind.denied)),
        CatalogueFailure.other,
      );
      expect(classifyCatalogueError(StateError('bug')), CatalogueFailure.other);
    });
  });

  group('Explore', () {
    test(
      'no connection with a saved search: saved results with their date; without one: an offline message, never a generic error',
      () async {
        final net = FakeCatalogue(jobs: [job('1')]);
        final cache = MemorySearchResultsCache(now: () => t0);
        final repo = OfflineFirstSearchRepository(
          net,
          cache,
          now: () => t0,
          networkTimeout: const Duration(milliseconds: 100),
        );
        final cubit = SearchCubit(repo);
        await cubit.search('flutter');
        expect((cubit.state as SearchSuccess).cachedAt, isNull);

        net.error = http.ClientException('offline');
        await cubit.search('flutter');
        final s = cubit.state as SearchSuccess;
        expect(s.cachedAt, t0);
        expect(s.hasMore, isFalse);

        await cubit.search('never searched');
        expect(cubit.state, isA<SearchFailure>());
        expect((cubit.state as SearchFailure).kind, CatalogueFailure.offline);

        net.error = const DataFailure(DataFailureKind.unavailable);
        await cubit.search('never searched either');
        expect((cubit.state as SearchFailure).kind, CatalogueFailure.server);

        net.error = StateError('bug');
        await cubit.search('x2');
        expect((cubit.state as SearchFailure).kind, CatalogueFailure.other);
        await cubit.close();
      },
    );

    test(
      'when the connection returns the saved results are replaced quietly, with no loading state in between',
      () async {
        final net = FakeCatalogue(jobs: [job('1')]);
        final cache = MemorySearchResultsCache(now: () => t0);
        final repo = OfflineFirstSearchRepository(
          net,
          cache,
          now: () => t0,
          networkTimeout: const Duration(milliseconds: 100),
        );
        final cubit = SearchCubit(
          repo,
          reconnectEvery: const Duration(milliseconds: 30),
        );
        final seen = <Type>[];
        final sub = cubit.stream.listen((s) => seen.add(s.runtimeType));
        await cubit.search('flutter');
        net.error = http.ClientException('offline');
        await cubit.search('flutter');
        expect((cubit.state as SearchSuccess).cachedAt, isNotNull);
        seen.clear();
        net.error = null;
        net.jobs = [job('1'), job('7', title: 'Senior Flutter Developer')];
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final s = cubit.state as SearchSuccess;
        expect(s.cachedAt, isNull);
        expect(s.jobs, hasLength(2));
        expect(
          seen,
          isNot(contains(SearchLoading)),
          reason: 'no skeleton flicker on reconnection',
        );
        await sub.cancel();
        await cubit.close();
      },
    );

    test('a failed quiet attempt leaves the saved results alone', () async {
      final net = FakeCatalogue(jobs: [job('1')]);
      final cache = MemorySearchResultsCache(now: () => t0);
      final repo = OfflineFirstSearchRepository(
        net,
        cache,
        now: () => t0,
        networkTimeout: const Duration(milliseconds: 100),
      );
      final cubit = SearchCubit(
        repo,
        reconnectEvery: const Duration(milliseconds: 30),
      );
      await cubit.search('flutter');
      net.error = http.ClientException('offline');
      await cubit.search('flutter');
      final before = cubit.state;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(cubit.state, before);
      await cubit.close();
    });
  });

  group('Home', () {
    test(
      'saved jobs with their date; without any: offline; service error: unavailable',
      () async {
        final net = FakeCatalogue(jobs: [job('1')]);
        final cache = MemorySearchResultsCache(now: () => t0);
        final repo = OfflineFirstSearchRepository(
          net,
          cache,
          now: () => t0,
          networkTimeout: const Duration(milliseconds: 100),
        );
        final cubit = LatestJobsCubit(repo);
        await cubit.load();
        expect(cubit.state.status, LatestStatus.ready);
        expect(cubit.state.cachedAt, isNull);

        net.error = http.ClientException('offline');
        await cubit.load();
        expect(cubit.state.status, LatestStatus.ready);
        expect(cubit.state.cachedAt, t0);
        expect(cubit.state.jobs, hasLength(1));

        final empty = LatestJobsCubit(
          OfflineFirstSearchRepository(
            net,
            MemorySearchResultsCache(),
            networkTimeout: const Duration(milliseconds: 100),
          ),
        );
        await empty.load();
        expect(empty.state.status, LatestStatus.offline);
        net.error = const DataFailure(DataFailureKind.unavailable);
        await empty.load();
        expect(empty.state.status, LatestStatus.unavailable);
        net.error = StateError('bug');
        await empty.load();
        expect(empty.state.status, LatestStatus.failure);
        await cubit.close();
        await empty.close();
      },
    );
  });
}

class _Slow implements SearchRepository {
  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) => Completer<SearchResult>().future;
}
