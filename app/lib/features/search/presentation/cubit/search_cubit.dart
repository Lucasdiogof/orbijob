import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/job_snapshot.dart';
import '../../domain/entities/job_posting.dart';
import '../../domain/job_filters.dart';
import '../../domain/search_repository.dart';

/// Every state carries the active [filters], so the filter bar can render in any of them.
sealed class SearchState extends Equatable {
  const SearchState({this.filters = const JobFilters()});
  final JobFilters filters;
  @override
  List<Object?> get props => [filters];
}

class SearchIdle extends SearchState {
  const SearchIdle({super.filters});
}

class SearchLoading extends SearchState {
  const SearchLoading(this.query, {super.filters});
  final String query;
  @override
  List<Object?> get props => [query, filters];
}

class SearchSuccess extends SearchState {
  const SearchSuccess(
    this.query,
    this.jobs, {
    super.filters,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });
  final String query;
  final List<ScoredJob> jobs;

  /// The catalogue has more jobs after these (the next page can be requested).
  final bool hasMore;
  final bool loadingMore;

  /// The last "show more" failed; [jobs] keeps what was already loaded.
  final bool loadMoreFailed;

  SearchSuccess copyWith({
    List<ScoredJob>? jobs,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) => SearchSuccess(
    query,
    jobs ?? this.jobs,
    filters: filters,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );

  @override
  List<Object?> get props => [
    query,
    jobs,
    filters,
    hasMore,
    loadingMore,
    loadMoreFailed,
  ];
}

/// An integrated source answered but nothing matched.
class SearchEmpty extends SearchState {
  const SearchEmpty(this.query, {super.filters});
  final String query;
  @override
  List<Object?> get props => [query, filters];
}

class SearchNoSource extends SearchState {
  const SearchNoSource(this.query, {super.filters});
  final String query;
  @override
  List<Object?> get props => [query, filters];
}

class SearchFailure extends SearchState {
  const SearchFailure(this.query, {super.filters});
  final String query;
  @override
  List<Object?> get props => [query, filters];
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._repo, {this.onQuery, this.pageSize = 20})
    : super(const SearchIdle());
  final SearchRepository _repo;
  final int pageSize;

  /// Notified with every non-empty query (feeds the recent-searches list).
  final void Function(String query)? onQuery;

  JobFilters _filters = const JobFilters();
  JobFilters get filters => _filters;

  /// The query of the list on screen; null while nothing has been searched.
  String? _active;
  String? _country;

  /// Rows consumed from the server so far (not [SearchSuccess.jobs].length: invalid rows are skipped on the way).
  int _offset = 0;

  /// Incremented by every new search; a response that belongs to an older one is discarded.
  int _generation = 0;

  Future<void> search(String query, {String? countryCode}) async {
    final q = query.trim();
    if (q.isEmpty) return clear();
    onQuery?.call(q);
    await _start(q, countryCode);
  }

  /// Lists the newest jobs (no text). The only way to see the catalogue without typing a term.
  Future<void> browse() => _start('', null);

  Future<void> _start(String q, String? countryCode) async {
    final gen = ++_generation;
    _active = q;
    _country = countryCode;
    _offset = 0;
    emit(SearchLoading(q, filters: _filters));
    try {
      final r = await _repo.search(
        q,
        countryCode: countryCode,
        filters: _filters,
        limit: pageSize,
      );
      if (gen != _generation) return;
      _offset = r.consumed;
      if (!r.hasIntegratedSource) {
        return emit(SearchNoSource(q, filters: _filters));
      }
      if (r.jobs.isEmpty && !r.hasMore) {
        return emit(SearchEmpty(q, filters: _filters));
      }
      emit(
        SearchSuccess(
          q,
          _unique(r.jobs),
          filters: _filters,
          hasMore: r.hasMore,
        ),
      );
    } catch (_) {
      if (gen != _generation) return;
      emit(SearchFailure(q, filters: _filters));
    }
  }

  /// Repeats the last search (the retry button of the error state), keeping filters and country.
  Future<void> retry() async {
    final q = _active;
    if (q == null) return;
    await _start(q, _country);
  }

  /// Applies new filters. If a list is on screen it is reloaded from the first page.
  Future<void> setFilters(JobFilters f) async {
    if (f == _filters) return;
    _filters = f;
    final q = _active;
    if (q == null) return emit(SearchIdle(filters: f));
    await _start(q, _country);
  }

  Future<void> clearFilters() => setFilters(const JobFilters());

  /// Appends the next page. Ignored while one is loading or when there is nothing more.
  Future<void> loadMore() async {
    final s = state;
    final q = _active;
    if (s is! SearchSuccess || !s.hasMore || s.loadingMore || q == null) return;
    final gen = _generation;
    emit(s.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final r = await _repo.search(
        q,
        countryCode: _country,
        filters: _filters,
        offset: _offset,
        limit: pageSize,
      );
      if (gen != _generation) return;
      _offset += r.consumed;
      emit(
        s.copyWith(
          jobs: _unique([...s.jobs, ...r.jobs]),
          hasMore: r.hasMore,
          loadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } catch (_) {
      if (gen != _generation) return;
      emit(s.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  /// A job that shifted onto the next page because the catalogue changed meanwhile is shown once.
  List<ScoredJob> _unique(List<ScoredJob> jobs) {
    final seen = <String>{};
    return [
      for (final j in jobs)
        if (seen.add(jobKey(j.job))) j,
    ];
  }

  void clear() {
    _generation++;
    _active = null;
    _country = null;
    _offset = 0;
    emit(SearchIdle(filters: _filters));
  }
}
