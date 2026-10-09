import 'entities/job_posting.dart';
import 'job_filters.dart';

class SearchResult {
  const SearchResult({
    required this.jobs,
    required this.hasIntegratedSource,
    this.hasMore = false,
    int? consumed,
  }) : _consumed = consumed; // ignore: prefer_initializing_formals
  final List<ScoredJob> jobs;

  /// False when no approved connector covers the query (country x profession).
  /// The UI must then say so and offer external search - never fake results.
  final bool hasIntegratedSource;

  /// Another page exists after this one.
  final bool hasMore;

  /// Server rows this page used up. Differs from `jobs.length` when invalid rows were skipped, and is what the next
  /// request's `offset` must advance by.
  int get consumed => _consumed ?? jobs.length;
  final int? _consumed;
}

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
