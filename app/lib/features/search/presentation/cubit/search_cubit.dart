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
  const SearchLoading();
}

class SearchSuccess extends SearchState {
  const SearchSuccess(this.jobs);
  final List<JobPosting> jobs;
  @override
  List<Object?> get props => [jobs];
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
  SearchCubit(this._repo) : super(const SearchIdle());
  final SearchRepository _repo;

  Future<void> search(String query, {String? countryCode}) async {
    final q = query.trim();
    if (q.isEmpty) return emit(const SearchIdle());
    emit(const SearchLoading());
    try {
      final r = await _repo.search(q, countryCode: countryCode);
      if (!r.hasIntegratedSource) return emit(SearchNoSource(q));
      emit(SearchSuccess(r.jobs));
    } catch (_) {
      emit(SearchFailure(q));
    }
  }
}
