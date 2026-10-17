import '../../../core/data/data_failure.dart';
import '../domain/entities/job_posting.dart';
import '../domain/health_specialty.dart';
import '../domain/job_area.dart';
import '../domain/job_filters.dart';
import '../domain/search_repository.dart';
import 'search_results_cache.dart';

/// True when [error] means "the device could not reach the catalogue" (no network, timeout, server unavailable or overloaded), as opposed to an answer
/// the server gave on purpose (denied, invalid input, an expired session…).
bool isConnectivityProblem(Object error) {
  final kind = mapDataError(error);
  if (kind == DataFailureKind.network || kind == DataFailureKind.unavailable) {
    return true;
  }
  if (kind != DataFailureKind.unknown) return false;
  final t = error.toString();
  return t.contains('SocketException') ||
      t.contains('Failed host lookup') ||
      t.contains('Connection closed') ||
      t.contains('Connection refused') ||
      t.contains('Network is unreachable') ||
      t.contains('ClientException');
}

/// What went wrong reading the catalogue: no connection or timeout ([CatalogueFailure.offline]), the service answering with an error
/// ([CatalogueFailure.server]) or anything else.
CatalogueFailure classifyCatalogueError(Object error) {
  final kind = mapDataError(error);
  if (kind == DataFailureKind.network) return CatalogueFailure.offline;
  if (kind == DataFailureKind.unavailable) return CatalogueFailure.server;
  return isConnectivityProblem(error)
      ? CatalogueFailure.offline
      : CatalogueFailure.other;
}

/// Reads the catalogue online and keeps the first page of every search that succeeded, so what the person already saw can be opened again without a
/// connection (ORBI-001).
///
/// The rule is narrow on purpose:
/// * the network is ALWAYS tried first; the cache never answers while the catalogue answers (a stale page is never mistaken for a fresh search);
/// * the cache answers only when the catalogue could not be reached ([isConnectivityProblem]) and only for the FIRST page of a search already made
///   (the result says when it was saved, [SearchResult.cachedAt], and has no further pages);
/// * a search never made, or older than the cache's age limit, rethrows the original error: the screen says it needs a connection, it never shows an
///   invented or unrelated list;
/// * only real answers are stored: a page with jobs, or "no integrated source covers this"; an empty page is not stored (it would hide a recovery).
class OfflineFirstSearchRepository
    implements
        SearchRepository,
        AreaCountSource,
        SpecialtyCountSource,
        JobLookup {
  OfflineFirstSearchRepository(
    this._inner,
    this._cache, {
    DateTime Function()? now,
    this.networkTimeout = const Duration(seconds: 10),
  }) : _now = now ?? DateTime.now;

  final SearchRepository _inner;
  final SearchResultsCache _cache;
  final DateTime Function() _now;

  /// How long the catalogue gets to answer before the saved copy (if any) is used: a poor connection must not leave the person on a skeleton.
  final Duration networkTimeout;

  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async {
    final key = searchCacheKey(
      query,
      countryCode: countryCode,
      filters: filters,
    );
    try {
      final r = await _inner
          .search(
            query,
            countryCode: countryCode,
            filters: filters,
            offset: offset,
            limit: limit,
          )
          .timeout(networkTimeout);
      if (offset == 0 && !r.notConfigured && (r.jobs.isNotEmpty)) {
        await _cache.write(
          CachedSearch(
            key: key,
            query: query,
            savedAt: _now().toUtc(),
            jobs: [for (final j in r.jobs) j.job],
            hasIntegratedSource: r.hasIntegratedSource,
          ),
        );
      }
      return r;
    } catch (e) {
      if (offset != 0 || !isConnectivityProblem(e)) rethrow;
      final saved = await _cache.read(key);
      if (saved == null) rethrow;
      return SearchResult(
        jobs: [for (final j in saved.jobs) ScoredJob(j)],
        hasIntegratedSource: saved.hasIntegratedSource,
        cachedAt: saved.savedAt,
      );
    }
  }

  @override
  Future<JobPosting?> jobById(String id) {
    final inner = _inner;
    if (inner is JobLookup) return (inner as JobLookup).jobById(id);
    throw UnsupportedError('this catalogue cannot look a job up by id');
  }

  @override
  Future<Map<JobArea, int>> areaCounts({
    void Function(Map<JobArea, int> soFar)? onPartial,
  }) {
    final inner = _inner;
    if (inner is AreaCountSource) {
      return (inner as AreaCountSource).areaCounts(onPartial: onPartial);
    }
    throw UnsupportedError('this catalogue cannot count areas');
  }

  @override
  Future<Map<HealthSpecialty, int>> specialtyCounts() {
    final inner = _inner;
    if (inner is SpecialtyCountSource) {
      return (inner as SpecialtyCountSource).specialtyCounts();
    }
    throw UnsupportedError('this catalogue cannot count specialties');
  }
}
