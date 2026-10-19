import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/features/search/data/offline_first_search_repository.dart';
import 'package:orbijob/features/search/data/search_results_cache.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';
import 'package:orbijob/features/search/domain/job_filters.dart';
import 'package:orbijob/features/search/domain/search_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ORBI-001: the job a notification points at opens without a connection when it was read before (also ahead of time), and is never served for a job the
/// catalogue says is gone.

JobPosting job(String id) => JobPosting(
  source: 'jobicy',
  externalId: id,
  company: 'Acme',
  title: 'Flutter Developer $id',
  originalUrl: 'https://example.com/$id',
  description: 'Texto original.',
);

class Catalogue implements SearchRepository, JobLookup {
  final jobs = <String, JobPosting?>{};
  Object? error;
  int lookups = 0;
  @override
  Future<JobPosting?> jobById(String id) async {
    lookups++;
    if (error != null) throw error!;
    return jobs[id];
  }

  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async => const SearchResult(jobs: [], hasIntegratedSource: true);
}

void main() {
  final t0 = DateTime.utc(2026, 10, 19, 12);

  test('read online it is kept; offline the kept copy opens; never read it rethrows', () async {
    final net = Catalogue()..jobs['u1'] = job('1');
    final cache = MemorySearchResultsCache(now: () => t0);
    final repo = OfflineFirstSearchRepository(
      net,
      cache,
      now: () => t0,
      networkTimeout: const Duration(milliseconds: 100),
    );
    expect((await repo.jobById('u1'))!.title, 'Flutter Developer 1');

    net.error = http.ClientException('offline');
    final back = await repo.jobById('u1');
    expect(back!.description, 'Texto original.');
    await expectLater(
      repo.jobById('never-read'),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('a job the catalogue no longer shows is null and is NOT served from the copy afterwards (it must not look open)', () async {
    final net = Catalogue()..jobs['u1'] = job('1');
    final cache = MemorySearchResultsCache(now: () => t0);
    final repo = OfflineFirstSearchRepository(
      net,
      cache,
      now: () => t0,
      networkTimeout: const Duration(milliseconds: 100),
    );
    await repo.jobById('u1');
    net.jobs['u1'] = null;
    expect(await repo.jobById('u1'), isNull);
  });

  test(
    'an answer the server gave on purpose is not hidden behind the copy',
    () async {
      final net = Catalogue()..jobs['u1'] = job('1');
      final repo = OfflineFirstSearchRepository(
        net,
        MemorySearchResultsCache(now: () => t0),
        now: () => t0,
        networkTimeout: const Duration(milliseconds: 100),
      );
      await repo.jobById('u1');
      net.error = const DataFailure(DataFailureKind.denied);
      await expectLater(repo.jobById('u1'), throwsA(isA<DataFailure>()));
    },
  );

  test('prefetch keeps up to ten jobs ahead of time and stops quietly at the first failure', () async {
    final net = Catalogue();
    for (var i = 1; i <= 12; i++) {
      net.jobs['u$i'] = job('$i');
    }
    final cache = MemorySearchResultsCache(now: () => t0);
    final repo = OfflineFirstSearchRepository(
      net,
      cache,
      now: () => t0,
      networkTimeout: const Duration(milliseconds: 100),
    );
    await repo.prefetchJobs([for (var i = 1; i <= 12; i++) 'u$i']);
    expect(net.lookups, 10);
    expect(cache.jobs.keys, containsAll(['u1', 'u10']));
    expect(cache.jobs.containsKey('u11'), isFalse);

    net.error = http.ClientException('offline');
    net.lookups = 0;
    await repo.prefetchJobs(['u1', 'u2']); // offline: no throw, no retry storm
    expect(net.lookups, 1);
  });

  test('on the device: kept per id, bounded, expiring, damaged data ignored, removed with the rest at sign-out', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = t0;
    final cache = PrefsSearchResultsCache(prefs, now: () => now);
    for (var i = 0; i < PrefsSearchResultsCache.maxJobs + 5; i++) {
      await cache.writeJob(CachedJob(id: 'u$i', savedAt: now, job: job('$i')));
    }
    expect(await cache.readJob('u0'), isNull, reason: 'the oldest went out');
    expect(
      (await cache.readJob('u${PrefsSearchResultsCache.maxJobs + 4}'))!
          .job
          .title,
      contains('Flutter'),
    );
    now = t0.add(const Duration(days: 15));
    expect(
      await cache.readJob('u${PrefsSearchResultsCache.maxJobs + 4}'),
      isNull,
      reason: 'older than 14 days is not offered',
    );
    now = t0;
    await prefs.setString(PrefsSearchResultsCache.jobsKey, '{broken');
    expect(await cache.readJob('u1'), isNull);
    await cache.writeJob(CachedJob(id: 'u1', savedAt: now, job: job('1')));
    expect(await cache.readJob('u1'), isNotNull);
    await cache.clear();
    expect(await cache.readJob('u1'), isNull);
  });
}
