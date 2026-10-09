import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/job_posting.dart';
import '../../domain/search_repository.dart';

sealed class SearchState extends Equatable {
  const SearchState();
  @override
  List<Object?> get props => [];
}

class SearchIdle extends SearchState {
  const SearchIdle();
}

class SearchLoading extends SearchState {
  const SearchLoading(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class SearchSuccess extends SearchState {
  const SearchSuccess(this.query, this.jobs);
  final String query;
  final List<ScoredJob> jobs;
  @override
  List<Object?> get props => [query, jobs];
}

/// An integrated source answered but nothing matched.
class SearchEmpty extends SearchState {
  const SearchEmpty(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class SearchNoSource extends SearchState {
  const SearchNoSource(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class SearchFailure extends SearchState {
  const SearchFailure(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._repo, {this.onQuery}) : super(const SearchIdle());
  final SearchRepository _repo;

  /// Notified with every non-empty query (feeds the recent-searches list).
  final void Function(String query)? onQuery;

  Future<void> search(String query, {String? countryCode}) async {
    final q = query.trim();
    if (q.isEmpty) return emit(const SearchIdle());
    onQuery?.call(q);
    emit(SearchLoading(q));
    try {
      final r = await _repo.search(q, countryCode: countryCode);
      if (!r.hasIntegratedSource) return emit(SearchNoSource(q));
      if (r.jobs.isEmpty) return emit(SearchEmpty(q));
      emit(SearchSuccess(q, r.jobs));
    } catch (_) {
      emit(SearchFailure(q));
    }
  }

  void clear() => emit(const SearchIdle());
}
