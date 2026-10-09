import 'entities/job_posting.dart';

class SearchResult {
  const SearchResult({required this.jobs, required this.hasIntegratedSource});
  final List<ScoredJob> jobs;

  /// False when no approved connector covers the query (country x profession).
  /// The UI must then say so and offer external search - never fake results.
  final bool hasIntegratedSource;
}

abstract class SearchRepository {
  Future<SearchResult> search(String query, {String? countryCode});
}

/// No connector is wired yet, so the honest answer is "no integrated source".
class NoSourceSearchRepository implements SearchRepository {
  @override
  Future<SearchResult> search(String query, {String? countryCode}) async =>
      const SearchResult(jobs: [], hasIntegratedSource: false);
}
