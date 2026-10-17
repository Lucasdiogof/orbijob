import 'entities/job_posting.dart';
import 'health_specialty.dart';
import 'job_area.dart';
import 'job_filters.dart';

class SearchResult {
  const SearchResult({
    required this.jobs,
    required this.hasIntegratedSource,
    this.hasMore = false,
    this.notConfigured = false,
    this.cachedAt,
    int? consumed,
  }) : _consumed = consumed; // ignore: prefer_initializing_formals
  final List<ScoredJob> jobs;

  /// False when no approved connector covers the query (country x profession).
  /// The UI must then say so and offer external search - never fake results.
  final bool hasIntegratedSource;

  /// Another page exists after this one.
  final bool hasMore;

  /// The build has no backend configuration at all (no SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY). Different from
  /// [hasIntegratedSource] = false (the backend answered that no source covers the query) and from an empty list.
  final bool notConfigured;

  /// Set when the catalogue could not be reached and this is the saved first page of the same search (ORBI-001): the moment it was saved. Such a
  /// result has no further pages. Null for anything the catalogue answered just now.
  final DateTime? cachedAt;

  /// Server rows this page used up. Differs from `jobs.length` when invalid rows were skipped, and is what the next
  /// request's `offset` must advance by.
  int get consumed => _consumed ?? jobs.length;
  final int? _consumed;
}

/// Why the catalogue could not be read, as far as the person needs to tell: no connection (or a timeout), the service not answering, or anything else.
enum CatalogueFailure { offline, server, other }

abstract class SearchRepository {
  /// [query] may be empty to browse the newest jobs. Pages are [limit] jobs starting at [offset], in a stable order.
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  });
}

/// Repositories that can fetch one catalogue job by its id (a notification points at a job this way).
abstract interface class JobLookup {
  /// The job, or null when it is no longer shown (closed, removed, not verified recently).
  Future<JobPosting?> jobById(String id);
}

/// Repositories that can say how many open jobs each [JobArea] has (one count request per area).
abstract interface class AreaCountSource {
  /// [onPartial] receives the counts known so far each time one more area is counted, so the screen need not wait for the slowest.
  Future<Map<JobArea, int>> areaCounts({
    void Function(Map<JobArea, int> soFar)? onPartial,
  });
}

/// Repositories that can count open jobs per [HealthSpecialty] (asked only when the Health area is opened).
abstract interface class SpecialtyCountSource {
  Future<Map<HealthSpecialty, int>> specialtyCounts();
}

/// A build started without the backend configuration. It must not claim "no source covers this search": it says the build
/// is not connected, so a developer who forgot `--dart-define-from-file` sees the real cause.
class UnconfiguredSearchRepository implements SearchRepository {
  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async => const SearchResult(
    jobs: [],
    hasIntegratedSource: false,
    notConfigured: true,
  );
}

/// No connector is wired yet, so the honest answer is "no integrated source".
class NoSourceSearchRepository implements SearchRepository {
  @override
  Future<SearchResult> search(
    String query, {
    String? countryCode,
    JobFilters filters = const JobFilters(),
    int offset = 0,
    int limit = 20,
  }) async => const SearchResult(jobs: [], hasIntegratedSource: false);
}
